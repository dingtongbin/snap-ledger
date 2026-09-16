/// 日期键值工具。
///
/// 设计约束：账单归属日一律用本地时区的 `yyyy-MM-dd` 字符串（dateKey），
/// 月份用 `yyyy-MM`（monthKey）；字符串字典序即时间序，SQL 范围查询简单可靠，
/// 且不受 UTC 转换、时区偏移影响。精确时刻另存毫秒时间戳仅用于排序。
class DateKeys {
  DateKeys._();

  static const List<String> _weekdays = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  /// 本地日期键，如 2026-09-14。
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String todayKey() => dateKey(DateTime.now());

  static String monthKey(DateTime d) => dateKey(d).substring(0, 7);

  static String monthKeyOf(String dateKey) => dateKey.substring(0, 7);

  static DateTime parseDateKey(String dk) {
    final y = int.parse(dk.substring(0, 4));
    final m = int.parse(dk.substring(5, 7));
    final d = int.parse(dk.substring(8, 10));
    return DateTime(y, m, d);
  }

  static DateTime parseMonthKey(String mk) {
    final y = int.parse(mk.substring(0, 4));
    final m = int.parse(mk.substring(5, 7));
    return DateTime(y, m);
  }

  /// 月份平移，跨年安全：shiftMonth('2025-12', 1) -> '2026-01'。
  static String shiftMonth(String mk, int delta) {
    final d = parseMonthKey(mk);
    return monthKey(DateTime(d.year, d.month + delta));
  }

  /// 含当前月在内的最近 n 个月键，时间升序，如 n=6 ->
  /// ['2026-04', ..., '2026-09']。
  static List<String> recentMonthKeys(int n, {DateTime? now}) {
    final base = now ?? DateTime.now();
    return List<String>.generate(
      n,
      (i) => monthKey(DateTime(base.year, base.month - (n - 1 - i))),
    );
  }

  /// 月份展示名，如 '2026年9月'。
  static String monthLabel(String mk) {
    final d = parseMonthKey(mk);
    return '${d.year}年${d.month}月';
  }

  /// 日期展示名，如 '9月14日 周一'。
  static String dayLabel(String dk) {
    final d = parseDateKey(dk);
    return '${d.month}月${d.day}日 ${_weekdays[d.weekday - 1]}';
  }

  /// 趋势图横轴短标签，如 '26/09'。
  static String monthShortLabel(String mk) {
    final d = parseMonthKey(mk);
    return '${d.year % 100}/${d.month.toString().padLeft(2, '0')}';
  }

  /// 任意日期所在周一到周日的日期范围，返回 (from, to) 左闭右开。
  static (String, String) weekRange(DateTime anyDay) {
    // weekday: Mon=1 .. Sun=7
    final monday = anyDay.subtract(Duration(days: anyDay.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    return (dateKey(monday), dateKey(sunday));
  }

  /// 某月第一天到下月第一天，左闭右开。
  static (String, String) monthRange(String monthKey) {
    final d = parseMonthKey(monthKey);
    final next = DateTime(d.year, d.month + 1);
    return (dateKey(d), dateKey(next));
  }

  /// 某年第一天到下年第一天，左闭右开。
  static (String, String) yearRange(String yearKey) {
    final y = int.parse(yearKey);
    return ('$yearKey-01-01', '${y + 1}-01-01');
  }

  /// 周标签，如 "9月8日 - 9月14日"。
  static String weekLabel(String from) {
    final d = parseDateKey(from);
    final to = d.add(const Duration(days: 6));
    return '${d.month}月${d.day}日 - ${to.month}月${to.day}日';
  }

  /// 年标签，如 "2026年"。
  static String yearLabel(String yearKey) => '$yearKey年';

  /// 提取年份键，如 "2026"。
  static String yearKeyOf(String dateKey) => dateKey.substring(0, 4);

  /// 月份中的天数。
  static int daysInMonth(String monthKey) {
    final d = parseMonthKey(monthKey);
    return DateTime(d.year, d.month + 1, 0).day;
  }
}
