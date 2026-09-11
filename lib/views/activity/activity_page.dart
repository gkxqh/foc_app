import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/event_service.dart';
import '../auth/login_page.dart';
import '../common/empty_state.dart';
import 'number_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final EventService _eventService = EventService();
  List<EventModel> _events = [];
  bool _isLoading = true;
  bool _wasLoggedIn = false;

  final List<String> _departmentList = ["维修部", "研发部", "行政部", "设计部", "流媒部"];
  final List<String> _freeTimeList = [
    '08:00-10:00',
    '10:00-12:00',
    '14:00-16:00',
    '16:00-18:00',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (isLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = isLoggedIn;
      if (isLoggedIn) {
        _fetchEvents();
      }
    }
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    final list = await _eventService.getEvents();
    if (mounted) {
      setState(() {
        _events = list;
        _isLoading = false;
      });
    }
  }

  void _promptLogin(String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请先登录'),
        content: Text('参与社团活动$action需要先登录账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('前往登录'),
          ),
        ],
      ),
    );
  }

  void _showSignUpDialog(EventModel event) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _promptLogin('报名');
      return;
    }

    showDialog<_SignUpResult>(
      context: context,
      builder: (ctx) => _SignUpDialog(
        eventTitle: event.title,
        departmentList: _departmentList,
        freeTimeList: _freeTimeList,
      ),
    ).then((result) async {
      if (result == null || !mounted) return;
      final ok = await _eventService.registerEvent(
        eventId: event.id,
        name: result.name,
        gender: result.gender,
        departments: result.departments,
        freeTimes: result.freeTimes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ok ? '报名成功！' : '报名失败，请稍后重试')));
      // 成功后重新拉取列表，让"已报名"状态与按钮可用性与服务端保持同步
      if (ok) {
        _fetchEvents();
      }
    });
  }

  void _checkLuckyNumber(EventModel event) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _promptLogin('查看抽奖号码');
      return;
    }
    final uid = auth.user?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('用户信息未加载完成，请稍后重试')));
      return;
    }

    final numModel = await _eventService.getLuckyNum(event.id, uid);
    if (!mounted) return;
    if (numModel != null && numModel.luckyNum.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NumberPage(
            luckyNum: numModel.luckyNum,
            isWinner: numModel.isWinner,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无您的抽奖号码或活动尚未开奖')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('社团活动'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新活动',
            onPressed: _fetchEvents,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchEvents,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: '近期暂无正在进行的招新或技术活动',
                      action: OutlinedButton.icon(
                        onPressed: _fetchEvents,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重新加载'),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _events.length,
                itemBuilder: (ctx, i) {
                  final event = _events[i];
                  final isSignUp = event.status == 1; // 报名进行中

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.poster != null && event.poster!.isNotEmpty)
                          Image.network(
                            event.poster!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (event.type != null &&
                                      event.type!.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        event.type!,
                                        style: const TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSignUp
                                          ? AppTheme.accentColor.withValues(
                                              alpha: 0.15,
                                            )
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      event.statusText,
                                      style: TextStyle(
                                        color: isSignUp
                                            ? AppTheme.accentColor
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                event.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (event.signupStartTime.isNotEmpty)
                                Text(
                                  '报名时间：${event.signupStartTime} ~ ${event.signupEndTime}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (event.isLucky)
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _checkLuckyNumber(event),
                                        icon: const Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 16,
                                        ),
                                        label: const Text('我的抽奖号'),
                                      ),
                                    ElevatedButton(
                                      onPressed: (isSignUp && !event.registered)
                                          ? () => _showSignUpDialog(event)
                                          : null,
                                      child: Text(
                                        event.registered ? '已报名' : '立即报名',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SignUpResult {
  final String name;
  final String gender;
  final List<String> departments;
  final List<String> freeTimes;

  const _SignUpResult({
    required this.name,
    required this.gender,
    required this.departments,
    required this.freeTimes,
  });
}

// 独立的报名弹窗组件：controller 由 State 持有并在 dispose 中释放，避免每次打开弹窗泄漏
class _SignUpDialog extends StatefulWidget {
  final String eventTitle;
  final List<String> departmentList;
  final List<String> freeTimeList;

  const _SignUpDialog({
    required this.eventTitle,
    required this.departmentList,
    required this.freeTimeList,
  });

  @override
  State<_SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<_SignUpDialog> {
  final _nameController = TextEditingController();
  String _gender = '男';
  final Set<String> _selectedDepts = {};
  final Set<String> _selectedTimes = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('报名：${widget.eventTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '真实姓名',
                hintText: '请输入姓名',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('性别：'),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '男', label: Text('男')),
                    ButtonSegment(value: '女', label: Text('女')),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (set) =>
                      setState(() => _gender = set.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '意向部门（可多选）：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Wrap(
              spacing: 6,
              children: widget.departmentList.map((dept) {
                final isChecked = _selectedDepts.contains(dept);
                return FilterChip(
                  label: Text(dept),
                  selected: isChecked,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedDepts.add(dept);
                      } else {
                        _selectedDepts.remove(dept);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              '空闲面试/值班时段（可多选）：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Wrap(
              spacing: 6,
              children: widget.freeTimeList.map((time) {
                final isChecked = _selectedTimes.contains(time);
                return FilterChip(
                  label: Text(time),
                  selected: isChecked,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTimes.add(time);
                      } else {
                        _selectedTimes.remove(time);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请填写姓名')));
              return;
            }
            if (_selectedDepts.isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请至少选择一个意向部门')));
              return;
            }
            Navigator.pop(
              context,
              _SignUpResult(
                name: name,
                gender: _gender,
                departments: _selectedDepts.toList(),
                freeTimes: _selectedTimes.toList(),
              ),
            );
          },
          child: const Text('确认报名'),
        ),
      ],
    );
  }
}
