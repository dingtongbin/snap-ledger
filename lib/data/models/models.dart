import 'package:flutter/material.dart';

import '../../core/exceptions.dart';
import '../default_data.dart';

/// 交易类型：1 支出 / 2 收入 / 3 转账。以固定整数码入库，保证向后兼容。
enum TxType {
  expense(1),
  income(2),
  transfer(3);

  const TxType(this.code);

  final int code;

  static TxType fromCode(int code) => TxType.values.firstWhere(
    (e) => e.code == code,
    orElse: () => throw AppException('未知账单类型: $code'),
  );
}

/// 账本。账单归属某一账本；查询可按账本过滤或聚合全部账本。
/// 默认账本（id=1）内置不可删除；删除账本要求其下无账单。
class LedgerBook {
  const LedgerBook({
    this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.sort = 0,
    this.deleted = false,
    this.builtin = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final int? id;
  final String name;

  /// Material 图标 codePoint，避免存储 IconData 对象。
  final int iconCode;
  final int colorValue;
  final int sort;
  final bool deleted;
  final bool builtin;
  final int createdAt;
  final int updatedAt;

  IconData get icon => AppIcons.of(iconCode);
  Color get color => Color(colorValue);

  static LedgerBook fromMap(Map<String, Object?> m) => LedgerBook(
    id: m['id'] as int?,
    name: m['name'] as String,
    iconCode: m['iconCode'] as int,
    colorValue: m['colorValue'] as int,
    sort: (m['sort'] as int?) ?? 0,
    deleted: ((m['deleted'] as int?) ?? 0) == 1,
    builtin: ((m['builtin'] as int?) ?? 0) == 1,
    createdAt: (m['createdAt'] as int?) ?? 0,
    updatedAt: (m['updatedAt'] as int?) ?? 0,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'iconCode': iconCode,
    'colorValue': colorValue,
    'sort': sort,
    'deleted': deleted ? 1 : 0,
    'builtin': builtin ? 1 : 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// 分类（仅支出/收入两类；转账无分类）。
class TxCategory {
  const TxCategory({
    this.id,
    required this.name,
    required this.kind,
    required this.iconCode,
    required this.colorValue,
    this.sort = 0,
    this.deleted = false,
    this.builtin = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final int? id;
  final String name;

  /// 所属类型，只能是 expense / income。
  final TxType kind;

  /// Material 图标 codePoint，避免存储 IconData 对象。
  final int iconCode;
  final int colorValue;
  final int sort;

  /// 软删除标记：分类允许删除，历史账单通过 id 关联并回退展示，
  /// 因此永不物理删除，也便于未来做回收站/同步。
  final bool deleted;
  final bool builtin;
  final int createdAt;
  final int updatedAt;

  IconData get icon => AppIcons.of(iconCode);
  Color get color => Color(colorValue);

  /// 展示名：分类被软删除后，其历史账单统一显示为「其他」。
  String get displayName => deleted ? '其他' : name;

  static TxCategory fromMap(Map<String, Object?> m) => TxCategory(
    id: m['id'] as int?,
    name: m['name'] as String,
    kind: TxType.fromCode(m['kind'] as int),
    iconCode: m['iconCode'] as int,
    colorValue: m['colorValue'] as int,
    sort: (m['sort'] as int?) ?? 0,
    deleted: ((m['deleted'] as int?) ?? 0) == 1,
    builtin: ((m['builtin'] as int?) ?? 0) == 1,
    createdAt: (m['createdAt'] as int?) ?? 0,
    updatedAt: (m['updatedAt'] as int?) ?? 0,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'kind': kind.code,
    'iconCode': iconCode,
    'colorValue': colorValue,
    'sort': sort,
    'deleted': deleted ? 1 : 0,
    'builtin': builtin ? 1 : 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  TxCategory copyWith({
    String? name,
    int? iconCode,
    int? colorValue,
    int? sort,
    bool? deleted,
    int? updatedAt,
  }) => TxCategory(
    id: id,
    name: name ?? this.name,
    kind: kind,
    iconCode: iconCode ?? this.iconCode,
    colorValue: colorValue ?? this.colorValue,
    sort: sort ?? this.sort,
    deleted: deleted ?? this.deleted,
    builtin: builtin,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// 账户（现金/银行卡/支付宝…）。余额由账单推导，不冗余存储，
/// 避免双写不一致；未来需要期初余额时追加列迁移即可。
class LedgerAccount {
  const LedgerAccount({
    this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.sort = 0,
    this.deleted = false,
    this.builtin = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final int? id;
  final String name;
  final int iconCode;
  final int colorValue;
  final int sort;
  final bool deleted;
  final bool builtin;
  final int createdAt;
  final int updatedAt;

  IconData get icon => AppIcons.of(iconCode);
  Color get color => Color(colorValue);

  static LedgerAccount fromMap(Map<String, Object?> m) => LedgerAccount(
    id: m['id'] as int?,
    name: m['name'] as String,
    iconCode: m['iconCode'] as int,
    colorValue: m['colorValue'] as int,
    sort: (m['sort'] as int?) ?? 0,
    deleted: ((m['deleted'] as int?) ?? 0) == 1,
    builtin: ((m['builtin'] as int?) ?? 0) == 1,
    createdAt: (m['createdAt'] as int?) ?? 0,
    updatedAt: (m['updatedAt'] as int?) ?? 0,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'iconCode': iconCode,
    'colorValue': colorValue,
    'sort': sort,
    'deleted': deleted ? 1 : 0,
    'builtin': builtin ? 1 : 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  LedgerAccount copyWith({
    String? name,
    int? iconCode,
    int? colorValue,
    int? sort,
    bool? deleted,
    int? updatedAt,
  }) => LedgerAccount(
    id: id,
    name: name ?? this.name,
    iconCode: iconCode ?? this.iconCode,
    colorValue: colorValue ?? this.colorValue,
    sort: sort ?? this.sort,
    deleted: deleted ?? this.deleted,
    builtin: builtin,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// 一笔账。金额恒为正整数（分），方向由 [type] 决定：
/// - 支出/收入：categoryId 非空，targetAccountId 恒空；
/// - 转账：categoryId 恒空，accountId -> targetAccountId。
class LedgerTransaction {
  const LedgerTransaction({
    this.id,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    required this.accountId,
    required this.targetAccountId,
    required this.dateKey,
    required this.timestamp,
    required this.note,
    this.ledgerId = 1,
    this.imagePaths = const [],
    this.deleted = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final int? id;
  final TxType type;

  /// 恒为正，单位分。
  final int amountCents;
  final int? categoryId;
  final int accountId;
  final int? targetAccountId;

  /// 归属账本 id；1 = 默认账本。
  final int ledgerId;

  /// 归属日（本地时区 yyyy-MM-dd）。
  final String dateKey;

  /// 毫秒时间戳，同日内排序用；编辑账单日期时保留原值或取新日期零点均可。
  final int timestamp;
  final String? note;

  /// 账单关联的图片绝对路径，按用户上传顺序排列。
  /// 不入库，每次从 [attachments] 表读取后回填。
  final List<String> imagePaths;

  final bool deleted;
  final int createdAt;
  final int updatedAt;

  static LedgerTransaction fromMap(Map<String, Object?> m) => LedgerTransaction(
    id: m['id'] as int?,
    type: TxType.fromCode(m['type'] as int),
    amountCents: m['amount'] as int,
    categoryId: m['categoryId'] as int?,
    accountId: m['accountId'] as int,
    targetAccountId: m['targetAccountId'] as int?,
    dateKey: m['dateKey'] as String,
    timestamp: (m['timestamp'] as int?) ?? 0,
    note: m['note'] as String?,
    ledgerId: (m['ledger_id'] as int?) ?? 1,
    deleted: ((m['deleted'] as int?) ?? 0) == 1,
    createdAt: (m['createdAt'] as int?) ?? 0,
    updatedAt: (m['updatedAt'] as int?) ?? 0,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'type': type.code,
    'amount': amountCents,
    'categoryId': categoryId,
    'accountId': accountId,
    'targetAccountId': targetAccountId,
    'dateKey': dateKey,
    'timestamp': timestamp,
    'note': note,
    'ledger_id': ledgerId,
    'deleted': deleted ? 1 : 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// 仅用于仓储层更新时间戳；账单字段变更请直接构造新实例，
  /// 避免可空参数语义歧义。
  LedgerTransaction copyWith({
    int? updatedAt,
    bool? deleted,
    List<String>? imagePaths,
    int? ledgerId,
  }) => LedgerTransaction(
        id: id,
        type: type,
        amountCents: amountCents,
        categoryId: categoryId,
        accountId: accountId,
        targetAccountId: targetAccountId,
        dateKey: dateKey,
        timestamp: timestamp,
        note: note,
        ledgerId: ledgerId ?? this.ledgerId,
        imagePaths: imagePaths ?? this.imagePaths,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 月度收支汇总（不含转账）。
class MonthSummary {
  const MonthSummary({required this.expenseCents, required this.incomeCents});

  final int expenseCents;
  final int incomeCents;

  int get balanceCents => incomeCents - expenseCents;
}

/// 统计页：某月某分类的合计。
class CategoryStat {
  const CategoryStat({
    required this.categoryId,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    required this.sumCents,
    required this.count,
  });

  final int? categoryId;
  final String name;
  final int iconCode;
  final int colorValue;
  final int sumCents;
  final int count;

  IconData get icon => AppIcons.of(iconCode);
  Color get color => Color(colorValue);
}

/// 趋势图：单月收支。
class MonthTypeStat {
  const MonthTypeStat({
    required this.monthKey,
    required this.expenseCents,
    required this.incomeCents,
  });

  final String monthKey;
  final int expenseCents;
  final int incomeCents;
}

/// 备份恢复结果计数。
class RestoreResult {
  const RestoreResult({
    required this.categories,
    required this.accounts,
    required this.transactions,
  });

  final int categories;
  final int accounts;
  final int transactions;

  @override
  String toString() =>
      '恢复完成：分类 $categories 项，账户 $accounts 个，账单 $transactions 笔';
}

/// 按天分组的账单（记账页按天懒加载分页用）。
class DayGroup {
  DayGroup({required this.dateKey})
    : transactions = [],
      expenseCents = 0,
      incomeCents = 0;

  final String dateKey;

  /// 当日全部账单，时间倒序。
  final List<LedgerTransaction> transactions;

  /// 当日支出小计（不含转账）。
  int expenseCents;

  /// 当日收入小计（不含转账）。
  int incomeCents;
}

/// 每日收支统计（统计页趋势柱状图用）。
class DailyTypeStat {
  const DailyTypeStat({
    required this.dateKey,
    required this.expenseCents,
    required this.incomeCents,
  });

  final String dateKey;
  final int expenseCents;
  final int incomeCents;
}
