import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/ledger_controller.dart';
import '../add/add_record_page.dart';
import '../widgets/common.dart';

/// 全局搜索：按备注 / 分类名 / 账户名模糊匹配全部历史账单。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _version = 0; // 编辑账单返回后自增，强制重查

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // 输入防抖：连续输入只在停顿后查一次。
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: '搜索备注、分类或账户',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<_SearchData>(
        key: ValueKey('search-$_query-$_version-${ledger.version}'),
        future: _query.isEmpty ? null : _load(context, _query),
        builder: (context, snap) {
          if (_query.isEmpty) {
            return const EmptyState(
              icon: Icons.search,
              title: '输入关键字搜索全部账单',
              subtitle: '支持备注、分类名、账户名',
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: '搜索失败：${snap.error}',
            );
          }
          final txs = snap.data!.txs;
          if (txs.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: '没有找到与“$_query”相关的账单',
            );
          }
          return _ResultList(
            data: snap.data!,
            onEdited: () => setState(() => _version++),
          );
        },
      ),
    );
  }

  static Future<_SearchData> _load(BuildContext context, String query) async {
    final results = await Future.wait([
      context.read<TransactionRepository>().search(query),
      context.read<AccountRepository>().listAll(includeDeleted: true),
      context.read<CategoryRepository>().listAll(includeDeleted: true),
    ]);
    return _SearchData(
      txs: results[0] as List<LedgerTransaction>,
      accounts: {for (final a in results[1] as List<LedgerAccount>) a.id!: a},
      categories: {for (final c in results[2] as List<TxCategory>) c.id!: c},
    );
  }
}

class _SearchData {
  const _SearchData({
    required this.txs,
    required this.accounts,
    required this.categories,
  });

  final List<LedgerTransaction> txs;
  final Map<int, LedgerAccount> accounts;
  final Map<int, TxCategory> categories;
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.data, required this.onEdited});

  final _SearchData data;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            '找到 ${data.txs.length} 笔',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final tx in data.txs)
                _ResultTile(tx: tx, data: data, onEdited: onEdited),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.tx,
    required this.data,
    required this.onEdited,
  });

  final LedgerTransaction tx;
  final _SearchData data;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTransfer = tx.type == TxType.transfer;
    final title = isTransfer
        ? '转账'
        : data.categories[tx.categoryId]?.name ?? S.unknownCategory;
    final account = data.accounts[tx.accountId]?.name ?? '未知账户';
    final note = (tx.note == null || tx.note!.isEmpty) ? '' : ' · ${tx.note}';
    final subtitle = '${DateKeys.dayLabel(tx.dateKey)} · $account$note';

    return ListTile(
      leading: isTransfer
          ? const CategoryBadge(
              icon: Icons.swap_horiz,
              color: AppTheme.transferBlue,
            )
          : CategoryBadge(
              icon: data.categories[tx.categoryId]?.icon ?? Icons.more_horiz,
            ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      titleTextStyle: TextStyle(color: cs.onSurface, fontSize: 15),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: AmountText(tx.amountCents, type: tx.type),
      onTap: () async {
        await AddRecordSheet.show(context, existing: tx);
        if (context.mounted) onEdited();
      },
    );
  }
}
