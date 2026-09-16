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

/// 当日明细页（日历格子点入）：当日收支结余汇总 + 账单列表。
class DayDetailPage extends StatefulWidget {
  const DayDetailPage({super.key, required this.dateKey, this.ledgerId});

  final String dateKey;

  /// null = 全部账本聚合。
  final int? ledgerId;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  Map<int, LedgerAccount> _accounts = const {};
  Map<int, TxCategory> _categories = const {};
  late Future<DayGroup?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadLookups();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<DayGroup?> _load() =>
      context.read<TransactionRepository>().dayGroup(
        widget.dateKey,
        ledgerId: widget.ledgerId,
      );

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkCard
        : Colors.white;
    final title = DateKeys.dayLabel(widget.dateKey);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<DayGroup?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final g = snap.data;
          if (g == null || g.transactions.isEmpty) {
            return const EmptyState(
              icon: Icons.event_busy_outlined,
              title: '这一天没有账单',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              // 汇总卡：收入 / 支出 / 结余。
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _sumCol('收入', g.incomeCents, AppTheme.incomeGreen, cs),
                    _divider(cs),
                    _sumCol('支出', g.expenseCents, AppColors.danger, cs),
                    _divider(cs),
                    _sumCol(
                      '结余',
                      g.incomeCents - g.expenseCents,
                      cs.onSurface,
                      cs,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final tx in g.transactions)
                      _DayTxRow(
                        tx: tx,
                        accounts: _accounts,
                        categories: _categories,
                        onOpened: _reload,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sumCol(String label, int cents, Color valueColor, ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            Money.format(cents),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cents == 0 ? cs.onSurfaceVariant : valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Container(
    width: 0.6,
    height: 26,
    color: cs.outlineVariant.withValues(alpha: 0.4),
  );
}

/// 当日账单行：点击进交易详情，返回后刷新本页。
class _DayTxRow extends StatelessWidget {
  const _DayTxRow({
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
    final isExpense = tx.type == TxType.expense;
    final title =
        categories[tx.categoryId]?.displayName ?? S.unknownCategory;
    final accountText =
        accounts[tx.accountId]?.name ?? '未知账户';
    final note = (tx.note == null || tx.note!.isEmpty) ? '' : ' · ${tx.note}';
    return ListTile(
      dense: true,
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
        type: isExpense ? TxType.expense : TxType.income,
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
