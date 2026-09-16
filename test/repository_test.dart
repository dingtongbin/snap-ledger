import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:snap_ledger/core/db/app_database.dart';
import 'package:snap_ledger/core/date_utils.dart';
import 'package:snap_ledger/core/exceptions.dart';
import 'package:snap_ledger/data/backup/backup_service.dart';
import 'package:snap_ledger/data/image_store.dart';
import 'package:snap_ledger/data/models/models.dart';
import 'package:snap_ledger/data/repositories/repositories.dart';

/// 伪造 path_provider 的文档目录（备份/图片端到端测试用）。
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.docs);

  final String docs;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;

  @override
  Future<String?> getApplicationSupportPath() async => docs;
}

void main() {
  // 宿主测试使用 FFI 实现；运行前需保证 sqlite3.dll 可被加载
  //（本工程已放于 tool/，运行时把该目录加入 PATH）。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late CategoryRepository cats;
  late AccountRepository accounts;
  late TransactionRepository txs;
  late LedgerBookRepository books;

  final monthKey = DateKeys.monthKey(DateTime.now());

  setUp(() async {
    db = await AppDatabase.openInMemory();
    cats = CategoryRepository(db);
    accounts = AccountRepository(db);
    txs = TransactionRepository(db);
    books = LedgerBookRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  LedgerTransaction tx(
    TxType type,
    int cents, {
    int? cat,
    int account = 201,
    int? target,
    String? date,
    String? note,
    int ledger = 1,
  }) => LedgerTransaction(
    type: type,
    amountCents: cents,
    categoryId: cat,
    accountId: account,
    targetAccountId: target,
    dateKey: date ?? DateKeys.todayKey(),
    timestamp: DateTime.now().millisecondsSinceEpoch,
    note: note,
    ledgerId: ledger,
  );

  test('种子数据完整且幂等', () async {
    expect((await cats.listByKind(TxType.expense)).length, 18);
    expect((await cats.listByKind(TxType.income)).length, 9);
    expect((await accounts.listAll()).length, 5);
    // 账本种子：默认账本存在且内置。
    final all = await books.listAll();
    expect(all.length, 1);
    expect(all.first.id, 1);
    expect(all.first.name, '默认账本');
    expect(all.first.builtin, isTrue);
  });

  test('月度汇总计入转账标签账单（转账只是普通收支分类）', () async {
    await txs.create(tx(TxType.expense, 10000, cat: 1));
    await txs.create(tx(TxType.income, 5000, cat: 101));
    // 「转账」= 支出(cat:18) + 收入(cat:109)，各 3000 分。
    await txs.create(tx(TxType.expense, 3000, cat: 18, account: 201));
    await txs.create(tx(TxType.income, 3000, cat: 109, account: 202));
    final s = await txs.monthSummary(monthKey);
    expect(s.expenseCents, 13000);
    expect(s.incomeCents, 8000);
    expect(s.balanceCents, -5000);
  });

  test('非法账单在仓储层被拒绝', () async {
    await expectLater(
      txs.create(tx(TxType.expense, 100)),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      txs.create(tx(TxType.expense, 0, cat: 1)),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      txs.create(tx(TxType.expense, -5, cat: 1)),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      txs.create(tx(TxType.transfer, 100, target: 201)),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      txs.create(tx(TxType.expense, 100, cat: 1, note: 'x' * 51)),
      throwsA(isA<AppException>()),
    );
  });

  test('账户余额 = 收入 - 支出（含转账标签账单）', () async {
    await txs.create(tx(TxType.expense, 10000, cat: 1, account: 201));
    await txs.create(tx(TxType.income, 25000, cat: 101, account: 202));
    // 转账 5000：202 支出(cat:18) → 201 收入(cat:109)。
    await txs.create(tx(TxType.expense, 5000, cat: 18, account: 202));
    await txs.create(tx(TxType.income, 5000, cat: 109, account: 201));
    final b = await txs.accountBalances();
    expect(b[201], -5000); // -10000 支出 + 5000 收入(转账)
    expect(b[202], 20000); // +25000 收入 - 5000 支出(转账)
  });

  test('软删除过滤列表与汇总，且可撤销', () async {
    final id = await txs.create(tx(TxType.expense, 10000, cat: 1));
    await txs.softDelete(id);
    expect(await txs.listByMonth(monthKey), isEmpty);
    expect((await txs.monthSummary(monthKey)).expenseCents, 0);
    await txs.restore(id);
    expect((await txs.monthSummary(monthKey)).expenseCents, 10000);
  });

  test('跨月数据互不干扰，趋势按月聚合', () async {
    final prev = '${DateKeys.shiftMonth(monthKey, -1)}-15';
    await txs.create(tx(TxType.expense, 10000, cat: 1, date: prev));
    await txs.create(tx(TxType.expense, 2500, cat: 2));
    expect((await txs.monthSummary(monthKey)).expenseCents, 2500);
    final trend = await txs.monthlySums([
      DateKeys.shiftMonth(monthKey, -1),
      monthKey,
    ]);
    expect(trend[0].expenseCents, 10000);
    expect(trend[1].expenseCents, 2500);

    // 统计页四条时段查询：不带账本与带账本都要能跑（SQL 拼接回归）。
    final today = DateKeys.todayKey();
    final monthRange = DateKeys.monthRange(monthKey);
    final from = monthRange.$1;
    final to = monthRange.$2;
    expect((await txs.periodSummary(from, to)).expenseCents, 2500);
    expect(
      (await txs.periodSummary(from, to, ledgerId: 1)).expenseCents,
      2500,
    );
    final daily = await txs.dailySums(
      from,
      to,
      allDates: [today],
      ledgerId: 1,
    );
    expect(daily.first.expenseCents, 2500);
    final dailyAll = await txs.dailySums(from, to, allDates: [today]);
    expect(dailyAll.first.expenseCents, 2500);
    final catStats = await txs.categorySumsForPeriod(
      from,
      to,
      TxType.expense,
    );
    expect(catStats.first.sumCents, 2500);
    final catStatsB1 = await txs.categorySumsForPeriod(
      from,
      to,
      TxType.expense,
      ledgerId: 1,
    );
    expect(catStatsB1.first.sumCents, 2500);
  });

  test('有账单的账户拒绝删除', () async {
    await txs.create(tx(TxType.expense, 100, cat: 1, account: 201));
    await expectLater(accounts.softDelete(201), throwsA(isA<AppException>()));
    // 转账标签账单（收入 cat:109）同样保护目标账户
    await txs.create(tx(TxType.income, 100, cat: 109, account: 202));
    await expectLater(accounts.softDelete(202), throwsA(isA<AppException>()));
  });

  test('账本：过滤查询、记账归属与删除保护', () async {
    // 建第二个账本，两账本各记一笔。
    final book2 = await books.create(name: '旅行账本', iconCode: 0xe19c, colorValue: 0xFF9E9E9E);
    await txs.create(tx(TxType.expense, 5000, cat: 1, ledger: 1));
    await txs.create(tx(TxType.expense, 2000, cat: 1, ledger: book2));

    // 全部账本聚合。
    expect((await txs.listByMonth(monthKey)).length, 2);
    // 按账本过滤。
    expect((await txs.listByMonth(monthKey, ledgerId: 1)).length, 1);
    expect(
      (await txs.listByMonth(monthKey, ledgerId: book2)).first.amountCents,
      2000,
    );
    // 汇总按账本隔离。
    expect((await txs.monthSummary(monthKey, ledgerId: book2)).expenseCents, 2000);
    expect((await txs.monthSummary(monthKey)).expenseCents, 7000);

    // 有账单的账本拒绝删除；空账本可删；默认账本不可删。
    await expectLater(books.softDelete(book2), throwsA(isA<AppException>()));
    final empty = await books.create(name: '空账本', iconCode: 0xe19c, colorValue: 0xFF9E9E9E);
    await books.softDelete(empty);
    expect((await books.listAll()).length, 2);
    await expectLater(books.softDelete(1), throwsA(isA<AppException>()));

    // dayGroup 按账本过滤。
    final dayKey = DateKeys.todayKey();
    final all = await txs.dayGroup(dayKey);
    expect(all!.transactions.length, 2);
    final onlyB2 = await txs.dayGroup(dayKey, ledgerId: book2);
    expect(onlyB2!.transactions.length, 1);
  });

  test('分类重名校验；软删除后账单仍显示原分类名', () async {
    await cats.create(
      name: '测试',
      kind: TxType.expense,
      iconCode: 1,
      colorValue: 1,
    );
    await expectLater(
      cats.create(name: '测试', kind: TxType.expense, iconCode: 1, colorValue: 1),
      throwsA(isA<AppException>()),
    );
    // 同名但已删除，不冲突
    await cats.softDelete(
      (await cats.listByKind(
        TxType.expense,
      )).firstWhere((c) => c.name == '测试').id!,
    );
    final id = await cats.create(
      name: '测试',
      kind: TxType.expense,
      iconCode: 1,
      colorValue: 1,
    );

    // 软删除保留分类行，历史账单统计归入「其他」展示（产品约定）；
    // 「已删除分类」仅作为 id 完全无对应行时的兜底。
    await txs.create(tx(TxType.expense, 2000, cat: id));
    await cats.softDelete(id);
    final stats = await txs.categorySums(monthKey, TxType.expense);
    expect(stats.single.name, '其他');
    expect(stats.single.sumCents, 2000);

    // 默认分类不能删除；自定义分类可删除。
    await expectLater(cats.softDelete(1), throwsA(isA<AppException>()));
    await expectLater(cats.softDelete(id), completes);
  });

  test('备份导出 -> 恢复往返一致（历史转账自动拆分为收支两条记录）', () async {
    final id1 = await txs.create(tx(TxType.expense, 10000, cat: 1));
    // 模拟旧版 type=3 转账行（直接插入绕过 _validate，用于测试 normalization）。
    await db.insert('transactions', {
      'type': 3,
      'amount': 500,
      'categoryId': null,
      'accountId': 201,
      'targetAccountId': 202,
      'dateKey': DateKeys.todayKey(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'note': null,
      'deleted': 0,
      'createdAt': 0,
      'updatedAt': 0,
    });
    await txs.softDelete(id1);

    final svc = BackupService(db);
    final json = await svc.exportJson();

    await db.delete('transactions');
    final r = await svc.restoreJson(json);
    expect(r.transactions, 2); // 备份原始行数
    // 恢复后 normalization 将 type=3 拆成支出(cat:18)+收入(cat:109)。
    // 软删除的 expense 仍保留 deleted=1，列表不含。
    expect((await txs.listByMonth(monthKey)).length, 2);
    final b = await txs.accountBalances();
    expect(b[201], -500); // 支出(转账) 500
    expect(b[202], 500); // 收入(转账) 500
  });

  test('备份内容校验与版本防护', () async {
    final svc = BackupService(db);
    await expectLater(
      svc.restoreJson('not json'),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      svc.restoreJson('{"app":"other","formatVersion":1,"schemaVersion":1}'),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      svc.restoreJson(
        '{"app":"snap-ledger","formatVersion":99,"schemaVersion":1,'
        '"categories":[],"accounts":[],"transactions":[]}',
      ),
      throwsA(isA<AppException>()),
    );
    // 合法空备份恢复成功
    final r = await svc.restoreJson(
      '{"app":"snap-ledger","formatVersion":1,"schemaVersion":1,'
      '"categories":[],"accounts":[],"transactions":[]}',
    );
    expect(r.transactions, 0);
  });

  test('备份 zip 端到端：加密导出 -> 错误密码拒绝 -> 正确密码恢复（含图片附件）',
      () async {
    // 伪造文档目录到临时文件夹（真实落盘验证）。
    final prevProvider = PathProviderPlatform.instance;
    final docs = await Directory.systemTemp.createTemp('bk_e2e_docs');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    try {
      // 1. 准备一张"图片"（2048 字节伪随机内容）并导入附件库。
      final imgSrc = File(
        '${docs.path}${Platform.pathSeparator}photo.jpg',
      );
      final imgBytes = List<int>.generate(2048, (i) => (i * 31 + 7) % 251);
      await imgSrc.writeAsBytes(imgBytes);
      final savedPath = await ImageStore.importFromFile(imgSrc);
      expect(File(savedPath).readAsBytesSync(), imgBytes);

      // 2. 记一笔带图片的支出（先建后补附件）。
      final txId = await txs.create(
        tx(TxType.expense, 66600, cat: 1, ledger: 1, note: 'e2e'),
      );
      expect(txId, isNotNull);
      final saved = (await txs.listByMonth(monthKey)).first;
      await txs.update(saved.copyWith(imagePaths: [savedPath]));

      // 3. 加密导出。
      final svc = BackupService(db);
      final zipPath = await svc.exportBackupToFile(password: 'secret123');
      final zipFile = File(zipPath);
      expect(await zipFile.exists(), isTrue);
      // 头部为加密容器 magic（BSJENC），且不含明文 JSON 标记。
      final head = await zipFile.openRead(0, 6).fold<List<int>>(
        <int>[],
        (a, c) => a..addAll(c),
      );
      expect(String.fromCharCodes(head), 'BSJENC');
      final rawAll = await zipFile.readAsBytes();
      expect(
        String.fromCharCodes(rawAll).contains('backup.json'),
        isFalse,
        reason: '密文中不应出现明文条目名',
      );

      // 4. 错误密码恢复被拒绝。
      final db2 = await AppDatabase.openInMemory();
      final svc2 = BackupService(db2);
      await expectLater(
        svc2.restoreZipFile(zipPath, password: 'wrong-password'),
        throwsA(isA<AppException>()),
      );

      // 5. 正确密码恢复：数据、账本、图片字节一致。
      final result = await svc2.restoreZipFile(
        zipPath,
        password: 'secret123',
      );
      expect(result.transactions, 1);

      final txs2 = TransactionRepository(db2);
      final restored = await txs2.listByMonth(monthKey);
      expect(restored.length, 1);
      expect(restored.first.amountCents, 66600);
      expect(restored.first.ledgerId, 1);
      expect(restored.first.note, 'e2e');
      // 图片路径已重映射且字节一致。
      expect(restored.first.imagePaths.length, 1);
      final newPath = restored.first.imagePaths.single;
      expect(newPath, isNot(savedPath));
      expect(await File(newPath).exists(), isTrue);
      expect(await File(newPath).readAsBytes(), imgBytes);

      // 账本恢复：默认账本存在。
      final books2 = LedgerBookRepository(db2);
      final allBooks = await books2.listAll();
      expect(allBooks.any((b) => b.builtin && b.id == 1), isTrue);

      await db2.close();
    } finally {
      PathProviderPlatform.instance = prevProvider;
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    }
  });

  test('备份 zip 端到端：无密码明文导出 -> 免密恢复', () async {
    final prevProvider = PathProviderPlatform.instance;
    final docs = await Directory.systemTemp.createTemp('bk_plain_docs');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    try {
      await txs.create(tx(TxType.income, 500, cat: 101));
      final svc = BackupService(db);
      final zipPath = await svc.exportBackupToFile(); // 不加密
      final head = await File(zipPath).openRead(0, 6).fold<List<int>>(
        <int>[],
        (a, c) => a..addAll(c),
      );
      expect(String.fromCharCodes(head), isNot('BSJENC'));

      final db2 = await AppDatabase.openInMemory();
      final result = await BackupService(db2).restoreZipFile(zipPath);
      expect(result.transactions, 1);
      expect(
        (await TransactionRepository(db2).listByMonth(monthKey))
            .first
            .amountCents,
        500,
      );
      await db2.close();
    } finally {
      PathProviderPlatform.instance = prevProvider;
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    }
  });
}
