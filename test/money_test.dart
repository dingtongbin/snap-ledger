import 'package:flutter_test/flutter_test.dart';
import 'package:snap_ledger/core/money.dart';

void main() {
  group('Money.parse', () {
    test('合法输入', () {
      expect(Money.parse('0'), 0);
      expect(Money.parse('12.3'), 1230);
      expect(Money.parse('12.34'), 1234);
      expect(Money.parse('0.05'), 5);
      expect(Money.parse('99999999.99'), Money.maxCents);
      expect(Money.parse(' 12.5 '), 1250); // 允许首尾空白
    });

    test('非法输入返回 null', () {
      for (final s in [
        '',
        ' ',
        'abc',
        '-5',
        '+5',
        '007',
        '01',
        '1.234',
        '1.2.3',
        '100000000',
        '1,234',
        '.',
        '1.',
      ]) {
        expect(Money.parse(s), isNull, reason: '"$s" 应被判为非法');
      }
    });
  });

  group('Money.format', () {
    test('基本与千分位', () {
      expect(Money.format(0), '0.00');
      expect(Money.format(5), '0.05');
      expect(Money.format(1000), '10.00');
      expect(Money.format(1005), '10.05');
      expect(Money.format(1234567), '12,345.67');
      expect(Money.format(100000000), '1,000,000.00');
      expect(Money.format(Money.maxCents), '99,999,999.99');
    });

    test('负数带负号', () {
      expect(Money.format(-1234), '-12.34');
    });

    test('format(去掉千分位) 与 parse 往返一致', () {
      for (final s in ['0', '8', '12.3', '99.99', '123456.78']) {
        final cents = Money.parse(s)!;
        final pretty = Money.format(cents).replaceAll(',', '');
        expect(Money.parse(pretty), cents);
      }
    });
  });

  group('AmountInput 键盘状态机', () {
    test('前导零处理', () {
      final a = AmountInput();
      expect(a.appendDigit(0), isTrue);
      expect(a.text, '0');
      expect(a.appendDigit(0), isFalse); // "00" 拒绝
      expect(a.text, '0');
      expect(a.appendDigit(5), isTrue); // "05" -> "5"
      expect(a.text, '5');
    });

    test('小数点与位数上限', () {
      final a = AmountInput();
      expect(a.appendDot(), isTrue);
      expect(a.text, '0.');
      expect(a.cents, isNull); // 尚不构成合法金额
      expect(a.appendDot(), isFalse);
      a.appendDigit(5);
      expect(a.appendDigit(6), isTrue);
      expect(a.appendDigit(7), isFalse); // 小数最多 2 位
      expect(a.text, '0.56');

      final b = AmountInput()..reset('99999999');
      expect(b.appendDigit(9), isFalse); // 整数最多 8 位
      expect(b.cents, 9999999900); // 99,999,999.00
      final c = AmountInput()..reset('99999999.99');
      expect(c.appendDigit(9), isFalse); // 小数位也已满
      expect(c.cents, Money.maxCents);
    });

    test('删除与清空', () {
      final a = AmountInput()
        ..appendDigit(1)
        ..appendDigit(2)
        ..appendDot()
        ..appendDigit(3);
      expect(a.text, '12.3');
      a.backspace();
      expect(a.text, '12.');
      a.clear();
      expect(a.isEmpty, isTrue);
      expect(a.cents, isNull);
    });

    test('isZeroOrEmpty 禁用保存', () {
      final a = AmountInput();
      expect(a.isZeroOrEmpty, isTrue);
      a.appendDigit(0);
      expect(a.isZeroOrEmpty, isTrue);
      a.appendDigit(1);
      expect(a.isZeroOrEmpty, isFalse);
    });

    test('fromCents 由分还原可编辑输入（固定两位小数，与详情展示一致）', () {
      expect(AmountInput.fromCents(0), '0.00');
      expect(AmountInput.fromCents(1205), '12.05');
      expect(AmountInput.fromCents(1200), '12.00');
      expect(AmountInput.fromCents(5), '0.05');
    });
  });
}
