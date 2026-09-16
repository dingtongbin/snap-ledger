import 'package:flutter_test/flutter_test.dart';
import 'package:snap_ledger/core/date_utils.dart';

void main() {
  test('dateKey 补零', () {
    expect(DateKeys.dateKey(DateTime(2026, 9, 14)), '2026-09-14');
    expect(DateKeys.dateKey(DateTime(999, 1, 2)), '0999-01-02');
  });

  test('shiftMonth 跨年安全', () {
    expect(DateKeys.shiftMonth('2025-12', 1), '2026-01');
    expect(DateKeys.shiftMonth('2026-01', -1), '2025-12');
    expect(DateKeys.shiftMonth('2026-09', -9), '2025-12');
    expect(DateKeys.shiftMonth('2026-03', 24), '2028-03');
  });

  test('recentMonthKeys 含当前月且升序', () {
    final keys = DateKeys.recentMonthKeys(6, now: DateTime(2026, 9, 14));
    expect(keys, [
      '2026-04',
      '2026-05',
      '2026-06',
      '2026-07',
      '2026-08',
      '2026-09',
    ]);
  });

  test('dayLabel 带星期', () {
    expect(DateKeys.dayLabel('2026-09-14'), '9月14日 周一');
    expect(DateKeys.dayLabel('2026-09-13'), '9月13日 周日');
  });

  test('monthLabel / monthShortLabel', () {
    expect(DateKeys.monthLabel('2026-09'), '2026年9月');
    expect(DateKeys.monthShortLabel('2026-09'), '26/09');
  });

  test('字符串键与 DateTime 互逆', () {
    final d = DateTime(2026, 9, 14);
    expect(DateKeys.parseDateKey(DateKeys.dateKey(d)), DateTime(2026, 9, 14));
    expect(DateKeys.parseMonthKey(DateKeys.monthKey(d)), DateTime(2026, 9));
  });
}
