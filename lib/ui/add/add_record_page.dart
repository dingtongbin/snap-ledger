import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/exceptions.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../data/default_data.dart';
import '../../data/image_store.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/book_controller.dart';
import '../../state/ledger_controller.dart';
import '../../state/ui_prefs.dart';
import '../mine/picker_dialogs.dart';
import '../widgets/common.dart';
import 'amount_keypad.dart';
import 'time_wheel_picker.dart';

/// 记账 / 编辑账单弹层，仅支持支出与收入。
///
/// 性能约定：打开前由 [show] 一次性并行预取交易方式与分类，弹层动画期间
/// 不做任何数据库查询、不出现 loading 二次重建 —— 打开即完整渲染。
/// 弹层内新建分类/交易方式时做单次增量刷新。
class AddRecordSheet extends StatefulWidget {
  const AddRecordSheet._({
    required this.accounts,
    required this.categories,
    this.existing,
  });

  final List<LedgerAccount> accounts;
  final List<TxCategory> categories;
  final LedgerTransaction? existing;

  static Future<void> show(
    BuildContext context, {
    LedgerTransaction? existing,
  }) async {
    final accRepo = context.read<AccountRepository>();
    final catRepo = context.read<CategoryRepository>();
    // 打开前预取，避免弹层动画与数据库查询/网格重建抢帧。
    final results = await Future.wait([accRepo.listAll(), catRepo.listAll()]);
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // 允许下拉关闭（移动端惯例）；内容区滚动/键盘输入不受影响。
      enableDrag: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddRecordSheet._(
          accounts: results[0] as List<LedgerAccount>,
          categories: results[1] as List<TxCategory>,
          existing: existing,
        ),
      ),
    );
  }

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  late TxType _type;
  final AmountInput _amount = AmountInput();
  late List<LedgerAccount> _accounts;
  late int _accountId;
  TxCategory? _category;
  late List<TxCategory> _categories;

  /// 账单日期（天按钮，默认今天 / 编辑态取原账单日期）。
  late DateTime _date;

  /// 当日秒偏移（时分秒按钮）。新建 = 弹层打开时刻的快照（静止不跳动）；
  /// 编辑 = 原账单时间戳的当日时刻。
  late int _secondsOfDay;

late final TextEditingController _noteCtrl;

  /// 本笔账单归属账本：编辑态取原账单；新建态 = 当前选中账本，
  /// 未选具体账本时为默认账本。
  late int _bookId;

  /// 当前已选/已保存的图片路径（绝对路径）。新建态为空列表，
  /// 编辑态从原账单的 [LedgerTransaction.imagePaths] 加载。
  late List<String> _imagePaths;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _accounts = widget.accounts;
    _categories = widget.categories;
    // 新建态恢复上次选择（交易类型/交易方式），编辑态以原账单为准。
    _type = e?.type ??
        (UiPrefs.getInt('add.type', TxType.expense.code) == TxType.income.code
            ? TxType.income
            : TxType.expense);
    _date = e == null ? DateTime.now() : DateKeys.parseDateKey(e.dateKey);
    final openedAt = e == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(e.timestamp);
    _secondsOfDay =
        openedAt.hour * 3600 + openedAt.minute * 60 + openedAt.second;
    if (e != null && e.amountCents > 0) {
      _amount.reset(AmountInput.fromCents(e.amountCents));
    }
    _accountId = e?.accountId ??
        UiPrefs.getInt(
            'add.accountId',
            _accounts.isEmpty
                ? 0
                : _accounts.firstWhere((a) => a.builtin,
                        orElse: () => _accounts.first)
                    .id!);
    // 编辑态账户可能已被删除：回退到第一个可用账户。
    if (!_accounts.any((a) => a.id == _accountId)) {
      _accountId = _accounts.isEmpty ? 0 : _accounts.first.id!;
    }
    // 上次使用的分类（需与当前类型匹配且未被删除）。
    final savedCatId = UiPrefs.getInt('add.categoryId', 0);
    if (e != null && e.categoryId != null) {
      _category = _categories.where((c) => c.id == e.categoryId).firstOrNull;
    } else if (savedCatId > 0) {
      _category = _categories.where((c) =>
          c.id == savedCatId && c.kind == _type).firstOrNull;
    }
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _imagePaths = List<String>.from(e?.imagePaths ?? const <String>[]);
    _bookId = e?.ledgerId ?? context.read<BookController>().writeTargetId;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<TxCategory> get _visibleCategories =>
      _categories.where((c) => c.kind == _type).toList();

  bool get _canSave =>
      _accounts.isNotEmpty &&
      !_amount.isZeroOrEmpty &&
      _category != null &&
      _category!.kind == _type;

  /// 天按钮标签：今天 / M月d日。
  String get _dateLabel => DateKeys.dateKey(_date) == DateKeys.todayKey()
      ? '今天'
      : '${_date.month}月${_date.day}日';

  /// 时分秒按钮标签（静止快照，不随时间跳动）。
  String get _timeLabel {
    final h = (_secondsOfDay ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secondsOfDay % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 保存用的精确时刻 = 天按钮日期 + 时分秒按钮时刻。
  DateTime get _combinedDateTime => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _secondsOfDay ~/ 3600,
    (_secondsOfDay % 3600) ~/ 60,
    _secondsOfDay % 60,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.80,
      child: Column(
        children: [
          // ── 拖拽把手：提示可下拉关闭 ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 6, bottom: 2),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── 顶排：支出/收入（左） + 日期/时刻（右） ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                UnderlineTabs(
                  labels: const [S.addExpense, S.addIncome],
                  selectedIndex: _type == TxType.expense ? 0 : 1,
                  onChanged: (i) =>
                      _switchType(i == 0 ? TxType.expense : TxType.income),
                ),
                const Spacer(),
                _timeChip(
                  onTap: _pickDate,
                  icon: Icons.event_outlined,
                  label: _dateLabel,
                ),
                const SizedBox(width: 6),
                _timeChip(
                  onTap: _pickTime,
                  icon: Icons.schedule_outlined,
                  label: _timeLabel,
                ),
              ],
            ),
          ),
          // ── 金额显示 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Text(
                        ' ¥  ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextSpan(
                      text: _amount.text.isEmpty ? '0.00' : _amount.text,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── 分类网格（末尾为「＋ 新建分类」） ──
          Expanded(
            child: _CategoryGrid(
              categories: _visibleCategories,
              selected: _category,
              onSelect: (c) {
                setState(() => _category = c);
                UiPrefs.setInt('add.categoryId', c.id ?? 0);
              },
              onAdd: _addCategory,
            ),
          ),
          // ── 账本 + 交易方式 + 备注 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                _chip(
                  onTap: _pickBook,
                  icon: Icons.menu_book_outlined,
                  label: context
                      .watch<BookController>()
                      .books
                      .where((b) => b.id == _bookId)
                      .map((b) => b.name)
                      .firstOrNull ??
                      '默认账本',
                ),
                const SizedBox(width: 8),
                _chip(
                  onTap: _pickAccount,
                  icon: Icons.account_balance_wallet_outlined,
                  label:
                      _accounts
                          .where((a) => a.id == _accountId)
                          .map((a) => a.name)
                          .firstOrNull ??
                      '选择交易方式',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    maxLength: 50,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '点击填写备注',
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── 图片（备注下方）：横滑缩略图 + 「＋ 图片」入口 ──
          _ImagePickerBar(
            paths: _imagePaths,
            onPick: _pickImages,
            onRemove: (p) => setState(() => _imagePaths.remove(p)),
          ),
          const Divider(height: 1),
          AmountKeypad(
            onDigit: (d) => setState(() => _amount.appendDigit(d)),
            onDot: () => setState(() => _amount.appendDot()),
            onBackspace: () => setState(() => _amount.backspace()),
            onPlus: () => _switchType(TxType.income),
            onMinus: () => _switchType(TxType.expense),
            onSave: _save,
            saveEnabled: _canSave,
            isIncome: _type == TxType.income,
          ),
        ],
      ),
    );
  }

  /// 顶排时间按钮（天 / 时分秒）。
  Widget _timeChip({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 选择本笔账单的归属账本（只影响本笔，不改全局视图筛选）。
  Future<void> _pickBook() async {
    final controller = context.read<BookController>();
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '选择账本',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: controller.books.length,
                itemBuilder: (ctx, i) {
                  final b = controller.books[i];
                  final selected = b.id == _bookId;
                  return ListTile(
                    leading: Icon(b.icon, color: b.color),
                    title: Text(b.name),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(ctx, b.id),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('新建账本'),
              onTap: () async {
                final res = await showBookEditDialog(ctx);
                if (res == null || !ctx.mounted) return;
                try {
                  final id = await ctx.read<LedgerBookRepository>().create(
                    name: res.name,
                    iconCode: res.iconCode,
                    colorValue: DefaultData.colorChoices.first.toARGB32(),
                  );
                  await controller.reload();
                  if (ctx.mounted && id > 0) Navigator.pop(ctx, id);
                } on AppException catch (e) {
                  if (ctx.mounted) showToast(ctx, e.message);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _bookId = picked);
  }

  Future<void> _pickAccount() async {
    final id = await showAccountPicker(
      context,
      accounts: _accounts,
      selectedId: _accountId,
      title: '选择交易方式',
      onAdd: () async {
        final res = await showAccountEditDialog(context);
        if (res == null || !mounted) return null;
        final accRepo = context.read<AccountRepository>();
        try {
          await accRepo.create(
            name: res.name,
            iconCode: res.iconCode,
            colorValue: DefaultData.colorChoices.first.toARGB32(),
          );
        } on AppException catch (err) {
          if (mounted) showToast(context, err.message);
          return null;
        }
        final list = await accRepo.listAll();
        if (mounted) setState(() => _accounts = list);
        return list;
      },
    );
    if (id != null && id != _accountId) {
      setState(() {
        _accountId = id;
        UiPrefs.setInt('add.accountId', id);
      });
    }
  }

  Future<void> _addCategory() async {
    final res = await showCategoryEditDialog(context, kind: _type);
    if (res == null || !mounted) return;
    final catRepo = context.read<CategoryRepository>();
    final int newId;
    try {
      newId = await catRepo.create(
        name: res.name,
        kind: _type,
        iconCode: res.iconCode,
        colorValue: DefaultData.colorChoices.first.toARGB32(),
      );
    } on AppException catch (err) {
      if (mounted) showToast(context, err.message);
      return;
    }
    final list = await catRepo.listAll();
    if (!mounted) return;
    setState(() {
      _categories = list;
      // 自动选中新分类。
      _category = list.where((c) => c.id == newId).firstOrNull ?? _category;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      // 直接进入日历视图。
      initialEntryMode: DatePickerEntryMode.calendar,
      // 右上角的「切换到文本输入」按钮隐藏在 builder 里的右上角吸顶区。
      builder: (ctx, child) => Stack(
        children: [
          child!,
          // 顶栏右上角吸顶同色区：拦截 Material 自带的 input 切换按钮的显示与点击。
          Positioned(
            top: 8,
            right: 8,
            child: AbsorbPointer(
              child: Container(
                width: 48,
                height: 48,
                color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimeWheelPicker(
      context,
      initialHour: _secondsOfDay ~/ 3600,
      initialMinute: (_secondsOfDay % 3600) ~/ 60,
    );
    if (picked != null) {
      setState(() => _secondsOfDay = picked.hour * 3600 + picked.minute * 60);
    }
  }

  /// 多选图片：选完后立即把原文件拷贝到 attachments 目录（不压缩），
  /// 把稳定路径写入 [_imagePaths]。
  Future<void> _pickImages() async {
    const group = XTypeGroup(label: '图片', extensions: <String>['*']);
    final List<XFile> files;
    try {
      files = await openFiles(acceptedTypeGroups: [group]);
    } on PlatformException catch (err) {
      if (mounted) showToast(context, '选择图片失败：${err.message ?? err.code}');
      return;
    } catch (_) {
      if (mounted) showToast(context, '选择图片失败');
      return;
    }
    if (files.isEmpty) return;
    final imported = <String>[];
    for (final f in files) {
      try {
        final path = await ImageStore.importFromFile(File(f.path));
        imported.add(path);
      } catch (err) {
        if (mounted) showToast(context, '读取图片失败：$err');
      }
    }
    if (imported.isEmpty || !mounted) return;
    setState(() => _imagePaths.addAll(imported));
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final cents = _amount.cents;
    if (cents == null || cents <= 0) return;
    if (_category == null || _category!.kind != _type) {
      showToast(context, '请选择分类');
      return;
    }
    final repo = context.read<TransactionRepository>();
    final ledger = context.read<LedgerController>();
    final e = widget.existing;
    final note = _noteCtrl.text.trim();
    final timestamp = _combinedDateTime.millisecondsSinceEpoch;
    final tx = LedgerTransaction(
      id: e?.id,
      type: _type,
      amountCents: cents,
      categoryId: _category!.id,
      accountId: _accountId,
      targetAccountId: null,
      dateKey: DateKeys.dateKey(_date),
      timestamp: timestamp,
      note: note.isEmpty ? null : note,
      ledgerId: _bookId,
      imagePaths: List<String>.from(_imagePaths),
      deleted: false,
      createdAt: e?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
    try {
      if (e == null) {
        await repo.create(tx);
      } else {
        await repo.update(tx);
      }
    } on AppException catch (err) {
      if (mounted) showToast(context, err.message);
      return;
    }
    ledger.bump();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _switchType(TxType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      UiPrefs.setInt('add.type', t.code);
      if (_category != null && _category!.kind != t) {
        _category = null;
      }
    });
  }
}

/// 图片选择条：左侧「＋ 图片」入口 + 已选缩略图横滑列表。
class _ImagePickerBar extends StatelessWidget {
  const _ImagePickerBar({
    required this.paths,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> paths;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: paths.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: cs.onSurfaceVariant, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      '图片',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          final path = paths[i - 1];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  cacheWidth: 168,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove(path),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 分类九宫格（数据已就绪，纯同步构建）。
/// 末尾固定一个「＋ 新建分类」入口；图标无背景，选中态用主色标识。
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final List<TxCategory> categories;
  final TxCategory? selected;
  final ValueChanged<TxCategory> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: categories.length + 1,
      itemBuilder: (context, i) {
        // 末尾「＋ 新建分类」。
        if (i >= categories.length) {
          return InkWell(
            onTap: onAdd,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: cs.onSurfaceVariant, size: 22),
                const SizedBox(height: 3),
                Text(
                  '新建',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
        final c = categories[i];
        final isSelected = selected?.id == c.id;
        return InkWell(
          onTap: () => onSelect(c),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                c.icon,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? cs.primary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
