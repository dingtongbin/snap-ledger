// 随手记账 —— 一款完全本地化的个人记账应用。
//
// Copyright (C) 2026 dingtongbin
// 联系方式：https://github.com/dingtongbin/snap-ledger
//
// 本程序是自由软件：你可以根据自由软件基金会发布的 GNU 通用公共许可证
// （GPL-3.0）条款重新分发或修改它。详见项目根目录 LICENSE 文件。
// 本程序不提供任何担保；亦不承担适销性或特定用途适用性的暗示担保。
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactory, databaseFactoryFfi, sqfliteFfiInit, Database;

import 'core/db/app_database.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'data/backup/backup_service.dart';
import 'data/repositories/repositories.dart';
import 'state/book_controller.dart';
import 'state/ledger_controller.dart';
import 'state/settings_controller.dart';
import 'state/ui_prefs.dart';
import 'ui/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux 桌面端使用 FFI 实现的 sqflite；sqlite3_flutter_libs
  // 会随应用自带 sqlite 引擎，无需系统安装。
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  final db = await AppDatabase.instance.open();

  // 把本应用的 GPL-3.0 许可证注册进系统“许可”页。
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>[S.appName],
      '本应用基于 GNU 通用公共许可证第 3 版（GPL-3.0）发布，\n'
      '完整许可证文本见项目根目录 LICENSE 文件，或访问\n'
      'https://www.gnu.org/licenses/gpl-3.0.html',
    );
  });

  // UI 选择状态持久化（交易方式/视图切换等，见 UiPrefs）。
  await UiPrefs.init(prefs);

  runApp(BookkeepingApp(db: db, prefs: prefs));
}

class BookkeepingApp extends StatelessWidget {
  const BookkeepingApp({super.key, required this.db, required this.prefs});

  final Database db;
  final SharedPreferences prefs;

  /// 全局 messenger：页面 pop 后仍可投递 Snackbar（如详情页删除的「撤销」）。
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Database>.value(value: db),
        Provider<CategoryRepository>(create: (_) => CategoryRepository(db)),
        Provider<AccountRepository>(create: (_) => AccountRepository(db)),
        Provider<TransactionRepository>(
          create: (_) => TransactionRepository(db),
        ),
        Provider<BackupService>(create: (_) => BackupService(db)),
        Provider<LedgerBookRepository>(create: (_) => LedgerBookRepository(db)),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(prefs),
        ),
        ChangeNotifierProvider<LedgerController>(
          create: (_) => LedgerController(),
        ),
        // 账本选择：启动即加载（表为空时数据库种子保证默认账本存在）。
        ChangeNotifierProvider<BookController>(
          create: (context) =>
              BookController(context.read<LedgerBookRepository>())..load(),
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: S.appName,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: BookkeepingApp.scaffoldMessengerKey,
          theme: AppTheme.light(settings.seedColor),
          darkTheme: AppTheme.dark(settings.seedColor),
          themeMode: settings.themeMode,
          locale: const Locale('zh'),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RootShell(),
        ),
      ),
    );
  }
}
