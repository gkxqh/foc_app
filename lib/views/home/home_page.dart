import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/service_texts.dart';
import '../common/empty_state.dart';
import '../common/skeleton_list.dart';
import '../common/rank_badge.dart';
import '../common/staggered_in.dart';
import '../../models/ticket_model.dart';
import '../../models/tech_stats_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/update_provider.dart';
import '../auth/login_page.dart';
import '../common/update_dialog.dart';
import 'annual_summary_page.dart';
import 'announcement_page.dart';
import 'repair_terms_page.dart';
import 'scan_give_page.dart';
import 'ticket_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _wasLoggedIn = false;
  bool _didInitialRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次进入刷新一次；此后仅在登录态从未登录变为已登录时（如登录页返回）
    // 重新拉取，避免 initState 与 didChangeDependencies 双入口在启动时重复请求
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (!_didInitialRefresh) {
      _didInitialRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _refreshData();
        _autoCheckUpdate();
      });
    } else if (loggedIn && !_wasLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshData();
      });
    }
    _wasLoggedIn = loggedIn;
  }

  Future<void> _refreshData() async {
    final auth = context.read<AuthProvider>();
    final config = context.read<ConfigProvider>();
    final ticket = context.read<TicketProvider>();

    await config.fetchConfig();
    if (auth.isTechnician && config.showTechRank) {
      await config.fetchTopTech();
    }
    if (auth.isLoggedIn && auth.user != null) {
      await ticket.fetchTickets(role: auth.user!.role, uid: auth.user!.uid);
    }
  }

  // 启动静默检查更新：只有发现「未被忽略」的新版本才弹窗，
  // 无更新/检查失败一律静默，不打扰用户；每次启动仅此一处触发
  Future<void> _autoCheckUpdate() async {
    final update = context.read<UpdateProvider>();
    final result = await update.checkForUpdate(auto: true);
    if (!mounted || result != UpdateCheckResult.newVersion) return;
    if (update.dialogVisible) return;
    showUpdateDialog(context, fromAutoCheck: true);
  }

  void _openRepairTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RepairTermsPage()),
    );
  }

  void _openAnnouncement() {
    final config = context.read<ConfigProvider>();
    final String body;
    if (config.submitTips.isNotEmpty &&
        config.globalTips.isNotEmpty &&
        config.submitTips != config.globalTips) {
      body =
          '**【最新公告】**\n\n${config.submitTips}\n\n---\n\n**【服务须知与条款】**\n\n${config.globalTips}';
    } else {
      body = config.globalTips.isNotEmpty
          ? config.globalTips
          : (config.submitTips.isNotEmpty
                ? config.submitTips
                : ServiceTexts.fallbackRepairTerms);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementPage(body: body)),
    );
  }

  Widget _buildAnnouncementBanner(ConfigProvider config) {
    final tipText = config.submitTips.isNotEmpty
        ? config.submitTips
        : (config.globalTips.isNotEmpty ? '四川大学飞扬俱乐部设备报修及志愿维护服务须知' : '');

    if (tipText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.banner),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.banner),
          onTap: _openAnnouncement,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    tipText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>();
    final ticketProvider = context.watch<TicketProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('云上飞扬'),
        actions: [
          if (auth.isTechnician) ...[
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: '接单',
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanGivePage()),
                );
                if (changed == true && mounted) {
                  _refreshData();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.insights_rounded),
              tooltip: '年度总结',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnualSummaryPage()),
                );
              },
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: !auth.isLoggedIn
            ? _buildNotLoggedInView()
            : auth.isTechnician
            ? _buildTechnicianView(config, ticketProvider)
            : _buildUserView(config, ticketProvider),
      ),
      floatingActionButton:
          (auth.isLoggedIn && !auth.isTechnician && config.repairFlag)
          ? FloatingActionButton.extended(
              onPressed: _openRepairTerms,
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.build_rounded),
              label: const Text('我要报修'),
            )
          : null,
    );
  }

  Widget _buildNotLoggedInView() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        // 吉祥物迎宾：首次打开的第一眼即建立"社团服务"的亲近感
        Center(
          child: Image.asset(
            'assets/illustrations/fy_q.png',
            height: 150,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Center(child: Text('欢迎使用云上飞扬', style: AppText.titleXl)),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            '四川大学飞扬俱乐部设备报修及维护服务',
            style: AppText.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          icon: const Icon(Icons.login_rounded),
          label: const Text('登录'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            '未注册用户请先前往微信小程序「云上飞扬」完成注册',
            style: AppText.captionSm.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // 工单加载失败横幅（网络异常时保留旧数据并提示，与"无工单"区分）
  Widget _buildTicketErrorBanner(TicketProvider ticketProvider) {
    final error = ticketProvider.lastError;
    if (error == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppTheme.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.banner),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.banner),
          onTap: () {
            // 请求进行中不再重复触发，防止连点与下拉刷新并发叠加
            if (ticketProvider.isLoading) return;
            final auth = context.read<AuthProvider>();
            if (auth.isLoggedIn && auth.user != null) {
              ticketProvider.fetchTickets(
                role: auth.user!.role,
                uid: auth.user!.uid,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AppTheme.warningOrange,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    error,
                    style: AppText.caption.copyWith(
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ),
                Text(
                  '点击重试',
                  style: AppText.captionSm.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserView(ConfigProvider config, TicketProvider ticketProvider) {
    final activeList = ticketProvider.activeTickets;

    if (ticketProvider.isLoading && activeList.isEmpty) {
      return const SkeletonList();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (config.showAnnouncement) _buildAnnouncementBanner(config),
        _buildTicketErrorBanner(ticketProvider),
        if (!config.repairFlag) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppTheme.warningOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.bedtime_outlined,
                  size: 48,
                  color: AppTheme.warningOrange,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  '报修通道暂未开启',
                  style: AppText.title.copyWith(color: AppTheme.warningOrange),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  '当前为假期或技术员休整时间，系统已暂停接收新工单。感谢您的理解！',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (activeList.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('我的进行中工单', style: AppText.title),
              Text(
                '共 ${activeList.length} 单',
                style: AppText.captionSm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...activeList.indexed.map((e) => _buildTicketCard(e.$2, index: e.$1)),
          const SizedBox(height: AppSpacing.xl),
        ] else if (config.repairFlag) ...[
          const EmptyState(
            icon: Icons.assignment_turned_in_outlined,
            image: 'assets/illustrations/fy_q.png',
            title: '您当前没有进行中的报修工单',
            subtitle: '如遇电脑软硬件故障，请点击右下方按钮发起报修',
            minHeight: 220,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }

  Widget _buildTechnicianView(
    ConfigProvider config,
    TicketProvider ticketProvider,
  ) {
    final activeList = ticketProvider.activeTickets;

    if (ticketProvider.isLoading && activeList.isEmpty) {
      return const SkeletonList();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (config.showAnnouncement) _buildAnnouncementBanner(config),
        _buildTicketErrorBanner(ticketProvider),
        if (activeList.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('我的进行中工单', style: AppText.title),
              Text(
                '共 ${activeList.length} 单',
                style: AppText.captionSm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...activeList.indexed.map((e) => _buildTicketCard(e.$2, index: e.$1)),
          const SizedBox(height: AppSpacing.xl),
        ],
        // 技术员排行榜（受软件设置开关控制）
        if (config.showTechRank) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('技术员英雄榜', style: AppText.title),
              Row(
                children: ['总榜', '江安', '望江'].map((tab) {
                  final isSelected = config.selectedCampusTab == tab;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: isSelected,
                      onSelected: (_) => config.setCampusTab(tab),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildPodiumView(config),
        ] else if (activeList.isEmpty) ...[
          const EmptyState(
            icon: Icons.done_all_rounded,
            image: 'assets/illustrations/fy_q.png',
            title: '当前没有进行中的工单',
            subtitle: '如需接单，请点击右上角扫码接单',
            minHeight: 220,
          ),
        ],
      ],
    );
  }

  Widget _buildPodiumView(ConfigProvider config) {
    final list = config.topTechList;

    if (config.isLoadingRank) {
      // 与其他页面统一：加载占位用骨架屏而非转圈
      return const SkeletonList(
        variant: SkeletonVariant.podium,
        itemCount: 1,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
      );
    }

    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: '本期暂无上榜技术员',
        minHeight: 160,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.md,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (list.length > 1) _buildPodiumColumn(context, list[1], 2, 110),
            if (list.isNotEmpty) _buildPodiumColumn(context, list[0], 1, 140),
            if (list.length > 2) _buildPodiumColumn(context, list[2], 3, 90),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumColumn(
    BuildContext context,
    TopTechModel item,
    int rank,
    double height,
  ) {
    final Color color = switch (rank) {
      1 => AppTheme.rankGold,
      2 => AppTheme.rankSilver,
      _ => AppTheme.rankBronze,
    };
    return Column(
      children: [
        RankBadge(rank: rank, size: 30),
        const SizedBox(height: 6),
        Text(
          item.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${item.count} 台',
          style: AppText.captionSm.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 70,
          height: height - 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.thumb),
            ),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            'No.$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(TicketModel ticket, {required int index}) {
    return StaggeredIn(
      index: index,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketDetailPage(ticket: ticket),
              ),
            );
            if (mounted) {
              _refreshData();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'ticket-status-${ticket.id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getStatusColor(ticket.repairStatus)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                          child: Text(
                            AppTheme.getStatusText(ticket.repairStatus),
                            style: AppText.captionSm.copyWith(
                              color: AppTheme.getStatusColor(
                                ticket.repairStatus,
                              ),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
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
                Row(
                  children: [
                    Chip(
                      label: Text(ticket.campus, style: AppText.micro),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(ticket.computerBrand, style: AppText.micro),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
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
}
