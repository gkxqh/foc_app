// 应用图标源图处理脚本：从透明底原图生成 flutter_launcher_icons 所需的两张 1024 图。
// 用法：dart run tool/gen_icon.dart
//  - assets/icon/icon.png           透明底主图标（README / macOS / Android 传统图标；iOS 自动去 alpha 成黑底）
//  - assets/icon/icon_foreground.png Android 自适应图标前景（人物缩至 66% 安全区，透明底）
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/icon/icon_src.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('无法解码 assets/icon/icon_src.png');
    exit(1);
  }

  // 主图标：透明 1024 画布，人物等比缩放至高度贴合
  final main = img.copyResize(
    src,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.compositeImage(canvas, main, dstX: (1024 - main.width) ~/ 2, dstY: 0);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(canvas));

  // 自适应图标前景：人物缩至画布 66%（Android launcher 裁圆后不裁到人物）
  final fg = img.copyResize(
    src,
    height: (1024 * 0.66).round(),
    interpolation: img.Interpolation.cubic,
  );
  final fgCanvas = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.compositeImage(
    fgCanvas,
    fg,
    dstX: (1024 - fg.width) ~/ 2,
    dstY: (1024 - fg.height) ~/ 2,
  );
  File('assets/icon/icon_foreground.png')
      .writeAsBytesSync(img.encodePng(fgCanvas));

  stdout.writeln('生成完成：icon.png (1024x1024 透明底) + icon_foreground.png (前景安全区)');
}
