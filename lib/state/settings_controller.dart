import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../core/theme.dart';

/// 全局设置（持久化到 SharedPreferences）。
///
/// - 外观模式：跟随系统 / 浅色 / 深色；主题色：预设色板任选；
/// - 展示货币符号：多币种的第一步（当前金额仍为单一本位币的分，
///   未来引入多币种时新增 currency 字段走 schema 迁移，展示层再按币种取符号）；
/// - 记账通知：每日提醒开关与时间（应用内提醒；系统推送后续接入）；
/// - 月预算：按月支出进度条展示，0 表示未设置。
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    final stored = _prefs.getInt(_kThemeMode) ?? 0;
    _themeMode = ThemeMode.values[stored.clamp(0, ThemeMode.values.length - 1)];
    _themeSeed = (_prefs.getInt(_kThemeSeed) ?? 0).clamp(
      0,
      AppTheme.themeSeeds.length - 1,
    );
    _currencySymbol = _prefs.getString(_kCurrencySymbol) ?? '¥';
    _monthlyBudgetCents = _prefs.getInt(_kMonthlyBudget) ?? 0;
    _reminderEnabled = _prefs.getBool(_kReminderEnabled) ?? false;
    _reminderHour = _prefs.getInt(_kReminderHour) ?? 21;
    _reminderMinute = _prefs.getInt(_kReminderMinute) ?? 0;
  }

  final SharedPreferences _prefs;

  static const String _kThemeMode = 'settings.themeMode';
  static const String _kThemeSeed = 'settings.themeSeed';
  static const String _kCurrencySymbol = 'settings.currencySymbol';
  static const String _kMonthlyBudget = 'settings.monthlyBudgetCents';
  static const String _kReminderEnabled = 'settings.reminderEnabled';
  static const String _kReminderHour = 'settings.reminderHour';
  static const String _kReminderMinute = 'settings.reminderMinute';
  static const String _kReminderLastShown = 'settings.reminderLastShown';

  late ThemeMode _themeMode;
  late int _themeSeed;
  late String _currencySymbol;
  late int _monthlyBudgetCents;
  late bool _reminderEnabled;
  late int _reminderHour;
  late int _reminderMinute;

  ThemeMode get themeMode => _themeMode;

  /// 预设主题色下标。
  int get themeSeedIndex => _themeSeed;

  /// 当前主题色（theme: AppTheme.light(settings.seedColor) 直接使用）。
  Color get seedColor => AppTheme
      .themeSeeds[_themeSeed.clamp(0, AppTheme.themeSeeds.length - 1)]
      .color;

  String get currencySymbol => _currencySymbol;

  /// 月预算（分）；0 = 未设置。
  int get monthlyBudgetCents => _monthlyBudgetCents;

  bool get reminderEnabled => _reminderEnabled;
  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;

  /// 当日已提醒过的日期键（yyyy-MM-dd），保证每天最多提醒一次。
  String? get reminderLastShown => _prefs.getString(_kReminderLastShown);

  Future<void> markReminderShown(String dateKey) =>
      _prefs.setString(_kReminderLastShown, dateKey);

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setThemeSeed(int index) async {
    final i = index.clamp(0, AppTheme.themeSeeds.length - 1);
    if (i == _themeSeed) return;
    _themeSeed = i;
    await _prefs.setInt(_kThemeSeed, i);
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final s = symbol.trim();
    if (s.isEmpty || s.length > 3 || s == _currencySymbol) return;
    _currencySymbol = s;
    await _prefs.setString(_kCurrencySymbol, s);
    notifyListeners();
  }

  /// 设置月预算（分）；0 或 null 表示清除。
  Future<void> setMonthlyBudget(int? cents) async {
    final v = (cents ?? 0).clamp(0, Money.maxCents);
    if (v == _monthlyBudgetCents) return;
    _monthlyBudgetCents = v;
    await _prefs.setInt(_kMonthlyBudget, v);
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool value) async {
    if (value == _reminderEnabled) return;
    _reminderEnabled = value;
    await _prefs.setBool(_kReminderEnabled, value);
    notifyListeners();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    if (hour == _reminderHour && minute == _reminderMinute) return;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
    _reminderHour = hour;
    _reminderMinute = minute;
    await _prefs.setInt(_kReminderHour, hour);
    await _prefs.setInt(_kReminderMinute, minute);
    notifyListeners();
  }
}
