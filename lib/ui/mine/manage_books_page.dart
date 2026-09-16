import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions.dart';
import '../../data/default_data.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../core/strings.dart';
import '../../state/book_controller.dart';
import '../widgets/common.dart';
import 'picker_dialogs.dart';

/// 账本管理：新建 / 编辑 / 删除（默认账本不可删）。
class ManageBooksPage extends StatefulWidget {
  const ManageBooksPage({super.key});

  @override
  State<ManageBooksPage> createState() => _ManageBooksPageState();
}

class _ManageBooksPageState extends State<ManageBooksPage> {
  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookController>().books;
    return Scaffold(
      appBar: AppBar(
        title: const Text('账本管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建账本',
            onPressed: _create,
          ),
        ],
      ),
      body: books.isEmpty
          ? const EmptyState(icon: Icons.menu_book_outlined, title: '还没有账本')
          : ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, i) {
                final b = books[i];
                return ListTile(
                  leading: Icon(b.icon, color: b.color),
                  title: Row(
                    children: [
                      Text(b.name),
                      if (b.builtin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('默认', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? _edit(b) : _delete(b),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text(S.edit)),
                      PopupMenuItem(value: 'delete', child: Text(S.delete)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _create() async {
    final res = await showBookEditDialog(context);
    if (res == null || !mounted) return;
    try {
      await context.read<LedgerBookRepository>().create(
        name: res.name,
        iconCode: res.iconCode,
        colorValue: DefaultData.colorChoices.first.toARGB32(),
      );
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    await context.read<BookController>().reload();
  }

  Future<void> _edit(LedgerBook b) async {
    final res = await showBookEditDialog(context, initial: b);
    if (res == null || !mounted) return;
    try {
      await context.read<LedgerBookRepository>().update(
        b,
        name: res.name,
        iconCode: res.iconCode,
        colorValue: b.colorValue,
      );
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    await context.read<BookController>().reload();
  }

  Future<void> _delete(LedgerBook b) async {
    if (b.id == null) return;
    final ok = await showConfirm(
      context,
      title: '删除账本「${b.name}」？',
      content: '仅可删除空账本；有账单的账本会被拒绝删除。',
      confirmLabel: S.delete,
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<LedgerBookRepository>().softDelete(b.id!);
      if (!mounted) return;
      showToast(context, '已删除');
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    await context.read<BookController>().reload();
  }
}
