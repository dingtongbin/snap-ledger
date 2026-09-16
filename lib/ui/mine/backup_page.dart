import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions.dart';
import '../../core/strings.dart';
import '../../data/backup/backup_service.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';

/// 备份与恢复页。
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.tabBackup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            context,
            icon: Icons.backup_outlined,
            title: '导出备份',
            body:
                '将全部分类、账户与账单（含已删除项）导出为 JSON 文件，'
                '可用于换机迁移或定期备份。CSV 为账单明细表，便于用 Excel 查看。',
            actions: [
              FilledButton.icon(
                onPressed: () => _exportJson(context),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('导出 JSON 备份'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportCsv(context),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('导出 CSV'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            context,
            icon: Icons.restore_outlined,
            title: '恢复备份',
            body:
                '选择本应用导出的 JSON 备份文件进行恢复。注意：'
                '恢复会覆盖当前全部数据，且无法撤销，建议先导出一份当前备份。',
            actions: [
              FilledButton.tonalIcon(
                onPressed: () => _restore(context),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('选择文件并恢复'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2C30)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  /// 显示忙碌遮罩并执行 [job]；job 内不得使用 BuildContext，
  /// 结果由调用方在 await 返回且 mounted 校验后再处理。
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

  Future<void> _exportJson(BuildContext context) async {
    final service = context.read<BackupService>();
    String? path;
    Object? error;
    await _runBusy(context, () async {
      try {
        path = await service.exportBackupToFile();
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
        content: SelectableText(path!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
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
        final r = await service.restoreZipFile(file.path);
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
