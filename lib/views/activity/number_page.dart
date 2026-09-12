import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NumberPage extends StatelessWidget {
  final String luckyNum;
  final bool isWinner;

  const NumberPage({super.key, required this.luckyNum, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 深浅主题分别取配色：浅色保持原有柔和底色，深色改用半透明叠加，
    // 避免亮色底块刺眼、深色文字（amber.shade900）在暗背景上看不清
    final Color cardBg = isWinner
        ? (isDark
              ? Colors.amber.withValues(alpha: 0.16)
              : Colors.amber.shade100)
        : (isDark
              ? AppTheme.primaryBlue.withValues(alpha: 0.14)
              : Colors.blue.shade50);
    final Color numberColor = isWinner
        ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
        : AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(title: const Text('我的抽奖号码')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWinner ? Colors.amber : AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isWinner ? '🎉 恭喜中奖！' : '🎟️ 您的活动专属幸运号码',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: numberColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      luckyNum,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: numberColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isWinner
                          ? '请凭此号码前往飞扬俱乐部摊位或活动负责人处领奖！'
                          : '活动现场将根据该号码进行互动与抽奖，请妥善保存！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回活动列表'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
