import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plaza_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/app_snackbar.dart';
import '../common/confirm_dialog.dart';
import '../common/empty_state.dart';
import '../common/page_insets.dart';
import '../common/responsive_center.dart';
import '../common/skeleton_list.dart';
import '../common/staggered_in.dart';

/// 接单广场：技术员浏览全部待接单工单，支持校区/品牌/设备/故障筛选、
/// 关键词搜索与日期排序，可直接接单（复用 /v1/ticket/give 的 order_hash 凭据）。
class ClaimPlazaPage extends StatefulWidget {
  const ClaimPlazaPage({super.key});

  @override
  State<ClaimPlazaPage> createState() => _ClaimPlazaPageState();
}

class _ClaimPlazaPageState extends State<ClaimPlazaPage> {
  final _keywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 进入页面时主动拉取一次，避免只展示 Provider 中的残留数据；
    // 仅技术员拉取（服务端对其他角色本就 403，无需发无用请求）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn && auth.isTechnician) {
        context.read<PlazaProvider>().fetchPlaza();
      }
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final plaza = context.read<PlazaProvider>();
    final auth = context.read<AuthProvider>();
    final ticketProvider = context.read<TicketProvider>();
    // 广场整表刷新（接单会轮换凭据），并联动"进行中"列表与桌面小组件快照
    await plaza.fetchPlaza();
    final user = auth.user;
    if (user != null) {
      await ticketProvider.fetchTickets(role: user.role, uid: user.uid);
    }
  }

  /// 接单：确认弹窗 → give（order_hash）→ 无论成败都整表刷新（服务端已流转）。
  /// 弹窗 SnackBar 在 await 前先捕获 messenger 与各 Provider 引用，
  /// 避免页面被弹窗卸载后 context 失效。
  Future<void> _claimTicket(TicketModel ticket) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认接单？',
      content:
          '接单后「${ticket.deviceType} • ${ticket.faultType}」将进入你的维修中列表，'
          '请尽快联系机主 ${ticket.ownerNickname ?? ''} 处理。',
      confirmText: '确认接单',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final plaza = context.read<PlazaProvider>();
    final auth = context.read<AuthProvider>();
    final ticketProvider = context.read<TicketProvider>();
    final error = await plaza.claimTicket(ticket);
    // 广场整表刷新（接单会轮换凭据），并联动"进行中"列表与桌面小组件快照
    await plaza.fetchPlaza();
    final user = auth.user;
    if (user != null) {
      await ticketProvider.fetchTickets(role: user.role, uid: user.uid);
    }
    if (!mounted) return;
    if (error == null) {
      showAppSnackBarOn(messenger, '接单成功，请尽快联系机主', type: SnackBarType.success);
    } else {
      showAppSnackBarOn(messenger, error, type: SnackBarType.error);
    }
  }

  /// 清空全部筛选条件时同步清理搜索框文本，避免输入框与状态脱同步
  void _clearAllFilters() {
    _keywordController.clear();
    context.read<PlazaProvider>().clearFilters();
  }

  /// 刷新失败但仍有旧数据时的顶部横幅：提示数据非最新并可点击重试
  Widget _buildStaleBanner(PlazaProvider plaza) {
    return Material(
      color: AppTheme.warningOrange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: AppTheme.warningOrange,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                plaza.lastError ?? '刷新失败，当前显示的可能不是最新数据',
                style: AppText.captionSm.copyWith(
                  color: AppTheme.warningOrange,
                ),
              ),
            ),
            TextButton(
              onPressed: () => plaza.fetchPlaza(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final plaza = context.watch<PlazaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('接单广场'),
        actions: [
          if (auth.isLoggedIn && auth.isTechnician)
            Badge(
              isLabelVisible: plaza.brandFilters.isNotEmpty ||
                  plaza.deviceFilters.isNotEmpty ||
                  plaza.faultFilters.isNotEmpty,
              label: Text(
                '${plaza.brandFilters.length + plaza.deviceFilters.length + plaza.faultFilters.length}',
              ),
              child: IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: '高级筛选',
                onPressed: _openFilterSheet,
              ),
            ),
        ],
      ),
      body: !auth.isLoggedIn
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: '请先登录后再使用接单广场',
              minHeight: 300,
            )
          : !auth.isTechnician
          ? const EmptyState(
              icon: Icons.badge_outlined,
              title: '仅技术员可访问接单广场',
              subtitle: '普通用户可在首页发起报修',
              minHeight: 300,
            )
          : Column(
              children: [
                _buildSearchBar(plaza),
                _buildFilterRow(plaza),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshAll,
                    child: Column(
                      children: [
                        // 有旧数据时刷新失败不再静默：顶部横幅提示可重试
                        if (plaza.lastError != null &&
                            plaza.tickets.isNotEmpty)
                          _buildStaleBanner(plaza),
                        Expanded(child: _buildListBody(plaza)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ---------- 筛选条 ----------

  Widget _buildSearchBar(PlazaProvider plaza) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: TextField(
        controller: _keywordController,
        onChanged: plaza.setKeyword,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索型号 / 故障描述 / 品牌',
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          suffixIcon: plaza.keyword.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _keywordController.clear();
                    plaza.setKeyword('');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(PlazaProvider plaza) {
    final campusOptions = ['全部', ...ApiConstants.campuses, '线下'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final campus in campusOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(campus),
                        selected: plaza.campusFilter == campus,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => plaza.setCampus(campus),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SegmentedButton<PlazaSortMode>(
            segments: const [
              ButtonSegment(
                value: PlazaSortMode.waitLongest,
                label: Text('等待最久'),
              ),
              ButtonSegment(
                value: PlazaSortMode.newestFirst,
                label: Text('最新'),
              ),
            ],
            selected: {plaza.sortMode},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (selection) =>
                plaza.setSortMode(selection.first),
          ),
        ],
      ),
    );
  }

  // ---------- 列表主体 ----------

  Widget _buildListBody(PlazaProvider plaza) {
    final tickets = plaza.visibleTickets;
    final loadError = plaza.lastError;

    if (plaza.isLoading && plaza.tickets.isEmpty) {
      return ListView(
        padding: pageListPadding(context),
        children: const [SkeletonList()],
      );
    }
    if (plaza.tickets.isEmpty && loadError != null) {
      return ListView(
        padding: pageListPadding(context),
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: loadError,
            minHeight: 240,
            action: OutlinedButton.icon(
              onPressed: () => context.read<PlazaProvider>().fetchPlaza(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ),
        ],
      );
    }
    if (plaza.tickets.isEmpty) {
      return ListView(
        padding: pageListPadding(context),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.storefront_rounded,
            image: 'assets/illustrations/fy_q.png',
            title: '暂无待接工单',
            subtitle: '有新的报修单时会出现在这里，可下拉刷新',
            minHeight: 220,
          ),
        ],
      );
    }
    if (tickets.isEmpty) {
      // 有数据但被筛选条件过滤光了
      return ListView(
        padding: pageListPadding(context),
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: '没有符合筛选条件的工单',
            minHeight: 220,
            action: OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('清空筛选'),
            ),
          ),
        ],
      );
    }
    return ResponsiveCenter(
      child: ListView.builder(
        padding: pageListPadding(context),
        itemCount: tickets.length,
        itemBuilder: (ctx, i) =>
            _buildPlazaCard(tickets[i], index: i, claiming: plaza.isClaiming),
      ),
    );
  }

  // ---------- 工单卡 ----------

  Widget _buildPlazaCard(
    TicketModel ticket, {
    required int index,
    required bool claiming,
  }) {
    final wait = PlazaFilters.formatWaitTime(ticket.createTime);
    return StaggeredIn(
      index: index,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => _showPreviewSheet(ticket),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (ticket.isUrgent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              size: 12,
                              color: AppTheme.warningOrange,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '加急',
                              style: AppText.captionSm.copyWith(
                                color: AppTheme.warningOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (wait != null)
                      Text(
                        '已等待 $wait',
                        style: AppText.captionSm.copyWith(
                          color: AppTheme.getStatusColor('Repairing'),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      ticket.createTime,
                      style: AppText.captionSm.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${ticket.deviceType} • ${ticket.faultType}',
                  style: AppText.title,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ticket.repairDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // 品牌名可能较长，Wrap 换行防溢出（同首页工单卡）
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(ticket.campus, style: AppText.micro),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    Chip(
                      label: Text(ticket.computerBrand, style: AppText.micro),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    if ((ticket.model ?? '').isNotEmpty &&
                        ticket.model != 'default')
                      Text(
                        ticket.model!,
                        style: AppText.captionSm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        ticket.ownerNickname ?? '机主未留昵称',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.captionSm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      Icons.phone_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        ticket.phone ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.captionSm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showPreviewSheet(ticket),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('详情'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: claiming ? null : () => _claimTicket(ticket),
                      icon: claiming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.back_hand_rounded, size: 18),
                      label: const Text('接单'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 详情预览 BottomSheet ----------

  void _showPreviewSheet(TicketModel ticket) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final plaza = sheetContext.watch<PlazaProvider>();
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(
                    'No.${ticket.id}',
                    style: AppText.caption.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (ticket.repairImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.thumb),
                    child: CachedNetworkImage(
                      imageUrl: ticket.repairImageUrl,
                      // 七牛签名链接会过期，过期/失败时优雅降级为占位
                      errorWidget: (_, _, _) => Container(
                        height: 160,
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _sheetRow(sheetContext, '设备', '${ticket.deviceType} • ${ticket.faultType}'),
                _sheetRow(sheetContext, '品牌型号',
                    [ticket.computerBrand, if (_plainModel(ticket) != null) _plainModel(ticket)!]
                        .join(' ')),
                _sheetRow(sheetContext, '校区', ticket.campus),
                _sheetRow(sheetContext, '保修状态', _warrantyText(ticket.warrantyStatus)),
                if ((ticket.purchaseDate ?? '').isNotEmpty)
                  _sheetRow(sheetContext, '购买日期', ticket.purchaseDate!),
                _sheetRow(sheetContext, '机主', ticket.ownerNickname ?? '未留昵称'),
                _sheetRow(sheetContext, '电话', ticket.phone ?? '未留'),
                _sheetRow(sheetContext, 'QQ', _plainQq(ticket) ?? '未留'),
                _sheetRow(sheetContext, '创建时间', ticket.createTime),
                const SizedBox(height: AppSpacing.md),
                Text('故障描述：', style: AppText.caption.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                )),
                const SizedBox(height: AppSpacing.xs),
                Text(ticket.repairDescription, style: AppText.body.copyWith(height: 1.4)),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    // 卡片"接单"请求在途时同样禁用，防止并发接单
                    onPressed: plaza.isClaiming
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _claimTicket(ticket);
                          },
                    icon: const Icon(Icons.back_hand_rounded),
                    label: const Text('接下这一单'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppText.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: AppText.body),
          ),
        ],
      ),
    );
  }

  // ---------- 高级筛选 BottomSheet ----------

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final plaza = sheetContext.watch<PlazaProvider>();
        final activeCount =
            plaza.brandFilters.length +
            plaza.deviceFilters.length +
            plaza.faultFilters.length;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    Text('高级筛选', style: AppText.title),
                    const Spacer(),
                    if (plaza.hasActiveFilters)
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: const Text('清空全部'),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _filterSection(
                        '品牌',
                        ApiConstants.brands,
                        plaza.brandFilters,
                        plaza.toggleBrand,
                      ),
                      _filterSection(
                        '设备类型',
                        ApiConstants.deviceTypes,
                        plaza.deviceFilters,
                        plaza.toggleDevice,
                      ),
                      _filterSection(
                        '故障类型',
                        ApiConstants.problemTypes,
                        plaza.faultFilters,
                        plaza.toggleFault,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(activeCount > 0 ? '完成（已选 $activeCount 项）' : '完成'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterSection(
    String title,
    List<String> options,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option, style: AppText.captionSm),
                  selected: selected.contains(option),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onToggle(option),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 小工具 ----------

  String? _plainModel(TicketModel ticket) {
    final m = ticket.model;
    if (m == null || m.isEmpty || m == 'default') return null;
    return m;
  }

  // qq_number 存储格式为 "联系方式类型|号码"，展示时去掉类型前缀（同工单详情页）
  String? _plainQq(TicketModel ticket) {
    final q = ticket.qqNumber;
    if (q == null || q.isEmpty) return null;
    final parts = q.split('|');
    return parts.length > 1 ? parts.sublist(1).join('|') : q;
  }

  String _warrantyText(String? status) {
    switch (status) {
      case 'under':
        return '保修期内';
      case 'expired':
        return '已过保';
      default:
        return '未知';
    }
  }
}
