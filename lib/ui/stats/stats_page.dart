import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import '../mine/reminder_page.dart';
import 'category_detail_page.dart';
import 'tx_detail_page.dart';

/// 统计页：周报 / 月报 / 年报三模式。
///
/// 两排固定控件（时段切换 + 时间导航 + 收支筛选）+ 五段滚动内容
/// （汇总卡 / 趋势图 / 饼图 / 分类列表 / 排行）。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

// ── 时段模式 ────────────────────────────────────────────────────────────────

enum _Period { week, month, year }

// ── 状态 ────────────────────────────────────────────────────────────────────

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.month;
  TxType _kind = TxType.expense;
  late DateTime _cursor; // 锚定日期：月报=该月1日，周报=该周一，年报=该年1月1日

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursor = DateTime(now.year, now.month); // 默认本月
  }

  /// 当前时段的日期范围 [from, to) 左闭右开。
  (String, String) get _range {
    switch (_period) {
      case _Period.week:
        return DateKeys.weekRange(_cursor);
      case _Period.month:
        return DateKeys.monthRange(DateKeys.monthKey(_cursor));
      case _Period.year:
        return DateKeys.yearRange(
          DateKeys.yearKeyOf(DateKeys.dateKey(_cursor)),
        );
    }
  }

  /// 时段标签，用于第二排左半段显示。
  String get _rangeLabel {
    switch (_period) {
      case _Period.week:
        return DateKeys.weekLabel(DateKeys.dateKey(_cursor));
      case _Period.month:
        return DateKeys.monthLabel(DateKeys.monthKey(_cursor));
      case _Period.year:
        return DateKeys.yearLabel(
          DateKeys.yearKeyOf(DateKeys.dateKey(_cursor)),
        );
    }
  }

  /// 时段天数（日均计算用）。
  int get _rangeDays {
    switch (_period) {
      case _Period.week:
        return 7;
      case _Period.month:
        return DateKeys.daysInMonth(DateKeys.monthKey(_cursor));
      case _Period.year:
        final y = DateKeys.parseDateKey(DateKeys.dateKey(_cursor)).year;
        return DateTime(y + 1).difference(DateTime(y)).inDays;
    }
  }

  /// 前/后翻时段。
  void _shift(int delta) {
    setState(() {
      switch (_period) {
        case _Period.week:
          _cursor = _cursor.add(Duration(days: 7 * delta));
        case _Period.month:
          _cursor = DateTime(_cursor.year, _cursor.month + delta);
        case _Period.year:
          _cursor = DateTime(_cursor.year + delta);
      }
    });
  }

  /// 切换时段模式后，把 cursor 对齐到当前时段。
  void _resetCursor() {
    final now = DateTime.now();
    setState(() {
      _cursor = switch (_period) {
        _Period.week => now.subtract(Duration(days: now.weekday - 1)),
        _Period.month => DateTime(now.year, now.month),
        _Period.year => DateTime(now.year),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final (from, to) = _range;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tabStats),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ReminderPage()),
            ),
            icon: const Icon(Icons.notifications_outlined, size: 20),
            label: Text(S.reminder),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 第一排：周报 / 月报 / 年报 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: UnderlineTabs(
              labels: const ['周报', '月报', '年报'],
              selectedIndex: _period.index,
              onChanged: (i) {
                _period = _Period.values[i];
                _resetCursor();
              },
            ),
          ),
          // ── 第二排：时间导航 + 收支切换 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left, size: 20),
                ),
                Expanded(
                  child: Text(
                    _rangeLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
                const SizedBox(width: 8),
                // 收支切换（紧凑版）
                ToggleButtons(
                  isSelected: [_kind == TxType.expense, _kind == TxType.income],
                  onPressed: (i) => setState(
                    () => _kind = i == 0 ? TxType.expense : TxType.income,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 48,
                  ),
                  children: const [
                    Text('支出', style: TextStyle(fontSize: 13)),
                    Text('收入', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          // ── 滚动内容区 ──
          Expanded(
            child: FutureBuilder<_StatsFullData>(
              key: ValueKey(
                '$_period-${DateKeys.dateKey(_cursor)}-$_kind-${ledger.version}',
              ),
              future: _load(context, from, to),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    title: '加载失败：${snap.error}',
                  );
                }
                final data = snap.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    _SummaryCard(
                      total: data.current,
                      days: _rangeDays,
                      prev: data.prev,
                      kind: _kind,
                    ),
                    const SizedBox(height: 8),
                    _TrendChart(dailySums: data.dailySums, period: _period),
                    const SizedBox(height: 8),
                    _CompositionSection(stats: data.categoryStats, kind: _kind),
                    const SizedBox(height: 8),
                    _CategoryListSection(
                      stats: data.categoryStats,
                      kind: _kind,
                      from: from,
                      to: to,
                    ),
                    if (data.topTxs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _RankingSection(
                        txs: data.topTxs,
                        kind: _kind,
                        categories: data.categories,
                        accounts: data.accounts,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<_StatsFullData> _load(
    BuildContext context,
    String from,
    String to,
  ) async {
    final txRepo = context.read<TransactionRepository>();
    final accRepo = context.read<AccountRepository>();
    final catRepo = context.read<CategoryRepository>();

    // 上期范围（环比用）。
    String prevFrom;
    String prevTo;
    switch (_period) {
      case _Period.week:
        prevFrom = DateKeys.dateKey(
          DateKeys.parseDateKey(from).subtract(const Duration(days: 7)),
        );
        prevTo = from;
      case _Period.month:
        (prevFrom, prevTo) = DateKeys.monthRange(
          DateKeys.shiftMonth(DateKeys.monthKeyOf(from), -1),
        );
      case _Period.year:
        (prevFrom, prevTo) = DateKeys.yearRange(
          (int.parse(DateKeys.yearKeyOf(from)) - 1).toString(),
        );
    }

    // 生成完整日期序列（补零用）。
    final allDates = <String>[];
    var d = DateKeys.parseDateKey(from);
    final end = DateKeys.parseDateKey(to);
    while (d.isBefore(end)) {
      allDates.add(DateKeys.dateKey(d));
      d = d.add(const Duration(days: 1));
    }

    final results = await Future.wait([
      txRepo.periodSummary(from, to), // 0
      txRepo.periodSummary(prevFrom, prevTo), // 1
      txRepo.dailySums(from, to, allDates: allDates), // 2
      txRepo.categorySumsForPeriod(from, to, _kind), // 3
      txRepo.topTransactions(from, to, _kind), // 4
      accRepo.listAll(includeDeleted: true), // 5
      catRepo.listAll(includeDeleted: true), // 6
    ]);
    return _StatsFullData(
      current: results[0] as MonthSummary,
      prev: results[1] as MonthSummary,
      dailySums: results[2] as List<DailyTypeStat>,
      categoryStats: results[3] as List<CategoryStat>,
      topTxs: results[4] as List<LedgerTransaction>,
      accounts: {for (final a in results[5] as List<LedgerAccount>) a.id!: a},
      categories: {for (final c in results[6] as List<TxCategory>) c.id!: c},
    );
  }
}

// ── 数据容器 ────────────────────────────────────────────────────────────────

class _StatsFullData {
  const _StatsFullData({
    required this.current,
    required this.prev,
    required this.dailySums,
    required this.categoryStats,
    required this.topTxs,
    required this.accounts,
    required this.categories,
  });

  final MonthSummary current;
  final MonthSummary prev;
  final List<DailyTypeStat> dailySums;
  final List<CategoryStat> categoryStats;
  final List<LedgerTransaction> topTxs;
  final Map<int, LedgerAccount> accounts;
  final Map<int, TxCategory> categories;
}

// ── 1. 汇总卡片 ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.days,
    required this.prev,
    required this.kind,
  });

  final MonthSummary total;
  final int days;
  final MonthSummary prev;
  final TxType kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amount = kind == TxType.expense
        ? total.expenseCents
        : total.incomeCents;
    final prevAmount = kind == TxType.expense
        ? prev.expenseCents
        : prev.incomeCents;
    final daily = days > 0 ? amount / days : 0;
    final changePct = prevAmount > 0
        ? ((amount - prevAmount) / prevAmount * 100)
        : (amount > 0 ? 100.0 : 0.0);
    final isUp = amount > prevAmount;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _col(
            '${kind == TxType.expense ? "支出" : "收入"}总额',
            Money.format(amount),
            cs,
          ),
          _col('日均', Money.format(daily.round()), cs),
          _col(
            '环比',
            '${isUp
                    ? '↑'
                    : prevAmount == amount
                    ? '→'
                    : '↓'} '
                '${changePct.abs().toStringAsFixed(1)}%',
            cs,
            color: prevAmount == amount
                ? null
                : isUp
                ? (kind == TxType.expense
                      ? const Color(0xFFEF5350)
                      : AppTheme.incomeGreen)
                : (kind == TxType.expense
                      ? AppTheme.incomeGreen
                      : const Color(0xFFEF5350)),
          ),
        ],
      ),
    );
  }

  Widget _col(String label, String value, ColorScheme cs, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. 趋势柱状图 ──────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.dailySums, required this.period});

  final List<DailyTypeStat> dailySums;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period == _Period.year ? '月度趋势' : '每日趋势',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _dot(AppTheme.expenseOrange, '支出'),
              const SizedBox(width: 12),
              _dot(AppTheme.incomeGreen, '收入'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: period == _Period.year
                ? _yearlyBars(context)
                : _dailyBars(context),
          ),
        ],
      ),
    );
  }

  Widget _dailyBars(BuildContext context) {
    // 月报可能有 28-31 根柱，周报 7 根；密集时隔几个显示标签。
    final maxV = _maxValue();
    final labelEvery = dailySums.length > 14 ? 5 : 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < dailySums.length; i++) ...[
          if (i > 0) const SizedBox(width: 1),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _miniBars(dailySums[i], maxV),
                const SizedBox(height: 4),
                if (i % labelEvery == 0)
                  Text(
                    _dayLabel(i),
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _yearlyBars(BuildContext context) {
    // 年报：把 dailySums 按月聚合后显示 12 根柱。
    final monthly = <String, DailyTypeStat>{};
    for (final d in dailySums) {
      final mk = DateKeys.monthKeyOf(d.dateKey);
      final existing = monthly[mk];
      monthly[mk] = DailyTypeStat(
        dateKey: mk,
        expenseCents: (existing?.expenseCents ?? 0) + d.expenseCents,
        incomeCents: (existing?.incomeCents ?? 0) + d.incomeCents,
      );
    }
    final months = monthly.values.toList();
    final maxV = months.fold<int>(
      1,
      (m, s) => math.max(m, math.max(s.expenseCents, s.incomeCents)),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < months.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _miniBars(months[i], maxV),
                const SizedBox(height: 4),
                Text(
                  '${i + 1}月',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  int _maxValue() {
    var m = 1;
    for (final d in dailySums) {
      m = math.max(m, math.max(d.expenseCents, d.incomeCents));
    }
    return m;
  }

  String _dayLabel(int i) {
    final d = DateKeys.parseDateKey(dailySums[i].dateKey);
    switch (period) {
      case _Period.week:
        return ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
      case _Period.month:
        return '${d.day}';
      default:
        return '';
    }
  }

  Widget _miniBars(DailyTypeStat s, int maxV) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(s.expenseCents / maxV, AppTheme.expenseOrange),
        const SizedBox(width: 2),
        _bar(s.incomeCents / maxV, AppTheme.incomeGreen),
      ],
    );
  }

  Widget _bar(double fraction, Color color) => Container(
    width: 8,
    height: math.max(2.0, fraction * 100),
    decoration: BoxDecoration(
      color: fraction <= 0 ? color.withValues(alpha: 0.15) : color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    ),
  );

  Widget _dot(Color c, String label) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

// ── 3. 饼图构成 ────────────────────────────────────────────────────────────

class _CompositionSection extends StatelessWidget {
  const _CompositionSection({required this.stats, required this.kind});

  final List<CategoryStat> stats;
  final TxType kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = stats.fold<int>(0, (s, c) => s + c.sumCents);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${kind == TxType.expense ? "支出" : "收入"}构成',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (stats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '暂无数据',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: DonutChart(
                    slices: [
                      for (final s in stats)
                        (color: s.color, fraction: s.sumCents / total),
                    ],
                    centerLabel: kind == TxType.expense ? '总支出' : '总收入',
                    centerValue: Money.format(total),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Legend(stats: stats, total: total),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.stats, required this.total});

  final List<CategoryStat> stats;
  final int total;

  @override
  Widget build(BuildContext context) {
    final shown = stats.length <= 6 ? stats : stats.sublist(0, 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                CategoryBadge(
                  icon: shown[i].icon,
                  color: shown[i].color,
                  size: 26,
                  iconSize: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    shown[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${(shown[i].sumCents / total * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        if (stats.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '… 另有 ${stats.length - 6} 个分类',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

// ── 4. 分类列表 ────────────────────────────────────────────────────────────

class _CategoryListSection extends StatelessWidget {
  const _CategoryListSection({
    required this.stats,
    required this.kind,
    required this.from,
    required this.to,
  });

  final List<CategoryStat> stats;
  final TxType kind;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${kind == TxType.expense ? "支出" : "收入"}分类',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (stats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '暂无分类数据',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final s in stats)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryDetailPage(
                      categoryName: s.name,
                      icon: s.icon,
                      categoryId: s.categoryId,
                      from: from,
                      to: to,
                      type: kind,
                      totalCents: s.sumCents,
                      count: s.count,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CategoryBadge(
                        icon: s.icon,
                        color: s.color,
                        size: 32,
                        iconSize: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${s.count}笔',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Money.format(s.sumCents),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ── 5. 排行列表 ────────────────────────────────────────────────────────────

class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.txs,
    required this.kind,
    required this.categories,
    required this.accounts,
  });

  final List<LedgerTransaction> txs;
  final TxType kind;
  final Map<int, TxCategory> categories;
  final Map<int, LedgerAccount> accounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${kind == TxType.expense ? "支出" : "收入"}排行',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < txs.length; i++)
            _RankTile(
              rank: i + 1,
              tx: txs[i],
              category: categories[txs[i].categoryId],
              account: accounts[txs[i].accountId],
            ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.rank,
    required this.tx,
    required this.category,
    required this.account,
  });

  final int rank;
  final LedgerTransaction tx;
  final TxCategory? category;
  final LedgerAccount? account;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TxDetailPage(
            tx: tx,
            categoryName: category?.name ?? S.unknownCategory,
            categoryIcon: category?.icon ?? Icons.more_horiz,
            accountName: account?.name ?? '未知账户',
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3
                      ? AppTheme.expenseOrange
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            CategoryBadge(
              icon: category?.icon ?? Icons.more_horiz,
              size: 30,
              iconSize: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? S.unknownCategory,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateKeys.dayLabel(tx.dateKey),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              Money.format(tx.amountCents),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 甜甜圈图（自绘，不引入图表库）。
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
  });

  final List<({Color color, double fraction})> slices;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(slices: slices),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              centerLabel,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              centerValue,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<({Color color, double fraction})> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 14;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt;
    const gap = 0.012;
    var start = -math.pi / 2;
    final hasGap = slices.length > 1;
    for (final s in slices) {
      var sweep = s.fraction * 2 * math.pi;
      if (hasGap) {
        if (sweep > gap * 2) sweep -= gap;
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint..color = s.color,
      );
      start += s.fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices.length != slices.length ||
      oldDelegate.slices.toString() != slices.toString();
}
