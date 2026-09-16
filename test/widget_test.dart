import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeeping/core/money.dart';
import 'package:bookkeeping/ui/add/amount_keypad.dart';

void main() {
  testWidgets('记账键盘按键与状态机联动', (tester) async {
    final input = AmountInput();
    var isIncome = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                Text('amt=${input.text}'),
                Expanded(
                  child: AmountKeypad(
                    onDigit: (d) => setState(() => input.appendDigit(d)),
                    onDot: () => setState(() => input.appendDot()),
                    onBackspace: () => setState(() => input.backspace()),
                    onPlus: () => setState(() => isIncome = true),
                    onMinus: () => setState(() => isIncome = false),
                    onSave: () {},
                    saveEnabled: !input.isZeroOrEmpty,
                    isIncome: isIncome,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('.'));
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('amt=12.5'), findsOneWidget);
    expect(input.cents, 1250);

    // 退格一位
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(input.text, '12.');

    // 加/减切换收支态
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(isIncome, isTrue);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(isIncome, isFalse);
  });

  testWidgets('保存按钮禁用态不触发保存回调', (tester) async {
    final input = AmountInput();
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AmountKeypad(
              onDigit: (d) => setState(() => input.appendDigit(d)),
              onDot: () => setState(() => input.appendDot()),
              onBackspace: () => setState(() => input.backspace()),
              onPlus: () {},
              onMinus: () {},
              onSave: () => saved++,
              saveEnabled: !input.isZeroOrEmpty,
              isIncome: false,
            ),
          ),
        ),
      ),
    );
    // 未输入金额时点击保存应无效
    await tester.tap(find.text('保存'), warnIfMissed: false);
    expect(saved, 0);
    await tester.tap(find.text('8'));
    await tester.pump(); // 触发重建，使保存按钮变为可用
    await tester.tap(find.text('保存'));
    expect(saved, 1);
    expect(input.cents, 800);
  });
}
