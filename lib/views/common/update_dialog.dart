import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_update_model.dart';
import '../../providers/update_provider.dart';

/// 更新弹窗：随 UpdateProvider 状态切换 新版本信息 / 下载进度 / 失败重试。
/// [fromAutoCheck] 为 true（启动静默检查）时提供「忽略此版本」免打扰出口；
/// 手动检查场景用户意图明确，不展示忽略项。
Future<void> showUpdateDialog(BuildContext context, {required bool fromAutoCheck}) {
  final update = context.read<UpdateProvider>();
  update.setDialogVisible(true);
  return showDialog(
    context: context,
    // 下载进行中不允许点外部误关，弹窗内始终有明确的取消/关闭按钮
    barrierDismissible: false,
    builder: (ctx) => _UpdateDialogBody(fromAutoCheck: fromAutoCheck),
  ).whenComplete(() => update.setDialogVisible(false));
}

class _UpdateDialogBody extends StatelessWidget {
  final bool fromAutoCheck;

  const _UpdateDialogBody({required this.fromAutoCheck});

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, update, _) {
        final info = update.info;
        return AlertDialog(
          title: Text(switch (update.status) {
            UpdateStatus.downloading => '正在下载更新',
            UpdateStatus.installing => '准备安装',
            UpdateStatus.error => '更新失败',
            _ => '发现新版本',
          }),
          content: info == null
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最新版本 v${info.version}，当前 v${update.currentVersion}',
                      style: AppText.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._buildContent(context, update, info),
                  ],
                ),
          actions: _buildActions(context, update),
        );
      },
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    UpdateProvider update,
    AppUpdateInfo info,
  ) {
    switch (update.status) {
      case UpdateStatus.downloading:
        return [
          LinearProgressIndicator(
            value: info.downloadSize > 0 ? update.progress : null,
            minHeight: 6,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            info.downloadSize > 0
                ? '${(update.progress * 100).toStringAsFixed(0)}% · 共 ${(info.downloadSize / 1024 / 1024).toStringAsFixed(1)} MB'
                : '${(update.progress * 100).toStringAsFixed(0)}%',
            style: AppText.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case UpdateStatus.installing:
        return [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('正在调起安装程序…', style: AppText.body)),
            ],
          ),
        ];
      case UpdateStatus.error:
        return [
          Text(
            update.errorMessage ?? '出了点问题，请稍后重试',
            style: AppText.body,
          ),
        ];
      default:
        final changelog = info.changelog.trim();
        if (changelog.isEmpty) return const [SizedBox.shrink()];
        // 更新日志为 Markdown（GitHub Release body）。Markdown 自带滚动，
        // 只限高不限内容长度；不能用 Expanded——外层 Column 是 mainAxisSize.min
        return [
          SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: Markdown(
                data: changelog,
                selectable: false,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: AppText.body.copyWith(
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  listBullet: AppText.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  h1: AppText.titleSm,
                  h2: AppText.titleSm,
                  h3: AppText.title,
                ),
              ),
            ),
          ),
        ];
    }
  }

  List<Widget> _buildActions(BuildContext context, UpdateProvider update) {
    switch (update.status) {
      case UpdateStatus.downloading:
        return [
          TextButton(
            onPressed: update.cancelDownload,
            child: const Text('取消下载'),
          ),
        ];
      case UpdateStatus.installing:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('后台'),
          ),
        ];
      case UpdateStatus.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: update.updateNow,
            child: const Text('重试'),
          ),
        ];
      default:
        return [
          if (fromAutoCheck)
            TextButton(
              onPressed: () async {
                await update.markIgnored();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('忽略此版本'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('以后再说'),
          ),
          ElevatedButton(
            onPressed: update.updateNow,
            child: const Text('立即更新'),
          ),
        ];
    }
  }
}
