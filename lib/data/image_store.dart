import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 账单附件（图片）物理文件管理。
///
/// 设计原则：
/// - 用户上传原图直接拷贝到应用文档目录下的 [attachmentsSubdir]，
///   **不做任何压缩或重编码**，保持原始画质；
/// - 文件名采用微秒级时间戳 + 原扩展名，绝对避免冲突；
/// - 删除账单时由调用方负责清理对应物理文件。
class ImageStore {
  ImageStore._();

  static const String attachmentsSubdir = 'attachments';

  /// 返回 attachments 目录绝对路径，不存在则创建。
  static Future<Directory> _attachmentsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'SnapLedger', attachmentsSubdir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 把 [source]（用户选择的原文件）拷贝到 attachments 目录，
  /// 返回新文件的绝对路径。
  ///
  /// 若拷贝失败抛 [FileSystemException]；不读不写图片内容，保留原字节。
  static Future<String> importFromFile(File source) async {
    if (!await source.exists()) {
      throw FileSystemException('源文件不存在', source.path);
    }
    final dir = await _attachmentsDir();
    final ext = p.extension(source.path);
    final ts = DateTime.now().microsecondsSinceEpoch;
    final name = ext.isEmpty ? '$ts' : '$ts$ext';
    final target = File(p.join(dir.path, name));
    await source.copy(target.path);
    return target.path;
  }

  /// 把外部字节内容写入 attachments 目录（备份恢复时使用）。
  static Future<String> importFromBytes(List<int> bytes, String filename) async {
    final dir = await _attachmentsDir();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final ext = p.extension(filename);
    final base = p.basenameWithoutExtension(filename);
    final safeBase = base.isEmpty ? 'img' : base;
    final name = '$ts-$safeBase$ext';
    final target = File(p.join(dir.path, name));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  /// 删除一组物理文件；不存在的静默忽略。
  static Future<void> deletePaths(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // 静默：物理文件清理失败不应阻塞业务流。
      }
    }
  }

  /// 暴露给备份导出：返回所有附件文件列表（用于 zip 打包）。
  static Future<List<File>> listAll() async {
    final dir = await _attachmentsDir();
    if (!dir.existsSync()) return const [];
    final entries = dir.listSync();
    return entries.whereType<File>().toList(growable: false);
  }

  /// 备份导入时把图片就地拷到当前环境的 attachments 目录。
  /// [source] 是从 zip 解压出的临时文件，返回持久化路径。
  static Future<String> importFromTemp(File source) =>
      importFromFile(source);
}