/// 应用名与通用文案集中管理，为未来 i18n（.arb / gen-l10n）预留出口；
/// 页面内的一次性文案可暂留原地，接入 gen-l10n 时统一抽取。
class S {
  S._();

  static const String appName = '随手记账';
  static const String appVersion = '0.1.0';
  static const String appSlogan = '本地记账 · 数据不出设备';

  // 底部导航
  static const String tabHelp = '帮助';
  static const String tabDetail = '明细';
  static const String tabStats = '统计';
  static const String tabMine = '设置';

  // 记账
  static const String addExpense = '支出';
  static const String addIncome = '收入';
  static const String addTransfer = '转账';
  static const String save = '保存';

  // 汇总
  static const String todayExpense = '今日支出';
  static const String todayIncome = '今日收入';
  static const String monthExpense = '本月支出';
  static const String monthIncome = '本月收入';
  static const String monthBalance = '结余';

  // 通用
  static const String search = '搜索';
  static const String reminder = '记账通知';
  static const String deleted = '已删除';
  static const String undo = '撤销';
  static const String confirm = '确定';
  static const String cancel = '取消';
  static const String delete = '删除';
  static const String edit = '编辑';
  static const String unknownCategory = '已删除分类';
}
