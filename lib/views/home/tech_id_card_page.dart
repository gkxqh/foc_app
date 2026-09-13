import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/ticket_service.dart';
import '../common/count_up_text.dart';
import '../common/empty_state.dart';
import '../common/flip_card.dart';
import '../common/page_insets.dart';
import '../common/responsive_center.dart';

/// 技术员维修履历统计（证件背面展示），由工单数据实时计算。
/// [firstDate] 取最早完成工单的日期部分（'YYYY-MM-DD'）。
class TechRepairStats {
  final int doneCount;
  final String firstDate;

  const TechRepairStats({required this.doneCount, required this.firstDate});
}

/// 证件二维码载荷：纯文本身份信息，任何扫码器可读，与卡面比对即可核验。
/// 不用 focapp:// 深链——该 scheme 仅为桌面小组件的显式 intent 注册，
/// 扫码器无法拉起；也没有可落地的服务端验证网页。
@visibleForTesting
String techIdQrPayload(UserModel user) =>
    '云上飞扬技术员证\n'
    '工号 ${user.uid}\n'
    '姓名 ${user.nickname}\n'
    '校区 ${user.campus}';

/// 技术员证页：竖屏双面电子证件，深色拉丝金属 + 金色机甲风，
/// 全部装饰由 CustomPaint 绘制（不用位图底图），点击整卡 3D 翻转。
/// 维修履历实时统计自工单接口（不走年度总结的预计算接口），失败静默降级为寄语。
class TechIdCardPage extends StatefulWidget {
  const TechIdCardPage({super.key});

  @override
  State<TechIdCardPage> createState() => _TechIdCardPageState();
}

class _TechIdCardPageState extends State<TechIdCardPage> {
  TechRepairStats? _stats;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// 实时统计维修履历：不 await 不提示，失败/空数据保持 null（背面显示寄语）
  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final tickets = await TicketService().getTickets(tid: user.uid);
      final done =
          tickets.where((t) => t.repairStatus == 'Done').toList()
            ..sort((a, b) => a.createTime.compareTo(b.createTime));
      if (!mounted || done.isEmpty) return;
      setState(
        () => _stats = TechRepairStats(
          doneCount: done.length,
          firstDate: done.first.createTime.split(' ').first,
        ),
      );
    } catch (_) {
      // 静默降级：背面显示寄语，不打扰
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('技术员证')),
      body: user == null || !user.isTechnician
          ? const Center(
              child: EmptyState(
                icon: Icons.badge_outlined,
                title: '仅技术员可查看电子证件',
                subtitle: '请使用技术员账号登录后查看',
                minHeight: 220,
              ),
            )
          : SingleChildScrollView(
              padding: pageListPadding(context, extraBottom: AppSpacing.xl),
              child: ResponsiveCenter(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 0.615,
                      child: FlipCard(
                        front: TechIdCardFront(user: user),
                        back: TechIdCardBack(user: user, stats: _stats),
                        onFlip: (back) => setState(() => _showBack = back),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _showBack ? '轻触卡片翻回正面' : '轻触卡片查看背面',
                      style: AppText.captionSm.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// 卡面正反面：所有内容按卡宽 W / 卡高 H 的比例布局，证件为固定比例画布，
// 文字不随系统字号缩放（特大字号下仍保持版式不溢出）。
// ============================================================================

/// 卡面正面：徽章、俱乐部名、机甲头像框、姓名/校区信息栏与编号
class TechIdCardFront extends StatelessWidget {
  final UserModel user;

  const TechIdCardFront({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return MediaQuery.withNoTextScaling(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.modal),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _MetalPainter(seed: 7)),
                CustomPaint(painter: _FrontDecorPainter()),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _logoBadge(w),
                    SizedBox(height: h * 0.022),
                    Text(
                      '飞扬俱乐部',
                      style: TextStyle(
                        fontSize: w * 0.105,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: w * 0.105 * 0.12,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: h * 0.014),
                    _subtitle(w),
                    SizedBox(height: h * 0.050),
                    _avatarFrame(w, h),
                    SizedBox(height: h * 0.045),
                    _infoBar(w, h, '姓名', user.nickname),
                    SizedBox(height: h * 0.020),
                    _infoBar(w, h, '校区', user.campus),
                    SizedBox(height: h * 0.048),
                    Text(
                      'No.${user.uid}',
                      style: TextStyle(
                        fontSize: w * 0.042,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.rankGold,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _logoBadge(double w) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(w * 0.010),
        child: Image.asset(
          'assets/preview/fy_logo.png',
          width: w * 0.14,
          height: w * 0.14,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// 「技 术 员」两侧金色短横：内端实、外端渐隐
  Widget _subtitle(double w) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _goldDash(w, fadeAtLeft: true),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.030),
          child: Text(
            '技 术 员',
            style: TextStyle(
              fontSize: w * 0.048,
              fontWeight: FontWeight.w700,
              color: AppTheme.rankGold,
              letterSpacing: 2,
            ),
          ),
        ),
        _goldDash(w, fadeAtLeft: false),
      ],
    );
  }

  Widget _goldDash(double w, {required bool fadeAtLeft}) {
    return Container(
      width: w * 0.075,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          begin: fadeAtLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: fadeAtLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.transparent,
            AppTheme.rankGold,
          ],
        ),
      ),
    );
  }

  /// 机甲头像框：切角八边形深色板 + 白描边 + 两侧金色梯形侧翼，
  /// 框内为用户网络头像（加载中/失败回兜底插画）
  Widget _avatarFrame(double w, double h) {
    final frameW = w * 0.47;
    final frameH = h * 0.235;
    return SizedBox(
      width: frameW,
      height: frameH,
      child: CustomPaint(
        painter: _AvatarFramePainter(),
        child: Padding(
          // 两侧让出侧翼，四周让出描边
          padding: EdgeInsets.symmetric(
            horizontal: frameW * 0.10,
            vertical: frameH * 0.075,
          ),
          child: ClipPath(
            clipper: _OctagonClipper(),
            child: _avatarImage(),
          ),
        ),
      ),
    );
  }

  Widget _avatarImage() {
    final url = user.avatarUrl;
    final fallback = Image.asset(
      'assets/illustrations/fy_face.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
    if (url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  /// 信息栏：两端斜切面板（顶边全宽、底边内缩），label 白 70%、值白色更粗更大
  Widget _infoBar(double w, double h, String label, String value) {
    return SizedBox(
      width: w * 0.76,
      height: h * 0.072,
      child: CustomPaint(
        painter: _InfoBarPainter(),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.055),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: w * 0.030,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(width: w * 0.030),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: w * 0.037,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡面背面：竖排俱乐部名、身份二维码、维修履历与飞扬娘立绘
class TechIdCardBack extends StatelessWidget {
  final UserModel user;
  final TechRepairStats? stats;

  const TechIdCardBack({super.key, required this.user, this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return MediaQuery.withNoTextScaling(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.modal),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _MetalPainter(seed: 21)),
                CustomPaint(painter: _BackDecorPainter()),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: h * 0.045),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(w * 0.008),
                            child: Image.asset(
                              'assets/preview/fy_logo.png',
                              width: w * 0.125,
                              height: w * 0.125,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.014),
                        Text(
                          'FEIYANG CLUB',
                          style: TextStyle(
                            fontSize: w * 0.028,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.20,
                  top: h * 0.24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in '飞扬俱乐部'.split(''))
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: h * 0.007),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: w * 0.098,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: w * 0.475,
                  width: w * 0.44,
                  top: h * 0.185,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              // 白边即 QR 静区（quiet zone），需 ≥4 个模块宽，
                              // 过窄时微信/系统相机经常拒识
                              padding: EdgeInsets.all(w * 0.042),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.thumb + 2,
                                ),
                              ),
                              child: QrImageView(
                                // 内容用纯文本身份信息：App 的 focapp:// scheme
                                // 仅为桌面小组件的显式 intent 注册（无 manifest
                                // intent-filter），扫码器拉不起深链，服务端也
                                // 没有可落地的验证网页；纯文本任何扫码器可读，
                                // 与卡面工号/姓名/校区比对即可核验
                                data: techIdQrPayload(user),
                                version: QrVersions.auto,
                                errorCorrectionLevel: QrErrorCorrectLevel.Q,
                                size: w * 0.34,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                gapless: true,
                              ),
                            ),
                            SizedBox(height: h * 0.014),
                            Text(
                              '扫码识别技术员身份',
                              style: AppText.micro.copyWith(
                                fontSize: w * 0.026,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: h * 0.032),
                      _recordHeader(w, h),
                      SizedBox(height: h * 0.020),
                      if (stats != null) ...[
                        Text(
                          '初次接单',
                          style: TextStyle(
                            fontSize: w * 0.026,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          stats!.firstDate,
                          style: TextStyle(
                            fontSize: w * 0.036,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: h * 0.022),
                        Text(
                          '累计维修',
                          style: TextStyle(
                            fontSize: w * 0.026,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            CountUpText(
                              '${stats!.doneCount}',
                              style: AppText.titleLg.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.rankGold,
                                fontSize: w * 0.052,
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '台',
                              style: TextStyle(
                                fontSize: w * 0.030,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        // 无数据/加载失败：静默降级为寄语，不显示错误态
                        Text(
                          '轻装上阵，未来可期',
                          style: TextStyle(
                            fontSize: w * 0.030,
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 2,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: w * 0.05,
                  bottom: h * 0.035,
                  child: Image.asset(
                    'assets/illustrations/fy_q.png',
                    height: h * 0.10,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 「维修履历」标题：左侧金色竖条
  Widget _recordHeader(double w, double h) {
    return Row(
      children: [
        Container(width: 3.5, height: h * 0.030, color: AppTheme.rankGold),
        const SizedBox(width: 7),
        Text(
          '维修履历',
          style: TextStyle(
            fontSize: w * 0.034,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CustomPaint 装饰：拉丝金属底、齿轮、螺丝、像素块、六边形、电路走线。
// 全部程序化绘制，模拟纸质技术员证的机甲风。
// ============================================================================

/// 拉丝金属底：深灰对角渐变 + 固定种子的随机横向细线 + 径向暗角。
/// 同一种子输出稳定，翻转重绘不闪变。
class _MetalPainter extends CustomPainter {
  final int seed;

  const _MetalPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 深灰对角渐变底
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F3237), Color(0xFF191B1E), Color(0xFF26282D)],
        ).createShader(rect),
    );
    // 拉丝细线：固定种子的伪随机横线，明暗相间模拟金属拉丝
    final rng = Random(seed);
    final line = Paint()..strokeWidth = 1;
    for (var i = 0; i < 110; i++) {
      final y = rng.nextDouble() * size.height;
      final bright = rng.nextBool();
      final alpha = 0.015 + rng.nextDouble() * 0.05;
      line.color = bright
          ? Colors.white.withValues(alpha: alpha)
          : Colors.black.withValues(alpha: alpha);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    // 径向暗角：边缘压暗聚焦中心
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: size.longestSide * 0.75,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.42),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MetalPainter oldDelegate) => oldDelegate.seed != seed;
}

/// 正面装饰：左右半出血大齿轮、三处小齿轮、金色像素簇、小六边形、四角螺丝
class _FrontDecorPainter extends CustomPainter {
  const _FrontDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 半出血大齿轮：左灰白（挖空中孔）、右深灰
    _drawGear(
      canvas,
      Offset(w * -0.01, h * 0.30),
      w * 0.17,
      12,
      const Color(0xFFC9CDD3).withValues(alpha: 0.14),
      holeR: w * 0.045,
      punchHole: true,
    );
    _drawGear(
      canvas,
      Offset(w * 1.01, h * 0.66),
      w * 0.17,
      12,
      const Color(0xFF6A7078).withValues(alpha: 0.35),
      holeR: w * 0.045,
      punchHole: true,
    );
    // 小齿轮
    _drawGear(
      canvas,
      Offset(w * 0.925, h * 0.085),
      w * 0.050,
      8,
      Colors.white.withValues(alpha: 0.13),
      holeR: w * 0.014,
    );
    _drawGear(
      canvas,
      Offset(w * 0.045, h * 0.895),
      w * 0.046,
      8,
      Colors.white.withValues(alpha: 0.11),
      holeR: w * 0.013,
    );
    _drawGear(
      canvas,
      Offset(w * 0.955, h * 0.905),
      w * 0.038,
      8,
      const Color(0xFF6A7078).withValues(alpha: 0.40),
      holeR: w * 0.011,
    );
    // 金色像素方块簇
    _drawPixels(canvas, Offset(w * 0.060, h * 0.155), w * 0.017,
        const [(0, 0), (1, 0), (1, 1), (2, 1)], 0.75);
    _drawPixels(canvas, Offset(w * 0.885, h * 0.435), w * 0.015,
        const [(0, 0), (0, 1), (1, 1)], 0.60);
    _drawPixels(canvas, Offset(w * 0.075, h * 0.700), w * 0.016,
        const [(0, 0), (1, 0), (2, 0), (0, 1)], 0.65);
    // 金描边小六边形
    _drawHexagon(canvas, Offset(w * 0.875, h * 0.145), w * 0.028, 0.65);
    _drawHexagon(canvas, Offset(w * 0.085, h * 0.555), w * 0.022, 0.55);
    _drawHexagon(canvas, Offset(w * 0.895, h * 0.775), w * 0.025, 0.60);
    // 四角螺丝
    _drawScrew(canvas, Offset(w * 0.052, h * 0.032), w * 0.021);
    _drawScrew(canvas, Offset(w * 0.948, h * 0.032), w * 0.021);
    _drawScrew(canvas, Offset(w * 0.052, h * 0.968), w * 0.021);
    _drawScrew(canvas, Offset(w * 0.948, h * 0.968), w * 0.021);
  }

  @override
  bool shouldRepaint(_FrontDecorPainter oldDelegate) => false;
}

/// 背面装饰：左右对称电路走线（Manhattan 折线 + 节点圆点）+ 像素/六边形/螺丝
class _BackDecorPainter extends CustomPainter {
  const _BackDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final white = Colors.white;
    final gold = AppTheme.rankGold;
    // 左右对称的电路走线，分数坐标（x, y）
    const leftTraces = <(List<double>, double)>[
      ([
        0.012, 0.09, 0.044, 0.09, 0.044, 0.15, 0.024, 0.15,
      ], 0.20),
      ([0.012, 0.22, 0.036, 0.22, 0.036, 0.34], -1), // -1 表示金色
      ([0.044, 0.47, 0.044, 0.60, 0.012, 0.60], 0.16),
      ([0.024, 0.70, 0.024, 0.82, 0.052, 0.82], -1),
      ([0.012, 0.90, 0.044, 0.90, 0.044, 0.80], 0.14),
    ];
    for (final (xy, alpha) in leftTraces) {
      final color = alpha < 0
          ? gold.withValues(alpha: 0.55)
          : white.withValues(alpha: alpha);
      _drawTrace(canvas, size, xy, color, mirrorX: false);
    }
    const rightTraces = <(List<double>, double)>[
      ([0.988, 0.09, 0.956, 0.09, 0.956, 0.15, 0.976, 0.15], 0.20),
      ([0.988, 0.22, 0.964, 0.22, 0.964, 0.34], -1),
      ([0.956, 0.47, 0.956, 0.60, 0.988, 0.60], 0.16),
      ([0.976, 0.70, 0.976, 0.82, 0.948, 0.82], -1),
      ([0.988, 0.90, 0.956, 0.90, 0.956, 0.80], 0.14),
    ];
    for (final (xy, alpha) in rightTraces) {
      final color = alpha < 0
          ? gold.withValues(alpha: 0.55)
          : white.withValues(alpha: alpha);
      _drawTrace(canvas, size, xy, color, mirrorX: true);
    }
    // 像素块与六边形点缀
    _drawPixels(canvas, Offset(w * 0.285, 0.075 * size.height), w * 0.015,
        const [(0, 0), (1, 0), (1, 1)], 0.60);
    _drawPixels(canvas, Offset(w * 0.100, 0.75 * size.height), w * 0.014,
        const [(0, 0), (1, 0), (0, 1)], 0.55);
    _drawPixels(canvas, Offset(w * 0.585, 0.845 * size.height), w * 0.015,
        const [(0, 0), (1, 0), (0, 1), (2, 0)], 0.60);
    _drawHexagon(canvas, Offset(w * 0.335, 0.205 * size.height), w * 0.022, 0.55);
    _drawHexagon(canvas, Offset(w * 0.085, 0.085 * size.height), w * 0.020, 0.50);
    _drawHexagon(canvas, Offset(w * 0.420, 0.885 * size.height), w * 0.024, 0.60);
    // 四角螺丝
    _drawScrew(canvas, Offset(w * 0.052, 0.032 * size.height), w * 0.021);
    _drawScrew(canvas, Offset(w * 0.948, 0.032 * size.height), w * 0.021);
    _drawScrew(canvas, Offset(w * 0.052, 0.968 * size.height), w * 0.021);
    _drawScrew(canvas, Offset(w * 0.948, 0.968 * size.height), w * 0.021);
  }

  @override
  bool shouldRepaint(_BackDecorPainter oldDelegate) => false;
}

/// 齿轮：矩形齿 + 圆盘 + 中孔。[punchHole] 时经 saveLayer 隔离后用
/// BlendMode.clear 挖空（大齿轮半出血压在金属底上不能打穿背景）。
void _drawGear(
  Canvas canvas,
  Offset center,
  double radius,
  int teeth,
  Color color, {
  required double holeR,
  bool punchHole = false,
}) {
  final paint = Paint()..color = color;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  for (var i = 0; i < teeth; i++) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(radius * 0.88, 0),
        width: radius * 0.30,
        height: radius * 0.26,
      ),
      paint,
    );
    canvas.rotate(2 * pi / teeth);
  }
  canvas.restore();
  canvas.drawCircle(center, radius * 0.78, paint);
  if (punchHole) {
    canvas.saveLayer(
      Rect.fromCircle(center: center, radius: radius),
      Paint(),
    );
    canvas.drawCircle(center, holeR, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  } else {
    canvas.drawCircle(center, holeR, Paint()..color = const Color(0xFF1B1D20));
  }
}

/// 像素方块簇：[cells] 为 (列, 行) 网格坐标，块间留缝呈现像素颗粒感
void _drawPixels(
  Canvas canvas,
  Offset origin,
  double cell,
  List<(int, int)> cells,
  double alpha,
) {
  final paint = Paint()..color = AppTheme.rankGold.withValues(alpha: alpha);
  for (final (cx, cy) in cells) {
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + cx * cell,
        origin.dy + cy * cell,
        cell * 0.88,
        cell * 0.88,
      ),
      paint,
    );
  }
}

/// 六边形（尖顶朝上）：金色细描边
void _drawHexagon(Canvas canvas, Offset center, double r, double alpha) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = -pi / 2 + i * pi / 3;
    final p = Offset(
      center.dx + r * cos(angle),
      center.dy + r * sin(angle),
    );
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppTheme.rankGold.withValues(alpha: alpha),
  );
}

/// 螺丝：浅灰圆帽 + 内六角深孔 + 左上高光弧
void _drawScrew(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFD8DBDF), Color(0xFF9AA0A7)],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  canvas.drawPath(_hexPath(c, r * 0.5), Paint()..color = const Color(0xFF17191C));
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: r * 0.72),
    pi * 1.05,
    pi * 0.5,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5),
  );
}

/// 电路走线：折线点为分数坐标，每段直角连接，节点处补实心圆点
void _drawTrace(
  Canvas canvas,
  Size size,
  List<double> xy,
  Color color, {
  required bool mirrorX,
}) {
  Offset point(int i) => Offset(
    (mirrorX ? size.width - size.width * xy[i] : size.width * xy[i]),
    size.height * xy[i + 1],
  );
  final path = Path()..moveTo(point(0).dx, point(0).dy);
  for (var i = 2; i < xy.length; i += 2) {
    final p = point(i);
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square
      ..color = color,
  );
  for (var i = 0; i < xy.length; i += 2) {
    canvas.drawCircle(point(i), 2.6, Paint()..color = color);
  }
}

Path _hexPath(Offset center, double r) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = i * pi / 3;
    final p = Offset(
      center.dx + r * cos(angle),
      center.dy + r * sin(angle),
    );
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  return path;
}

/// 机甲头像框：两侧金色梯形侧翼 + 切角八边形深色板（白描边 2.5）
class _AvatarFramePainter extends CustomPainter {
  const _AvatarFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wingW = w * 0.075;
    final inset = 2.5;
    final panel = Rect.fromLTRB(
      wingW + inset,
      inset,
      w - wingW - inset,
      h - inset,
    );
    final cut = panel.shortestSide * 0.11;
    // 左右金色梯形侧翼（宽端贴面板、窄端朝外）
    final wingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppTheme.rankGold.withValues(alpha: 0.55),
          AppTheme.rankGold,
        ],
      ).createShader(panel);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.30)
        ..lineTo(wingW + 2, h * 0.16)
        ..lineTo(wingW + 2, h * 0.84)
        ..lineTo(0, h * 0.70)
        ..close(),
      wingPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h * 0.30)
        ..lineTo(w - wingW - 2, h * 0.16)
        ..lineTo(w - wingW - 2, h * 0.84)
        ..lineTo(w, h * 0.70)
        ..close(),
      wingPaint,
    );
    // 八边形深色板 + 白描边
    final panelPath = _octagonPath(panel, cut);
    canvas.drawPath(
      panelPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF24262B), Color(0xFF17191C)],
        ).createShader(panel),
    );
    canvas.drawPath(
      panelPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_AvatarFramePainter oldDelegate) => false;
}

/// 信息栏：两端斜切面板（顶边全宽、底边内缩）+ 深灰渐变 + 白描边 + 金色角块
class _InfoBarPainter extends CustomPainter {
  const _InfoBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cut = size.height * 0.55;
    final panel =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width - cut, size.height)
          ..lineTo(cut, size.height)
          ..close();
    canvas.drawPath(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF3B3F45), const Color(0xFF22242A)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    // 左上/右下金色角块（贴边平行四边形）
    final gold = Paint()..color = AppTheme.rankGold;
    final k = size.height * 0.16;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.16, 0)
        ..lineTo(size.width * 0.16 - k, k)
        ..lineTo(0, k)
        ..close(),
      gold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height)
        ..lineTo(size.width * 0.84, size.height)
        ..lineTo(size.width * 0.84 + k, size.height - k)
        ..lineTo(size.width, size.height - k)
        ..close(),
      gold,
    );
  }

  @override
  bool shouldRepaint(_InfoBarPainter oldDelegate) => false;
}

/// 切角八边形路径（头像框与内容裁剪共用形状）
Path _octagonPath(Rect r, double cut) => Path()
  ..moveTo(r.left + cut, r.top)
  ..lineTo(r.right - cut, r.top)
  ..lineTo(r.right, r.top + cut)
  ..lineTo(r.right, r.bottom - cut)
  ..lineTo(r.right - cut, r.bottom)
  ..lineTo(r.left + cut, r.bottom)
  ..lineTo(r.left, r.bottom - cut)
  ..lineTo(r.left, r.top + cut)
  ..close();

/// 头像内容按八边形裁剪（比外框描边略小）
class _OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) =>
      _octagonPath(Offset.zero & size, size.shortestSide * 0.12);

  @override
  bool shouldReclip(_OctagonClipper oldDelegate) => false;
}
