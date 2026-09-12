import 'dart:io';

import 'package:image/image.dart' as img;

/// 生成设置页图标预览与 iOS 开屏用的缩略资产。
/// 原图（assets/icon/*.png，480-700KB/张）仅显示在 52pt 预览和 220pt 开屏，
/// 直接进包严重浪费；此处按 640px 高输出到 assets/preview/，5 张省约 1.5MB。
/// 用法：dart run tool/gen_preview_icons.dart
void main() {
  const outDir = 'assets/preview';
  Directory(outDir).createSync(recursive: true);

  const jobs = [
    ('character_icon.png', 640),
    ('red_avatar.png', 640),
    ('logo_alt.png', 640),
    ('logo_art.png', 640),
    ('fy_logo.png', 640),
  ];

  for (final (name, targetHeight) in jobs) {
    final raw = img.decodePng(File('assets/icon/$name').readAsBytesSync());
    if (raw == null) {
      stderr.writeln('decode failed: $name');
      continue;
    }
    final resized = img.copyResize(
      raw,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
    final out = File('$outDir/$name');
    out.writeAsBytesSync(img.encodePng(resized, level: 9));
    final kb = (out.lengthSync() / 1024).round();
    stdout.writeln('$name: ${resized.width}x${resized.height} ($kb KB)');
  }
}
