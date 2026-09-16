import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/book_controller.dart';
import '../calendar/calendar_view.dart';
import '../search/search_page.dart';
import '../stats/tx_detail_page.dart';
import '../widgets/book_picker.dart';
import '../widgets/common.dart';

/// 记账页：今日概览卡（今日/本月收支 + 月预算进度）+ 按天分组的账单流。
/// 账单流按天分页懒加载（ListView.builder 懒渲染，滚到尾部加载更多）。
/// 头部支持切换账本（默认「全部账本」聚合）与 列表/日历 两种视图。
class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  var _calendarMode = false;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final books = context.watch<BookController>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.tabDetail),
            const SizedBox(width: 8),
            const _BookChip(),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _calendarMode
                  ? Icons.view_list_outlined
                  : Icons.calendar_month_outlined,
            ),
            tooltip: _calendarMode ? '列表视图' : '日历视图',
            onPressed: () => setState(() => _calendarMode = !_calendarMode),
          ),
          IconButton(
            icon: const Icon(Icons.search_outlined),
            tooltip: S.search,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SearchPage()),
            ),
          ),
        ],
      ),
      body: _calendarMode
          ? CalendarView(
              key: ValueKey('cal-${books.selectedId}'),
              ledgerId: books.selectedId,
              version: ledger.version,
            )
          : Column(
              children: [
                // 概览卡与账单流都随 version/账本变化整体重建，保证增删改后即时刷新。
                _TodayOverview(
                  key: ValueKey('overview-${ledger.version}-${books.selectedId}'),
                ),
                Expanded(
                  child: _DayFeed(
                    key: ValueKey('feed-${ledger.version}-${books.selectedId}'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 头部账本选择 chip：显示当前账本（或「全部账本」），点击弹出选择层。
class _BookChip extends StatelessWidget {
  const _BookChip();

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

/// 顶部概览卡：今日支出/收入、本月支出/收入、月预算进度。
class _TodayOverview extends StatelessWidget {
  const _TodayOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateKeys.dateKey(now);
    final month = DateKeys.monthKey(now);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppTheme.bannerGradient(Theme.of(context).colorScheme),
      ),
      child: FutureBuilder<List<MonthSummary>>(
        key: ValueKey(
          'overview-$today-${context.watch<LedgerController>().version}',
        ),
        future: _load(context, today, month),
        builder: (context, snap) {
          final zero = const MonthSummary(expenseCents: 0, incomeCents: 0);
          final todaySum = snap.data?[0] ?? zero;
          final monthSum = snap.data?.length == 2 ? snap.data![1] : zero;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _cell(
                      S.todayExpense,
                      todaySum.expenseCents,
                      big: true,
                    ),
                  ),
                  Expanded(
                    child: _cell(
                      S.todayIncome,
                      todaySum.incomeCents,
                      big: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _cell(S.monthExpense, monthSum.expenseCents)),
                  Expanded(child: _cell(S.monthIncome, monthSum.incomeCents)),
                ],
              ),
              const SizedBox(height: 12),
              _BudgetRow(monthExpense: monthSum.expenseCents),
            ],
          );
        },
      ),
    );
  }

  static Future<List<MonthSummary>> _load(
    BuildContext context,
    String today,
    String month,
  ) async {
    final repo = context.read<TransactionRepository>();
    final ledgerId = context.read<BookController>().filterLedgerId;
    final results = await Future.wait([
      repo.daySummary(today, ledgerId: ledgerId),
      repo.monthSummary(month, ledgerId: ledgerId),
    ]);
    return results;
  }

  static Widget _cell(String label, int cents, {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          Money.format(cents),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: big ? 21 : 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// 月预算行：未设置时提示点击设置；已设置时展示进度条与已用百分比。
class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.monthExpense});

  final int monthExpense;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final budget = settings.monthlyBudgetCents;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _editBudget(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget > 0
                      ? (monthExpense > budget
                            ? '月预算 ${Money.format(budget)} · 已超支 ${Money.format(monthExpense - budget)}'
                            : '月预算 ${Money.format(budget)} · 剩余 ${Money.format(budget - monthExpense)}')
                      : '月预算未设置，点击设置',
                  style: TextStyle(
                    fontSize: 12,
                    color: monthExpense > budget
                        ? const Color(0xFFFFD54F)
                        : Colors.white.withValues(
                            alpha: budget > 0 ? 0.9 : 0.7,
                          ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (budget > 0)
                Text(
                  '已用 ${(monthExpense / budget * 100).clamp(0, 999).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: Colors.white24),
                    FractionallySizedBox(
                      widthFactor: (monthExpense / budget).clamp(0.0, 1.0),
                      child: Container(
                        color: monthExpense > budget
                            ? const Color(0xFFFFD54F)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context) async {
    final budget = context.read<SettingsController>().monthlyBudgetCents;
    final controller = TextEditingController(
      text: budget > 0 ? Money.format(budget).replaceAll(',', '') : '',
    );
    final cents = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置月预算'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '每月支出预算金额',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          if (budget > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('清除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, Money.parse(controller.text) ?? -1),
            child: Text(S.confirm),
          ),
        ],
      ),
    );
    if (cents == null || !context.mounted) return;
    if (cents < 0) {
      showToast(context, '金额格式不正确');
      return;
    }
    await context.read<SettingsController>().setMonthlyBudget(cents);
  }
}

/// 按天分组的账单流：分页懒加载 + ListView.builder 懒渲染。
class _DayFeed extends StatefulWidget {
  const _DayFeed({super.key});

  @override
  State<_DayFeed> createState() => _DayFeedState();
}

class _DayFeedState extends State<_DayFeed> {
  static const int _pageSize = 15; // 每页天数
  static const double _preloadExtent = 400; // 距尾部多远预加载下一页

  final ScrollController _controller = ScrollController();
  final List<DayGroup> _days = [];
  Map<int, LedgerAccount> _accounts = const {};
  Map<int, TxCategory> _categories = const {};
  var _offset = 0;
  var _hasMore = true;
  var _loading = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadLookups();
    _loadMore();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _onScroll() {
    if (_controller.position.extentAfter < _preloadExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<TransactionRepository>().listDaysPaged(
        limit: _pageSize,
        offset: _offset,
        ledgerId: context.read<BookController>().filterLedgerId,
      );
      if (!mounted) return;
      setState(() {
        _days.addAll(page);
        _offset += page.length;
        _hasMore = page.length >= _pageSize;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 失败停在页尾，由「重试」入口再次触发，避免滚动时死循环刷请求。
      setState(() {
        _loading = false;
        _failed = true;
        _hasMore = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_days.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_days.isEmpty && _failed) {
      return GestureDetector(
        onTap: _loadMore,
        behavior: HitTestBehavior.opaque,
        child: const EmptyState(icon: Icons.error_outline, title: '加载失败，点击重试'),
      );
    }
    if (_days.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: '还没有账单',
        subtitle: '点击下方 + 开始第一笔记账吧',
      );
    }
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _days.length + 1,
      itemBuilder: (context, i) {
        if (i >= _days.length) {
          return _footer();
        }
        return _DayCard(
          group: _days[i],
          accounts: _accounts,
          categories: _categories,
        );
      },
    );
  }

  /// 尾部：加载中 / 失败重试 / 到底提示。
  Widget _footer() {
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton(
            onPressed: _loadMore,
            child: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_hasMore) {
      // 兜底：滚动监听未触发时，尾部占位也兜住加载。
      return const SizedBox(height: 32);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '没有更多了',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 一天的账单卡片：头部（日期 + 当日收支）+ 内部为该天明细列表。
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.group,
    required this.accounts,
    required this.categories,
  });

  final DayGroup group;
  final Map<int, LedgerAccount> accounts;
  final Map<int, TxCategory> categories;

  @override
  Widget build(BuildContext context) {
    final isToday = group.dateKey == DateKeys.dateKey(DateTime.now());
    final title = isToday
        ? '今天 · ${DateKeys.dayLabel(group.dateKey)}'
        : DateKeys.dayLabel(group.dateKey);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Text(
                  '支 ${Money.format(group.expenseCents)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkGray),
                ),
                const SizedBox(width: 10),
                Text(
                  '收 ${Money.format(group.incomeCents)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkGray),
                ),
              ],
            ),
          ),
          for (final tx in group.transactions)
            _TxTile(tx: tx, accounts: accounts, categories: categories),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.accounts,
    required this.categories,
  });

  final LedgerTransaction tx;
  final Map<int, LedgerAccount> accounts;
  final Map<int, TxCategory> categories;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTransfer = tx.type == TxType.transfer;
    final title = isTransfer
        ? '转账'
        : categories[tx.categoryId]?.displayName ?? S.unknownCategory;
    final account = accounts[tx.accountId];
    final target = tx.targetAccountId == null
        ? null
        : accounts[tx.targetAccountId];
    final accountText = isTransfer
        ? '${account?.name ?? "未知账户"} → ${target?.name ?? "未知账户"}'
        : account?.name ?? '未知账户';
    final note = (tx.note == null || tx.note!.isEmpty) ? '' : ' · ${tx.note}';
    final badge = isTransfer
        ? const CategoryBadge(
            icon: Icons.swap_horiz,
            color: AppTheme.transferBlue,
          )
        : CategoryBadge(
            icon: categories[tx.categoryId]?.icon ?? Icons.more_horiz,
          );

    return ListTile(
      dense: true,
      leading: badge,
      title: Text(title, style: const TextStyle(fontSize: 15)),
      titleTextStyle: TextStyle(color: cs.onSurface, fontSize: 15),
      subtitle: Text(
        '$accountText$note',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: AmountText(tx.amountCents, type: tx.type),
      // 单击进入独立详情页；转账记录同样可进入（只读）。
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TxDetailPage(tx: tx),
        ),
      ),
      onLongPress: () => _delete(context),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final id = tx.id;
    if (id == null) return;
    final ok = await showConfirm(
      context,
      title: '删除这条账单？',
      content: '删除后可在底部提示中选择“撤销”。',
      confirmLabel: S.delete,
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final repo = context.read<TransactionRepository>();
    final ledger = context.read<LedgerController>();
    await repo.softDelete(id);
    ledger.bump();
    if (context.mounted) {
      showToast(context, S.deleted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已删除该账单'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: S.undo,
            onPressed: () {
              repo.restore(id);
              ledger.bump();
            },
          ),
        ),
      );
    }
  }
}
