# 随手记账 Bookkeeping

一款完全本地化的记账应用，使用 Flutter 构建，
以 **GPL-3.0** 许可证开源。

![platforms](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Windows-blue)

## 功能

- **明细**：月份切换、本月支出/收入/结余汇总卡、按日分组账单列表；
  点击编辑、长按删除（带撤销）。
- **记账**：支出 / 收入 / 转账三合一弹层 + 自定义金额键盘；
  分类九宫格、账户与日期选择、备注。
- **图表**：当月分类占比甜甜圈图、分类排行、近 6 个月收支趋势（不含转账）。
- **我的**：账户管理（余额推导）、分类管理（默认分类 + 自定义）、
  外观（跟随系统/浅色/深色）、货币符号、备份与恢复、清空数据、GPL-3.0 许可证全文。

## 快速开始

```bash
flutter pub get
flutter run                 # Android / iOS / Windows 任一已接入设备
flutter test                # 单元 + 组件测试
flutter analyze             # 静态检查（当前零问题）
```

### 国内镜像源（本项目约定）

依赖与制品全部走国内镜像，环境变量已写入 `scripts/mirror.env`，
并已通过 `setx` 持久化到当前 Windows 用户：

| 用途 | 镜像 |
| --- | --- |
| pub 依赖 | `PUB_HOSTED_URL=https://pub.flutter-io.cn` |
| Flutter SDK 制品 | `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` |
| Gradle 发行包 | 腾讯镜像（见 `android/gradle/wrapper/gradle-wrapper.properties`） |
| Maven 依赖/插件 | 阿里云（见 `android/settings.gradle.kts`、`android/build.gradle.kts`） |

Bash 环境可 `source scripts/mirror.env` 后再执行 flutter 命令。

### Windows 桌面运行

Windows 端数据库走 `sqflite_common_ffi`，需要 `sqlite3.dll`。
仓库 `tool/sqlite3.dll` 已就位；`flutter run -d windows` 时需保证该目录在
`PATH` 中（或把 dll 复制到可执行文件同目录）。该 dll 来自 Python 官方发行版
（SQLite 属公有领域，无许可证冲突）。

## 技术要点

- **金额全流程整数（分）**：彻底规避浮点误差，输入端 `AmountInput`
  状态机集中校验（前导零、小数位、位数上限）。
- **日期用本地时区字符串键**：`yyyy-MM-dd` / `yyyy-MM`，字典序即时序，
  SQL 查询简单可靠，不受 UTC 偏移影响。
- **sqflite + 版本化迁移**：`onUpgrade` 迁移链只增不毁，种子数据幂等。
- **软删除**：账单可撤销；分类删除后历史账单仍显示原名，信息不丢失；
  有账单的账户拒绝删除，保证余额口径完整。
- **备份/恢复**：JSON 全量导出（带 formatVersion/schemaVersion 版本防护，
  事务内清空重写，失败自动回滚）；CSV 便于 Excel 查看。
- **零侵入自绘图表**：甜甜圈图与趋势柱图为 `CustomPainter` 实现，无第三方图表依赖。

## 目录结构

```
lib/
├── core/          # 金额、日期、主题、异常、数据库
├── data/
│   ├── models/    # 账单/分类/账户模型
│   ├── repositories/  # 三个仓储（分类/账户/账单）
│   ├── backup/    # 备份与恢复服务
│   └── default_data.dart  # 种子数据与图标注册表
├── state/         # 设置控制器、账本版本控制器
└── ui/            # 明细、记账、图表、我的等页面
docs/DESIGN.md     # 边界问题与扩展性设计说明（必读）
```

## Roadmap（扩展性预留）

多币种、预算、周期记账、回收站、搜索、云同步、Web 端支持等
已在 [docs/DESIGN.md](docs/DESIGN.md) 中给出迁移与实现路径。

## 许可证

[GPL-3.0](LICENSE)。基于本项目的二次分发须同样遵循 GPL-3.0 开源。
