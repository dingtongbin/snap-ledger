import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/repositories/repositories.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import 'backup_page.dart';
import 'license_view_page.dart';
import 'manage_pages.dart';

/// 「我的」页：账本管理、外观、数据与关于。
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        children: [
          _section(context, '账本'),
          _tile(
            context,
            icon: Icons.category_outlined,
            title: '分类管理',
            subtitle: '支出与收入分类自定义',
            onTap: () => _push(context, const CategoryManagePage()),
          ),
          _section(context, '通用'),
          _tile(
            context,
            icon: Icons.brightness_6_outlined,
            title: '外观',
            subtitle: modeLabel,
            onTap: () => _pickTheme(context, settings),
          ),
          _tile(
            context,
            icon: Icons.palette_outlined,
            title: '主题色',
            subtitle: AppTheme.themeSeeds[settings.themeSeedIndex].name,
            onTap: () => _pickSeed(context, settings),
          ),
          _section(context, '数据'),
          _tile(
            context,
            icon: Icons.cloud_sync_outlined,
            title: '备份与恢复',
            subtitle: '导出 JSON / CSV，或从备份恢复',
            onTap: () => _push(context, const BackupPage()),
          ),
          _tile(
            context,
            icon: Icons.delete_sweep_outlined,
            title: '清空全部账单',
            titleColor: cs.error,
            subtitle: '仅保留分类与账户，不可恢复',
            onTap: () => _clearAll(context),
          ),
          _section(context, '关于'),
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
              applicationIcon: const Icon(Icons.savings_outlined, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'GNU GPL v3.0 · 基于 Flutter 构建',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? cs.primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: titleColor ?? cs.onSurface,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
      content: '真的要删除全部账单吗？建议先在「备份与恢复」中导出一份备份。',
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
}
