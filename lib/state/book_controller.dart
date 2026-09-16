import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';
import '../data/repositories/repositories.dart';

/// 账本选择状态。
///
/// - [selectedId] == null 表示「全部账本」聚合视图（默认显示方式）；
/// - 记账目标：选中具体账本时新账单记入该账本，否则记入默认账本；
/// - 选中结果持久化到 SharedPreferences，重启后保留。
class BookController extends ChangeNotifier {
  BookController(this._repo);

  final LedgerBookRepository _repo;

  static const String _kSelectedId = 'book.selectedId';

  List<LedgerBook> books = const [];
  int? selectedId;

  /// 选中账本；null = 全部账本。
  LedgerBook? get selected =>
      books.where((b) => b.id == selectedId).firstOrNull;

  /// 查询过滤参数：null = 全部账本。
  int? get filterLedgerId => selectedId;

  /// 记账目标账本 id：选中的具体账本；未选时用默认账本（builtin 优先，
  /// 否则 id 最小者；空表兜底 1）。
  int get writeTargetId {
    if (selectedId != null) return selectedId!;
    final def = books.where((b) => b.builtin).firstOrNull ?? books.firstOrNull;
    return def?.id ?? 1;
  }

  Future<void> load() async {
    books = await _repo.listAll();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kSelectedId);
    // 选中项已被删除时回退到「全部账本」。
    selectedId = books.any((b) => b.id == saved) ? saved : null;
    notifyListeners();
  }

  Future<void> select(int? id) async {
    if (id == selectedId) return;
    // 只允许选中存在的账本；null 表示全部。
    if (id != null && !books.any((b) => b.id == id)) return;
    selectedId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kSelectedId);
    } else {
      await prefs.setInt(_kSelectedId, id);
    }
  }

  /// 账本增删改后刷新列表；选中项失效则回退全部。
  Future<void> reload() => load();
}
