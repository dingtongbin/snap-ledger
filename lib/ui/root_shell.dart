import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/strings.dart';
import '../data/repositories/repositories.dart';
import '../state/ledger_controller.dart';
import '../state/settings_controller.dart';
import 'add/add_record_page.dart';
import 'detail/detail_page.dart';
import 'help/help_page.dart';
import 'mine/mine_page.dart';
import 'stats/stats_page.dart';

/// 应用主壳：四个常驻页 + 底部导航中的「＋」记账入口。
/// IndexedStack 保持各页状态（滚动位置、月份选择等）。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0; // 默认「明细」

  /// 导航项序号：0 明细 / 1 报表 / 3 帮助 / 4 设置（2 是「＋」，不切页）。
  static const int _helpIndex = 3;
  static const int _mineIndex = 4;

  @override
  void initState() {
    super.initState();
    // 启动后做一次到点提醒检查（应用内提醒；系统推送后续接入）。
    Future.microtask(_maybeRemind);
  }

  /// 记账通知：到点且当日无账单时提醒一次，当天不重复。
  Future<void> _maybeRemind() async {
    final settings = context.read<SettingsController>();
    if (!settings.reminderEnabled) return;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    if (nowMinutes < settings.reminderHour * 60 + settings.reminderMinute) {
      return;
    }
    final today = DateKeys.dateKey(now);
    if (settings.reminderLastShown == today) return;
    final hasTx = await context.read<TransactionRepository>().hasAnyOn(today);
    await settings.markReminderShown(today);
    if (!hasTx && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('今天还没记账，记一笔吧！'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openAdd() async {
    await AddRecordSheet.show(context);
    if (mounted) context.read<LedgerController>().bump();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        // 导航序号 -> 页面栈序号：明细0 / 图表1 / 备份2 / 设置3。
        index: _index == _mineIndex
            ? 3
            : _index == _helpIndex
            ? 2
            : _index,
        children: const [DetailPage(), StatsPage(), HelpPage(), MinePage()],
      ),
      bottomNavigationBar: BottomAppBar(
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                _item(0, Icons.receipt_long_outlined, S.tabDetail, cs),
                _item(1, Icons.donut_large_outlined, S.tabStats, cs),
                _addButton(cs),
                _item(_helpIndex, Icons.help_outline, S.tabHelp, cs),
                _item(_mineIndex, Icons.settings_outlined, S.tabMine, cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label, ColorScheme cs) {
    final selected = _index == i;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        // 选中/悬停只让图标和文字变色，不画背景高亮。
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部导航中的「＋」记账按钮：主色圆形，无选中态。
  Widget _addButton(ColorScheme cs) {
    return Expanded(
      child: Center(
        child: Material(
          color: cs.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openAdd,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.add, color: cs.onPrimary, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
