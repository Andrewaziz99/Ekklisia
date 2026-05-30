import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../core/router/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _crossCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _glowCtrl;

  late final Animation<double> _crossScale;
  late final Animation<double> _crossFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    // Cross entrance
    _crossCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _crossScale = CurvedAnimation(
      parent: _crossCtrl,
      curve: Curves.elasticOut,
    );
    _crossFade = CurvedAnimation(
      parent: _crossCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    // Text entrance
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFade = CurvedAnimation(
      parent: _textCtrl,
      curve: Curves.easeIn,
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textCtrl,
      curve: Curves.easeOutCubic,
    ));

    // Ambient glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _crossCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _textCtrl.forward();
    // Stay for a moment then navigate
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) context.go(Routes.home);
  }

  @override
  void dispose() {
    _crossCtrl.dispose();
    _textCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = theme.primaryColor;
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      body: Stack(
        children: [
          // ── Background image (very subtle) ───────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/Ekklisia_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),

          // ── Deep gradient overlay ────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: BrightnessColors.splashGradient(brightness),
              ),
            ),
          ),

          // ── Gold corner ornaments ─────────────────────────────────────
          ..._buildCornerOrnaments(),

          // ── Ambient glow behind cross ─────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _glowOpacity,
              builder: (_, __) => Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gold
                          .withOpacity(_glowOpacity.value * 0.15),
                      blurRadius: 80,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coptic Cross
                ScaleTransition(
                  scale: _crossScale,
                  child: FadeTransition(
                    opacity: _crossFade,
                    child: const _CopticCross(),
                  ),
                ),

                const SizedBox(height: 36),

                // App name
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: const _AppTitle(),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom ornamental band ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: const _BottomBand(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerOrnaments() {
    final brightness = Theme.of(context).brightness;
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    final style = TextStyle(
      color: goldDim,
      fontSize: 18,
      height: 1,
    );
    final ornament = Text('❖', style: style);

    return [
      Positioned(top: 24, left: 24, child: ornament),
      Positioned(top: 24, right: 24, child: ornament),
      Positioned(bottom: 60, left: 24, child: ornament),
      Positioned(bottom: 60, right: 24, child: ornament),
      // Horizontal rules
      Positioned(
        top: 36,
        left: 52,
        right: 52,
        child: Container(height: 0.5, color: goldBorder),
      ),
      Positioned(
        bottom: 72,
        left: 52,
        right: 52,
        child: Container(height: 0.5, color: goldBorder),
      ),
    ];
  }
}

// ── Coptic Cross SVG-style using Flutter Canvas ───────────────────────────────

class _CopticCross extends StatelessWidget {
  const _CopticCross();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = Theme.of(context).primaryColor;
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: goldBorder, width: 1),
        color: bgDeep.withOpacity(0.6),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _CopticCrossPainter(gold: gold, goldBorder: goldBorder),
      ),
    );
  }
}

class _CopticCrossPainter extends CustomPainter {
  _CopticCrossPainter({required this.gold, required this.goldBorder});

  final Color gold;
  final Color goldBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const arm = 30.0;
    const dot = 5.0;

    // Vertical bar
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), paint);
    // Horizontal bar
    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), paint);

    // Small dots at the 4 ends (Coptic cross style)
    final dotPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.fill;

    for (final p in [
      Offset(cx, cy - arm),
      Offset(cx, cy + arm),
      Offset(cx - arm, cy),
      Offset(cx + arm, cy),
    ]) {
      canvas.drawCircle(p, dot / 2, dotPaint);
    }

    // Centre circle
    canvas.drawCircle(Offset(cx, cy), 5, dotPaint);
    canvas.drawCircle(
      Offset(cx, cy),
      10,
      Paint()
        ..color = goldBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── App Title ─────────────────────────────────────────────────────────────────

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Column(
      children: [
        // Coptic ornament line
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 0.5, color: goldDim),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('✦',
                  style: TextStyle(
                      color: goldDim, fontSize: 10)),
            ),
            Container(width: 40, height: 0.5, color: goldDim),
          ],
        ),
        const SizedBox(height: 14),

        // App name in Arabic
        Text(
          'إكليسيا',
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: goldLight,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            height: 1.1,
          ),
        ),

        const SizedBox(height: 4),

        // Latin subtitle
        Text(
          'E K K L I C I A',
          style: TextStyle(
            color: goldDim,
            fontSize: 11,
            letterSpacing: 6,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 8),

        // Tagline
        Text(
          'المكتبة القبطية الأرثوذكسية',
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: textSecondary,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Bottom Band ───────────────────────────────────────────────────────────────

class _BottomBand extends StatelessWidget {
  const _BottomBand();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [bgDeep, Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Text(
            '✦  ✦  ✦',
            style: TextStyle(
              color: goldDim,
              fontSize: 10,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الكنيسة القبطية الأرثوذكسية',
            style: TextStyle(
              fontFamily: 'Scheherazade',
              color: textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}