import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/empty_state.dart';
import '../common/page_insets.dart';
import '../common/skeleton_list.dart';
import '../common/staggered_in.dart';
import '../home/ticket_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ticketProvider = context.watch<TicketProvider>();

    final historyList = ticketProvider.historyTickets;
    final loadError = ticketProvider.lastError;

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
        child: ticketProvider.isLoading && historyList.isEmpty
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
            : ListView.builder(
                padding: pageListPadding(context),
                itemCount: historyList.length,
                itemBuilder: (ctx, i) {
                  final ticket = historyList[i];
                  return StaggeredIn(
                    index: i,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ListTile(
                        onTap: () {
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
                        title: Text(
                          '${ticket.deviceType} • ${ticket.faultType}',
                        ),
                        subtitle: Text(
                          '${ticket.campus} | ${ticket.createTime}',
                        ),
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
      ),
    );
  }
}
