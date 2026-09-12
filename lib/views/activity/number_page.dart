import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../common/count_up_text.dart';
import '../common/pop_in.dart';

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
              : AppTheme.primaryBlue.withValues(alpha: 0.08));
    final Color numberColor = isWinner
        ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
        : AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(title: const Text('我的抽奖号码')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 庆祝卡弹跳入场；中奖时更高一点的初始缩放放大惊喜感
              PopIn(
                fromScale: isWinner ? 0.5 : 0.8,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.modal),
                    border: Border.all(
                      color: isWinner ? Colors.amber : AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isWinner
                                ? Icons.emoji_events_rounded
                                : Icons.confirmation_number_rounded,
                            color: numberColor,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              isWinner ? '恭喜中奖！' : '您的活动专属幸运号码',
                              style: AppText.title.copyWith(color: numberColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      CountUpText(
                        luckyNum,
                        style: AppText.displayNumber.copyWith(
                          letterSpacing: 4,
                          color: numberColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        isWinner
                            ? '请凭此号码前往飞扬俱乐部摊位或活动负责人处领奖！'
                            : '活动现场将根据该号码进行互动与抽奖，请妥善保存！',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
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
