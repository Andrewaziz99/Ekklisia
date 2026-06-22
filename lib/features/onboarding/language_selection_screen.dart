// lib/features/onboarding/language_selection_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// First-launch language selection screen.
// Shown once after the splash animation. Saves the choice and navigates to
// the home screen. Supports Arabic (RTL) and Greek (LTR).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/brightness_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {
  AppLanguage? _selected;
  bool _isAnimatingOut = false;

  late final AnimationController _enterCtrl;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _enterFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeIn,
    );
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selected == null || _isAnimatingOut) return;
    setState(() => _isAnimatingOut = true);

    await context
        .read<SettingsCubit>()
        .completeLanguageSelection(_selected!);

    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      body: Stack(
        children: [
          // ── Background texture ────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/Ekklisia_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.25),
            ),
          ),
          // ── Gradient overlay ──────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: BrightnessColors.splashGradient(brightness),
              ),
            ),
          ),
          // ── Corner ornaments ──────────────────────────────────────────
          ..._cornerOrnaments(goldDim, goldBorder),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _enterFade,
              child: SlideTransition(
                position: _enterSlide,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // App logo
                      const AppLogo(size: 90, contained: true),
                      const SizedBox(height: 24),

                      // Heading (Arabic + Greek together)
                      Text(
                        'اختر اللغة',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: goldLight,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Επιλέξτε γλώσσα',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 8),
                      // Ornamental divider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 40, height: 0.5, color: goldDim),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('✦',
                                style: TextStyle(
                                    color: goldDim, fontSize: 8)),
                          ),
                          Container(width: 40, height: 0.5, color: goldDim),
                        ],
                      ),

                      const Spacer(flex: 1),

                      // Language cards
                      _LanguageCard(
                        language: AppLanguage.arabic,
                        isSelected: _selected == AppLanguage.arabic,
                        onTap: () =>
                            setState(() => _selected = AppLanguage.arabic),
                      ),
                      const SizedBox(height: 14),
                      _LanguageCard(
                        language: AppLanguage.greek,
                        isSelected: _selected == AppLanguage.greek,
                        onTap: () =>
                            setState(() => _selected = AppLanguage.greek),
                      ),

                      const Spacer(flex: 2),

                      // Confirm button
                      AnimatedOpacity(
                        opacity: _selected != null ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 250),
                        child: GestureDetector(
                          onTap: _selected != null ? _confirm : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _selected != null
                                    ? [
                                        const Color(0xFFC8A84B),
                                        const Color(0xFF8B6914),
                                      ]
                                    : [
                                        const Color(0xFF4A3D1A),
                                        const Color(0xFF4A3D1A),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: goldBorder, width: 0.5),
                              boxShadow: _selected != null
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFC8A84B)
                                            .withOpacity(0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'متابعة  /  Συνέχεια',
                                  style: TextStyle(
                                    color: _selected != null
                                        ? const Color(0xFF0D1B2A)
                                        : goldDim,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cornerOrnaments(Color goldDim, Color goldBorder) {
    final style = TextStyle(color: goldDim, fontSize: 16, height: 1);
    final o = Text('❖', style: style);
    return [
      Positioned(top: 24, left: 24, child: o),
      Positioned(top: 24, right: 24, child: o),
      Positioned(bottom: 48, left: 24, child: o),
      Positioned(bottom: 48, right: 24, child: o),
      Positioned(
        top: 36, left: 50, right: 50,
        child: Container(height: 0.5, color: goldBorder),
      ),
      Positioned(
        bottom: 60, left: 50, right: 50,
        child: Container(height: 0.5, color: goldBorder),
      ),
    ];
  }
}

// ── Language Card ─────────────────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;

    final isArabic = language == AppLanguage.arabic;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? gold.withOpacity(0.08)
              : bgMid,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? gold : goldBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gold.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          // Force LTR layout so both cards are always: [flag] [text] [indicator]
          // regardless of the device locale. Individual Text widgets keep their
          // own textDirection for correct character rendering.
          textDirection: TextDirection.ltr,
          children: [
            // Flag / symbol
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? gold.withOpacity(0.15)
                    : bgElevated,
                border: Border.all(
                  color: isSelected ? gold : goldBorder,
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  language.flagEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Text — sits naturally beside the flag (no Expanded stretch)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  language.label,
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Scheherazade' : 'GFSDidot',
                    color: isSelected ? goldLight : textSecondary,
                    fontSize: isArabic ? 22 : 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic ? 'Arabic / العربية' : 'Greek / Ελληνικά',
                  style: TextStyle(
                    color: textSecondary.withOpacity(0.6),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // Push selection indicator to the far right
            const Spacer(),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? gold : Colors.transparent,
                border: Border.all(
                  color: isSelected ? gold : goldBorder,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 13,
                        color: Color(0xFF0D1B2A),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
