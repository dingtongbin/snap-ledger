import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../data/default_data.dart';
import '../../data/models/models.dart';
import '../widgets/common.dart';

/// 分类编辑结果（尚未入库，由调用方写入仓储）。
class CategoryEditResult {
  const CategoryEditResult(this.name, this.iconCode);

  final String name;
  final int iconCode;
}

/// 账户编辑结果（尚未入库）。
class AccountEditResult {
  const AccountEditResult(this.name, this.iconCode);

  final String name;
  final int iconCode;
}

/// 新建/编辑分类。
Future<CategoryEditResult?> showCategoryEditDialog(
  BuildContext context, {
  TxCategory? initial,
  required TxType kind,
}) async {
  final r = await _showEditDialog(
    context,
    title: initial == null ? '新建分类' : '编辑分类',
    initialName: initial?.name ?? '',
    initialIcon: initial?.icon ?? DefaultData.iconChoices.first,
  );
  if (r == null) return null;
  return CategoryEditResult(r.$1, r.$2);
}

/// 新建/编辑账户。
Future<AccountEditResult?> showAccountEditDialog(
  BuildContext context, {
  LedgerAccount? initial,
}) async {
  final r = await _showEditDialog(
    context,
    title: initial == null ? '新建交易方式' : '编辑交易方式',
    initialName: initial?.name ?? '',
    initialIcon: initial?.icon ?? DefaultData.iconChoices.first,
  );
  if (r == null) return null;
  return AccountEditResult(r.$1, r.$2);
}

/// 新建/编辑账本结果（尚未入库）。
class BookEditResult {
  const BookEditResult(this.name, this.iconCode);

  final String name;
  final int iconCode;
}

/// 新建/编辑账本。
Future<BookEditResult?> showBookEditDialog(
  BuildContext context, {
  LedgerBook? initial,
}) async {
  final r = await _showEditDialog(
    context,
    title: initial == null ? '新建账本' : '编辑账本',
    initialName: initial?.name ?? '',
    initialIcon: initial?.icon ?? DefaultData.iconChoices.first,
  );
  if (r == null) return null;
  return BookEditResult(r.$1, r.$2);
}

/// 返回 (名称, 图标codePoint)。
Future<(String, int)?> _showEditDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required IconData initialIcon,
}) {
  return showDialog<(String, int)>(
    context: context,
    builder: (_) => _EditDialog(
      title: title,
      initialName: initialName,
      initialIcon: initialIcon,
    ),
  );
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.initialName,
    required this.initialIcon,
  });

  final String title;
  final String initialName;
  final IconData initialIcon;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initialName,
  );
  late IconData _icon = widget.initialIcon;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext dialogContext) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showToast(dialogContext, '名称不能为空');
      return;
    }
    Navigator.pop(dialogContext, (name, _icon.codePoint));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final outline = cs.outlineVariant;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: outline),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary, width: 1.2),
    );

    return AlertDialog(
      // 标题压扁，避免大字号挤占内容区。
      titlePadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              maxLength: 12,
              autofocus: widget.initialName.isEmpty,
              decoration: InputDecoration(
                hintText: '名称（12 字以内）',
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                enabledBorder: border,
                focusedBorder: focusedBorder,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 168,
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final icon in DefaultData.iconChoices) _iconBtn(icon, cs),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => _save(context),
          child: const Text(S.confirm),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, ColorScheme cs) {
    final selected = icon.codePoint == _icon.codePoint;
    return InkWell(
      onTap: () => setState(() => _icon = icon),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 选中态仅用主色文字 / 主色描边标识，不挑色。
          color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 21,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}