import 'package:flutter/foundation.dart';

import '../core/date_utils.dart';

/// 账本全局控制器：版本号 + 当前月份。
///
/// 设计取舍：不做响应式数据缓存层，任何写操作后 [bump]，
/// 监听页面对版本号变化重新查询。数据量级（个人记账，单月数百条）
/// 下简单可靠；未来接入复杂同步/大表时可替换为 repository 级流式通知。
class LedgerController extends ChangeNotifier {
  int _version = 0;
  String _monthKey = DateKeys.monthKey(DateTime.now());

  int get version => _version;
  String get monthKey => _monthKey;

  void setMonth(String mk) {
    if (mk == _monthKey) return;
    _monthKey = mk;
    notifyListeners();
  }

  void bump() {
    _version++;
    notifyListeners();
  }
}
