import 'package:flutter/material.dart';

/// 英雄榜排名徽章：金/银/铜分级配色替代 emoji 奖牌（各平台渲染不一致）。
class RankBadge extends StatelessWidget {
  final int rank;
  final double size;

  const RankBadge({super.key, required this.rank, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final (Color color, Color textColor) = switch (rank) {
      1 => (const Color(0xFFF5B301), Colors.white),
      2 => (const Color(0xFF9EA7B3), Colors.white),
      3 => (const Color(0xFFB07A4B), Colors.white),
      _ => (Colors.grey.shade400, Colors.white),
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
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
