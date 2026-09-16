import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../data/default_data.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../widgets/common.dart';
import 'picker_dialogs.dart';

/// 分类管理：支出/收入两个页签，支持新建、编辑、删除。
/// 删除为软删除，历史账单回退显示「已删除分类」。
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  int _tick = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分类管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '支出'),
              Tab(text: '收入'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _create,
          shape: const StadiumBorder(),
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [_list(TxType.expense), _list(TxType.income)],
        ),
      ),
    );
  }

  Widget _list(TxType kind) {
    return FutureBuilder<List<TxCategory>>(
      key: ValueKey('cat-$kind-$_tick'),
      future: context.read<CategoryRepository>().listByKind(kind),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cats = snap.data!;
        if (cats.isEmpty) {
          return EmptyState(
            icon: Icons.category_outlined,
            title: '还没有分类，点右下角新建',
          );
        }
        return ListView.builder(
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final c = cats[i];
            return ListTile(
              leading: CategoryBadge(icon: c.icon),
              title: Row(
                children: [
                  Text(c.name),
                  if (c.builtin) ...[
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
                onSelected: (v) => v == 'edit' ? _edit(c) : _delete(c),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text(S.edit)),
                  PopupMenuItem(value: 'delete', child: Text(S.delete)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  TxType _currentKind() {
    final idx = DefaultTabController.maybeOf(context)?.index ?? 0;
    return idx == 1 ? TxType.income : TxType.expense;
  }

  Future<void> _create() async {
    final kind = _currentKind();
    final r = await showCategoryEditDialog(context, kind: kind);
    if (r == null || !mounted) return;
    try {
      await context.read<CategoryRepository>().create(
        name: r.name,
        kind: kind,
        iconCode: r.iconCode,
        colorValue: DefaultData.colorChoices.first.toARGB32(),
      );
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    setState(() => _tick++);
  }

  Future<void> _edit(TxCategory c) async {
    final r = await showCategoryEditDialog(context, initial: c, kind: c.kind);
    if (r == null || !mounted) return;
    try {
      await context.read<CategoryRepository>().update(
        c,
        name: r.name,
        iconCode: r.iconCode,
        colorValue: c.color.toARGB32(),
      );
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    setState(() => _tick++);
  }

  Future<void> _delete(TxCategory c) async {
    if (c.id == null) return;
    final repo = context.read<CategoryRepository>();
    final used = await repo.countByCategory(c.id!);
    if (!mounted) return;
    final ok = await showConfirm(
      context,
      title: '删除分类「${c.name}」？',
      content: used > 0
          ? '该分类下有 $used 笔账单，删除后这些账单仍会保留，分类显示为「${S.unknownCategory}」。'
          : '删除后可在分类列表中重建同名分类。',
      confirmLabel: S.delete,
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await repo.softDelete(c.id!);
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    setState(() => _tick++);
  }
}

/// 账户管理：新建、编辑、删除（有账单的账户禁止删除）。
class AccountManagePage extends StatefulWidget {
  const AccountManagePage({super.key});

  @override
  State<AccountManagePage> createState() => _AccountManagePageState();
}

class _AccountManagePageState extends State<AccountManagePage> {
  int _tick = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        shape: const StadiumBorder(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<dynamic>>(
        key: ValueKey('acct-$_tick'),
        future: Future.wait([
          context.read<AccountRepository>().listAll(),
          context.read<TransactionRepository>().accountBalances(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snap.data![0] as List<LedgerAccount>;
          final balances = snap.data![1] as Map<int, int>;
          if (accounts.isEmpty) {
            return EmptyState(icon: Icons.wallet_outlined, title: '还没有账户');
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, i) {
              final a = accounts[i];
              final b = balances[a.id!] ?? 0;
              final cs = Theme.of(context).colorScheme;
              return ListTile(
                leading: CategoryBadge(icon: a.icon),
                title: Text(a.name),
                subtitle: const Text('余额'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Money.format(b),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: b < 0 ? cs.error : cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? _edit(a) : _delete(a),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text(S.edit)),
                        PopupMenuItem(value: 'delete', child: Text(S.delete)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create() async {
    final r = await showAccountEditDialog(context);
    if (r == null || !mounted) return;
    try {
      await context.read<AccountRepository>().create(
        name: r.name,
        iconCode: r.iconCode,
        colorValue: DefaultData.colorChoices.first.toARGB32(),
      );
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    setState(() => _tick++);
  }

  Future<void> _edit(LedgerAccount a) async {
    final r = await showAccountEditDialog(context, initial: a);
    if (r == null || !mounted) return;
    try {
      await context.read<AccountRepository>().update(
        a,
        name: r.name,
        iconCode: r.iconCode,
        colorValue: a.color.toARGB32(),
      );
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    setState(() => _tick++);
  }

  Future<void> _delete(LedgerAccount a) async {
    if (a.id == null) return;
    final ok = await showConfirm(
      context,
      title: '删除账户「${a.name}」？',
      content: '账户下没有账单时才能删除。',
      confirmLabel: S.delete,
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<AccountRepository>().softDelete(a.id!);
      setState(() => _tick++);
    } on AppException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }
}
