import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/window_class.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/empty_state.dart';
import '../common/page_insets.dart';
import '../common/responsive_center.dart';
import '../common/skeleton_list.dart';
import '../common/staggered_in.dart';
import '../home/ticket_detail_page.dart';
import '../home/ticket_detail_view.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // 宽屏双栏右栏当前展示的工单 id；展示时从最新列表解析
  String? _selectedTicketId;

  @override
  void initState() {
    super.initState();
    // 进入页面时主动拉取一次，避免只展示 Provider 中的残留数据
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  void _fetch() {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      context.read<TicketProvider>().fetchTickets(
        role: auth.user!.role,
        uid: auth.user!.uid,
      );
    }
  }

  TicketModel? _selectedTicketOf(TicketProvider tp) {
    final id = _selectedTicketId;
    if (id == null) return null;
    for (final t in tp.historyTickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ticketProvider = context.watch<TicketProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('历史工单')),
      // 不包 SafeArea：列表尾部的底部 inset 统一由 pageListPadding 消费
      // （此前 SafeArea 与 pageListPadding 叠加导致底部双重补白）
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.user != null) {
            await ticketProvider.fetchTickets(
              role: auth.user!.role,
              uid: auth.user!.uid,
            );
          }
        },
        child: useTwoPane(context)
            ? _buildTwoPane(ticketProvider)
            : _buildListBody(ticketProvider),
      ),
    );
  }

  /// 宽屏（≥720dp）列表-详情双栏：左栏列表，右栏选中工单详情
  Widget _buildTwoPane(TicketProvider ticketProvider) {
    final selected = _selectedTicketOf(ticketProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final leftWidth = screenWidth >= 840 ? 360.0 : 300.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: leftWidth,
          child: _buildListBody(
            ticketProvider,
            selectOnly: true,
            selectedId: _selectedTicketId,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: selected == null
              ? const Center(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '选择工单查看详情',
                    subtitle: '在左侧选择一条历史工单',
                    minHeight: 200,
                  ),
                )
              : ResponsiveCenter(
                  child: TicketDetailView(
                    key: ValueKey(
                      Object.hash(
                        selected.id,
                        selected.repairStatus,
                        selected.completeImageUrl,
                      ),
                    ),
                    ticket: selected,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildListBody(
    TicketProvider ticketProvider, {
    bool selectOnly = false,
    String? selectedId,
  }) {
    final historyList = ticketProvider.historyTickets;
    final loadError = ticketProvider.lastError;

    return ticketProvider.isLoading && historyList.isEmpty
        ? const SkeletonList()
        : historyList.isEmpty && loadError != null
        ? ListView(
            padding: pageListPadding(context),
            children: [
              const SizedBox(height: 80),
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: loadError,
                minHeight: 240,
                action: OutlinedButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新加载'),
                ),
              ),
            ],
          )
        : historyList.isEmpty
        ? ListView(
            padding: pageListPadding(context),
            children: const [
              SizedBox(height: 80),
              EmptyState(
                icon: Icons.history_toggle_off_rounded,
                image: 'assets/illustrations/fy_q.png',
                title: '暂无历史已结束工单',
                minHeight: 220,
              ),
            ],
          )
        : ResponsiveCenter(
            child: ListView.builder(
              padding: pageListPadding(context),
              itemCount: historyList.length,
              itemBuilder: (ctx, i) {
                final ticket = historyList[i];
                final selected = ticket.id == selectedId;
                return StaggeredIn(
                  index: i,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    // 双栏模式下选中项高亮描边，标示右栏当前内容
                    color: selected
                        ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                        : null,
                    shape: selected
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            side: BorderSide(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          )
                        : null,
                    child: ListTile(
                      onTap: () {
                        // 宽屏双栏：点条目就地选中，不再整页 push
                        if (selectOnly) {
                          setState(() => _selectedTicketId = ticket.id);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TicketDetailPage(ticket: ticket),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.getStatusColor(
                          ticket.repairStatus,
                        ).withValues(alpha: 0.15),
                        child: Icon(
                          ticket.repairStatus == 'Done'
                              ? Icons.check
                              : ticket.repairStatus == 'Canceled'
                              ? Icons.cancel_outlined
                              : Icons.close,
                          color: AppTheme.getStatusColor(ticket.repairStatus),
                          size: 20,
                        ),
                      ),
                      title: Text('${ticket.deviceType} • ${ticket.faultType}'),
                      subtitle: Text('${ticket.campus} | ${ticket.createTime}'),
                      trailing: Text(
                        AppTheme.getStatusText(ticket.repairStatus),
                        style: AppText.captionSm.copyWith(
                          color: AppTheme.getStatusColor(ticket.repairStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
  }
}
