import 'package:flutter/material.dart';

/// 运行期图标还原注册表。
///
/// 入库的是图标 codePoint（int），展示时通过本表还原为 IconData；
/// 全部可选图标都来自 DefaultData 固定集合，因此总能命中；
/// 备份导入遇到未知 codePoint 时回退到 more_horiz，避免崩溃。
class AppIcons {
  AppIcons._();

  static final Map<int, IconData> _byCode = {
    ...{for (final i in DefaultData.iconChoices) i.codePoint: i},
    // 种子数据与 UI 用到的全部图标
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.shopping_cart.codePoint: Icons.shopping_cart,
    Icons.directions_bus.codePoint: Icons.directions_bus,
    Icons.shopping_basket.codePoint: Icons.shopping_basket,
    Icons.bolt.codePoint: Icons.bolt,
    Icons.phone_iphone.codePoint: Icons.phone_iphone,
    Icons.apartment.codePoint: Icons.apartment,
    Icons.local_hospital.codePoint: Icons.local_hospital,
    Icons.sports_esports.codePoint: Icons.sports_esports,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.school.codePoint: Icons.school,
    Icons.flight_takeoff.codePoint: Icons.flight_takeoff,
    Icons.pets.codePoint: Icons.pets,
    Icons.spa.codePoint: Icons.spa,
    Icons.devices.codePoint: Icons.devices,
    Icons.volunteer_activism.codePoint: Icons.volunteer_activism,
    Icons.payments.codePoint: Icons.payments,
    Icons.emoji_events.codePoint: Icons.emoji_events,
    Icons.work.codePoint: Icons.work,
    Icons.trending_up.codePoint: Icons.trending_up,
    Icons.card_giftcard.codePoint: Icons.card_giftcard,
    Icons.assignment_return.codePoint: Icons.assignment_return,
    Icons.recycling.codePoint: Icons.recycling,
    Icons.account_balance.codePoint: Icons.account_balance,
    Icons.account_balance_wallet.codePoint: Icons.account_balance_wallet,
    Icons.chat_bubble.codePoint: Icons.chat_bubble,
    Icons.wallet.codePoint: Icons.wallet,
    Icons.more_horiz.codePoint: Icons.more_horiz,
    Icons.swap_horiz.codePoint: Icons.swap_horiz,
  };

  static IconData of(int codePoint) => _byCode[codePoint] ?? Icons.more_horiz;
}

/// 默认种子数据（常见的个人记账分类体系）。
/// id 固定，迁移/合并数据时可稳定引用；新增默认项只能追加到末尾，
/// 不得改动已有条目的 id，保证用户历史数据不被串位。
class DefaultData {
  DefaultData._();

  static const int _orange = 0xFFFF9800;
  static const int _red = 0xFFEF5350;
  static const int _blue = 0xFF42A5F5;
  static const int _teal = 0xFF26A69A;
  static const int _amber = 0xFFFFB300;
  static const int _indigo = 0xFF5C6BC0;
  static const int _brown = 0xFF8D6E63;
  static const int _purple = 0xFFAB47BC;
  static const int _cyan = 0xFF00ACC1;
  static const int _green = 0xFF66BB6A;
  static const int _pink = 0xFFEC407A;
  static const int _blueGrey = 0xFF78909C;
  static const int _grey = 0xFF9E9E9E;
  static const int _deepOrange = 0xFFF4511E;

  static const List<SeedCategory> expenseCategories = [
    SeedCategory(1, '餐饮', Icons.restaurant, _orange),
    SeedCategory(2, '购物', Icons.shopping_cart, _red),
    SeedCategory(3, '交通', Icons.directions_bus, _blue),
    SeedCategory(4, '日用', Icons.shopping_basket, _teal),
    SeedCategory(5, '水电煤', Icons.bolt, _amber),
    SeedCategory(6, '通讯', Icons.phone_iphone, _indigo),
    SeedCategory(7, '住房', Icons.apartment, _brown),
    SeedCategory(8, '医疗', Icons.local_hospital, _red),
    SeedCategory(9, '娱乐', Icons.sports_esports, _purple),
    SeedCategory(10, '运动', Icons.fitness_center, _cyan),
    SeedCategory(11, '教育', Icons.school, _indigo),
    SeedCategory(12, '旅行', Icons.flight_takeoff, _blue),
    SeedCategory(13, '宠物', Icons.pets, _green),
    SeedCategory(14, '美容', Icons.spa, _pink),
    SeedCategory(15, '数码', Icons.devices, _blueGrey),
    SeedCategory(16, '人情', Icons.volunteer_activism, _deepOrange),
    SeedCategory(17, '其他', Icons.more_horiz, _grey),
    // v2：转账只是支出/收入里的一个普通标签分类，无任何特殊逻辑。
    SeedCategory(18, '转账', Icons.swap_horiz, _blueGrey),
  ];

  static const List<SeedCategory> incomeCategories = [
    SeedCategory(101, '工资', Icons.payments, _teal),
    SeedCategory(102, '奖金', Icons.emoji_events, _amber),
    SeedCategory(103, '兼职', Icons.work, _blue),
    SeedCategory(104, '理财', Icons.trending_up, _purple),
    SeedCategory(105, '红包', Icons.card_giftcard, _red),
    SeedCategory(106, '退款', Icons.assignment_return, _cyan),
    SeedCategory(107, '二手闲置', Icons.recycling, _green),
    SeedCategory(108, '其他', Icons.more_horiz, _grey),
    SeedCategory(109, '转账', Icons.swap_horiz, _blueGrey),
  ];

  static const List<SeedAccount> accounts = [
    SeedAccount(201, '现金', Icons.payments, _green),
    SeedAccount(202, '银行卡', Icons.account_balance, _blue),
    SeedAccount(203, '支付宝', Icons.account_balance_wallet, _indigo),
    SeedAccount(204, '微信', Icons.chat_bubble, _green),
    SeedAccount(205, '其他', Icons.wallet, _grey),
  ];

  /// 自定义分类/账户可用的图标集（系统固定集合，用户不能自定义图形）。
  static const List<IconData> iconChoices = [
    // 餐饮
    Icons.restaurant,
    Icons.local_cafe,
    Icons.fastfood,
    Icons.bakery_dining,
    Icons.ramen_dining,
    Icons.lunch_dining,
    Icons.icecream,
    Icons.local_bar,
    // 购物
    Icons.shopping_cart,
    Icons.storefront,
    Icons.local_mall,
    Icons.local_grocery_store,
    Icons.checkroom,
    // 交通
    Icons.directions_bus,
    Icons.directions_car,
    Icons.two_wheeler,
    Icons.local_taxi,
    Icons.train,
    Icons.flight_takeoff,
    // 居住/家用
    Icons.home,
    Icons.apartment,
    Icons.kitchen,
    Icons.chair,
    Icons.bed,
    Icons.weekend,
    Icons.cleaning_services,
    Icons.build,
    // 水电/能源
    Icons.bolt,
    Icons.water_drop,
    Icons.local_gas_station,
    // 电子数码
    Icons.phone_iphone,
    Icons.computer,
    Icons.videocam,
    Icons.camera_alt,
    Icons.headphones,
    // 娱乐
    Icons.sports_esports,
    Icons.music_note,
    Icons.movie,
    Icons.sports_basketball,
    // 健康
    Icons.local_hospital,
    Icons.medication,
    Icons.health_and_safety,
    Icons.fitness_center,
    Icons.spa,
    // 学习
    Icons.school,
    Icons.menu_book,
    // 生活
    Icons.pets,
    Icons.child_care,
    Icons.favorite,
    Icons.star,
    // 人情/收入
    Icons.redeem,
    Icons.card_giftcard,
    Icons.volunteer_activism,
    Icons.payments,
    Icons.savings,
    Icons.work,
    Icons.trending_up,
    // 兜底
    Icons.more_horiz,
  ];

  /// 自定义分类/账户可用的颜色集。
  static const List<Color> colorChoices = [
    Color(_orange),
    Color(_red),
    Color(_pink),
    Color(_purple),
    Color(_indigo),
    Color(_blue),
    Color(_cyan),
    Color(_teal),
    Color(_green),
    Color(_amber),
    Color(_brown),
    Color(_grey),
  ];
}

class SeedCategory {
  const SeedCategory(this.id, this.name, this.icon, this.color);

  final int id;
  final String name;
  final IconData icon;
  final int color;
}

class SeedAccount {
  const SeedAccount(this.id, this.name, this.icon, this.color);

  final int id;
  final String name;
  final IconData icon;
  final int color;
}
