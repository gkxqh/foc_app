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
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = info.version);
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于云上飞扬')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
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
                child: const Icon(Icons.flight_takeoff_rounded, size: 50, color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '云上飞扬 (Feiyang on Cloud)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _version.isEmpty ? 'Flutter 跨平台版' : '版本 $_version (Flutter 跨平台版)',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '“云上飞扬”是四川大学飞扬俱乐部研发部打造的校园个人设备一体化服务平台。其前身为“小川电脑管家”。\n\n全新 Flutter 跨平台 App 拥有更流畅的原生性能，支持设备报修、技术员派单转单接单、社团活动与现场互动抽奖等功能。',
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'Powered By 四川大学飞扬俱乐部研发部',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
