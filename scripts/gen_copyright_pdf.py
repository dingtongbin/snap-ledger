# -*- coding: utf-8 -*-
"""生成软著申请表逐栏填写答案（申请表逐栏填写.txt）
与两份鉴别材料 PDF（源程序60页 / 用户手册）。

用法：python scripts/gen_copyright_pdf.py
"""
import glob
import os
import shutil

from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.normpath(os.path.join(ROOT, '软著材料'))
IMG_DIR = os.path.normpath(os.path.join(OUT, 'img'))
APP = '随手记账V0.1.0'
IMG_CACHE = 'C:/Users/30978/.zcode/cli/image-cache/sess_cf0646cb-d47a-4aa7-a6fc-4e097d886bcb'

# ── 字体 ──
pdfmetrics.registerFont(TTFont('msyh', 'C:/Windows/Fonts/msyh.ttc', subfontIndex=0))

# ── 逐栏答案（与应用表单字段一一对应）──
ANSWERS = """════════════ 软著申请表 · 逐栏填写答案（直接复制） ════════════

【开发的硬件环境】(≤50字)
Intel Core i7 处理器，16GB 内存，512GB 固态硬盘，独立显卡的 PC 机。

【运行的硬件环境】(≤50字)
内存 4GB 及以上、存储空间 64GB 及以上的智能手机，或 x86-64 个人电脑。

【开发该软件的操作系统】(≤50字)
Microsoft Windows 11；真机测试使用 Android 13。

【软件开发环境 / 开发工具】(≤50字)
Flutter SDK 3.44.9、Visual Studio Code、Android Studio、Git。

【该软件的运行平台 / 操作系统】(≤50字)
Windows 10/11（x64）；Android 8.0 及以上版本。

【软件运行支撑环境 / 支持软件】(≤50字)
Flutter 运行时引擎；本地 SQLite 数据库引擎；无需任何联网服务。

【编程语言】(表内已选 flutter，可补全为)
Dart（Flutter 框架）

【源程序量】
10241 行

【开发目的】(≤50字)
为个人用户提供无需注册、数据不出设备的日常收支记录工具。

【面向领域 / 行业】(≤50字)
个人财务管理 / 记账工具软件，面向个人及家庭用户。

【软件的主要功能】(500~1300字，本文约900字)
本软件是一款完全本地化的个人收支记账工具，主要功能如下：
一、收支记账。用户选择支出或收入类型后，通过分类九宫格选择分类，
使用专用数字键盘输入金额，支持调整记账日期与具体时刻，可填写备注
并附加任意张数的原始图片；图片以时间戳重命名保存，不做任何压缩。
二、多账本管理。支持新建、改名、删除多个账本，账单归属对应账本；
明细与统计页面可在全部账本汇总与单个账本之间切换，默认显示全部账本。
三、明细查询。账单按天分组展示，顶部汇总今日与本月收支及月预算使用
进度；支持全局搜索备注、分类名与账户名；单击账单进入详情页查看金额、
时间、来源、备注、图片等完整信息，并可直接编辑或删除。
四、日历视图。以月历形式逐日显示支出与收入小计，支持左右滑动、箭头
与跳转面板切换月份；点击日期后下方列表即时联动展示当日账单，并可
进入当日完整明细页。
五、统计分析。提供周报、月报、年报三种统计周期，汇总本期总额、日均
金额与上一周期对比值；以折线图展示趋势（悬停可查看单点日期与金额），
以环形图展示分类占比，并提供分类列表与支出排行，均支持按账本过滤。
六、数据安全。支持一键导出备份压缩包（内含全部图片附件），可设置
密码进行 AES-256-GCM 加密；支持导出 CSV 明细表；支持选择备份文件
恢复数据；账单删除后提供撤销功能。
七、个性化与帮助。提供深色、浅色及跟随系统三种外观与多种主题色；
内置图文使用帮助；全程无需注册账号，具备任何联网上传能力。

【软件的技术特点】(≤100字，本文约95字；标签建议勾选：APP、信息安全软件)
跨平台 Flutter 框架一次开发同时支持 Windows 与 Android；金额全程
整数分存储规避浮点误差；本地 SQLite 数据库版本化迁移；图片附件原样
保存并以时间戳命名；备份采用 PBKDF2 派生密钥与 AES-256-GCM 加密。

【程序鉴别材料】
见「随手记账V0.1.0-源程序.pdf」：前30页+后30页共60页，每页50行，
页眉含软件名称、版本号与页码。

【文档鉴别材料】
见「随手记账V0.1.0-用户手册.pdf」（不足60页，全部提交）。

【其他相关证明文件】
个人申请一般无需上传；如走单位申请需营业执照副本盖章件。
"""

# ── 画布参数 ──
PAGE_W, PAGE_H = A4
M_L, M_R = 46, 46
HEADER_Y = PAGE_H - 34
TOP_Y = PAGE_H - 58
BOTTOM_Y = 42
LEADING = 14.6
LINES_PER_PAGE = 50


def header(c, page_no, total):
    c.setFont('msyh', 8.5)
    c.setFillColorRGB(0.25, 0.25, 0.25)
    text = f'{APP}    第 {page_no} 页 / 共 {total} 页'
    c.drawCentredString(PAGE_W / 2, HEADER_Y, text)


def source_pdf(lines, path):
    total_lines = [lines[i:i + LINES_PER_PAGE]
                   for i in range(0, len(lines), LINES_PER_PAGE)]
    if len(total_lines) > 60:
        pages = total_lines[:30] + total_lines[-30:]
    else:
        pages = total_lines
    total = len(pages)
    c = canvas.Canvas(path, pagesize=A4)
    c.setTitle(f'{APP} 源程序')
    c.setAuthor('dingtongbin')
    for pi, page in enumerate(pages, start=1):
        header(c, pi, total)
        c.setFont('msyh', 8.5)
        c.setFillColorRGB(0.1, 0.1, 0.1)
        y = TOP_Y
        for ln in page:
            if ln.strip():
                width_ok = pdfmetrics.stringWidth(ln, 'msyh', 8.5) <= (
                    PAGE_W - M_L - M_R)
                text = ln if width_ok else ln[:80] + '…'
                c.drawString(M_L, y, text)
            y -= LEADING
        c.showPage()
    c.save()
    return total


SECTIONS = [
    ('1 软件概述',
     ['随手记账是一款完全本地化的个人记账应用：支出记一笔、收入记一笔，'
      '随手就完事。所有账目、图片与备份均保存在用户本机，应用不具备任何'
      '联网上传能力。',
      '运行环境：Windows 10 及以上；Android 8.0 及以上。']),
    ('2 界面总览', []),
    ('3 快速记账',
     ['步骤：点击底部导航中央的「＋」按钮进入记账弹层；在支出/收入页签下'
      '点选分类；使用内置数字键盘输入金额；需要时调整日期与时刻、选择'
      '交易方式、填写备注并附加图片；点击「保存」完成记账。']),
    ('4 明细与账本',
     ['明细页按天分组展示全部账单，顶部为今日/本月收支汇总卡与月预算'
      '进度；页面顶部提供账本切换，默认显示全部账本汇总，切换到具体'
      '账本后仅展示该账本数据。',
      '单击账单进入账单详情页，可查看金额、时间、来源、备注与图片，并'
      '执行编辑或删除；删除后可点击提示中的「撤销」恢复。']),
    ('5 日历视图',
     ['点击明细页右上角日历图标切换到日历视图：每个日期格显示当日支出'
      '（红）与收入（绿）小计，左右滑动或点击箭头切换月份，点击标题可'
      '直接跳转到指定年月；点击日期后，下方列表即时切换为该日账单，并'
      '可点击「当日详情」进入当日完整明细页。']),
    ('6 统计',
     ['提供周报/月报/年报三种统计周期，可前后切换或直接跳转；汇总卡显示'
      '本期总额、日均值与上一周期对比金额；趋势为折线图（鼠标悬停查看'
      '单点数值），并有分类占比环图、分类列表与支出排行，全部支持按账本'
      '过滤。']),
    ('7 设置',
     ['设置页提供：账本管理、分类管理（默认分类不可删除，自定义分类删除'
      '后其历史账单归入「其他」）、外观（深浅色）、主题色、数据备份与'
      '恢复、清空数据、开源许可与关于信息。']),
    ('8 备份与恢复',
     ['导出备份：生成 zip 包（账本数据 + 全部图片附件），可设置密码进行'
      ' AES-256-GCM 加密；导出 CSV：账单明细表，Excel 可直接打开；恢复'
      '备份：选择 zip 包后覆盖当前全部数据。所有数据保存在本机文档目录'
      '的 SnapLedgerBackup 与 SnapLedger/attachments 下。']),
    ('9 常见问题',
     ['为什么没有转账类型：转账改为支出/收入中的「转账」标签分类，转出'
      '记一笔支出、转入记一笔收入。',
      '删除的账单能找回吗：删除后底部提示可撤销，错过提示则无法恢复。',
      '备份密码遗忘：密码不存储于任何位置，忘记后备份无法解密。']),
]

SHOTS = [
    ('shot_detail.png', '图1 明细页', '2 界面总览'),
    ('shot_add.png', '图2 记账弹层', '3 快速记账'),
    ('shot_tx_detail.png', '图3 账单详情', '4 明细与账本'),
    ('shot_calendar.png', '图4 日历视图', '5 日历视图'),
    ('shot_stats.png', '图5 统计页', '6 统计'),
    ('shot_settings.png', '图6 设置页', '7 设置'),
]


def wrap(text, font, size, width):
    words = text
    out, cur = [], ''
    for ch in words:
        if pdfmetrics.stringWidth(cur + ch, font, size) <= width:
            cur += ch
        else:
            out.append(cur)
            cur = ch
    out.append(cur)
    return out


def manual_pdf(path):
    c = canvas.Canvas(path, pagesize=A4)
    c.setTitle(f'{APP} 用户手册')
    c.setAuthor('dingtongbin')
    page = 1
    y = TOP_Y
    header(c, page, 0)

    def heading(text):
        nonlocal y, page
        c.setFont('msyh', 13)
        c.setFillColorRGB(0.1, 0.1, 0.1)
        c.drawString(M_L, y, text)
        y -= 22

    def para(text):
        nonlocal y, page
        c.setFont('msyh', 10.5)
        c.setFillColorRGB(0.15, 0.15, 0.15)
        for ln in wrap(text, 'msyh', 10.5, PAGE_W - M_L - M_R):
            if y < BOTTOM_Y + 20:
                c.showPage(); page += 1; header(c, page, 0); y = TOP_Y
            c.drawString(M_L, y, ln)
            y -= 15

    def image(img_path, cap):
        nonlocal y, page
        from PIL import Image as PILImage
        w, h = PILImage.open(img_path).size
        draw_h = 300
        draw_w = draw_h * w / h
        if y - draw_h < BOTTOM_Y + 24:
            c.showPage(); page += 1; header(c, page, 0); y = TOP_Y
        c.drawImage(img_path, PAGE_W / 2 - draw_w / 2, y - draw_h,
                    height=draw_h, width=draw_w,
                    preserveAspectRatio=True, mask='auto')
        y -= draw_h + 6
        c.setFont('msyh', 9)
        c.setFillColorRGB(0.35, 0.35, 0.35)
        c.drawCentredString(PAGE_W / 2, y, cap)
        y -= 20

    elements = [('h', '随手记账（snap-ledger）用户手册'),
                ('p', '版本：V0.1.0    作者：dingtongbin'),
                ('p', '完全本地化的个人记账应用 · 数据不出设备')]
    for title, paras in SECTIONS:
        elements.append(('h', title))
        for t in paras:
            elements.append(('p', t))
        for f, cap, sec in SHOTS:
            if sec == title:
                elements.append(('img', os.path.join(IMG_DIR, f), cap))

    for kind in elements:
        if kind[0] == 'h':
            if y < BOTTOM_Y + 40:
                c.showPage(); page += 1; header(c, page, 0); y = TOP_Y
            heading(kind[1])
        elif kind[0] == 'p':
            para(kind[1])
        else:
            image(kind[1], kind[2])
    c.save()
    return page


def answers_txt(path):
    open(path, 'w', encoding='utf-8', newline='\n').write(ANSWERS)


def main():
    os.makedirs(OUT, exist_ok=True)
    answers_txt(os.path.join(OUT, '申请表逐栏填写.txt'))

    files = sorted(glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'),
                             recursive=True))
    lines = []
    for f in files:
        rel = os.path.relpath(f, ROOT).replace(os.sep, '/')
        lines.append(f'// ===== {rel} =====')
        lines.extend(open(f, encoding='utf-8').read().splitlines())
        lines.append('')
    src = os.path.join(OUT, '随手记账V0.1.0-源程序.pdf')
    total = source_pdf(lines, src)
    print(f'源程序 PDF: {src}  页数={total}')

    man = os.path.join(OUT, '随手记账V0.1.0-用户手册.pdf')
    pages = manual_pdf(man)
    print(f'用户手册 PDF: {man}  页数={pages}')


if __name__ == '__main__':
    main()
