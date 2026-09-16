import 'package:flutter/material.dart';

/// 记账键盘。右列为退格 / 加 / 减 / 保存（各占一格）。
/// 「加」切到收入、「减」切到支出，与顶部标签联动；
/// 功能键无背景填充，悬停/按压高亮铺满整个方块。
/// 输入合法性全部由 [AmountInput] 把关，键盘只负责转发按键。
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onDot,
    required this.onBackspace,
    required this.onPlus,
    required this.onMinus,
    required this.onSave,
    required this.saveEnabled,
    required this.isIncome,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDot;
  final VoidCallback onBackspace;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final VoidCallback onSave;
  final bool saveEnabled;

  /// 当前是否收入态（控制加/减高亮）。
  final bool isIncome;

  static const double _keyHeight = 52;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 按键：InkWell 铺满整个方块，无独立背景填充。
    Widget numKey(
      String t, {
      int flex = 1,
      VoidCallback? onTap,
      Widget? child,
    }) {
      return Expanded(
        flex: flex,
        child: SizedBox(
          height: _keyHeight,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child:
                  child ??
                  Text(
                    t,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ),
        ),
      );
    }

    Widget funcKey(Widget child, VoidCallback onTap) {
      return Expanded(
        child: SizedBox(
          height: _keyHeight,
          child: InkWell(
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            numKey('7', onTap: () => onDigit(7)),
            numKey('8', onTap: () => onDigit(8)),
            numKey('9', onTap: () => onDigit(9)),
            funcKey(
              Icon(
                Icons.backspace_outlined,
                size: 24,
                color: cs.onSurfaceVariant,
              ),
              onBackspace,
            ),
          ],
        ),
        Row(
          children: [
            numKey('4', onTap: () => onDigit(4)),
            numKey('5', onTap: () => onDigit(5)),
            numKey('6', onTap: () => onDigit(6)),
            funcKey(
              Icon(
                Icons.add,
                size: 26,
                color: isIncome ? cs.primary : cs.onSurfaceVariant,
              ),
              onPlus,
            ),
          ],
        ),
        Row(
          children: [
            numKey('1', onTap: () => onDigit(1)),
            numKey('2', onTap: () => onDigit(2)),
            numKey('3', onTap: () => onDigit(3)),
            funcKey(
              Icon(
                Icons.remove,
                size: 26,
                color: !isIncome ? cs.primary : cs.onSurfaceVariant,
              ),
              onMinus,
            ),
          ],
        ),
        Row(
          children: [
            numKey('0', flex: 2, onTap: () => onDigit(0)),
            numKey('.', onTap: onDot),
            Expanded(
              child: SizedBox(
                height: _keyHeight,
                child: Ink(
                  color: saveEnabled ? cs.primary : cs.surfaceContainerHighest,
                  child: InkWell(
                    onTap: saveEnabled ? onSave : null,
                    child: Center(
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: saveEnabled
                              ? cs.onPrimary
                              : cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
