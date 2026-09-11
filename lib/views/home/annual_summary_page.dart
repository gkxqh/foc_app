import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/tech_stats_model.dart';
import '../../services/config_service.dart';

class AnnualSummaryPage extends StatefulWidget {
  const AnnualSummaryPage({super.key});

  @override
  State<AnnualSummaryPage> createState() => _AnnualSummaryPageState();
}

class _AnnualSummaryPageState extends State<AnnualSummaryPage> {
  final ConfigService _configService = ConfigService();
  TechSummaryModel? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    TechSummaryModel? sum;
    try {
      sum = await _configService.getTechSum();
    } catch (_) {
      // 拉取失败时以空总结兜底，避免页面卡死在加载态
    }
    if (mounted) {
      setState(() {
        _summary = sum ?? TechSummaryModel();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('技术员年度总结')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '年度维修总台数',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _summary?.totalOrders ?? '0',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '感谢你为川大师生排忧解难！',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildStatTile(
                            icon: Icons.access_time_rounded,
                            title: '初次接单时间',
                            value: _summary?.firstTime.isEmpty ?? true
                                ? '暂无记录'
                                : _summary!.firstTime,
                          ),
                          const Divider(),
                          _buildStatTile(
                            icon: Icons.history_toggle_off_rounded,
                            title: '最近接单时间',
                            value: _summary?.lastTime.isEmpty ?? true
                                ? '暂无记录'
                                : _summary!.lastTime,
                          ),
                          const Divider(),
                          _buildStatTile(
                            icon: Icons.timer_outlined,
                            title: '累计维修总时长',
                            value: _summary?.totalTime.isEmpty ?? true
                                ? '暂无记录'
                                : _summary!.totalTime,
                          ),
                          const Divider(),
                          _buildStatTile(
                            icon: Icons.bolt_rounded,
                            title: '最短单台耗时',
                            value: _summary?.shortestTime.isEmpty ?? true
                                ? '暂无记录'
                                : _summary!.shortestTime,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
