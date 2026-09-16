import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/default_data.dart';
import 'package:flutter/material.dart' show IconData, Icons;

/// 数据库单例与迁移管理。
///
/// 边界设计：
/// - 版本化迁移（[_onUpgrade]）只允许追加迁移步骤，禁止破坏性变更，
///   保证任意历史版本可逐步升级到当前版本；
/// - 种子数据幂等：仅当表为空时写入，且使用固定 id（见 [DefaultData]），
///   升级/重装/恢复备份都不会重复插入；
/// - 桌面端（Windows/Linux）数据库放在用户应用支持目录，Android/iOS
///   放在系统标准数据库目录，卸载即随应用清理。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  /// 当前数据库 schema 版本。每次变更 schema 必须 +1 并在
  /// [_onUpgrade] 追加迁移分支。备份格式的 schemaVersion 字段用于校验兼容性。
  static const int schemaVersion = 4;

  Database? _db;

  Future<Database> open() async {
    final cached = _db;
    if (cached != null) return cached;
    final dir = await _resolveDbDir();
    await Directory(dir).create(recursive: true);
    final db = await openDatabase(
      p.join(dir, 'bookkeeping.db'),
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _db = db;
    return db;
  }

  /// 供单元测试使用：打开内存库。
  static Future<Database> openInMemory() => openDatabase(
    inMemoryDatabasePath,
    version: schemaVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );

  static Future<String> _resolveDbDir() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return getDatabasesPath();
    }
    final base = await getApplicationSupportDirectory();
    return p.join(base.path, 'databases');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await createSchema(db);
    await seedDefaults(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 → v2：转账从独立类型（type=3）转为支出/收入里的普通标签分类；
    // 历史 type=3 账单自动拆分为「支出(转账)」+「收入(转账)」两条记录。
    if (oldVersion < 2) {
      await _migrateV2(db);
    }
    // v2 → v3：账单支持多图，新增 attachments 表。
    if (oldVersion < 3) {
      await _migrateV3(db);
    }
    // v3 → v4：账本，ledgers 表 + transactions.ledger_id。
    if (oldVersion < 4) {
      await _migrateV4(db);
    }
  }

  /// v4 迁移：新增账本体系。默认账本 id=1 内置；存量账单全部归入默认账本。
  static Future<void> _migrateV4(Database db) async {
    await _createLedgersTable(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'ledgers',
      {
        'id': 1,
        'name': '默认账本',
        'iconCode': Icons.menu_book.codePoint,
        'colorValue': 0xFF409EFF,
        'sort': 0,
        'deleted': 0,
        'builtin': 1,
        'createdAt': now,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final hasLedger = cols.any((c) => c['name'] == 'ledger_id');
    if (!hasLedger) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN ledger_id INTEGER NOT NULL DEFAULT 1',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_ledger ON transactions (ledger_id, deleted)',
    );
  }

  static Future<void> _createLedgersTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        builtin INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// v3 迁移：新增 attachments 表，记录账单图片。
  static Future<void> _migrateV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tx_id INTEGER NOT NULL,
        path TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attachments_tx ON attachments (tx_id, deleted)',
    );
  }

  /// v2 迁移：插入转账标签分类 + 将历史 type=3 拆为两条普通记录。
  static Future<void> _migrateV2(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 幂等插入转账分类（INSERT OR IGNORE，已存在则跳过）。
    await db.insert(
      'categories',
      _seedMap(18, '转账', Icons.swap_horiz, 0xFF78909C, 1, 18, now),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'categories',
      _seedMap(109, '转账', Icons.swap_horiz, 0xFF78909C, 2, 109, now),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await normalizeTransfers(db);
  }

  /// 将所有 type=3（历史转账）账单拆成「支出(转账)」+「收入(转账)」两条记录。
  /// 迁移与备份恢复共享此逻辑，保证数据库内无 type=3 行。
  static Future<void> normalizeTransfers(DatabaseExecutor db) async {
    final rows = await db.query('transactions', where: 'type = 3');
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final r in rows) {
      final id = r['id'] as int;
      final accountId = r['accountId'] as int;
      final targetId = r['targetAccountId'] as int? ?? accountId;
      final amount = r['amount'] as int;
      final dateKey = r['dateKey'] as String;
      final timestamp = r['timestamp'] as int? ?? 0;
      final note = r['note'] as String?;
      final deleted = r['deleted'] as int? ?? 0;
      final createdAt = r['createdAt'] as int? ?? 0;
      final updatedAt = r['updatedAt'] as int? ?? 0;

      // 支出侧：accountId 转出。
      batch.insert('transactions', {
        'type': 1,
        'amount': amount,
        'categoryId': 18,
        'accountId': accountId,
        'targetAccountId': null,
        'dateKey': dateKey,
        'timestamp': timestamp,
        'note': note,
        'deleted': deleted,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
      // 收入侧：targetAccountId 转入。
      batch.insert('transactions', {
        'type': 2,
        'amount': amount,
        'categoryId': 109,
        'accountId': targetId,
        'targetAccountId': null,
        'dateKey': dateKey,
        'timestamp': timestamp,
        'note': note,
        'deleted': deleted,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
      // 删除原始 type=3 行。
      batch.delete('transactions', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind INTEGER NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        builtin INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        builtin INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        categoryId INTEGER,
        accountId INTEGER NOT NULL,
        targetAccountId INTEGER,
        dateKey TEXT NOT NULL,
        timestamp INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        ledger_id INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // 账本：账单归属分组，默认账本 id=1 内置。
    await _createLedgersTable(db);
    // 高频查询路径建索引：按月列账、按分类统计、按账户汇总。
    await db.execute(
      'CREATE INDEX idx_tx_month ON transactions (dateKey, deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_category ON transactions (categoryId, deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_account ON transactions (accountId, deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_ledger ON transactions (ledger_id, deleted)',
    );
    // 账单附件（图片）：通过 tx_id 关联，物理文件存放在应用文档目录。
    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tx_id INTEGER NOT NULL,
        path TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attachments_tx ON attachments (tx_id, deleted)',
    );
  }

  /// 幂等种子：仅当对应表为空时插入默认数据。
  static Future<void> seedDefaults(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var empty =
        Sqflite.firstIntValue(
          await db.query('categories', columns: ['COUNT(*)']),
        ) ==
        0;
    if (empty) {
      final batch = db.batch();
      for (final c in DefaultData.expenseCategories) {
        batch.insert(
          'categories',
          _seedMap(c.id, c.name, c.icon, c.color, 1, c.id, now),
        );
      }
      for (final c in DefaultData.incomeCategories) {
        batch.insert(
          'categories',
          _seedMap(c.id, c.name, c.icon, c.color, 2, c.id, now),
        );
      }
      await batch.commit(noResult: true);
    }
    empty =
        Sqflite.firstIntValue(
          await db.query('accounts', columns: ['COUNT(*)']),
        ) ==
        0;
    if (empty) {
      final batch = db.batch();
      var sort = 0;
      for (final a in DefaultData.accounts) {
        batch.insert('accounts', {
          'id': a.id,
          'name': a.name,
          'iconCode': a.icon.codePoint,
          'colorValue': a.color,
          'sort': sort++,
          'deleted': 0,
          'builtin': 1,
          'createdAt': now,
          'updatedAt': now,
        });
      }
      await batch.commit(noResult: true);
    }
    empty =
        Sqflite.firstIntValue(
          await db.query('ledgers', columns: ['COUNT(*)']),
        ) ==
        0;
    if (empty) {
      await db.insert('ledgers', {
        'id': 1,
        'name': '默认账本',
        'iconCode': Icons.menu_book.codePoint,
        'colorValue': 0xFF409EFF,
        'sort': 0,
        'deleted': 0,
        'builtin': 1,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  static Map<String, Object?> _seedMap(
    int id,
    String name,
    IconData icon,
    int color,
    int kind,
    int sort,
    int now,
  ) => {
    'id': id,
    'name': name,
    'kind': kind,
    'iconCode': icon.codePoint,
    'colorValue': color,
    'sort': sort,
    'deleted': 0,
    'builtin': 1,
    'createdAt': now,
    'updatedAt': now,
  };
}
