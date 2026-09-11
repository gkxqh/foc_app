import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../common/empty_state.dart';
import '../common/skeleton_list.dart';
import '../common/rank_badge.dart';
import '../../models/ticket_model.dart';
import '../../models/tech_stats_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/ticket_provider.dart';
import '../auth/login_page.dart';
import 'annual_summary_page.dart';
import 'give_order_page.dart';
import 'scan_give_page.dart';
import 'submit_ticket_page.dart';
import 'ticket_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 登录态从未登录变为已登录时（如登录页返回），重新拉取工单，避免一直显示旧空态
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (loggedIn && !_wasLoggedIn) {
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
    await config.fetchTopTech();
    if (auth.isLoggedIn && auth.user != null) {
      await ticket.fetchTickets(role: auth.user!.role, uid: auth.user!.uid);
    }
  }

  void _showNoticeDialog() {
    final config = context.read<ConfigProvider>();
    final tips = config.globalTips.isNotEmpty
        ? config.globalTips
        : '1. 送修前请移除电源外其余外设配件（包括鼠标、接收器、U盘、内存卡等）；\n2. 如要更换配件，请提前购买准备好；\n3. 如需重装系统，送修前电脑充满电；\n4. 请备份好重要数据，飞扬不对任何数据丢失负责；\n5. 我们志愿服务并非万能，不保证100%能够修好。';

    bool agreed = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('报修须知与服务条款'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Markdown(data: tips),
              ),
              CheckboxListTile(
                value: agreed,
                onChanged: (v) => setDialogState(() => agreed = v ?? false),
                title: const Text(
                  '我已阅读并同意上述须知',
                  style: TextStyle(fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              // 与小程序一致：必须勾选同意才能继续报修
              onPressed: agreed
                  ? () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubmitTicketPage(),
                        ),
                      );
                    }
                  : null,
              child: const Text('我已知晓并同意'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementBanner(ConfigProvider config) {
    final tipText = config.submitTips.isNotEmpty
        ? config.submitTips
        : (config.globalTips.isNotEmpty ? '四川大学飞扬俱乐部设备报修及志愿维护服务须知' : '');

    if (tipText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _showNoticeDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tipText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
              tooltip: '扫码接单',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanGivePage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_rounded),
              tooltip: '接单',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GiveOrderPage()),
                );
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
              onPressed: _showNoticeDialog,
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
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_outlined,
              size: 50,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            '欢迎使用云上飞扬',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '四川大学飞扬俱乐部设备报修及维护服务',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          icon: const Icon(Icons.login_rounded),
          label: const Text('手机验证码登录 / 注册'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: AppTheme.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
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
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AppTheme.warningOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ),
                const Text(
                  '点击重试',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAnnouncementBanner(config),
        _buildTicketErrorBanner(ticketProvider),
        if (!config.repairFlag) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: const [
                Icon(
                  Icons.bedtime_outlined,
                  size: 48,
                  color: AppTheme.warningOrange,
                ),
                SizedBox(height: 12),
                Text(
                  '报修通道暂未开启',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningOrange,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '当前为假期或技术员休整时间，系统已暂停接收新工单。感谢您的理解！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (activeList.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我的进行中工单',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '共 ${activeList.length} 单',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeList.map((t) => _buildTicketCard(t)),
          const SizedBox(height: 20),
        ] else if (config.repairFlag) ...[
          SizedBox(
            height: 220,
            child: EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: '您当前没有进行中的报修工单',
              subtitle: '如遇电脑软硬件故障，请点击右下方按钮发起报修',
            ),
          ),
          const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAnnouncementBanner(config),
        _buildTicketErrorBanner(ticketProvider),
        if (activeList.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我的进行中工单',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '共 ${activeList.length} 单',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeList.map((t) => _buildTicketCard(t)),
          const SizedBox(height: 20),
        ],
        // 技术员排行榜
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '技术员英雄榜',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
        const SizedBox(height: 16),
        _buildPodiumView(config),
      ],
    );
  }

  Widget _buildPodiumView(ConfigProvider config) {
    final list = config.topTechList;

    if (config.isLoadingRank) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (list.isEmpty) {
      return const SizedBox(
        height: 160,
        child: EmptyState(
          icon: Icons.emoji_events_outlined,
          title: '本期暂无上榜技术员',
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
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
      1 => const Color(0xFFF5B301),
      2 => const Color(0xFF9EA7B3),
      _ => const Color(0xFFB07A4B),
    };
    return Column(
      children: [
        RankBadge(rank: rank, size: 30),
        const SizedBox(height: 6),
        Text(
          item.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '${item.count} 台',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height - 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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

  Widget _buildTicketCard(TicketModel ticket) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TicketDetailPage(ticket: ticket)),
          );
          if (mounted) {
            _refreshData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'ticket-status-${ticket.id}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getStatusColor(ticket.repairStatus)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppTheme.getStatusText(ticket.repairStatus),
                        style: TextStyle(
                          color: AppTheme.getStatusColor(ticket.repairStatus),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ticket.createTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${ticket.deviceType} • ${ticket.faultType}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ticket.repairDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: Text(
                      ticket.campus,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 6),
                  Chip(
                    label: Text(
                      ticket.computerBrand,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
