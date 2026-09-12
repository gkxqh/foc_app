import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 英雄榜排名徽章：金/银/铜分级配色替代 emoji 奖牌（各平台渲染不一致）。
/// 配色取自 AppTheme 的榜单 token，与首页领奖台色柱共用一套。
class RankBadge extends StatelessWidget {
  final int rank;
  final double size;

  const RankBadge({super.key, required this.rank, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final (Color color, Color textColor) = switch (rank) {
      1 => (AppTheme.rankGold, Colors.white),
      2 => (AppTheme.rankSilver, Colors.white),
      3 => (AppTheme.rankBronze, Colors.white),
      // 3 名以外的兜底：中性灰（与"已取消"状态色一致）
      _ => (AppTheme.statusCanceled, Colors.white),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
