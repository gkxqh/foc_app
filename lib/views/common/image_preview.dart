import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全屏图片预览：支持双指缩放与拖动，点击背景关闭
void showImagePreview(BuildContext context, String imageUrl) {
  Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => _ImagePreviewPage(imageUrl: imageUrl),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _ImagePreviewPage extends StatelessWidget {
  final String imageUrl;

  const _ImagePreviewPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // 全屏黑底预览页无 AppBar，显式声明浅色系统栏图标，避免沿用上一页深色图标
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  // 加载期间给出转圈反馈，避免全黑无响应感
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(color: Colors.white70),
                    );
                  },
                  errorBuilder: (_, _, _) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text('图片加载失败', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
