import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/app_snackbar.dart';
import '../common/confirm_dialog.dart';
import '../common/image_preview.dart';
import '../common/page_insets.dart';
import '../common/step_progress.dart';

/// 工单详情内容体：无 Scaffold/AppBar，供两种宿主共用——
/// 1. 整页 [TicketDetailPage]：标题栏与转场由页面层负责；
/// 2. 宽屏（≥720dp）列表-详情双栏的右栏：直接嵌入。
///
/// 嵌入模式没有路由可退，[onFinished] 用于替代「操作成功后 pop 返回列表」：
/// 宿主借此刷新列表/清空选中；整页模式不传，走 Navigator.pop。
class TicketDetailView extends StatefulWidget {
  final TicketModel ticket;
  final ScrollController? controller;

  /// 工单本地副本发生变化（状态流转/凭证上传）时通知宿主，
  /// 整页模式下标题栏徽章依赖此回调同步刷新
  final ValueChanged<TicketModel>? onChanged;

  /// 操作导致工单终结（直接结束/取消）后调用，替代 Navigator.pop
  final VoidCallback? onFinished;

  const TicketDetailView({
    super.key,
    required this.ticket,
    this.controller,
    this.onChanged,
    this.onFinished,
  });

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  late TicketModel _ticket;
  bool _isUploadingCompleteImg = false;
  bool _isActionBusy = false; // 确认/结束/关闭/取消等操作的防重标志

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  // 联系方式展示值：qq_number 存储格式为 "联系方式类型|号码"，展示时去掉类型前缀
  String? get _plainPhone {
    final p = _ticket.phone;
    return (p == null || p.isEmpty) ? null : p;
  }

  String? get _plainQq {
    final q = _ticket.qqNumber;
    if (q == null || q.isEmpty) return null;
    final parts = q.split('|');
    return parts.length > 1 ? parts.sublist(1).join('|') : q;
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, '$label已复制：$value', type: SnackBarType.error);
  }

  /// 状态变化同步给宿主（整页标题栏徽章）
  void _updateTicket(TicketModel next) {
    setState(() => _ticket = next);
    widget.onChanged?.call(next);
  }

  // 操作等效「离开详情」：整页模式 pop，双栏嵌入模式回调宿主刷新列表
  void _finish() {
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      Navigator.pop(context);
    }
  }

  // 联系方式行：有值时附复制按钮
  Widget _buildContactRow(String label, String? value) {
    final hasValue = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // 长号码右对齐折行而非溢出
          Expanded(
            child: Text(
              hasValue ? value : '未预留',
              textAlign: TextAlign.right,
              style: AppText.caption.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (hasValue) ...[
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _copyToClipboard(label, value),
              child: Padding(
                padding: const EdgeInsets.all(
                  10.0,
                ), // 15px 图标 + 10px 边距 ≈ 35px，接近最小触摸目标
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _getStepIndex(String status) {
    switch (status) {
      case 'Pending':
        return 0;
      case 'Repairing':
        return 1;
      case 'UserConfirming':
      case 'TechConfirming':
        return 2;
      case 'Done':
      case 'Closed':
      case 'Canceled':
        return 3;
      default:
        return 0;
    }
  }

  // 选择图片来源：拍照或相册，返回 null 表示用户取消
  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadCompleteImage() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 80);
    } catch (_) {
      // 相机/相册权限被拒等场景：image_picker 会抛出异常而非返回 null
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? '无法打开相机，请检查相机权限设置'
                : '无法打开相册，请检查权限设置',
          ),
        ),
      );
      return;
    }
    if (file == null) return;

    setState(() => _isUploadingCompleteImg = true);
    final res = await ApiClient().uploadImage(file.path);

    if (!mounted) return;

    if (res.success && res.data != null) {
      final ticketProvider = context.read<TicketProvider>();
      final ok = await ticketProvider.setCompleteImage(_ticket.id, res.data!);
      if (!mounted) return;
      if (ok) {
        _updateTicket(_ticket.copyWith(completeImageUrl: res.data));
        if (!mounted) return;
        showAppSnackBar(context, '维修凭证上传成功', type: SnackBarType.success);
      } else {
        // 图片已上传但未关联到工单，必须明确告知，否则技术员以为凭证已生效
        showAppSnackBar(
          context,
          '凭证上传成功但关联工单失败，请重新上传',
          type: SnackBarType.warning,
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message ?? '图片上传失败')));
    }
    if (mounted) setState(() => _isUploadingCompleteImg = false);
  }

  void _confirmTicket(bool isTech) async {
    if (isTech &&
        (_ticket.completeImageUrl == null ||
            _ticket.completeImageUrl!.isEmpty)) {
      // 未上传凭证：仅弹出提示要求上传，不自动进入拍照
      final goUpload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('请先上传维修凭证'),
          content: const Text('请求用户确认完成前，需要先上传维修完成凭证图片。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('我知道了'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去上传'),
            ),
          ],
        ),
      );
      if (goUpload == true) {
        _uploadCompleteImage();
      }
      return;
    }

    final newStatus = isTech ? 'UserConfirming' : 'TechConfirming';

    final ok = await showConfirmDialog(
      context,
      title: '确认完成维修？',
      content: '只有用户与技术员双方确认后，工单才会正式关闭。',
    );

    if (ok != true) return;
    if (!mounted || _isActionBusy) return;
    setState(() => _isActionBusy = true);

    final ticketProvider = context.read<TicketProvider>();
    final success = await ticketProvider.changeTicketStatus(
      _ticket.id,
      newStatus,
    );

    if (!mounted) return;
    setState(() => _isActionBusy = false);

    if (success) {
      _updateTicket(_ticket.copyWith(repairStatus: newStatus));
      showAppSnackBar(context, '已提交完成确认', type: SnackBarType.success);
    } else {
      showAppSnackBar(context, '操作失败', type: SnackBarType.error);
    }
  }

  Future<void> _completeDirectly() async {
    if (_isActionBusy) return;
    final ok = await showConfirmDialog(
      context,
      title: '直接结束工单？',
      content: '工单将立即置为已完成，跳过用户确认。建议确认用户已知晓维修结果，并已上传维修凭证。',
      confirmText: '结束工单',
    );
    if (!ok || !mounted || _isActionBusy) return;
    setState(() => _isActionBusy = true);

    final ticketProvider = context.read<TicketProvider>();
    final okDone = await ticketProvider.completeTicket(_ticket.id);
    if (!mounted) return;
    setState(() => _isActionBusy = false);
    if (okDone) {
      showAppSnackBar(context, '工单已结束', type: SnackBarType.success);
      _finish();
    } else {
      showAppSnackBar(context, '操作失败，请稍后重试', type: SnackBarType.error);
    }
  }

  // 技术员强制关闭异常工单（Closed），与小程序 closeTheTicket 对齐
  Future<void> _forceCloseTicket() async {
    if (_isActionBusy) return;
    final ok = await showConfirmDialog(
      context,
      title: '强制关闭工单',
      content: '确认强制关闭工单吗？该功能仅在异常情况下使用。',
      confirmText: '强制关闭',
      danger: true,
    );

    if (!ok || !mounted || _isActionBusy) return;
    setState(() => _isActionBusy = true);

    final ticketProvider = context.read<TicketProvider>();
    final success = await ticketProvider.changeTicketStatus(
      _ticket.id,
      'Closed',
    );
    if (!mounted) return;
    setState(() => _isActionBusy = false);
    if (success) {
      _updateTicket(_ticket.copyWith(repairStatus: 'Closed'));
      showAppSnackBar(context, '工单已强制关闭', type: SnackBarType.success);
    } else {
      showAppSnackBar(context, '操作失败，请稍后重试', type: SnackBarType.error);
    }
  }

  Future<void> _cancelTicket() async {
    final ok = await showConfirmDialog(
      context,
      title: '取消报修工单？',
      content: '确定要取消此工单吗？',
      confirmText: '取消工单',
      danger: true,
    );

    if (!ok || !mounted || _isActionBusy) return;
    setState(() => _isActionBusy = true);

    final ticketProvider = context.read<TicketProvider>();
    final success = await ticketProvider.changeTicketStatus(
      _ticket.id,
      'Canceled',
    );
    if (!mounted) return;
    setState(() => _isActionBusy = false);
    if (success) {
      showAppSnackBar(context, '工单已取消', type: SnackBarType.success);
      _finish();
    } else {
      showAppSnackBar(context, '取消失败，请稍后重试', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTech = auth.isTechnician;
    final stepIndex = _getStepIndex(_ticket.repairStatus);

    return ListView(
      controller: widget.controller,
      padding: pageListPadding(context),
      children: [
        // 步骤条（取消/关闭走异常红终态，不播呼吸光环）
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.sm,
            ),
            child: StepProgress(
              labels: [
                '电脑报修',
                '技术员接单',
                if (_ticket.repairStatus == 'UserConfirming')
                  '用户确认'
                else if (_ticket.repairStatus == 'TechConfirming')
                  '技术员确认'
                else
                  '维修确认',
                if (_ticket.repairStatus == 'Canceled')
                  '已取消'
                else if (_ticket.repairStatus == 'Closed')
                  '已关闭'
                else
                  '工单完成',
              ],
              currentStep: stepIndex,
              abnormalLast:
                  _ticket.repairStatus == 'Canceled' ||
                  _ticket.repairStatus == 'Closed',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 状态 Banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppTheme.getStatusColor(_ticket.repairStatus)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.banner),
            border: Border.all(
              color: AppTheme.getStatusColor(_ticket.repairStatus)
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: AppTheme.getStatusColor(_ticket.repairStatus),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前状态：${AppTheme.getStatusText(_ticket.repairStatus)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getStatusColor(_ticket.repairStatus),
                      ),
                    ),
                    Text(
                      '创建时间：${_ticket.createTime}',
                      style: AppText.captionSm.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 故障详情卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 徽章与故障类型允许换行：长品牌名/长故障类型不再互相挤出溢出
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Text(
                        _ticket.campus,
                        style: AppText.captionSm.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Text(
                        _ticket.computerBrand,
                        style: AppText.captionSm.copyWith(
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(_ticket.faultType, style: AppText.title),
                  ],
                ),
                const Divider(height: 24),
                _buildDetailRow('设备类型', _ticket.deviceType),
                _buildDetailRow('设备品牌', _ticket.computerBrand),
                if (_ticket.model != null && _ticket.model!.isNotEmpty)
                  _buildDetailRow('设备型号', _ticket.model!),
                _buildDetailRow(
                  '保修状态',
                  _ticket.warrantyStatus == 'under'
                      ? '在保'
                      : _ticket.warrantyStatus == 'expired'
                      ? '过保'
                      : '未知',
                ),
                _buildDetailRow('设备问题', _ticket.faultType),
                if (_ticket.purchaseDate != null &&
                    _ticket.purchaseDate!.isNotEmpty)
                  _buildDetailRow('购买日期', _ticket.purchaseDate!),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '故障描述：',
                  style: AppText.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _ticket.repairDescription,
                  style: AppText.body.copyWith(height: 1.4),
                ),
                if (_ticket.repairImageUrl.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: () =>
                        showImagePreview(context, _ticket.repairImageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.thumb),
                      child: _CachedTicketImage(
                        imageUrl: _ticket.repairImageUrl,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 联系方式卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('联系信息', style: AppText.title),
                const SizedBox(height: AppSpacing.sm),
                _buildContactRow('机主昵称', _ticket.ownerNickname),
                _buildContactRow('联系电话', _plainPhone),
                _buildContactRow('QQ号', _plainQq),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 维修完成凭证 (如果已上传)
        if (_ticket.completeImageUrl != null &&
            _ticket.completeImageUrl!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('技术员维修完成凭证', style: AppText.title),
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: () =>
                        showImagePreview(context, _ticket.completeImageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.thumb),
                      child: _CachedTicketImage(
                        imageUrl: _ticket.completeImageUrl!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
        // 底部操作区（双向确认/直接结束仅在维修中状态开放，防止绕过状态机）
        if (!_ticket.isFinished) ...[
          if (isTech) ...[
            OutlinedButton.icon(
              onPressed: _isUploadingCompleteImg ? null : _uploadCompleteImage,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text(
                _ticket.completeImageUrl != null &&
                        _ticket.completeImageUrl!.isNotEmpty
                    ? '重新上传维修凭证'
                    : '上传维修完成凭证图片',
              ),
            ),
            if (_ticket.repairStatus == 'Repairing') ...[
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: () => _confirmTicket(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('请求用户确认完成'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _completeDirectly,
                child: Text(
                  '无需确认直接结束工单',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _forceCloseTicket,
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text(
                '强制关闭工单',
                style: TextStyle(color: AppTheme.errorRed),
              ),
            ),
          ] else ...[
            if (_ticket.repairStatus == 'Repairing')
              ElevatedButton.icon(
                onPressed: () => _confirmTicket(false),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('确认电脑维修完成'),
              ),
            if (_ticket.repairStatus == 'Pending') ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _cancelTicket,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                ),
                child: const Text('取消报修'),
              ),
            ],
          ],
        ],
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // 长值（长设备型号等）右对齐折行而非溢出
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.caption.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// 工单图片缓存加载占位：本地缓存命中秒开，失败时用主题化占位填满原高度
class _CachedTicketImage extends StatelessWidget {
  final String imageUrl;

  const _CachedTicketImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // 固定 180 高在宽屏（折叠屏展开/横屏）会被 cover 裁成极端横条，
    // 改为 16:9 随宽度伸缩，窄屏观感与原高度接近
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
