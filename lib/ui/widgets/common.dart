import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';

/// 金额文本：全局统一符号规范——支出 `-` 前景色，收入 `+` 绿色，转账蓝色。
class AmountText extends StatelessWidget {
  const AmountText(
    this.cents, {
    super.key,
    this.type = TxType.expense,
    this.style,
  });

  final int cents;
  final TxType type;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, prefix) = switch (type) {
      TxType.income => (AppTheme.incomeGreen, '+'),
      TxType.transfer => (AppTheme.transferBlue, ''),
      TxType.expense => (cs.onSurface, '-'),
    };
    return Text(
      '$prefix${Money.format(cents)}',
      style:
          (style ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))
              .copyWith(color: color),
    );
  }
}

/// 通用下划线标签栏：选中项文字加粗 + 底部主色短横线。
///
/// 替代 SegmentedButton / ToggleButtons，视觉更轻。
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.fontSize = 14,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: i == selectedIndex
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: i == selectedIndex
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 18,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? cs.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 分类/账户圆形图标徽章。
///
/// [color] 缺省时使用主题主色（统一色系模式）：图标主色 + 淡色底，
/// 深浅色模式自适应。仅统计图表等必须区分分类的场景才传入显式颜色。
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.iconSize = 21,
  });

  final IconData icon;

  /// null = 统一色系（主题主色）。
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(icon, color: c, size: iconSize),
    );
  }
}

/// 空状态占位。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 月份切换器（‹ 2026年9月 ›）。
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.monthKey,
    required this.onChanged,
    this.foreground,
  });

  final String monthKey;
  final ValueChanged<int> onChanged;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(-1),
          icon: Icon(Icons.chevron_left, color: fg),
        ),
        SizedBox(
          width: 104,
          child: Text(
            DateKeys.monthLabel(monthKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(1),
          icon: Icon(Icons.chevron_right, color: fg),
        ),
      ],
    );
  }
}

/// 统一确认弹窗，返回是否确认。
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  String? content,
  String? confirmLabel,
  bool danger = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: cs.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? S.confirm),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// 轻提示。
void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// 交易方式选择底部弹层，返回所选账户 id。
///
/// [onAdd]：点击「＋ 新建交易方式」时触发（弹层保持打开）。
/// 返回更新后的完整列表用于原地刷新；返回 null 表示取消新建。
Future<int?> showAccountPicker(
  BuildContext context, {
  required List<LedgerAccount> accounts,
  int? selectedId,
  String title = '选择交易方式',
  Future<List<LedgerAccount>?> Function()? onAdd,
}) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (_) => _AccountPickerSheet(
      accounts: accounts,
      selectedId: selectedId,
      title: title,
      onAdd: onAdd,
    ),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet({
    required this.accounts,
    required this.title,
    this.selectedId,
    this.onAdd,
  });

  final List<LedgerAccount> accounts;
  final String title;
  final int? selectedId;
  final Future<List<LedgerAccount>?> Function()? onAdd;

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  late List<LedgerAccount> _list = widget.accounts;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _list.length + (widget.onAdd == null ? 0 : 1),
              itemBuilder: (ctx, i) {
                // 末尾「新建交易方式」入口。
                if (i >= _list.length) {
                  return ListTile(
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('新建交易方式'),
                    enabled: !_busy,
                    onTap: _create,
                  );
                }
                final a = _list[i];
                final selected = a.id == widget.selectedId;
                return ListTile(
                  leading: CategoryBadge(icon: a.icon, size: 36, iconSize: 19),
                  title: Text(a.name),
                  trailing: selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, a.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (_busy || widget.onAdd == null) return;
    _busy = true;
    final updated = await widget.onAdd!();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (updated != null) _list = updated;
    });
  }
}
