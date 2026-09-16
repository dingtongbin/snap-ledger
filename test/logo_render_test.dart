import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 生成应用 logo：assets/logo/logo.png（1024x1024）。
/// 运行 `flutter test test/logo_render_test.dart` 即可重新生成。
///
/// 设计：蓝色圆角方块（主题蓝渐变）+ 白色账本（装订脊 + 三条账目线）
/// + 右下角绿色对勾圆章——「随手记完一笔」。
void main() {
  test('生成 logo png', () async {
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // 1. 蓝色圆角方块背景（对角渐变，制造轻微立体感）。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(224),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5CADFF), Color(0xFF2E8BEE)],
        ).createShader(const Rect.fromLTWH(0, 0, size, size)),
    );

    // 2. 账本：先画蓝色装订脊，再叠白色内页。
    const book = Rect.fromLTWH(248, 256, 528, 492);
    canvas.drawRRect(
      RRect.fromRectAndRadius(book, const Radius.circular(52)),
      Paint()..color = const Color(0xFF2F86E8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(book.left + 56, book.top, book.width - 56, book.height),
        const Radius.circular(44),
      ),
      Paint()..color = Colors.white,
    );

    // 3. 三条账目线（浅蓝圆头短线，长短错落模拟流水）。
    final linePaint = Paint()
      ..color = const Color(0xFFA9CEFB)
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    final lines = [
      const Offset(372, 384),
      const Offset(700, 384),
      const Offset(372, 478),
      const Offset(732, 478),
      const Offset(372, 572),
      const Offset(636, 572),
    ];
    for (var i = 0; i < lines.length; i += 2) {
      canvas.drawLine(lines[i], lines[i + 1], linePaint);
    }

    // 4. 右下角对勾圆章：白色描边 + 绿底 + 白色对勾。
    const badgeCenter = Offset(700, 684);
    canvas.drawCircle(badgeCenter, 140, Paint()..color = Colors.white);
    canvas.drawCircle(
      badgeCenter,
      120,
      Paint()..color = const Color(0xFF07C160),
    );
    final check = Paint()
      ..color = Colors.white
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(badgeCenter.dx - 58, badgeCenter.dy + 2)
        ..lineTo(badgeCenter.dx - 12, badgeCenter.dy + 48)
        ..lineTo(badgeCenter.dx + 62, badgeCenter.dy - 44),
      check,
    );

    // 5. 导出 PNG。
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('assets/logo/logo.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('logo written: ${file.absolute.path} (${file.lengthSync()} bytes)');
  });
}
