import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/confirm_dialog.dart';
import '../common/image_preview.dart';
import '../common/page_insets.dart';
import 'give_order_page.dart';

class TicketDetailPage extends StatefulWidget {
  final TicketModel ticket;

  const TicketDetailPage({super.key, required this.ticket});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label已复制：$value')));
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
          const Spacer(),
          Text(
            hasValue ? value : '未预留',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w500),
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
        setState(() {
          _ticket = _ticket.copyWith(completeImageUrl: res.data);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('维修凭证上传成功')));
      } else {
        // 图片已上传但未关联到工单，必须明确告知，否则技术员以为凭证已生效
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('凭证上传成功但关联工单失败，请重新上传')));
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
      setState(() {
        _ticket = _ticket.copyWith(repairStatus: newStatus);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已提交完成确认')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失败')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('工单已结束')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
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
      setState(() {
        _ticket = _ticket.copyWith(repairStatus: 'Closed');
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('工单已强制关闭')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('工单已取消')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('取消失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTech = auth.isTechnician;
    final stepIndex = _getStepIndex(_ticket.repairStatus);

    return Scaffold(
      appBar: AppBar(
        // 与首页工单卡状态徽章共享 Hero tag：转场时徽章从卡片飞到标题栏。
        // 两端 child 必须保持同构（同款徽章样式），否则样式突变会产生闪烁
        title: Hero(
          tag: 'ticket-status-${_ticket.id}',
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.getStatusColor(_ticket.repairStatus)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Text(
                AppTheme.getStatusText(_ticket.repairStatus),
                style: AppText.caption.copyWith(
                  color: AppTheme.getStatusColor(_ticket.repairStatus),
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        actions: [
          // 转单码 = 工单号 + 服务端下发的 6 位 tvcode（与小程序原版一致）；
          // 服务端会校验 tvcode，未获取到时隐藏入口而非伪造
          if (isTech &&
              !_ticket.isFinished &&
              (_ticket.transcode?.isNotEmpty ?? false))
            IconButton(
              icon: const Icon(Icons.qr_code_rounded),
              tooltip: '生成转单凭证',
              onPressed: () {
                final transcode = '${_ticket.id}${_ticket.transcode}';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GiveOrderPage(transcodeToShare: transcode),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: pageListPadding(context),
        children: [
          // 步骤条
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xl,
                horizontal: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _buildStepItem('电脑报修', 0, stepIndex),
                  _buildStepDivider(0, stepIndex),
                  _buildStepItem('技术员接单', 1, stepIndex),
                  _buildStepDivider(1, stepIndex),
                  _buildStepItem(
                    _ticket.repairStatus == 'UserConfirming'
                        ? '用户确认'
                        : _ticket.repairStatus == 'TechConfirming'
                        ? '技术员确认'
                        : '维修确认',
                    2,
                    stepIndex,
                  ),
                  _buildStepDivider(2, stepIndex),
                  _buildStepItem(
                    _ticket.repairStatus == 'Canceled'
                        ? '已取消'
                        : _ticket.repairStatus == 'Closed'
                        ? '已关闭'
                        : '工单完成',
                    3,
                    stepIndex,
                    isSpecial:
                        _ticket.repairStatus == 'Canceled' ||
                        _ticket.repairStatus == 'Closed',
                  ),
                ],
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
                  Row(
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
                      const SizedBox(width: AppSpacing.sm),
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
                      const Spacer(),
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
                        child: Image.network(
                          _ticket.repairImageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 180,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
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
                        child: Image.network(
                          _ticket.completeImageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 180,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
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
                onPressed: _isUploadingCompleteImg
                    ? null
                    : _uploadCompleteImage,
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
      ),
    );
  }

  Widget _buildStepItem(
    String title,
    int step,
    int currentStep, {
    bool isSpecial = false,
  }) {
    final bool isDone = currentStep >= step;
    // 颜色随主题翻转：未完成步骤用 onSurfaceVariant 弱化，异常终态用语义红
    final Color color = isSpecial
        ? AppTheme.errorRed
        : isDone
        ? AppTheme.primaryBlue
        : Theme.of(context).colorScheme.onSurfaceVariant
              .withValues(alpha: 0.55);

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Icon(
              isDone ? Icons.check : Icons.circle,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppText.micro.copyWith(
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int step, int currentStep) {
    final isDone = currentStep > step;
    return Container(
      width: 20,
      height: 2,
      color: isDone
          ? AppTheme.primaryBlue
          : Theme.of(context).colorScheme.onSurfaceVariant
                .withValues(alpha: 0.3),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppText.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: AppText.caption.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
