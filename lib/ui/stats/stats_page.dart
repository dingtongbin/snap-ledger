import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/book_controller.dart';
import '../../state/ui_prefs.dart';
import '../../state/ledger_controller.dart';
import '../widgets/book_picker.dart';
import '../widgets/common.dart';
import '../mine/reminder_page.dart';
import 'category_detail_page.dart';
import 'tx_detail_page.dart';

/// 统计页头部账本选择 chip（与明细页样式一致）。
class _StatsBookChip extends StatelessWidget {
  const _StatsBookChip();

  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookController>();
    final cs = Theme.of(context).colorScheme;
    final label = books.selected?.name ?? '全部账本';
    return InkWell(
      onTap: () => showBookPicker(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 13, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(Icons.expand_more, size: 14, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

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
  _Period _period =
      _Period.values[UiPrefs.getInt('stats.period', _Period.month.index)];
  TxType _kind = TxType
      .values[UiPrefs.getInt('stats.kind', TxType.expense.code)];
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
    final books = context.watch<BookController>();
    final (from, to) = _range;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.tabStats),
            const SizedBox(width: 8),
            const _StatsBookChip(),
          ],
        ),
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
                UiPrefs.setInt('stats.period', i);
                _resetCursor();
              },
            ),
          ),
          // ── 第二排：时间导航 + 收支切换 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                // 时间导航：按钮紧贴文本，整组靠左。
                IconButton(
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left, size: 20),
                ),
                Text(
                  _rangeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
                const Spacer(),
                // 收支切换（紧凑版）
                ToggleButtons(
                  isSelected: [_kind == TxType.expense, _kind == TxType.income],
                  onPressed: (i) => setState(() {
                    _kind = i == 0 ? TxType.expense : TxType.income;
                    UiPrefs.setInt('stats.kind', _kind.code);
                  }),
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
                '$_period-${DateKeys.dateKey(_cursor)}-$_kind-'
                '${ledger.version}-${books.selectedId}',
              ),
              future: _load(context, from, to),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  // 骨架屏：布局与真实内容一致，感知等待更短、不跳动。
                  return const _StatsSkeleton();
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
                      period: _period,
                    ),
                    const SizedBox(height: 8),
                    _TrendChart(dailySums: data.dailySums, period: _period, kind: _kind),
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

    final ledgerId = context.read<BookController>().filterLedgerId;
    final results = await Future.wait([
      txRepo.periodSummary(from, to, ledgerId: ledgerId), // 0
      txRepo.periodSummary(prevFrom, prevTo, ledgerId: ledgerId), // 1
      txRepo.dailySums(
        from,
        to,
        allDates: allDates,
        ledgerId: ledgerId,
      ), // 2
      txRepo.categorySumsForPeriod(from, to, _kind, ledgerId: ledgerId), // 3
      txRepo.topTransactions(from, to, _kind, ledgerId: ledgerId), // 4
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

/// 统计加载骨架：模拟汇总卡 / 趋势图 / 构成区的占位布局。
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? AppColors.darkCard : Colors.white;
    final barColor = cs.surfaceContainerHighest;
    Widget box(double h, {double w = double.infinity}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    Widget card({required Widget child}) => Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  box(14, w: 64),
                  const SizedBox(width: 16),
                  box(14, w: 64),
                  const SizedBox(width: 16),
                  box(14, w: 64),
                ],
              ),
              const SizedBox(height: 12),
              box(12, w: 120),
            ],
          ),
        ),
        card(child: Column(children: [box(120)])),
        card(child: Column(children: [box(14, w: 90), const SizedBox(height: 12), box(90)])),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.days,
    required this.prev,
    required this.kind,
    required this.period,
  });

  final MonthSummary total;
  final int days;
  final MonthSummary prev;
  final TxType kind;
  final _Period period;

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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
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
            switch (period) {
              _Period.week => '对比上周',
              _Period.month => '对比上月',
              _Period.year => '对比去年',
            },
            Money.format(prevAmount),
            cs,
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

// ── 2. 趋势折线图 ──────────────────────────────────────────────────────────

class _TrendChart extends StatefulWidget {
  const _TrendChart({
    required this.dailySums,
    required this.period,
    required this.kind,
  });

  final List<DailyTypeStat> dailySums;
  final _Period period;
  final TxType kind;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dailySums = widget.dailySums;
    final period = widget.period;
    final isExpense = widget.kind == TxType.expense;
    final lineColor = isExpense
        ? AppTheme.expenseOrange
        : AppTheme.incomeGreen;

    // 数据序列：年报按月聚合为 12 点，周报/月报逐日。
    final List<double> values;
    final List<String> labels;
    final List<String> tooltips;
    if (period == _Period.year) {
      final monthly = List<double>.filled(12, 0);
      var year = '';
      for (final d in dailySums) {
        year = d.dateKey.substring(0, 4);
        final month = int.parse(DateKeys.monthKeyOf(d.dateKey).substring(5));
        monthly[month - 1] += isExpense ? d.expenseCents : d.incomeCents;
      }
      values = monthly;
      labels = [for (var i = 1; i <= 12; i++) '$i月'];
      tooltips = [for (var i = 1; i <= 12; i++) '$year年$i月'];
    } else {
      values = [
        for (final d in dailySums) (isExpense ? d.expenseCents : d.incomeCents).toDouble(),
      ];
      final labelEvery = values.length > 14 ? 5 : 1;
      labels = [
        for (var i = 0; i < values.length; i++)
          i % labelEvery == 0 ? _dayLabel(dailySums, i) : '',
      ];
      tooltips = [
        for (final d in dailySums)
          '${int.parse(d.dateKey.substring(5, 7))}月'
              '${int.parse(d.dateKey.substring(8))}日',
      ];
    }

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                period == _Period.year ? '月度趋势' : '每日趋势',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                isExpense ? '支出' : '收入',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: MouseRegion(
              onHover: (e) {
                final w = context.size?.width ?? 0;
                final n = values.length;
                if (w <= 0 || n == 0) return;
                const hPad = _LineChartPainter._hPad;
                final plotW = w - hPad * 2;
                final i = n == 1
                    ? 0
                    : ((e.localPosition.dx - hPad) / plotW * (n - 1))
                        .round()
                        .clamp(0, n - 1);
                setState(() => _hover = i);
              },
              onExit: (_) => setState(() => _hover = null),
              child: CustomPaint(
                painter: _LineChartPainter(
                  values: values,
                  labels: labels,
                  tooltips: tooltips,
                  hoverIndex: _hover,
                  lineColor: lineColor,
                  labelColor: cs.onSurfaceVariant,
                  gridColor: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(List<DailyTypeStat> sums, int i) {
    final d = DateKeys.parseDateKey(sums[i].dateKey);
    switch (widget.period) {
      case _Period.week:
        return ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
      case _Period.month:
        return '${d.day}';
      default:
        return '';
    }
  }
}

/// 单序列折线图：尖角折线 + 渐变填充 + 网格基线 + X 轴标签。
/// 无常驻数据点；悬浮时绘制竖直引导线、高亮点与「日期 + 金额」气泡。
/// 标签由画布绘制，与数据点横向精确对齐。
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.tooltips,
    required this.hoverIndex,
    required this.lineColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<double> values;
  final List<String> labels;
  final List<String> tooltips;
  final int? hoverIndex;
  final Color lineColor;
  final Color labelColor;
  final Color gridColor;

  static const double _topPad = 14;
  static const double _bottomPad = 18;
  static const double _hPad = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold<double>(1, (m, v) => math.max(m, v));
    final chartH = size.height - _topPad - _bottomPad;
    final plotW = size.width - _hPad * 2;

    Offset pointAt(int i) {
      if (values.length == 1) {
        return Offset(size.width / 2, _topPad + chartH * (1 - values[0] / maxV));
      }
      final x = _hPad + plotW * i / (values.length - 1);
      final y = _topPad + chartH * (1 - values[i] / maxV);
      return Offset(x, y);
    }

    // 网格基线：0 / 50% / 100% 三条细线。
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = _topPad + chartH * f;
      canvas.drawLine(Offset(_hPad, y), Offset(size.width - _hPad, y), gridPaint);
    }

    final pts = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // 渐变填充。
    if (pts.length > 1) {
      final fillPath = Path()
        ..moveTo(pts.first.dx, pts.first.dy)
        ..addPolygon(pts, false)
        ..lineTo(pts.last.dx, _topPad + chartH)
        ..lineTo(pts.first.dx, _topPad + chartH)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.22),
              lineColor.withValues(alpha: 0.02),
            ],
          ).createShader(
            Rect.fromLTWH(0, _topPad, size.width, chartH),
          ),
      );

      // 折线：尖角转折（miter），无常驻数据点。
      canvas.drawPath(
        Path()..addPolygon(pts, false),
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.miter
          ..strokeCap = StrokeCap.butt,
      );
    }

    // 悬浮：竖直引导线 + 高亮点 + 日期金额气泡。
    final hi = hoverIndex;
    if (hi != null && hi >= 0 && hi < pts.length) {
      final p = pts[hi];
      // 竖直引导线。
      canvas.drawLine(
        Offset(p.dx, _topPad),
        Offset(p.dx, _topPad + chartH),
        Paint()
          ..color = lineColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      // 高亮点。
      canvas.drawCircle(p, 3.5, Paint()..color = lineColor);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // 气泡。
      final tipText = '${tooltips[hi]}  ${Money.format(values[hi].round())}';
      final tp = TextPainter(
        text: TextSpan(
          text: tipText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bw = tp.width + 14;
      final bh = tp.height + 8;
      var bx = p.dx - bw / 2;
      bx = bx.clamp(2.0, size.width - bw - 2);
      var by = p.dy - bh - 8;
      if (by < 2) by = p.dy + 8;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xE6303236));
      tp.paint(canvas, Offset(bx + 7, by + 4));
    }

    // X 轴标签（与数据点同 x 坐标绘制）。
    for (var i = 0; i < labels.length; i++) {
      final text = labels[i];
      if (text.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = pts[i].dx;
      tp.paint(
        canvas,
        Offset((x - tp.width / 2).clamp(0.0, size.width - tp.width),
            size.height - _bottomPad + 4),
      );
    }

    // 峰值标注（右上角）。
    final maxTp = TextPainter(
      text: TextSpan(
        text: Money.format(maxV.round()),
        style: TextStyle(fontSize: 9, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(
      canvas,
      Offset(size.width - maxTp.width, 0),
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.tooltips != tooltips ||
      old.hoverIndex != hoverIndex ||
      old.lineColor != lineColor ||
      old.labelColor != labelColor ||
      old.gridColor != gridColor;
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
            ? AppColors.darkCard
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
                const SizedBox(width: 8),
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
                const SizedBox(width: 6),
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
            ? AppColors.darkCard
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
            ? AppColors.darkCard
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
          builder: (_) => TxDetailPage(tx: tx),
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
                    category?.displayName ?? S.unknownCategory,
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
