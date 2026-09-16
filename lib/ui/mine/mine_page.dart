import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/backup/backup_service.dart';
import '../../data/repositories/repositories.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import 'license_view_page.dart';
import 'manage_books_page.dart';
import 'manage_pages.dart';

/// 「设置」页：分组卡片布局（无小标题），紧凑行高显示更多条目。
/// 数据组内置导入/导出；备份逻辑由 [BackupService] 提供。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final modeLabel = switch (settings.themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
    return Scaffold(
      appBar: AppBar(title: Text(S.tabMine)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 88),
        children: [
          _group(context, [
            _tile(
              context,
              icon: Icons.menu_book_outlined,
              title: '账本管理',
              subtitle: '多账本分组与切换',
              onTap: () => _push(context, const ManageBooksPage()),
            ),
            _tile(
              context,
              icon: Icons.category_outlined,
              title: '分类管理',
              subtitle: '支出与收入分类自定义',
              onTap: () => _push(context, const CategoryManagePage()),
            ),
          ]),
          _group(context, [
            _tile(
              context,
              icon: Icons.brightness_6_outlined,
              title: '外观',
              subtitle: modeLabel,
              isAction: true,
              onTap: () => _pickTheme(context, settings),
            ),
            _tile(
              context,
              icon: Icons.palette_outlined,
              title: '主题色',
              subtitle: AppTheme.themeSeeds[settings.themeSeedIndex].name,
              isAction: true,
              onTap: () => _pickSeed(context, settings),
            ),
          ]),
          _group(context, [
            _tile(
              context,
              icon: Icons.file_download_outlined,
              title: '导出备份',
              subtitle: 'zip 包：账本数据 + 图片附件，可加密',
              isAction: true,
              onTap: () => _exportBackup(context),
            ),
            _tile(
              context,
              icon: Icons.table_view_outlined,
              title: '导出 CSV',
              subtitle: '账单明细表，Excel 可读',
              isAction: true,
              onTap: () => _exportCsv(context),
            ),
            _tile(
              context,
              icon: Icons.restore_outlined,
              title: '从备份恢复',
              subtitle: '选择 zip 备份包，覆盖当前数据',
              isAction: true,
              onTap: () => _restore(context),
            ),
            _tile(
              context,
              icon: Icons.delete_sweep_outlined,
              title: '清空全部账单',
              titleColor: cs.error,
              subtitle: '仅保留分类与账户，不可恢复',
              isAction: true,
              onTap: () => _clearAll(context),
            ),
          ]),
          _group(context, [
            _tile(
              context,
              icon: Icons.gavel_outlined,
              title: '开源许可（GPL-3.0）',
              subtitle: '本应用为自由软件',
              onTap: () => _push(context, const LicenseViewPage()),
            ),
            _tile(
              context,
              icon: Icons.info_outline,
              title: '关于${S.appName}',
              subtitle: '版本 ${S.appVersion}',
              onTap: () => showLicensePage(
                context: context,
                applicationName: S.appName,
                applicationVersion: S.appVersion,
                applicationIcon: Image.asset(
                  'assets/logo/logo.png',
                  width: 64,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'GNU GPL v3.0 · 基于 Flutter 构建',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分组卡片：同一类设置项包在一张圆角白卡里，行间细分隔线。
  Widget _group(BuildContext context, List<Widget> tiles) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              const Divider(height: 0.6, thickness: 0.6, indent: 42),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    bool isAction = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Icon(icon, size: 20, color: titleColor ?? cs.primary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor ?? cs.onSurface,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      // 右箭头只用于「进入下一页」；动作项（导出/清空/选择器）不带箭头。
      trailing: isAction
          ? null
          : Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _pickTheme(
    BuildContext context,
    SettingsController settings,
  ) async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (final (m, label, icon) in const [
              (ThemeMode.system, '跟随系统', Icons.brightness_auto_outlined),
              (ThemeMode.light, '浅色', Icons.light_mode_outlined),
              (ThemeMode.dark, '深色', Icons.dark_mode_outlined),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: m == settings.themeMode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (mode != null) await settings.setThemeMode(mode);
  }

  Future<void> _pickSeed(
    BuildContext context,
    SettingsController settings,
  ) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('主题色'),
        children: [
          for (var i = 0; i < AppTheme.themeSeeds.length; i++)
            ListTile(
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.themeSeeds[i].color,
              ),
              title: Text(AppTheme.themeSeeds[i].name),
              trailing: i == settings.themeSeedIndex
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, i),
            ),
        ],
      ),
    );
    if (picked != null) await settings.setThemeSeed(picked);
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok1 = await showConfirm(
      context,
      title: '清空全部账单？',
      content: '将删除所有账单记录（分类与账户保留），此操作不可恢复。',
      confirmLabel: '清空',
      danger: true,
    );
    if (!ok1 || !context.mounted) return;
    final ok2 = await showConfirm(
      context,
      title: '再次确认',
      content: '真的要删除全部账单吗？建议先通过「导出备份」留存一份。',
      confirmLabel: '仍要清空',
      danger: true,
    );
    if (!ok2 || !context.mounted) return;
    final repo = context.read<TransactionRepository>();
    final ledger = context.read<LedgerController>();
    await repo.clearAll();
    ledger.bump();
    if (context.mounted) showToast(context, '已清空全部账单');
  }

  /// 显示忙碌遮罩并执行 [job]；结果由调用方在 await 返回后再处理。
  Future<void> _runBusy(
    BuildContext context,
    Future<void> Function() job,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    navigator.push(route);
    try {
      await job();
    } finally {
      navigator.removeRoute(route);
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final service = context.read<BackupService>();
    // 先设定密码：可留空 = 不加密（明文 zip，恢复时无需密码）。
    final password = await _askPassword(
      context,
      title: '设置备份密码',
      hint: '密码（留空则不加密）',
    );
    if (password == null) return; // 用户取消
    if (!context.mounted) return;
    String? path;
    Object? error;
    await _runBusy(context, () async {
      try {
        path = await service.exportBackupToFile(password: password);
      } catch (e) {
        error = e;
      }
    });
    if (!context.mounted) return;
    if (error != null) {
      showToast(context, '导出失败：$error');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备份完成'),
        content: SelectableText(
          path! + (password.isEmpty ? '\n\n⚠️ 未加密，请妥善保管' : '\n\n已加密，请牢记密码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  /// 密码输入弹窗。返回 null = 取消；空字符串 = 明确不加密。
  Future<String?> _askPassword(
    BuildContext context, {
    required String title,
    required String hint,
    String confirmLabel = '确定',
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final service = context.read<BackupService>();
    String? path;
    Object? error;
    await _runBusy(context, () async {
      try {
        path = await service.exportCsvToFile();
      } catch (e) {
        error = e;
      }
    });
    if (!context.mounted) return;
    if (error != null) {
      showToast(context, '导出失败：$error');
    } else {
      showToast(context, '已导出：$path');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final service = context.read<BackupService>();
    final ledger = context.read<LedgerController>();
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: '随手记账备份包', extensions: ['zip']),
      ],
    );
    if (file == null) return;
    if (!context.mounted) return;
    // 加密备份先要密码；明文备份直接走确认。
    String? password;
    final encrypted = await BackupService.isEncryptedFile(file.path);
    if (!context.mounted) return;
    if (encrypted) {
      password = await _askPassword(
        context,
        title: '该备份已加密',
        hint: '输入备份密码',
        confirmLabel: '继续',
      );
      if (password == null || password.isEmpty) return;
      if (!context.mounted) return;
    }
    final ok = await showConfirm(
      context,
      title: '恢复备份？',
      content: '恢复会覆盖当前全部数据（分类、账户、账单），且无法撤销。',
      confirmLabel: '恢复',
      danger: true,
    );
    if (!ok || !context.mounted) return;

    Object? error;
    String? message;
    await _runBusy(context, () async {
      try {
        final r = await service.restoreZipFile(
          file.path,
          password: password,
        );
        message = r.toString();
        ledger.bump();
      } on AppException catch (e) {
        message = e.message;
      } catch (e) {
        error = e;
      }
    });
    if (!context.mounted) return;
    if (error != null) {
      showToast(context, '恢复失败：$error');
    } else {
      showToast(context, message ?? '恢复完成');
    }
  }
}
