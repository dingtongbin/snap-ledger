import 'package:sqflite/sqflite.dart';

import '../../core/exceptions.dart';
import '../../core/strings.dart';
import '../image_store.dart';
import '../models/models.dart';

/// 分类仓储。分类只做软删除：历史账单保留 categoryId，
/// 展示层对已删除分类回退显示「已删除分类」，数据永不丢失语义。
class CategoryRepository {
  CategoryRepository(this._db);

  final Database _db;

  static const int maxNameLength = 12;

  Future<List<TxCategory>> listAll({bool includeDeleted = false}) async {
    final rows = await _db.query(
      'categories',
      where: includeDeleted ? null : 'deleted = 0',
      orderBy: 'kind ASC, sort ASC, id ASC',
    );
    return rows.map(TxCategory.fromMap).toList();
  }

  Future<List<TxCategory>> listByKind(
    TxType kind, {
    bool includeDeleted = false,
  }) async {
    assert(kind != TxType.transfer, '转账没有分类');
    final rows = await _db.query(
      'categories',
      where: 'kind = ?${includeDeleted ? '' : ' AND deleted = 0'}',
      whereArgs: [kind.code],
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(TxCategory.fromMap).toList();
  }

  Future<TxCategory?> byId(int id) async {
    final rows = await _db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TxCategory.fromMap(rows.first);
  }

  Future<int> create({
    required String name,
    required TxType kind,
    required int iconCode,
    required int colorValue,
  }) async {
    final n = await _validateName(name);
    await _ensureUnique(n, kind);
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxSort = Sqflite.firstIntValue(
      await _db.query(
        'categories',
        columns: ['COALESCE(MAX(sort), 0)'],
        where: 'kind = ?',
        whereArgs: [kind.code],
      ),
    );
    return _db.insert('categories', {
      'name': n,
      'kind': kind.code,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'sort': (maxSort ?? 0) + 1,
      'deleted': 0,
      'builtin': 0,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> update(
    TxCategory category, {
    required String name,
    required int iconCode,
    required int colorValue,
  }) async {
    final id = category.id;
    if (id == null) throw const AppException('分类不存在');
    final n = await _validateName(name);
    await _ensureUnique(n, category.kind, excludeId: id);
    await _db.update(
      'categories',
      {
        'name': n,
        'iconCode': iconCode,
        'colorValue': colorValue,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除。已被账单引用也允许删除（历史账单回退展示），
  /// 这样用户可以清理不需要的分类而不破坏账本完整性。
  Future<void> softDelete(int id) async {
    await _db.update(
      'categories',
      {'deleted': 1, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countByCategory(
    int categoryId, {
    bool includeDeleted = false,
  }) async {
    return Sqflite.firstIntValue(
          await _db.query(
            'transactions',
            columns: ['COUNT(*)'],
            where: 'categoryId = ?${includeDeleted ? '' : ' AND deleted = 0'}',
            whereArgs: [categoryId],
          ),
        ) ??
        0;
  }

  Future<String> _validateName(String raw) async {
    final n = raw.trim();
    if (n.isEmpty) throw const AppException('分类名不能为空');
    if (n.length > maxNameLength) {
      throw const AppException('分类名不能超过 $maxNameLength 个字');
    }
    return n;
  }

  Future<void> _ensureUnique(String name, TxType kind, {int? excludeId}) async {
    final cnt = Sqflite.firstIntValue(
      await _db.query(
        'categories',
        columns: ['COUNT(*)'],
        where:
            'deleted = 0 AND kind = ? AND name = ?${excludeId != null ? ' AND id != ?' : ''}',
        whereArgs: excludeId != null
            ? [kind.code, name, excludeId]
            : [kind.code, name],
      ),
    );
    if ((cnt ?? 0) > 0) throw const AppException('已存在同名分类');
  }
}

/// 账户仓储。删除保护：账户被任何账单/转账引用时拒绝删除，
/// 防止账单变成“无主”数据破坏余额口径。
class AccountRepository {
  AccountRepository(this._db);

  final Database _db;

  static const int maxNameLength = 12;

  Future<List<LedgerAccount>> listAll({bool includeDeleted = false}) async {
    final rows = await _db.query(
      'accounts',
      where: includeDeleted ? null : 'deleted = 0',
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(LedgerAccount.fromMap).toList();
  }

  Future<LedgerAccount?> byId(int id) async {
    final rows = await _db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : LedgerAccount.fromMap(rows.first);
  }

  Future<int> create({
    required String name,
    required int iconCode,
    required int colorValue,
  }) async {
    final n = await _validateName(name);
    await _ensureUnique(n);
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxSort = Sqflite.firstIntValue(
      await _db.query('accounts', columns: ['COALESCE(MAX(sort), 0)']),
    );
    return _db.insert('accounts', {
      'name': n,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'sort': (maxSort ?? 0) + 1,
      'deleted': 0,
      'builtin': 0,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> update(
    LedgerAccount account, {
    required String name,
    required int iconCode,
    required int colorValue,
  }) async {
    final id = account.id;
    if (id == null) throw const AppException('账户不存在');
    final n = await _validateName(name);
    await _ensureUnique(n, excludeId: id);
    await _db.update(
      'accounts',
      {
        'name': n,
        'iconCode': iconCode,
        'colorValue': colorValue,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDelete(int id) async {
    final used = Sqflite.firstIntValue(
      await _db.query(
        'transactions',
        columns: ['COUNT(*)'],
        where: 'deleted = 0 AND (accountId = ? OR targetAccountId = ?)',
        whereArgs: [id, id],
      ),
    );
    if ((used ?? 0) > 0) {
      throw const AppException('该账户下仍有账单或转账，无法删除');
    }
    await _db.update(
      'accounts',
      {'deleted': 1, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> _validateName(String raw) async {
    final n = raw.trim();
    if (n.isEmpty) throw const AppException('账户名不能为空');
    if (n.length > maxNameLength) {
      throw const AppException('账户名不能超过 $maxNameLength 个字');
    }
    return n;
  }

  Future<void> _ensureUnique(String name, {int? excludeId}) async {
    final cnt = Sqflite.firstIntValue(
      await _db.query(
        'accounts',
        columns: ['COUNT(*)'],
        where:
            'deleted = 0 AND name = ?${excludeId != null ? ' AND id != ?' : ''}',
        whereArgs: excludeId != null ? [name, excludeId] : [name],
      ),
    );
    if ((cnt ?? 0) > 0) throw const AppException('已存在同名账户');
  }
}

/// 账单仓储。所有查询默认过滤软删除数据。
class TransactionRepository {
  TransactionRepository(this._db);

  final Database _db;

  Future<int> create(LedgerTransaction tx) async {
    _validate(tx);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insert(
      'transactions',
      tx.copyWith(updatedAt: now).toMap()
        ..['createdAt'] = now
        ..['updatedAt'] = now,
    );
    await _writeAttachments(id, tx.imagePaths);
    return id;
  }

  Future<void> update(LedgerTransaction tx) async {
    if (tx.id == null) throw const AppException('账单不存在');
    _validate(tx);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'transactions',
      tx.copyWith(updatedAt: now).toMap()..remove('createdAt'),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
    // 全量替换附件：删除旧的物理 + 记录，按当前列表写入。
    await _replaceAttachments(tx.id!, tx.imagePaths);
  }

  /// 把 [txId] 对应的所有附件记录替换为 [paths]；物理文件在调用方
  /// （含编辑流程）已就位，本仓储只管表。
  Future<void> _replaceAttachments(int txId, List<String> paths) async {
    await _db.delete('attachments', where: 'tx_id = ?', whereArgs: [txId]);
    await _writeAttachments(txId, paths);
  }

  Future<void> _writeAttachments(int txId, List<String> paths) async {
    if (paths.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (var i = 0; i < paths.length; i++) {
      batch.insert('attachments', {
        'tx_id': txId,
        'path': paths[i],
        'sort': i,
        'deleted': 0,
        'createdAt': now,
      });
    }
    await batch.commit(noResult: true);
  }

  /// 软删除，配合 UI 的「撤销」与未来的回收站/同步。
  Future<void> softDelete(int id) async {
    await _db.update(
      'transactions',
      {'deleted': 1, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restore(int id) async {
    await _db.update(
      'transactions',
      {'deleted': 0, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 某月全部账单，按日期倒序、同日按时间倒序。
  Future<List<LedgerTransaction>> listByMonth(String monthKey) async {
    final rows = await _db.query(
      'transactions',
      where: 'deleted = 0 AND substr(dateKey, 1, 7) = ?',
      whereArgs: [monthKey],
      orderBy: 'dateKey DESC, timestamp DESC, id DESC',
    );
    final txs = rows.map(LedgerTransaction.fromMap).toList();
    final attMap = await _attachmentMapFor(txs);
    return txs.map((t) => _withAttachments(t, attMap)).toList();
  }

  /// 拉取给定账单集合的附件映射（tx_id -> [path]）。
  Future<Map<int, List<String>>> _attachmentMapFor(
    List<LedgerTransaction> txs,
  ) async {
    final ids = [for (final t in txs) if (t.id != null) t.id!];
    if (ids.isEmpty) return const {};
    final ph = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'attachments',
      columns: ['tx_id', 'path'],
      where: 'deleted = 0 AND tx_id IN ($ph)',
      whereArgs: ids,
      orderBy: 'tx_id ASC, sort ASC',
    );
    final map = <int, List<String>>{};
    for (final r in rows) {
      map.putIfAbsent(r['tx_id'] as int, () => []).add(r['path'] as String);
    }
    return map;
  }

  LedgerTransaction _withAttachments(
    LedgerTransaction tx,
    Map<int, List<String>> map,
  ) {
    final id = tx.id;
    if (id == null) return tx;
    final paths = map[id];
    if (paths == null || paths.isEmpty) return tx;
    return tx.copyWith(imagePaths: paths);
  }

  /// 当日（dateKey）是否已有账单，记账提醒用。
  Future<bool> hasAnyOn(String dateKey) async {
    final rows = await _db.query(
      'transactions',
      where: 'deleted = 0 AND dateKey = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 单日收支汇总（不含转账），今日概览卡用。
  Future<MonthSummary> daySummary(String dateKey) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN type = 1 THEN amount END), 0) AS expense, '
      'COALESCE(SUM(CASE WHEN type = 2 THEN amount END), 0) AS income '
      'FROM transactions WHERE deleted = 0 AND dateKey = ?',
      [dateKey],
    );
    return MonthSummary(
      expenseCents: (rows.first['expense'] as int?) ?? 0,
      incomeCents: (rows.first['income'] as int?) ?? 0,
    );
  }

  /// 按天分页懒加载：日期倒序，返回 [offset, offset + limit) 窗口内的天，
  /// 每天带当日全部账单与收支小计。返回天数少于 limit 即没有更多。
  Future<List<DayGroup>> listDaysPaged({int limit = 15, int offset = 0}) async {
    final dayRows = await _db.rawQuery(
      'SELECT dateKey FROM transactions WHERE deleted = 0 '
      'GROUP BY dateKey ORDER BY dateKey DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    if (dayRows.isEmpty) return const [];
    final keys = [for (final r in dayRows) r['dateKey'] as String];
    final placeholders = List.filled(keys.length, '?').join(',');
    final txRows = await _db.query(
      'transactions',
      where: 'deleted = 0 AND dateKey IN ($placeholders)',
      whereArgs: keys,
      orderBy: 'dateKey DESC, timestamp DESC, id DESC',
    );
    final byDay = <String, DayGroup>{};
    final flat = <LedgerTransaction>[];
    for (final r in txRows) {
      final tx = LedgerTransaction.fromMap(r);
      flat.add(tx);
      final g = byDay.putIfAbsent(
        tx.dateKey,
        () => DayGroup(dateKey: tx.dateKey),
      );
      g.transactions.add(tx);
      switch (tx.type) {
        case TxType.expense:
          g.expenseCents += tx.amountCents;
        case TxType.income:
          g.incomeCents += tx.amountCents;
        case TxType.transfer:
          break;
      }
    }
    // 一次性回填所有账单的附件路径，并重组 DayGroup 列表。
    final attMap = await _attachmentMapFor(flat);
    final result = <DayGroup>[];
    for (final k in keys) {
      final old = byDay[k]!;
      final ng = DayGroup(dateKey: k)
        ..expenseCents = old.expenseCents
        ..incomeCents = old.incomeCents;
      for (final t in old.transactions) {
        ng.transactions.add(_withAttachments(t, attMap));
      }
      result.add(ng);
    }
    return result;
  }

  /// 全局搜索：备注 / 分类名 / 账户名模糊匹配，时间倒序，限制条数防失控。
  Future<List<LedgerTransaction>> search(
    String query, {
    int limit = 200,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final rows = await _db.rawQuery(
      'SELECT t.* FROM transactions t '
      'LEFT JOIN categories c ON c.id = t.categoryId '
      'LEFT JOIN accounts a ON a.id = t.accountId '
      'WHERE t.deleted = 0 '
      'AND (t.note LIKE ? OR c.name LIKE ? OR a.name LIKE ?) '
      'ORDER BY t.dateKey DESC, t.timestamp DESC, t.id DESC LIMIT ?',
      [like, like, like, limit],
    );
    final txs = rows.map(LedgerTransaction.fromMap).toList();
    final attMap = await _attachmentMapFor(txs);
    return [for (final t in txs) _withAttachments(t, attMap)];
  }

  /// 月度收支汇总（不含转账）。
  Future<MonthSummary> monthSummary(String monthKey) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN type = 1 THEN amount END), 0) AS expense, '
      'COALESCE(SUM(CASE WHEN type = 2 THEN amount END), 0) AS income '
      'FROM transactions WHERE deleted = 0 AND substr(dateKey, 1, 7) = ?',
      [monthKey],
    );
    return MonthSummary(
      expenseCents: (rows.first['expense'] as int?) ?? 0,
      incomeCents: (rows.first['income'] as int?) ?? 0,
    );
  }

  /// 统计页：某月按分类聚合（支出或收入）。已删除分类回退名称。
  Future<List<CategoryStat>> categorySums(String monthKey, TxType type) async {
    final rows = await _db.rawQuery(
      '''
      SELECT t.categoryId AS cid, c.name AS name, c.iconCode AS iconCode,
             c.colorValue AS colorValue, SUM(t.amount) AS s, COUNT(t.id) AS cnt
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.categoryId
      WHERE t.deleted = 0 AND t.type = ? AND substr(t.dateKey, 1, 7) = ?
      GROUP BY t.categoryId
      ORDER BY s DESC
      ''',
      [type.code, monthKey],
    );
    return rows.map((r) {
      final sum = (r['s'] as int?) ?? 0;
      return CategoryStat(
        categoryId: r['cid'] as int?,
        name: (r['name'] as String?) ?? S.unknownCategory,
        iconCode: (r['iconCode'] as int?) ?? 0xe5cd /* more_horiz 兜底 */,
        colorValue: (r['colorValue'] as int?) ?? 0xFF9E9E9E,
        sumCents: sum,
        count: (r['cnt'] as int?) ?? 0,
      );
    }).toList();
  }

  /// 趋势：给定月份集合（升序）的收支汇总，缺失月份补零。
  Future<List<MonthTypeStat>> monthlySums(List<String> monthKeys) async {
    if (monthKeys.isEmpty) return const [];
    final ph = List.filled(monthKeys.length, '?').join(', ');
    final rows = await _db.rawQuery(
      'SELECT substr(dateKey, 1, 7) AS m, type, SUM(amount) AS s '
      'FROM transactions WHERE deleted = 0 AND type IN (1, 2) '
      "AND substr(dateKey, 1, 7) IN ($ph) GROUP BY m, type",
      monthKeys,
    );
    final map = <String, MonthTypeStat>{
      for (final k in monthKeys)
        k: MonthTypeStat(monthKey: k, expenseCents: 0, incomeCents: 0),
    };
    for (final r in rows) {
      final m = r['m'] as String;
      final s = (r['s'] as int?) ?? 0;
      final cur = map[m]!;
      map[m] = (r['type'] as int) == 1
          ? MonthTypeStat(
              monthKey: m,
              expenseCents: s,
              incomeCents: cur.incomeCents,
            )
          : MonthTypeStat(
              monthKey: m,
              expenseCents: cur.expenseCents,
              incomeCents: s,
            );
    }
    return monthKeys.map((k) => map[k]!).toList();
  }

  /// 各账户余额（分）：
  /// 余额 = 收入 - 支出 - 转出 + 转入。
  Future<Map<int, int>> accountBalances() async {
    final rows = await _db.rawQuery('''
      SELECT acct, SUM(v) AS b FROM (
        SELECT accountId AS acct,
               CASE WHEN type = 2 THEN amount ELSE -amount END AS v
        FROM transactions WHERE deleted = 0
        UNION ALL
        SELECT targetAccountId AS acct, amount AS v
        FROM transactions WHERE deleted = 0 AND type = 3
      ) GROUP BY acct
    ''');
    return {
      for (final r in rows)
        if (r['acct'] != null) r['acct'] as int: (r['b'] as int?) ?? 0,
    };
  }

  /// 清空全部账单（分类/账户保留）。「清空数据」用，物理删除，需二次确认。
  Future<void> clearAll() async {
    // 物理文件：所有 attachments 路径一并清理。
    final rows = await _db.query('attachments', columns: ['path']);
    final paths = [for (final r in rows) r['path'] as String];
    await _db.delete('transactions');
    await _db.delete('attachments');
    // 延迟加载避免循环依赖。
    // ignore: invalid_use_of_visible_for_testing_member
    await ImageStore.deletePaths(paths);
  }

  /// 备份恢复时按外部给出的物理路径批量写入 attachments。
  /// 用于 zip 恢复后立即回填图片路径（调用方先 importFromBytes 到本地）。
  Future<void> replaceAttachmentsForRestore(
    int txId,
    List<String> paths,
  ) async {
    await _replaceAttachments(txId, paths);
  }

  /// 备份导出：列出全部附件的 (tx_id, path)。
  Future<List<Map<String, Object?>>> listAllAttachments() async {
    return _db.query('attachments', orderBy: 'tx_id ASC, sort ASC');
  }

  void _validate(LedgerTransaction tx) {
    final a = tx.amountCents;
    if (a <= 0) throw const AppException('金额必须大于 0');
    if (a > 9999999999) throw const AppException('金额超出上限');
    if (tx.dateKey.length != 10) throw const AppException('账单日期不合法');
    switch (tx.type) {
      case TxType.expense:
      case TxType.income:
        if (tx.categoryId == null) throw const AppException('请选择分类');
        if (tx.targetAccountId != null) throw const AppException('账单参数不合法');
      case TxType.transfer:
        if (tx.categoryId != null) throw const AppException('账单参数不合法');
        if (tx.targetAccountId == null || tx.targetAccountId == tx.accountId) {
          throw const AppException('转出与转入账户不能相同');
        }
    }
    final note = tx.note;
    if (note != null && note.length > 50) throw const AppException('备注最长 50 字');
  }

  /// 时段收支汇总：dateKey 范围 [from, to) 左闭右开。
  Future<MonthSummary> periodSummary(String from, String to) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN type = 1 THEN amount END), 0) AS expense, '
      'COALESCE(SUM(CASE WHEN type = 2 THEN amount END), 0) AS income '
      'FROM transactions WHERE deleted = 0 AND dateKey >= ? AND dateKey < ?',
      [from, to],
    );
    return MonthSummary(
      expenseCents: (rows.first['expense'] as int?) ?? 0,
      incomeCents: (rows.first['income'] as int?) ?? 0,
    );
  }

  /// 时段内每日收支明细（趋势图数据源）。
  /// [allDates] 为完整日期序列 [from, to)，无交易日自动补零。
  Future<List<DailyTypeStat>> dailySums(
    String from,
    String to, {
    required List<String> allDates,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT dateKey AS d, type, SUM(amount) AS s '
      'FROM transactions WHERE deleted = 0 AND type IN (1, 2) '
      'AND dateKey >= ? AND dateKey < ? GROUP BY d, type ORDER BY d',
      [from, to],
    );
    final map = <String, DailyTypeStat>{};
    for (final r in rows) {
      final dk = r['d'] as String;
      final existing = map[dk];
      final sum = (r['s'] as int?) ?? 0;
      if (r['type'] == 1) {
        map[dk] = DailyTypeStat(
          dateKey: dk,
          expenseCents: sum,
          incomeCents: existing?.incomeCents ?? 0,
        );
      } else {
        map[dk] = DailyTypeStat(
          dateKey: dk,
          expenseCents: existing?.expenseCents ?? 0,
          incomeCents: sum,
        );
      }
    }
    return [
      for (final dk in allDates)
        map[dk] ?? DailyTypeStat(dateKey: dk, expenseCents: 0, incomeCents: 0),
    ];
  }

  /// 时段内按分类聚合（饼图 + 分类列表数据源）。
  Future<List<CategoryStat>> categorySumsForPeriod(
    String from,
    String to,
    TxType type,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT t.categoryId AS cid, c.name AS name, c.iconCode AS iconCode, '
      'c.colorValue AS colorValue, SUM(t.amount) AS s, COUNT(t.id) AS cnt '
      'FROM transactions t '
      'LEFT JOIN categories c ON c.id = t.categoryId '
      'WHERE t.deleted = 0 AND t.type = ? '
      'AND t.dateKey >= ? AND t.dateKey < ? '
      'GROUP BY t.categoryId ORDER BY s DESC',
      [type.code, from, to],
    );
    return rows.map((r) {
      final name = r['name'] as String? ?? S.unknownCategory;
      return CategoryStat(
        categoryId: r['cid'] as int?,
        name: name,
        iconCode: (r['iconCode'] as int?) ?? 0xe5cd,
        colorValue: (r['colorValue'] as int?) ?? 0xFF9E9E9E,
        sumCents: (r['s'] as int?) ?? 0,
        count: (r['cnt'] as int?) ?? 0,
      );
    }).toList();
  }

  /// 某分类在时段内的全部账单（分类明细页用）。
  Future<List<LedgerTransaction>> transactionsByCategory(
    int categoryId,
    String from,
    String to,
    TxType type,
  ) async {
    final rows = await _db.query(
      'transactions',
      where:
          'deleted = 0 AND type = ? AND categoryId = ? '
          'AND dateKey >= ? AND dateKey < ?',
      whereArgs: [type.code, categoryId, from, to],
      orderBy: 'dateKey DESC, timestamp DESC, id DESC',
    );
    final txs = rows.map(LedgerTransaction.fromMap).toList();
    final attMap = await _attachmentMapFor(txs);
    return [for (final t in txs) _withAttachments(t, attMap)];
  }

  /// 时段内按金额降序的账单排行（排行列表用）。
  Future<List<LedgerTransaction>> topTransactions(
    String from,
    String to,
    TxType type, {
    int limit = 50,
  }) async {
    final rows = await _db.query(
      'transactions',
      where: 'deleted = 0 AND type = ? AND dateKey >= ? AND dateKey < ?',
      whereArgs: [type.code, from, to],
      orderBy: 'amount DESC, dateKey DESC, id DESC LIMIT $limit',
    );
    final txs = rows.map(LedgerTransaction.fromMap).toList();
    final attMap = await _attachmentMapFor(txs);
    return [for (final t in txs) _withAttachments(t, attMap)];
  }
}
