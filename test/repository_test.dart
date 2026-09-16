import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bookkeeping/core/db/app_database.dart';
import 'package:bookkeeping/core/date_utils.dart';
import 'package:bookkeeping/core/exceptions.dart';
import 'package:bookkeeping/data/backup/backup_service.dart';
import 'package:bookkeeping/data/models/models.dart';
import 'package:bookkeeping/data/repositories/repositories.dart';

void main() {
  // 宿主测试使用 FFI 实现；运行前需保证 sqlite3.dll 可被加载
  //（本工程已放于 tool/，运行时把该目录加入 PATH）。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late CategoryRepository cats;
  late AccountRepository accounts;
  late TransactionRepository txs;

  final monthKey = DateKeys.monthKey(DateTime.now());

  setUp(() async {
    db = await AppDatabase.openInMemory();
    cats = CategoryRepository(db);
    accounts = AccountRepository(db);
    txs = TransactionRepository(db);
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
  }) => LedgerTransaction(
    type: type,
    amountCents: cents,
    categoryId: cat,
    accountId: account,
    targetAccountId: target,
    dateKey: date ?? DateKeys.todayKey(),
    timestamp: DateTime.now().millisecondsSinceEpoch,
    note: note,
  );

  test('种子数据完整且幂等', () async {
    expect((await cats.listByKind(TxType.expense)).length, 18);
    expect((await cats.listByKind(TxType.income)).length, 9);
    expect((await accounts.listAll()).length, 5);
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
  });

  test('有账单的账户拒绝删除', () async {
    await txs.create(tx(TxType.expense, 100, cat: 1, account: 201));
    await expectLater(accounts.softDelete(201), throwsA(isA<AppException>()));
    // 转账标签账单（收入 cat:109）同样保护目标账户
    await txs.create(tx(TxType.income, 100, cat: 109, account: 202));
    await expectLater(accounts.softDelete(202), throwsA(isA<AppException>()));
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

    // 软删除保留分类行，历史账单统计仍显示原分类名（信息不丢失）；
    // 「已删除分类」仅作为 id 完全无对应行时的兜底。
    await txs.create(tx(TxType.expense, 2000, cat: id));
    await cats.softDelete(id);
    final stats = await txs.categorySums(monthKey, TxType.expense);
    expect(stats.single.name, '测试');
    expect(stats.single.sumCents, 2000);
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
        '{"app":"bookkeeping","formatVersion":99,"schemaVersion":1,'
        '"categories":[],"accounts":[],"transactions":[]}',
      ),
      throwsA(isA<AppException>()),
    );
    // 合法空备份恢复成功
    final r = await svc.restoreJson(
      '{"app":"bookkeeping","formatVersion":1,"schemaVersion":1,'
      '"categories":[],"accounts":[],"transactions":[]}',
    );
    expect(r.transactions, 0);
  });
}
