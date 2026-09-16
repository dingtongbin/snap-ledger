/// 金额工具。
///
/// 设计约束：全流程以「分」为单位的整数存储与运算，彻底规避二进制浮点误差；
/// 仅在输入与展示边界做字符串转换。
class Money {
  Money._();

  /// 单笔记账金额上限：99,999,999.99 元。超出直接拒绝录入，
  /// 同时保证 int 求和永不溢出（ Dart int 为 64 位）。
  static const int maxCents = 9999999999;

  /// 合法输入：0 或非 0 开头的 1~8 位整数 + 最多 2 位小数。
  /// 拒绝前导零（007）、多余小数位（1.234）、负号等一切杂音。
  static final RegExp _pattern = RegExp(r'^(0|[1-9]\d{0,7})(\.\d{1,2})?$');

  /// 把用户输入的「元」字符串解析为分；非法输入返回 null（不抛异常）。
  static int? parse(String input) {
    final s = input.trim();
    if (s.isEmpty || !_pattern.hasMatch(s)) return null;
    final dot = s.indexOf('.');
    if (dot < 0) return int.parse(s) * 100;
    final yuan = int.parse(s.substring(0, dot));
    final fen = s.substring(dot + 1).padRight(2, '0');
    return yuan * 100 + int.parse(fen);
  }

  /// 分 -> 千分位格式化金额，如 1234567 -> "12,345.67"；负数带负号。
  static String format(int cents) {
    final neg = cents < 0;
    final v = cents.abs();
    final fen = (v % 100).toString().padLeft(2, '0');
    final yuan = (v ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < yuan.length; i++) {
      buf.write(yuan[i]);
      final left = yuan.length - i - 1;
      if (left > 0 && left % 3 == 0) buf.write(',');
    }
    return '${neg ? '-' : ''}$buf.$fen';
  }
}

/// 记账键盘的输入状态机。
///
/// 所有合法性校验集中在这一处，UI 层只消费 [text] 与 [cents]：
/// - 首位 0 后再输数字直接替换（避免 "007"）；
/// - 小数点只能出现一次，空输入按 '.' 视为 "0."；
/// - 小数最多 2 位、整数最多 8 位（对应 [Money.maxCents]）；
/// - 未输入完成时 [cents] 为 null，保存按钮据此禁用。
class AmountInput {
  String _text = '';

  String get text => _text;

  bool get isEmpty => _text.isEmpty;

  /// 当前金额是否为 0 或尚未构成合法金额（用于禁用保存）。
  bool get isZeroOrEmpty {
    final c = cents;
    return c == null || c == 0;
  }

  int? get cents => Money.parse(_text);

  void clear() => _text = '';

  /// 编辑已有账单时恢复输入内容（内容须已通过 [Money.parse] 校验）。
  void reset(String text) => _text = text;

  void backspace() {
    if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
  }

  /// 追加数字；违反规则时返回 false（键盘可给轻微反馈或忽略）。
  bool appendDigit(int d) {
    assert(d >= 0 && d <= 9, 'digit out of range');
    final dot = _text.indexOf('.');
    if (dot < 0) {
      if (_text == '0') {
        if (d == 0) return false;
        _text = '$d'; // "0x" -> "x"
        return true;
      }
      if (_text.length >= 8) return false;
      _text = '$_text$d';
      return true;
    }
    if (_text.length - dot - 1 >= 2) return false;
    _text = '$_text$d';
    return true;
  }

  /// 追加小数点；已存在或超过整数位数上限时拒绝。
  bool appendDot() {
    if (_text.contains('.')) return false;
    _text = _text.isEmpty ? '0.' : '$_text.';
    return true;
  }

  /// 由「分」还原键盘可继续编辑的输入串，如 1205 -> "12.05"。
  static String fromCents(int cents) {
    final s = Money.format(cents).replaceAll(',', '');
    if (!s.contains('.')) return s;
    var t = s;
    while (t.endsWith('0')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
    return t;
  }
}
