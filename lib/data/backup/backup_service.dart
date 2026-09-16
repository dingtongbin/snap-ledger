import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';
import '../../core/exceptions.dart';
import '../image_store.dart';
import '../models/models.dart';

/// 备份与恢复。
///
/// 边界设计：
/// - 导出包含全量数据（含软删除记录），格式带 formatVersion/schemaVersion，
///   向前兼容：文件版本比当前新则拒绝恢复并提示升级；
/// - 备份文件为 zip 包：`backup.json` + `attachments/`（图片原字节），
///   图片不压缩重编码，仅容器打包；
/// - 恢复在单事务内“清空+写入”，失败自动回滚，不会留下半截数据；
/// - 行级校验：JSON 结构非法立即失败，不写库。
class BackupService {
  BackupService(this._db);

  final Database _db;

  static const int formatVersion = 3;
  static const String appTag = 'snap-ledger';
  static const String backupDirName = 'SnapLedgerBackup';
  static const String _jsonEntryName = 'backup.json';
  static const String _attachmentsPrefix = 'attachments/';

  // ── 加密容器格式 ──
  // 文件布局：magic(6) + salt(16) + nonce(12) + mac(16) + AES-256-GCM(zip 字节)。
  // 密钥由 PBKDF2-HMAC-SHA256(密码, salt, 12 万轮) 派生；密码不落盘。
  // 无密码导出 = 明文 zip（不带 magic 头），恢复时按头部自动识别。
  static final List<int> _magic = utf8.encode('BSJENC');
  static const int _saltLen = 16;
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int _pbkdf2Rounds = 120000;

  static bool _isEncrypted(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// 用密码加密 zip 字节，返回容器完整字节（含 magic 头）。
  static Future<Uint8List> _encryptZip(
    List<int> zipBytes,
    String password,
  ) async {
    final algo = AesGcm.with256bits();
    final salt = _randomBytes(_saltLen);
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Rounds,
      bits: 256,
    );
    final keyBytes = await (await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    )).extractBytes();
    final box = await algo.encrypt(
      zipBytes,
      secretKey: SecretKey(keyBytes),
    );
    final out = BytesBuilder();
    out.add(_magic);
    out.add(salt);
    out.add(box.nonce);
    out.add(box.mac.bytes);
    out.add(box.cipherText);
    return out.toBytes();
  }

  /// 解开加密容器，返回内层 zip 字节。密码错误 / 数据损坏抛异常。
  static Future<Uint8List> _decryptZip(
    List<int> bytes,
    String password,
  ) async {
    if (bytes.length < _magic.length + _saltLen + _nonceLen + _macLen) {
      throw const AppException('备份文件已损坏');
    }
    final salt = bytes.sublist(_magic.length, _magic.length + _saltLen);
    final nonceStart = _magic.length + _saltLen;
    final nonce = bytes.sublist(nonceStart, nonceStart + _nonceLen);
    final macStart = nonceStart + _nonceLen;
    final mac = bytes.sublist(macStart, macStart + _macLen);
    final cipher = bytes.sublist(macStart + _macLen);

    final algo = AesGcm.with256bits();
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Rounds,
      bits: 256,
    );
    final keyBytes = await (await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    )).extractBytes();
    try {
      final clear = await algo.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(keyBytes),
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      throw const AppException('密码错误，或备份文件已损坏');
    }
  }

  static Uint8List _randomBytes(int len) {
    final r = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(len, (_) => r.nextInt(256)),
    );
  }

  /// 判断备份文件是否加密（供 UI 决定是否先弹密码框）。
  static Future<bool> isEncryptedFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return false;
    final head = await f.openRead(0, _magic.length).fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    return _isEncrypted(head);
  }

  /// 生成 JSON 备份字符串（attachments 路径记录在案，调用方负责落盘）。
  Future<String> exportJson() async {
    final data = {
      'app': appTag,
      'formatVersion': formatVersion,
      'schemaVersion': AppDatabase.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': await _db.query('categories', orderBy: 'id'),
      'accounts': await _db.query('accounts', orderBy: 'id'),
      'ledgers': await _db.query('ledgers', orderBy: 'id'),
      'transactions': await _db.query('transactions', orderBy: 'id'),
      'attachments': await _db.query('attachments', orderBy: 'tx_id, sort'),
    };
    return jsonEncode(data);
  }

  /// 导出完整备份（zip：backup.json + attachments 图片）到文档目录，
  /// 返回文件绝对路径。
  ///
  /// [password] 非空时整体 AES-256-GCM 加密（文件扩展名 .zip 不变，
  /// 内容为加密容器）；为空则输出明文 zip，恢复时自动识别。
  Future<String> exportBackupToFile({String? password}) async {
    final dir = await _ensureBackupDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(RegExp(r'[:T]'), '-');
    final suffix = (password != null && password.isNotEmpty) ? '.加密' : '';
    final outPath = p.join(dir, 'snap-ledger_$stamp$suffix.zip');

    final archive = Archive();
    // 1. backup.json
    final jsonBytes = utf8.encode(await exportJson()).toList();
    archive.addFile(
      ArchiveFile(_jsonEntryName, jsonBytes.length, jsonBytes),
    );
    // 2. attachments：按文件名原样打包（时间戳名，无路径穿越风险）。
    for (final f in await ImageStore.listAll()) {
      final bytes = await f.readAsBytes();
      archive.addFile(
        ArchiveFile('$_attachmentsPrefix${p.basename(f.path)}', bytes.length, bytes),
      );
    }
    var payload = ZipEncoder().encode(archive)!.toList();
    if (password != null && password.isNotEmpty) {
      payload = await _encryptZip(payload, password);
    }
    final output = File(outPath);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(payload, flush: true);
    return outPath;
  }

  /// 兼容旧入口：仅导出 JSON 字符串（不含图片）。
  Future<String> exportJsonToFile() async {
    final dir = await _ensureBackupDir();
    final name =
        'snap-ledger_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(RegExp(r'[:T]'), '-')}.json';
    final file = p.join(dir, name);
    await _write(file, await exportJson());
    return file;
  }

  /// 恢复备份文件：自动识别明文 zip / 加密容器。
  /// [password] 仅在文件加密时需要；密码错误抛 AppException。
  Future<RestoreResult> restoreZipFile(
    String zipPath, {
    String? password,
  }) async {
    final raw = await File(zipPath).readAsBytes();
    final Uint8List bytes;
    if (_isEncrypted(raw)) {
      final pw = password;
      if (pw == null || pw.isEmpty) {
        throw const AppException('该备份已加密，请输入密码');
      }
      bytes = await _decryptZip(raw, pw);
    } else {
      bytes = raw;
    }
    final archive = ZipDecoder().decodeBytes(bytes);

    final jsonEntry = archive.findFile(_jsonEntryName);
    if (jsonEntry == null) {
      throw const AppException('备份包缺少 backup.json');
    }
    final json = utf8.decode(jsonEntry.content as List<int>);

    // 先把图片解到临时目录，入库成功后再持久化。
    final tempDir = await Directory.systemTemp.createTemp('bk_restore');
    final restoredImages = <String, String>{}; // zip内文件名 -> 本地新路径
    try {
      for (final entry in archive) {
        if (entry.isFile &&
            entry.name.startsWith(_attachmentsPrefix) &&
            !entry.name.contains('..')) {
          final name = p.basename(entry.name);
          if (name.isEmpty) continue;
          final tempFile = File(p.join(tempDir.path, name));
          await tempFile.writeAsBytes(entry.content as List<int>, flush: true);
          restoredImages[name] = tempFile.path;
        }
      }
      final result = await restoreJson(json, imageTempMap: restoredImages);
      return result;
    } finally {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  }

  Future<RestoreResult> restoreJson(
    String json, {
    Map<String, String>? imageTempMap,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const AppException('备份文件不是合法的 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppException('备份文件格式不正确');
    }
    if (decoded['app'] != appTag) {
      throw const AppException('这不是随手记账的备份文件');
    }
    final fv = decoded['formatVersion'];
    if (fv is! int || fv > formatVersion) {
      throw const AppException('备份版本过新，请先升级应用');
    }
    final sv = decoded['schemaVersion'];
    if (sv is! int || sv > AppDatabase.schemaVersion) {
      throw const AppException('备份数据库版本过新，请先升级应用');
    }
    for (final key in const ['categories', 'accounts', 'transactions']) {
      if (decoded[key] is! List) throw AppException('备份缺少 $key 数据');
    }
    // 在闭包外提取，避免类型提升在闭包内失效。
    final catRows = decoded['categories'] as List;
    final accRows = decoded['accounts'] as List;
    final txRows = decoded['transactions'] as List;
    final attRows = decoded['attachments'] is List
        ? decoded['attachments'] as List
        : <Object?>[];
    // v2 及更早的备份没有账本数据：恢复后保证默认账本存在。
    final ledgerRows = decoded['ledgers'] is List
        ? decoded['ledgers'] as List
        : null;

    // 恢复图片：把 zip 里的临时文件写入本地 attachments，
    // 建立「旧路径 -> 新路径」映射。
    final oldToNew = <String, String>{};
    for (final row in attRows) {
      if (row is! Map) continue;
      final oldPath = row['path']?.toString();
      if (oldPath == null || oldPath.isEmpty) continue;
      final name = p.basename(oldPath);
      final tempPath = imageTempMap?[name];
      if (tempPath == null) continue;
      final newPath = await ImageStore.importFromTemp(File(tempPath));
      oldToNew[oldPath] = newPath;
    }

    var cats = 0, accs = 0, txs = 0;
    await _db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('attachments');
      await txn.delete('ledgers');
      cats = await _insertAll(txn, 'categories', catRows);
      accs = await _insertAll(txn, 'accounts', accRows);
      txs = await _insertAll(txn, 'transactions', txRows);
      if (ledgerRows != null) {
        await _insertAll(txn, 'ledgers', ledgerRows);
      } else {
        // 旧备份无账本：幂等补默认账本（账单 ledger_id 默认 1）。
        await txn.insert('ledgers', {
          'id': 1,
          'name': '默认账本',
          'iconCode': Icons.menu_book.codePoint,
          'colorValue': 0xFF409EFF,
          'sort': 0,
          'deleted': 0,
          'builtin': 1,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // attachments 表：路径映射到本地新路径。
      for (final row in attRows) {
        if (row is! Map) continue;
        final oldPath = row['path']?.toString();
        if (oldPath == null) continue;
        final newPath = oldToNew[oldPath];
        if (newPath == null) continue;
        await txn.insert('attachments', {
          'tx_id': row['tx_id'],
          'path': newPath,
          'sort': (row['sort'] as int?) ?? 0,
          'deleted': 0,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      // 恢复的旧备份可能含 type=3 转账记录，统一拆为支出(转账)+收入(转账)。
      await AppDatabase.normalizeTransfers(txn);
    });
    return RestoreResult(categories: cats, accounts: accs, transactions: txs);
  }

  static Future<int> _insertAll(
    DatabaseExecutor txn,
    String table,
    List<Object?> rows,
  ) async {
    var count = 0;
    for (final row in rows) {
      if (row is! Map) throw AppException('备份中 $table 存在非法行');
      await txn.insert(table, Map<String, Object?>.from(row));
      count++;
    }
    return count;
  }

  /// 导出账单 CSV（带 BOM，Excel 打开中文不乱码）。金额以“元”呈现便于阅读。
  Future<String> exportCsvToFile() async {
    final rows = await _db.query(
      'transactions',
      orderBy: 'dateKey DESC, id DESC',
    );
    final buf = StringBuffer('\uFEFF');
    buf.writeln('id,类型,金额(元),日期,备注,账本ID,账户ID,分类ID,转入账户ID,已删除,创建时间');
    for (final r in rows) {
      final yuan = ((r['amount'] as int) / 100).toStringAsFixed(2);
      buf.writeln(
        [
          r['id'],
          (r['type'] as int) == 1
              ? '支出'
              : ((r['type'] as int) == 2 ? '收入' : '转账'),
          yuan,
          r['dateKey'],
          _csv(r['note']),
          r['ledger_id'],
          r['accountId'],
          r['categoryId'],
          r['targetAccountId'],
          ((r['deleted'] as int?) ?? 0) == 1 ? '是' : '否',
          r['createdAt'],
        ].join(','),
      );
    }
    final dir = await _ensureBackupDir();
    final name =
        'snap-ledger_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
    final file = p.join(dir, name);
    await _write(file, buf.toString());
    return file;
  }

  static String _csv(Object? v) {
    final s = v?.toString() ?? '';
    if (RegExp(r'[",\n\r]').hasMatch(s)) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Future<String> _ensureBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, backupDirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static Future<void> _write(String path, String content) async {
    final f = File(path);
    await f.writeAsString(content, flush: true);
  }
}
