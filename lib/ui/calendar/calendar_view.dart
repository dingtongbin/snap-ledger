import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../stats/tx_detail_page.dart';
import '../widgets/common.dart';
import 'day_detail_page.dart';

/// 日历视图：上=月历格子（点日期切换下方列表），下=选中日的账单列表卡片。
///
/// 懒加载与懒渲染约定：
/// - 月历为 PageView.builder，仅构建可见页；
/// - 每月账单首次进入时查询一次，按天分组缓存，缓存按「当前页 ±3 月」修剪；
/// - 下方列表直接复用当月缓存数据，选中切换零查询。
class CalendarView extends StatefulWidget {
  const CalendarView({super.key, required this.ledgerId, required this.version});

  /// null = 全部账本聚合。
  final int? ledgerId;

  /// 账单版本号：增删改后清缓存刷新，保持当前选中日期不变。
  final int version;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  /// 月份索引锚点：2020-01 = 0。
  static const int _epochYear = 2020;

  late int _index;
  late String _selectedDateKey;

  /// monthKey -> (dateKey -> 当日账单，时间倒序)。
  final Map<String, Map<String, List<LedgerTransaction>>> _cache = {};

  Map<int, LedgerAccount> _accounts = const {};
  Map<int, TxCategory> _categories = const {};

  static int _indexOf(DateTime d) => (d.year - _epochYear) * 12 + d.month - 1;
  static DateTime _monthOf(int index) =>
      DateTime(_epochYear + index ~/ 12, index % 12 + 1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _index = _indexOf(now);
    _selectedDateKey = DateKeys.dateKey(now);
    _loadLookups();
  }

  @override
  void didUpdateWidget(covariant CalendarView old) {
    super.didUpdateWidget(old);
    // 账单增删改：清缓存触发重查，选中日期保持不变。
    if (old.version != widget.version) {
      _cache.clear();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final results = await Future.wait([
      context.read<AccountRepository>().listAll(includeDeleted: true),
      context.read<CategoryRepository>().listAll(includeDeleted: true),
    ]);
    if (!mounted) return;
    setState(() {
      _accounts = {for (final a in results[0] as List<LedgerAccount>) a.id!: a};
      _categories = {for (final c in results[1] as List<TxCategory>) c.id!: c};
    });
  }

  Future<Map<String, List<LedgerTransaction>>> _loadMonth(String monthKey) async {
    final hit = _cache[monthKey];
    if (hit != null) return hit;
    final txs = await context.read<TransactionRepository>().listByMonth(
      monthKey,
      ledgerId: widget.ledgerId,
    );
    final byDay = <String, List<LedgerTransaction>>{};
    for (final t in txs) {
      byDay.putIfAbsent(t.dateKey, () => []).add(t);
    }
    _cache[monthKey] = byDay;
    _trimCache();
    return byDay;
  }

  /// 仅保留当前页 ±3 月的数据，防长距翻页累积内存。
  void _trimCache() {
    if (_cache.length <= 7) return;
    final keep = <String>{
      for (var i = _index - 3; i <= _index + 3; i++)
        DateKeys.monthKey(_monthOf(i)),
    };
    _cache.removeWhere((k, _) => !keep.contains(k));
  }

  void _jumpTo(DateTime month) {
    final target = _indexOf(month);
    if (target == _index) return;
    final now = DateTime.now();
    setState(() {
      _index = target;
      // 换月时默认选中：当月选今天，其它月选 1 号。
      final m = _monthOf(target);
      _selectedDateKey = (m.year == now.year && m.month == now.month)
          ? DateKeys.dateKey(now)
          : DateKeys.dateKey(DateTime(m.year, m.month));
      _trimCache();
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: _monthOf(_index)),
    );
    if (picked != null) _jumpTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final month = _monthOf(_index);
    return Column(
      children: [
        // 月历整体为一张卡片（导航 + 星期头 + 格子），与下方列表卡片同风格。
        // 格子区固定预留高度，列表吃剩余空间。
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 月份导航：‹ 标题 ›，点标题弹跳转面板。
              Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _jumpTo(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '${month.year}年${month.month}月',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _jumpTo(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
        ),
        // 星期表头（周一起始）。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 月历格子：每天等高（58px，容纳圆圈 + 两行金额），
        // 卡片高度随当月实际行数自适应（shrinkWrap），无死空间。
        // 左右滑动切月；AnimatedSwitcher 提供过渡动画。
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -120) {
              _jumpTo(DateTime(month.year, month.month + 1));
            } else if (v > 120) {
              _jumpTo(DateTime(month.year, month.month - 1));
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previousChildren,
                ?currentChild,
              ],
            ),
            child: _MonthPage(
              key: ValueKey(_index),
              month: _monthOf(_index),
              loader: _loadMonth,
              selectedKey: _selectedDateKey,
              onSelect: (dateKey) => setState(() => _selectedDateKey = dateKey),
            ),
          ),
        ),
            ],
          ),
        ),
        // 选中日的账单列表卡片。
        Expanded(child: _SelectedDayCard(
          dateKey: _selectedDateKey,
          monthKey: DateKeys.monthKey(_monthOf(_index)),
          loader: _loadMonth,
          accounts: _accounts,
          categories: _categories,
          ledgerId: widget.ledgerId,
          onDataChanged: () {
            _cache.clear();
            if (mounted) setState(() {});
          },
        )),
      ],
    );
  }
}

/// 单月页：进入视口才构建；数据经 [loader] 带缓存加载。
class _MonthPage extends StatelessWidget {
  const _MonthPage({
    super.key,
    required this.month,
    required this.loader,
    required this.selectedKey,
    required this.onSelect,
  });

  final DateTime month;
  final Future<Map<String, List<LedgerTransaction>>> Function(String monthKey)
      loader;

  /// 仅当前可见页有选中高亮；翻页过程中的缓存页不显示。
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final monthKey = DateKeys.monthKey(month);
    return FutureBuilder<Map<String, List<LedgerTransaction>>>(
      future: loader(monthKey),
      builder: (context, snap) {
        final byDay = snap.data ?? const <String, List<LedgerTransaction>>{};
        return _MonthGrid(
          month: month,
          byDay: byDay,
          selectedKey: selectedKey,
          onSelect: onSelect,
          loading: !snap.hasData,
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selectedKey,
    required this.onSelect,
    required this.loading,
  });

  final DateTime month;
  final Map<String, List<LedgerTransaction>> byDay;
  final String? selectedKey;
  final ValueChanged<String> onSelect;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1; // 周一 = 1
    final todayKey = DateKeys.dateKey(DateTime.now());

    return loading && byDay.isEmpty
        ? const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : LayoutBuilder(
            builder: (context, cons) {
              // 每天等高：固定行高 46px（圆圈 20 + 两行金额 + 最小余量），
              // 网格 shrinkWrap 自适应行数，卡片高度贴合内容。
              const rowHeight = 46.0;
              final cellW = (cons.maxWidth - 12) / 7;
              return GridView.count(
                crossAxisCount: 7,
                childAspectRatio: cellW / rowHeight,
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
            children: [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                Builder(
                  builder: (context) {
                    final dateKey = DateKeys.dateKey(
                      first.add(Duration(days: day - 1)),
                    );
                    final list = byDay[dateKey] ?? const [];
                    var exp = 0;
                    var inc = 0;
                    for (final t in list) {
                      if (t.type == TxType.expense) {
                        exp += t.amountCents;
                      } else if (t.type == TxType.income) {
                        inc += t.amountCents;
                      }
                    }
                    return _DayCell(
                      day: day,
                      dateKey: dateKey,
                      expenseCents: exp,
                      incomeCents: inc,
                      isToday: dateKey == todayKey,
                      isSelected: dateKey == selectedKey,
                      onTap: () => onSelect(dateKey),
                    );
                  },
                ),
            ],
          );
            },
          );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.dateKey,
    required this.expenseCents,
    required this.incomeCents,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final String dateKey;
  final int expenseCents;
  final int incomeCents;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 选中态 = 日期数字实心圆；今天（未选中）= 主色描边圆。不用方框。
    final circleColor = isSelected ? cs.primary : Colors.transparent;
    final textColor = isSelected
        ? cs.onPrimary
        : isToday
        ? cs.primary
        : dark
        ? Colors.white
        : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: cs.primary, width: 1.2)
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
            // 支出 / 收入各占一行，整数元显示；每行超宽自动缩放。
            if (expenseCents > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '-${_yuan(expenseCents)}',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                    color: AppColors.danger,
                  ),
                ),
              ),
            if (incomeCents > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${_yuan(incomeCents)}',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.incomeGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 日历格子用整数元（去掉 ".00"），视觉更短更清爽。
  static String _yuan(int cents) => (cents / 100).round().toString();
}

/// 选中日的账单列表卡片：头部（日期 + 收支小计 + 当日详情入口）+ 账单行。
class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.dateKey,
    required this.monthKey,
    required this.loader,
    required this.accounts,
    required this.categories,
    required this.ledgerId,
    required this.onDataChanged,
  });

  final String dateKey;
  final String monthKey;
  final Future<Map<String, List<LedgerTransaction>>> Function(String monthKey)
      loader;
  final Map<int, LedgerAccount> accounts;
  final Map<int, TxCategory> categories;
  final int? ledgerId;
  final VoidCallback onDataChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? AppColors.darkCard : Colors.white;
    return FutureBuilder<Map<String, List<LedgerTransaction>>>(
      future: loader(monthKey),
      builder: (context, snap) {
        final list = snap.data?[dateKey];
        final txs = list ?? const <LedgerTransaction>[];
        var exp = 0;
        var inc = 0;
        for (final t in txs) {
          if (t.type == TxType.expense) {
            exp += t.amountCents;
          } else if (t.type == TxType.income) {
            inc += t.amountCents;
          }
        }
        final isToday = dateKey == DateKeys.dateKey(DateTime.now());
        final header = isToday
            ? '今天 · ${DateKeys.dayLabel(dateKey)}'
            : DateKeys.dayLabel(dateKey);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 头部：日期 + 收支 + 当日详情入口。
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
                child: Row(
                  children: [
                    Text(header, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 10),
                    if (exp > 0)
                      Text(
                        '支 ${Money.format(exp)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.danger,
                        ),
                      ),
                    if (exp > 0 && inc > 0) const SizedBox(width: 8),
                    if (inc > 0)
                      Text(
                        '收 ${Money.format(inc)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.incomeGreen,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DayDetailPage(
                            dateKey: dateKey,
                            ledgerId: ledgerId,
                          ),
                        ),
                      ),
                      child: const Text('当日详情', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0.6, thickness: 0.6),
              // 账单行。
              Expanded(
                child: txs.isEmpty
                    ? Center(
                        child: Text(
                          '这一天没有账单',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 4),
                        children: [
                          for (final t in txs)
                            _CalendarTxRow(
                              tx: t,
                              accounts: accounts,
                              categories: categories,
                              onOpened: onDataChanged,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 当日列表行：点击进交易详情，返回后刷新日历缓存。
class _CalendarTxRow extends StatelessWidget {
  const _CalendarTxRow({
    required this.tx,
    required this.accounts,
    required this.categories,
    required this.onOpened,
  });

  final LedgerTransaction tx;
  final Map<int, LedgerAccount> accounts;
  final Map<int, TxCategory> categories;
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = categories[tx.categoryId]?.displayName ?? S.unknownCategory;
    final accountText = accounts[tx.accountId]?.name ?? '未知账户';
    final note = (tx.note == null || tx.note!.isEmpty) ? '' : ' · ${tx.note}';
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: CategoryBadge(
        icon: categories[tx.categoryId]?.icon ?? Icons.more_horiz,
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        '$accountText$note',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: AmountText(
        tx.amountCents,
        type: tx.type == TxType.income ? TxType.income : TxType.expense,
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TxDetailPage(tx: tx),
          ),
        );
        onOpened();
      },
    );
  }
}

/// 跳转月份面板：年切换 + 12 宫格。
class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;
  final _now = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_year 年',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var m = 1; m <= 12; m++)
                  InkWell(
                    onTap: () =>
                        Navigator.pop(context, DateTime(_year, m)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _year == _now.year && m == _now.month
                            ? cs.primary.withValues(alpha: 0.12)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$m 月',
                        style: TextStyle(
                          fontSize: 13,
                          color: _year == _now.year && m == _now.month
                              ? cs.primary
                              : cs.onSurface,
                          fontWeight:
                              _year == _now.year && m == _now.month
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
