import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../add/add_record_page.dart';
import '../widgets/common.dart';

/// 某分类在指定时段内的账单明细。
class CategoryDetailPage extends StatelessWidget {
  const CategoryDetailPage({
    super.key,
    required this.categoryName,
    required this.icon,
    required this.categoryId,
    required this.from,
    required this.to,
    required this.type,
    required this.totalCents,
    required this.count,
  });

  final String categoryName;
  final IconData icon;
  final int? categoryId;
  final String from;
  final String to;
  final TxType type;
  final int totalCents;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: Column(
        children: [
          // 顶部汇总：总额 + 笔数
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCard
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CategoryBadge(icon: icon, size: 36, iconSize: 19),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Money.format(totalCents),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '共 $count 笔',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LedgerTransaction>>(
              future: context
                  .read<TransactionRepository>()
                  .transactionsByCategory(categoryId ?? -1, from, to, type),
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
                final txs = snap.data!;
                if (txs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '该分类暂无账单',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: txs.length,
                  itemBuilder: (ctx, i) {
                    final tx = txs[i];
                    return ListTile(
                      leading: CategoryBadge(
                        icon: icon,
                        size: 36,
                        iconSize: 19,
                      ),
                      title: Text(
                        tx.note?.isNotEmpty == true ? tx.note! : categoryName,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        DateKeys.dayLabel(tx.dateKey),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: AmountText(tx.amountCents, type: tx.type),
                      onTap: () => AddRecordSheet.show(context, existing: tx),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
