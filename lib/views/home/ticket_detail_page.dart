import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ticket_model.dart';
import '../../providers/auth_provider.dart';
import 'give_order_page.dart';
import 'ticket_detail_view.dart';

/// 工单详情整页：标题栏（Hero 状态徽章 + 转单入口）+ [TicketDetailView] 内容体。
/// 宽屏双栏右栏直接嵌 [TicketDetailView]，不经过本页。
class TicketDetailPage extends StatefulWidget {
  final TicketModel ticket;

  const TicketDetailPage({super.key, required this.ticket});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  // 标题栏徽章/转单入口依赖最新状态；内容体状态变化经 onChanged 镜像过来
  late TicketModel _appBarTicket;

  @override
  void initState() {
    super.initState();
    _appBarTicket = widget.ticket;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTech = auth.isTechnician;
    final ticket = _appBarTicket;

    return Scaffold(
      appBar: AppBar(
        // 与首页工单卡状态徽章共享 Hero tag：转场时徽章从卡片飞到标题栏。
        // 两端 child 必须保持同构（同款徽章样式），否则样式突变会产生闪烁
        title: Hero(
          tag: 'ticket-status-${ticket.id}',
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.getStatusColor(ticket.repairStatus)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Text(
                AppTheme.getStatusText(ticket.repairStatus),
                style: AppText.caption.copyWith(
                  color: AppTheme.getStatusColor(ticket.repairStatus),
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
              !ticket.isFinished &&
              (ticket.transcode?.isNotEmpty ?? false))
            IconButton(
              icon: const Icon(Icons.qr_code_rounded),
              tooltip: '生成转单凭证',
              onPressed: () {
                final transcode = '${ticket.id}${ticket.transcode}';
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
      body: TicketDetailView(
        ticket: widget.ticket,
        onChanged: (next) {
          if (next.repairStatus != _appBarTicket.repairStatus ||
              next.completeImageUrl != _appBarTicket.completeImageUrl) {
            setState(() => _appBarTicket = next);
          }
        },
      ),
    );
  }
}
