import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../state/settings_controller.dart';
import '../add/time_wheel_picker.dart';

/// 记账通知（每日记账提醒）设置。
///
/// 当前持久化开关与提醒时间，应用启动时在到点且当日无账单的情况下
/// 应用内提醒一次；系统级推送（Android 通知渠道 / 桌面通知）在后续
/// 版本接入通知插件后复用这里的配置。
class ReminderPage extends StatelessWidget {
  const ReminderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final timeLabel =
        '${settings.reminderHour}:${settings.reminderMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text(S.reminder)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.reminderEnabled,
                  onChanged: settings.setReminderEnabled,
                  title: const Text('每日记账提醒', style: TextStyle(fontSize: 15)),
                  subtitle: Text(
                    '开启后每天到点提醒记一笔',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  enabled: settings.reminderEnabled,
                  title: const Text('提醒时间', style: TextStyle(fontSize: 15)),
                  trailing: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 15,
                      color: settings.reminderEnabled
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  onTap: settings.reminderEnabled
                      ? () => _pickTime(context, settings)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '提醒在应用运行时生效；系统级通知将在后续版本支持。',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    SettingsController settings,
  ) async {
    final picked = await showTimeWheelPicker(
      context,
      initialHour: settings.reminderHour,
      initialMinute: settings.reminderMinute,
    );
    if (picked != null) {
      await settings.setReminderTime(picked.hour, picked.minute);
    }
  }
}
