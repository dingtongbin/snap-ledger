# -*- coding: utf-8 -*-
"""生成软件著作权登记材料（输出到 软著材料/，已加入 .gitignore 不入库）。

材料清单：
1. 随手记账V1.0.0-源程序.docx   前30页+后30页，每页50行，页眉带名称/版本/页码
2. 随手记账V1.0.0-用户手册.docx  图文操作手册（含界面截图）
3. 申请表填写参考.md             软件用途/技术特点/主要功能等申请表文字

用法：python scripts/gen_copyright.py
"""
import glob
import os
import shutil

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.shared import Cm, Pt, RGBColor

APP_NAME = '随手记账'
APP_VERSION = 'V1.0.0'
HEADER_PREFIX = f'{APP_NAME}{APP_VERSION}'
OUT_DIR = '软著材料'
LINES_PER_PAGE = 50
MAX_PAGES = 60  # 前30 + 后30

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
IMG_CACHE = os.path.expandvars(
    r'C:\Users\30978\.zcode\cli\image-cache'
    r'\sess_cf0646cb-d47a-4aa7-a6fc-4e097d886bcb')


def collect_source_lines():
    """按稳定顺序收集 lib/ 全部 Dart 源码行。"""
    files = sorted(glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'),
                             recursive=True),
                   key=lambda f: (f.replace(os.sep, '/'),))
    lines = []
    for f in files:
        rel = os.path.relpath(f, ROOT).replace(os.sep, '/')
        lines.append(f'// ===== {rel} =====')
        with open(f, encoding='utf-8') as fh:
            for ln in fh.read().splitlines():
                lines.append(ln.rstrip())
        lines.append('')
    return files, lines


def add_page_field(paragraph):
    """页眉插入 Word PAGE 域（自动页码）。"""
    run = paragraph.add_run()
    fld = OxmlElement('w:fldSimple')
    fld.set(qn := '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
            'instr', ' PAGE ')
    run._r.addnext(fld)
    r2 = OxmlElement('w:r')
    t = OxmlElement('w:t')
    t.text = '1'
    r2.append(t)
    fld.append(r2)


def set_header(doc):
    sec = doc.sections[0]
    sec.page_width, sec.page_height = Cm(21.0), Cm(29.7)
    sec.left_margin = sec.right_margin = Cm(2.3)
    sec.top_margin, sec.bottom_margin = Cm(2.5), Cm(2.2)
    hp = sec.header.paragraphs[0]
    hp.text = ''
    run = hp.add_run(HEADER_PREFIX + '    第 ')
    run.font.size = Pt(9)
    add_page_field(hp)
    run2 = hp.add_run(' 页')
    run2.font.size = Pt(9)
    hp.alignment = WD_ALIGN_PARAGRAPH.CENTER


def code_docx(lines, path):
    """源程序鉴别材料：每页固定 50 行。"""
    doc = Document()
    set_header(doc)
    style = doc.styles['Normal']
    style.font.name = 'Courier New'
    style.font.size = Pt(9)
    pages = [lines[i:i + LINES_PER_PAGE]
             for i in range(0, len(lines), LINES_PER_PAGE)]
    for pi, page in enumerate(pages):
        if pi > 0:
            doc.add_page_break()
        for ln in page:
            p = doc.add_paragraph(ln if ln.strip() else '')
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.0
    doc.save(path)
    return len(pages)


def shot(name):
    src = os.path.join(IMG_CACHE, name)
    dst = os.path.join(OUT_DIR, 'img', name)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.exists(src):
        shutil.copy(src, dst)
        return dst
    return None


def manual_docx(path):
    doc = Document()
    set_header(doc)

    def h(t, lv=1):
        doc.add_heading(t, level=lv)

    def p(t, bold=False, center=False):
        para = doc.add_paragraph()
        if center:
            para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = para.add_run(t)
        run.bold = bold
        return para

    def img(name, width_cm=8.5, caption=''):
        path = shot(name)
        if not path:
            return
        para = doc.add_paragraph()
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        para.add_run().add_picture(path, width=Cm(width_cm))
        if caption:
            cp = doc.add_paragraph(caption)
            cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
            cp.runs[0].font.size = Pt(9)
            cp.runs[0].font.color.rgb = RGBColor(0x60, 0x60, 0x60)

    # 封面信息
    p('随手记账（snap-ledger）', bold=True, center=True)
    p(f'用户手册（{APP_VERSION}）', center=True)
    p('完全本地化的个人记账应用 · 数据不出设备', center=True)
    p('作者：dingtongbin', center=True)
    doc.add_page_break()

    h('1 软件概述')
    p('随手记账是一款完全本地化的个人记账应用：支出记一笔、收入记一笔，'
      '随手就完事。所有账目、图片与备份均保存在用户本机，'
      '应用不具备任何联网上传能力。')
    p('运行环境：Windows 10 及以上；Android 8.0 及以上。')

    h('2 界面总览')
    img('737587cbee3bcc818729ecbe4832d5eb.png', 8.5, '图1 明细页与统计页')

    h('3 快速记账')
    p('步骤：点击底部导航中央的「＋」按钮，进入记账弹层；'
      '在支出/收入页签下点选分类；使用内置数字键盘输入金额；'
      '需要时调整日期与时刻、选择交易方式、填写备注并附加图片；'
      '点击「保存」完成记账。')
    img('d494a079795122d492631d80944fefc5.png', 7.0, '图2 记账弹层')

    h('4 明细与账本')
    p('明细页按天分组展示全部账单，顶部为今日/本月收支汇总卡与月预算进度；'
      '页面顶部提供账本切换，默认显示全部账本汇总，'
      '切换到具体账本后仅展示该账本数据。'
      '在设置中可新建、改名或删除账本（默认账本不可删除）。')
    p('单击账单进入账单详情页，可查看金额、时间、来源、备注与图片，'
      '并执行编辑或删除；删除后可点击提示中的「撤销」恢复。')

    h('5 日历视图')
    p('点击明细页右上角日历图标切换到日历视图：'
      '每个日期格显示当日支出（红）与收入（绿）小计，'
      '左右滑动或点击箭头切换月份，点击标题可直接跳转到指定年月；'
      '点击日期后，下方列表即时切换为该日账单，'
      '点击「当日详情」进入当日完整明细页。')
    img('0d20ff355d3fec6f69dfbb95ef48cdf9.png', 8.5, '图3 日历视图')

    h('6 统计')
    p('提供周报/月报/年报三种统计周期，可前后切换或直接跳转；'
      '汇总卡显示本期总额、日均值与上一周期具体金额；'
      '趋势为折线图（鼠标悬停查看单点数值），'
      '并有分类占比环图、分类列表与支出排行，'
      '全部随支出/收入筛选与账本筛选联动。')

    h('7 设置')
    p('设置页提供：账本管理、分类管理（默认分类不可删除，'
      '自定义分类删除后其历史账单归入「其他」）、外观（深浅色）、'
      '主题色、数据备份与恢复、清空数据、开源许可与关于信息。')
    img('68e8fb54735c7d26ed05c0babf2aef14.png', 8.5, '图4 设置页')

    h('8 备份与恢复')
    p('导出备份：生成 zip 包（账本数据 + 全部图片附件），'
      '可设置密码进行 AES-256-GCM 加密；'
      '导出 CSV：账单明细表，Excel 可直接打开；'
      '恢复备份：选择 zip 包后覆盖当前全部数据。'
      '所有数据保存在本机文档目录的 SnapLedgerBackup 与 '
      'SnapLedger/attachments 下。')

    h('9 常见问题')
    p('为什么没有转账类型：转账改为支出/收入中的「转账」标签分类，'
      '转出记一笔支出、转入记一笔收入。'
      '删除的账单能找回吗：删除后底部提示可撤销，错过提示则无法恢复。'
      '备份密码遗忘：密码不存储于任何位置，忘记后备份无法解密。')
    doc.save(path)


def application_notes(path):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('''# 软著申请表填写参考（CPCC 中国版权保护中心）

> 以下为申请表各栏的参考文字，登记人信息请以真实证件为准。

- 软件全称：随手记账软件（简称：snap-ledger）
- 版本号：V1.0.0
- 开发完成日期：2026-09-16（以 v0.1.0 标签日期为准，可自行调整）
- 首次发表日期：2026-09-17（GitHub Release 发布日；也可勾选"未发表"）
- 开发方式：独立开发
- 著作权人：dingtongbin（登记时填写身份证真实姓名，个人申请）
- 编程语言：Dart（Flutter 框架）
- 源程序量：以生成页数为准（见源程序文档页脚）

## 软件用途和技术特点（约200字）

本软件是一款运行于 Windows 与 Android 平台的完全本地化个人记账应用，
供个人用户日常记录与管理收支。用户可选择支出或收入类型，通过自定义
分类与专用数字键盘快速记录账目，并可附加备注与原始图片；支持多账本
分组管理、日历视图逐日查看收支、按周/月/年的统计分析与分类排行；
支持账单数据的加密备份（AES-256-GCM）与跨设备恢复。技术特点：采用
Flutter 跨平台框架开发，金额全程以整数分存储规避浮点误差，本地
SQLite 数据库版本化迁移，图片附件原样保存并以时间戳命名，备份容器
使用 PBKDF2 派生密钥加密，全程不依赖任何网络服务。

## 主要功能（申请表栏参考）

1. 收支记账：分类选择、金额键盘输入、日期时刻调整、备注与多图附件；
2. 多账本：账本新建/改名/删除，全部账本汇总与单账本过滤；
3. 明细与日历：按天分组列表、日历视图逐日收支小计与当日明细；
4. 统计分析：周报/月报/年报，折线趋势、分类占比、支出排行；
5. 数据安全：加密备份导出、CSV 导出、恢复覆盖导入、账单删除撤销；
6. 个性化：深浅色外观、六种主题色、内置图文使用帮助。
''')


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    files, lines = collect_source_lines()
    total_pages = (len(lines) + LINES_PER_PAGE - 1) // LINES_PER_PAGE
    if total_pages > MAX_PAGES:
        first = lines[:30 * LINES_PER_PAGE]
        last = lines[-30 * LINES_PER_PAGE:]
        pages_lines = first + last
    else:
        pages_lines = lines
    src_doc = os.path.join(OUT_DIR, f'{HEADER_PREFIX}-源程序.docx')
    n = code_docx(pages_lines, src_doc)
    print(f'源程序: {src_doc}  页数={n}（源码总行数 {len(lines)}，文件 {len(files)}）')

    man_doc = os.path.join(OUT_DIR, f'{HEADER_PREFIX}-用户手册.docx')
    manual_docx(man_doc)
    print(f'用户手册: {man_doc}')

    notes = os.path.join(OUT_DIR, '申请表填写参考.md')
    application_notes(notes)
    print(f'申请表参考: {notes}')


if __name__ == '__main__':
    main()
