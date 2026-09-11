// 飞扬 logo 备用图标生成：黑 logo → 白 logo，黑底补成正方形（只补短边不裁剪）。
// 用法：dart run tool/gen_logo.dart
// 产出：
//  - assets/icon/logo_alt.png                  1024 黑底白 logo（README / iOS 备用）
//  - android/.../mipmap-*/ic_launcher_logo.png Android activity-alias 各 dpi 图标
//  - ios/Runner/foc_logo.png                   iOS 备用图标（Info.plist 引用，无扩展名）
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/icon/logo_src.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('无法解码 assets/icon/logo_src.png');
    exit(1);
  }

  // 判断背景：角像素透明 = 透明底；不透明且亮 = 白底（一并去底）
  final corner = src.getPixel(0, 0);
  final transparentBg = corner.a < 128;
  stdout.writeln(
    '原图 ${src.width}x${src.height}，背景：${transparentBg ? '透明' : '不透明(将去除)'}',
  );

  // 生成白色 logo（保留 alpha；白底则去底）
  final white = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final lum = p.luminance;
      if (!transparentBg && lum > 200) {
        continue; // 白底 → 透明
      }
      white.setPixelRgba(x, y, 255, 255, 255, p.a);
    }
  }

  // 黑底 1024 画布，logo 等比缩放至宽贴合（只补短边，不裁剪）
  final scaled = img.copyResize(
    white,
    width: 1024,
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(width: 1024, height: 1024); // RGB 默认黑
  img.compositeImage(
    canvas,
    scaled,
    dstX: 0,
    dstY: (1024 - scaled.height) ~/ 2,
  );
  File('assets/icon/logo_alt.png').writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('assets/icon/logo_alt.png 完成 (1024x1024 黑底白 logo)');

  // Android activity-alias 各 dpi 图标
  const dpis = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  dpis.forEach((dpi, size) {
    final im = img.copyResize(
      canvas,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    File('android/app/src/main/res/mipmap-$dpi/ic_launcher_logo.png')
        .writeAsBytesSync(img.encodePng(im));
  });
  stdout.writeln('Android mipmap-*/ic_launcher_logo.png 完成');

  // iOS 备用图标
  File('ios/Runner/foc_logo.png').writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('ios/Runner/foc_logo.png 完成');
}
