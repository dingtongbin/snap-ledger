import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../main.dart';
import '../../state/ledger_controller.dart';
import '../add/add_record_page.dart';
import '../widgets/common.dart';

/// 单笔账单详情（从明细 / 日历 / 排行列表点击进入）。
///
/// 展示顺序：分类图标 → 金额（支出 `-` / 收入 `+`）→ 时间 → 来源 →
/// 备注 → 图片；底部为删除与编辑按钮。
/// Stateful：编辑弹层保存返回后重新查库刷新；删除后经全局 messenger
/// 在上一层页面投递可撤销 Snackbar。
class TxDetailPage extends StatefulWidget {
  const TxDetailPage({super.key, required this.tx});

  final LedgerTransaction tx;

  @override
  State<TxDetailPage> createState() => _TxDetailPageState();
}

class _TxDetailPageState extends State<TxDetailPage> {
  late LedgerTransaction _tx = widget.tx;
  Map<int, LedgerAccount> _accounts = const {};
  Map<int, TxCategory> _categories = const {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
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

  /// 编辑保存 / 撤销删除后重查库，保持页面与数据一致。
  Future<void> _reload() async {
    final id = _tx.id;
    if (id == null) return;
    final fresh = await context.read<TransactionRepository>().byId(id);
    if (!mounted) return;
    if (fresh == null) {
      // 账单已被删除：退出详情页。
      Navigator.pop(context);
      return;
    }
    setState(() => _tx = fresh);
  }

  bool get _isTransfer => _tx.type == TxType.transfer;

  String get _categoryName => _isTransfer
      ? '转账'
      : _categories[_tx.categoryId]?.displayName ?? S.unknownCategory;

  IconData get _categoryIcon => _isTransfer
      ? Icons.swap_horiz
      : _categories[_tx.categoryId]?.icon ?? Icons.more_horiz;

  String get _accountText {
    final account = _accounts[_tx.accountId]?.name ?? '未知账户';
    if (!_isTransfer) return account;
    final target = _tx.targetAccountId == null
        ? null
        : _accounts[_tx.targetAccountId];
    return '$account → ${target?.name ?? "未知账户"}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = _tx.type == TxType.income;
    final dt = DateTime.fromMillisecondsSinceEpoch(_tx.timestamp);
    final timeText =
        '${DateKeys.dayLabel(_tx.dateKey)} '
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
                  ? AppColors.darkCard
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                CategoryBadge(icon: _categoryIcon, size: 48, iconSize: 24),
                const SizedBox(height: 10),
                Text(
                  _categoryName,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isIncome ? '+' : '-'}${Money.format(_tx.amountCents)}',
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
                  ? AppColors.darkCard
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
                  _accountText,
                  cs,
                ),
                _infoTile(
                  Icons.notes_outlined,
                  '备注',
                  (_tx.note != null && _tx.note!.isNotEmpty) ? _tx.note! : '无',
                  cs,
                ),
              ],
            ),
          ),
          // 图片区：有图才渲染；横滑缩略图，点开全屏查看。
          if (_tx.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCard
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '图片（${_tx.imagePaths.length}）',
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
                      itemCount: _tx.imagePaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => _openViewer(context, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // cacheWidth 限制解码尺寸：多张原图也不拖垮列表。
                          child: Image.file(
                            File(_tx.imagePaths[i]),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            cacheWidth: 288,
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
                  onPressed: () => AddRecordSheet.show(context, existing: _tx)
                      .then((_) => _reload()),
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
          paths: _tx.imagePaths,
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
    final id = _tx.id;
    if (id == null) return;
    final ok = await showConfirm(
      context,
      title: '删除这条账单？',
      content: '删除后可在提示中选择"撤销"。',
      confirmLabel: S.delete,
      danger: true,
    );
    if (!ok || !context.mounted) return;
    // 在 pop 前捕获依赖；pop 后用全局 messenger 投递可撤销 Snackbar，
    // 与明细页长按删除的行为保持一致。
    final repo = context.read<TransactionRepository>();
    final ledger = context.read<LedgerController>();
    final messenger = BookkeepingApp.scaffoldMessengerKey.currentState;
    await repo.softDelete(id);
    ledger.bump();
    if (context.mounted) Navigator.pop(context, true);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
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
