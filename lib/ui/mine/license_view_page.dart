import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// GPL-3.0 许可证全文查看页（读取打包进资源的根目录 LICENSE 文件）。
class LicenseViewPage extends StatelessWidget {
  const LicenseViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开源许可（GPL-3.0）')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('LICENSE'),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snap.data ?? '许可文件缺失',
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
          );
        },
      ),
    );
  }
}
