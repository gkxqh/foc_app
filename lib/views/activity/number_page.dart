import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NumberPage extends StatelessWidget {
  final String luckyNum;
  final bool isWinner;

  const NumberPage({super.key, required this.luckyNum, required this.isWinner});

  @override
  Widget build(BuildContext context) {
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
                  color: isWinner ? Colors.amber.shade100 : Colors.blue.shade50,
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
                        color: isWinner
                            ? Colors.amber.shade900
                            : AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      luckyNum,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: isWinner
                            ? Colors.amber.shade900
                            : AppTheme.primaryBlue,
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
