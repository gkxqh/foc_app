import 'dart:io';

import 'package:image/image.dart' as img;

/// 生成 App 内插画资产：裁掉透明边界后按高度缩放，控制包体。
/// 用法：dart run tool/gen_illustrations.dart
void main() {
  const sourceDir = '/Users/neko/Downloads/飞扬娘2026';
  const outDir = 'assets/illustrations';
  Directory(outDir).createSync(recursive: true);

  final jobs = [
    // Q 版全身：空态插画与首页未登录引导（显示高度 ~120pt，@3x 留裕量）
    ('Q.png', 'fy_q.png', 480),
    // 正脸：关于页等小尺寸场景备用
    ('小正脸.png', 'fy_face.png', 320),
  ];

  for (final (srcName, outName, targetHeight) in jobs) {
    final raw = img.decodePng(File('$sourceDir/$srcName').readAsBytesSync());
    if (raw == null) {
      stderr.writeln('decode failed: $srcName');
      continue;
    }
    // 裁掉四周透明像素，避免插画在布局里"看起来偏小"
    final cropped = img.trim(raw, mode: img.TrimMode.transparent);
    final resized = img.copyResize(
      cropped,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
    final out = File('$outDir/$outName');
    out.writeAsBytesSync(img.encodePng(resized, level: 9));
    final kb = (out.lengthSync() / 1024).round();
    stdout.writeln(
      '$outName: ${cropped.width}x${cropped.height} -> '
      '${resized.width}x${resized.height} ($kb KB)',
    );
  }
}
