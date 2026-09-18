import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// 轻量 UI 选择状态持久化。
///
/// 约定：
/// - 读：内存缓存优先，其次磁盘，最后默认值——写入后同会话立即可读；
/// - 写：立即进内存，磁盘写入按 key 合并延迟 300ms（快速连点只落一次盘）；
/// - 兜底：磁盘写失败静默忽略（内存值仍在，下次写再试），任何情况下不抛异常。
class UiPrefs {
  UiPrefs._();

  static late final SharedPreferences _prefs;
  static final Map<String, Object> _cache = {};
  static final Map<String, Timer> _timers = {};

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  static int getInt(String key, int def) =>
      _cache[key] as int? ?? _prefs.getInt(key) ?? def;

  static bool getBool(String key, bool def) =>
      _cache[key] as bool? ?? _prefs.getBool(key) ?? def;

  static void setInt(String key, int value) =>
      _set<int>(key, value, _prefs.setInt);

  static void setBool(String key, bool value) =>
      _set<bool>(key, value, _prefs.setBool);

  static void _set<T>(
    String key,
    T value,
    Future<bool> Function(String, T) write,
  ) {
    _cache[key] = value as Object;
    _timers[key]?.cancel();
    _timers[key] = Timer(const Duration(milliseconds: 300), () {
      _timers.remove(key);
      // 兜底：磁盘写失败静默，内存值继续生效，下次写入重试。
      write(key, value).catchError((_) => false);
    });
  }
}
