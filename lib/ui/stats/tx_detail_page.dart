import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/ledger_controller.dart';
import '../add/add_record_page.dart';
import '../widgets/common.dart';

/// 单笔账单详情（从明细 / 排行列表点击进入）。
///
/// 展示顺序：分类图标 → 金额（支出 `-` / 收入 `+`）→ 时间 → 来源 →
/// 备注 → 图片；底部为删除与编辑按钮。
class TxDetailPage extends StatelessWidget {
  const TxDetailPage({
    super.key,
    required this.tx,
    required this.categoryName,
    required this.categoryIcon,
    required this.accountName,
  });

  final LedgerTransaction tx;
  final String categoryName;
  final IconData categoryIcon;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = tx.type == TxType.income;
    final dt = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    final timeText =
        '${DateKeys.dayLabel(tx.dateKey)} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('账单详情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // 金额卡片：分类图标 + 分类名 + 金额（支出 - / 收入 +）。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2C30)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                CategoryBadge(icon: categoryIcon, size: 48, iconSize: 24),
                const SizedBox(height: 10),
                Text(
                  categoryName,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isIncome ? '+' : '-'}${Money.format(tx.amountCents)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? AppTheme.incomeGreen : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 信息列表：时间 → 来源 → 备注。
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2C30)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _infoTile(
                  Icons.calendar_today_outlined,
                  '时间',
                  timeText,
                  cs,
                ),
                _infoTile(
                  Icons.account_balance_wallet_outlined,
                  '来源',
                  accountName,
                  cs,
                ),
                _infoTile(
                  Icons.notes_outlined,
                  '备注',
                  (tx.note != null && tx.note!.isNotEmpty) ? tx.note! : '无',
                  cs,
                ),
              ],
            ),
          ),
          // 图片区：有图才渲染；横滑缩略图，点开全屏查看。
          if (tx.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2C30)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '图片（${tx.imagePaths.length}）',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tx.imagePaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => _openViewer(context, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(tx.imagePaths[i]),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(S.delete),
                  style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => AddRecordSheet.show(context, existing: tx),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(S.edit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => _ImageViewer(
          paths: tx.imagePaths,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final id = tx.id;
    if (id == null) return;
    final ok = await showConfirm(
      context,
      title: '删除这条账单？',
      content: '删除后可在底部提示中选择"撤销"。',
      confirmLabel: S.delete,
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final repo = context.read<TransactionRepository>();
    final ledger = context.read<LedgerController>();
    await repo.softDelete(id);
    ledger.bump();
    if (context.mounted) {
      Navigator.pop(context, true); // 返回 true 表示已删除
      showToast(context, S.deleted);
    }
  }
}

/// 全屏图片查看器：左右滑动切换，双指/双击缩放。
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.paths, required this.initialIndex});

  final List<String> paths;
  final int initialIndex;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _ctrl = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${widget.paths.length}',
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.file(
              File(widget.paths[i]),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
