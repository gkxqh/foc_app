import 'package:flutter/material.dart';

import '../common/responsive_center.dart';

import '../../core/theme/app_theme.dart';
import '../../models/tech_stats_model.dart';
import '../../services/config_service.dart';
import '../common/count_up_text.dart';
import '../common/empty_state.dart';
import '../common/page_insets.dart';
import '../common/skeleton_list.dart';

class AnnualSummaryPage extends StatefulWidget {
  const AnnualSummaryPage({super.key});

  @override
  State<AnnualSummaryPage> createState() => _AnnualSummaryPageState();
}

class _AnnualSummaryPageState extends State<AnnualSummaryPage> {
  final ConfigService _configService = ConfigService();
  TechSummaryModel? _summary;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final sum = await _configService.getTechSum();
      if (!mounted) return;
      setState(() {
        _summary = sum;
        _isLoading = false;
      });
    } catch (_) {
      // 加载失败需明确提示并可重试，不能以“0 台/暂无记录”伪装成空数据
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('技术员年度总结')),
      body: _isLoading
          // 与其他页面统一：加载占位用统计卡骨架屏而非全屏转圈
          ? Padding(
              padding: pageListPadding(context, horizontal: 20, top: 20),
              child: const SkeletonList(
                variant: SkeletonVariant.stats,
                itemCount: 1,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
              ),
            )
          : _loadFailed
          ? Center(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: '年度总结加载失败，请检查网络后重试',
                action: OutlinedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新加载'),
                ),
              ),
            )
          : ResponsiveCenter(
              child: SingleChildScrollView(
                padding: pageListPadding(context, horizontal: 20, top: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxxl,
                        horizontal: AppSpacing.xl,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.modal),
                        boxShadow: AppShadow.glow(AppTheme.primaryBlue),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '年度维修总台数',
                            style: AppText.body.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          CountUpText(
                            _summary?.totalOrders ?? '0',
                            style: AppText.displayNumber.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '感谢你为川大师生排忧解难！',
                            style: AppText.caption.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
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
            ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              title,
              style: AppText.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: AppText.body.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
