import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/strings.dart';

/// 帮助主题。正文内容存放在项目 `assets/help/*.md`，
/// 运行时按需加载渲染；新增帮助只需往该目录加 md 文件并在此登记元信息。
class HelpTopic {
  const HelpTopic({
    required this.title,
    required this.subtitle,
    required this.figure,
    required this.figureColor,
    required this.asset,
  });

  final String title;
  final String subtitle;
  final IconData figure;
  final Color figureColor;

  /// 帮助正文 markdown 资源路径。
  final String asset;
}

/// 帮助页：仅标题列表，点击进入对应主题的内容页（Markdown 渲染）。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const List<HelpTopic> _topics = [
    HelpTopic(
      title: '记一笔账',
      subtitle: '从点「＋」到保存的完整流程',
      figure: Icons.add_circle,
      figureColor: Color(0xFF409EFF),
      asset: 'assets/help/01-record.md',
    ),
    HelpTopic(
      title: '分类与交易方式',
      subtitle: '自定义分类、新建交易方式的规则',
      figure: Icons.category_outlined,
      figureColor: Color(0xFFAB47BC),
      asset: 'assets/help/02-categories.md',
    ),
    HelpTopic(
      title: '账本',
      subtitle: '多账本分组、切换与归属规则',
      figure: Icons.menu_book_outlined,
      figureColor: Color(0xFFFF9F43),
      asset: 'assets/help/03-books.md',
    ),
    HelpTopic(
      title: '日历视图',
      subtitle: '按月查看每日收支，跳转与当日明细',
      figure: Icons.calendar_month_outlined,
      figureColor: Color(0xFF3E7BFA),
      asset: 'assets/help/04-calendar.md',
    ),
    HelpTopic(
      title: '统计',
      subtitle: '周报月报年报、趋势图与排行',
      figure: Icons.insights_outlined,
      figureColor: Color(0xFF07C160),
      asset: 'assets/help/05-stats.md',
    ),
    HelpTopic(
      title: '图片附件',
      subtitle: '贴图不压缩、时间戳保存、全屏查看',
      figure: Icons.image_outlined,
      figureColor: Color(0xFF00ACC1),
      asset: 'assets/help/06-images.md',
    ),
    HelpTopic(
      title: '备份与恢复',
      subtitle: '导出 zip / CSV，恢复会覆盖数据',
      figure: Icons.cloud_done_outlined,
      figureColor: Color(0xFF409EFF),
      asset: 'assets/help/07-backup.md',
    ),
    HelpTopic(
      title: '常见问题',
      subtitle: '转账、存储位置、误删找回',
      figure: Icons.help_outline,
      figureColor: Color(0xFF9E9E9E),
      asset: 'assets/help/08-faq.md',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? AppColors.darkCard : Colors.white;
    return Scaffold(
      appBar: AppBar(title: Text(S.tabHelp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 88),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _topics.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 0.6, thickness: 0.6, indent: 58),
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -2,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _topics[i].figureColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _topics[i].figure,
                        size: 19,
                        color: _topics[i].figureColor,
                      ),
                    ),
                    title: Text(
                      _topics[i].title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _topics[i].subtitle,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HelpTopicPage(topic: _topics[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '帮助内容存放于项目 assets/help/*.md · GPL-3.0 开源',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 帮助主题内容页：从 assets/help 加载 Markdown 并渲染。
class HelpTopicPage extends StatelessWidget {
  const HelpTopicPage({super.key, required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? AppColors.darkCard : Colors.white;
    return Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(topic.asset),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                '帮助内容加载失败：${snap.error}',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            );
          }
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: MarkdownBody(
              data: snap.data ?? '',
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    h1: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    h2: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    p: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: cs.onSurface,
                    ),
                    listBullet: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                    blockquote: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: cs.primary, width: 3),
                      ),
                    ),
                    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  ),
            ),
          );
        },
      ),
    );
  }
}
