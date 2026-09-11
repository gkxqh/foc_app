import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('历史工单')),
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
            ? const Center(child: CircularProgressIndicator())
            : historyList.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Center(child: Text('暂无历史已结束工单', style: TextStyle(color: Colors.grey))),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: historyList.length,
                itemBuilder: (ctx, i) {
                  final ticket = historyList[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                        backgroundColor: AppTheme.getStatusColor(ticket.repairStatus).withValues(alpha: 0.15),
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
                        style: TextStyle(
                          color: AppTheme.getStatusColor(ticket.repairStatus),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
