import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// 两列上下滑轮时间选择器（时、分，秒固定为 0）。
///
/// 点击「确定」返回 (hour, minute)；点取消 / 屏障关闭返回 null。
Future<({int hour, int minute})?> showTimeWheelPicker(
  BuildContext context, {
  required int initialHour,
  required int initialMinute,
}) {
  return showModalBottomSheet<({int hour, int minute})>(
    context: context,
    builder: (_) => _TimeWheelSheet(
      initialHour: initialHour.clamp(0, 23),
      initialMinute: initialMinute.clamp(0, 59),
    ),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initialHour, required this.initialMinute});

  final int initialHour;
  final int initialMinute;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;
  late int _hour = widget.initialHour;
  late int _minute = widget.initialMinute;

  @override
  void initState() {
    super.initState();
    _hCtrl = FixedExtentScrollController(initialItem: _hour);
    _mCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController ctrl,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListWheelScrollView.useDelegate(
      controller: ctrl,
      itemExtent: 38,
      perspective: 0.003,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (_, i) => Center(
          child: Text(
            i.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ),
        childCount: max + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        height: 280,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCard
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // 标题栏
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const Spacer(),
                Text(
                  '选择时间',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    (hour: _hour, minute: _minute),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 蓝色高亮背景 + 列标识「时」「分」（z 顺序在底层）。
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '时',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 28),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '分',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 滚轮层（叠加在高亮条之上，画所有数字 + 选中行的「时/分」）。
                  Row(
                    children: [
                      Expanded(
                        child: _wheel(
                          ctrl: _hCtrl,
                          max: 23,
                          onChanged: (v) => setState(() => _hour = v),
                        ),
                      ),
                      Text(
                        ':',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      Expanded(
                        child: _wheel(
                          ctrl: _mCtrl,
                          max: 59,
                          onChanged: (v) => setState(() => _minute = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}