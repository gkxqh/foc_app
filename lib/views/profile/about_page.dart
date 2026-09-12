import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  // 用 try/catch 而非 catchError：catchError 回调返回 null 会让
  // Future<PackageInfo> 以 null 完成，触发非空类型断言错误
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = info.version);
      }
    } catch (_) {
      // 读取失败保持空串，界面展示兜底文案
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于云上飞扬')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('云上飞扬 (Feiyang on Cloud)', style: AppText.titleXl),
              const SizedBox(height: 6),
              Text(
                _version.isEmpty ? 'Flutter 跨平台版' : '版本 $_version ',
                style: AppText.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    '“云上飞扬”是四川大学飞扬俱乐部研发部打造的校园个人设备一体化服务平台。其前身为“小川电脑管家”。',
                    style: AppText.body.copyWith(height: 1.6),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Powered By 四川大学飞扬俱乐部研发部 ｜ 刻御晴空',
                style: AppText.captionSm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
