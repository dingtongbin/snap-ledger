import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions.dart';
import '../../data/default_data.dart';
import '../../data/repositories/repositories.dart';
import '../../state/book_controller.dart';
import '../mine/manage_books_page.dart';
import '../mine/picker_dialogs.dart';
import 'common.dart';

/// 账本选择底部弹层。
///
/// - 首项「全部账本」（value = null）；
/// - 「管理账本」进入管理页；「＋ 新建账本」原地创建并选中。
/// 返回选中的账本 id（null = 全部账本）；未变更时也返回当前值。
Future<int?> showBookPicker(BuildContext context) {
  final controller = context.read<BookController>();
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => MultiProvider(
      providers: [
        Provider<LedgerBookRepository>.value(
          value: context.read<LedgerBookRepository>(),
        ),
        ChangeNotifierProvider<BookController>.value(value: controller),
      ],
      child: const _BookPickerSheet(),
    ),
  );
}

class _BookPickerSheet extends StatefulWidget {
  const _BookPickerSheet();

  @override
  State<_BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends State<_BookPickerSheet> {
  var _busy = false;

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await showBookEditDialog(context);
      if (res == null || !mounted) return;
      final repo = context.read<LedgerBookRepository>();
      try {
        final id = await repo.create(
          name: res.name,
          iconCode: res.iconCode,
          colorValue: DefaultData.colorChoices.first.toARGB32(),
        );
        if (!mounted) return;
        final books = context.read<BookController>();
        await books.reload();
        await books.select(id);
        if (mounted) Navigator.pop(context, id);
      } on AppException catch (e) {
        if (mounted) showToast(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookController>().books;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '选择账本',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: Icon(Icons.all_inclusive, color: cs.primary),
            title: const Text('全部账本'),
            trailing: context.watch<BookController>().selectedId == null
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              context.read<BookController>().select(null);
              Navigator.pop(context, null);
            },
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: books.length,
              itemBuilder: (ctx, i) {
                final b = books[i];
                final selected = context.watch<BookController>().selectedId == b.id;
                return ListTile(
                  leading: Icon(b.icon, color: b.color),
                  title: Text(b.name),
                  subtitle: b.builtin ? const Text('内置', style: TextStyle(fontSize: 11)) : null,
                  trailing: selected ? const Icon(Icons.check) : null,
                  onTap: () {
                    context.read<BookController>().select(b.id);
                    Navigator.pop(context, b.id);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
            title: const Text('管理账本'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ManageBooksPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: cs.primary),
            title: const Text('新建账本'),
            enabled: !_busy,
            onTap: _create,
          ),
        ],
      ),
    );
  }
}
