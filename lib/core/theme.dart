import 'package:flutter/material.dart';

/// 语义化颜色 token：全 app 引用此处，页面内不写裸色值。
class AppColors {
  AppColors._();

  /// 支出 / 危险（红）。
  static const Color danger = Color(0xFFEF5350);

  /// 次要文字灰（对白底对比度 ≥ 4.5:1，WCAG AA）。
  static const Color inkGray = Color(0xFF6F7276);

  /// 深色模式卡片底。
  static const Color darkCard = Color(0xFF2A2C30);

  /// 主文字色（浅底黑 / 全局基准）。
  static const Color ink = Color(0xFF1F2024);
}

class AppTheme {
  AppTheme._();

  /// 可选主题色（预设），第一项为默认亮蓝。
  /// 写啥显示啥，不做算法调整。
  static const List<({String name, Color color})> themeSeeds = [
    (name: '亮蓝', color: Color(0xFF409EFF)),
    (name: '深蓝', color: Color(0xFF337ECC)),
    (name: '青绿', color: Color(0xFF6ECDC0)),
    (name: '紫罗兰', color: Color(0xFFB9A0D8)),
    (name: '活力橙', color: Color(0xFFFFB878)),
    (name: '玫红', color: Color(0xFFF49CB8)),
  ];

  /// 收入金额绿（原始干净值）。
  static const Color incomeGreen = Color(0xFF07C160);

  /// 转账蓝。
  static const Color transferBlue = Color(0xFF3E7BFA);

  /// 支出图表橙（原始干净值）。
  static const Color expenseOrange = Color(0xFFFF9F43);

  static ThemeData light(Color seedColor) => _base(_flatScheme(seedColor));

  static ThemeData dark(Color seedColor) {
    // 深色模式用同一个干净色值，背景翻黑/翻白由 _base 控制。
    return _base(_flatScheme(seedColor, brightness: Brightness.dark));
  }

  /// 显式构造 ColorScheme，避免 Material3 fromSeed 的"自动提饱和"，
  /// 让用户给的色值就是看到的色值。
  static ColorScheme _flatScheme(
    Color seed, {
    Brightness brightness = Brightness.light,
  }) {
    if (brightness == Brightness.light) {
      return ColorScheme(
        brightness: Brightness.light,
        primary: seed,
        onPrimary: Colors.white,
        secondary: seed,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.ink,
        error: const Color(0xFFE25C5C),
        onError: Colors.white,
      );
    }
    return ColorScheme(
      brightness: Brightness.dark,
      primary: seed,
      onPrimary: AppColors.ink,
      secondary: seed,
      onSecondary: AppColors.ink,
      surface: AppColors.ink,
      onSurface: Colors.white,
      error: const Color(0xFFE25C5C),
      onError: Colors.white,
    );
  }

  /// 汇总卡/资料横幅的渐变：跟随主题色，保证换色后视觉统一。
  static Gradient bannerGradient(ColorScheme cs) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(cs.primary, Colors.white, 0.18)!, cs.primary],
  );

  static ThemeData _base(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      // Windows 上显式命中中文字体，避免 Segoe UI -> 中文字体的
      // 运行时回退混排导致的小字发虚。
      fontFamily: 'Microsoft YaHei UI',
      // 主背景：浅灰（深色模式交给系统方案）。
      scaffoldBackgroundColor: dark ? null : const Color(0xFFE8EAED),
      // 卡片统一与页面背景区分：浅色=白，深色=略亮的中性灰。
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF2A2C30) : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      canvasColor: dark ? const Color(0xFF2A2C30) : Colors.white,
      // ListTile 图标与文字水平间距收紧，避免「左右离文字非常远」。
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        minLeadingWidth: 24,
        horizontalTitleGap: 8,
        iconColor: dark ? Colors.white : AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? null : cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        // 标题靠左，全应用统一；小一号加粗更有页头感。
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
          fontFamily: 'Microsoft YaHei UI',
        ),
      ),
      // 底部导航：很浅的顶部阴影，无边框；颜色跟随主题。
      bottomAppBarTheme: BottomAppBarThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF2A2C30) : Colors.white,
        shadowColor: dark ? null : Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.4),
        space: 0.6,
        thickness: 0.6,
      ),
    );
  }
}
