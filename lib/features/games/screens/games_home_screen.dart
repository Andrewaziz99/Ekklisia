// lib/features/games/screens/games_home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Games lobby — lets the user choose between "Guess Who" and "MCQ" games.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../data/models/game_model.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../features/settings/cubit/settings_cubit.dart';
import '../../../services/settings_service.dart';
import '../cubit/game_cubit.dart';
import 'game_screen_base.dart';
import 'guess_who_game_screen.dart';
import 'mcq_game_screen.dart';

class GamesHomeScreen extends StatelessWidget {
  const GamesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F0E8)
          : BrightnessColors.bgDeep(brightness),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: kGameNavy,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 15),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGreek ? 'Παιχνίδια' : 'الألعاب',
                            style: TextStyle(
                              fontFamily: isGreek ? null : 'Scheherazade',
                              color: kGameGold,
                              fontSize: isGreek ? 22 : 26,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            isGreek
                                ? 'Δοκίμασε τις γνώσεις σου'
                                : 'اختبر معلوماتك',
                            style: TextStyle(
                              fontFamily: isGreek ? null : 'Scheherazade',
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: isGreek ? 11 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Decorative cross
                    Text('✦',
                        style: TextStyle(
                          color: kGameGold.withValues(alpha: 0.4),
                          fontSize: 24,
                        )),
                  ],
                ),
              ),
            ),
          ),

          // ── Game type cards ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(
                children: [
                  // Subtitle
                  Text(
                    isGreek
                        ? 'Επίλεξε κατηγορία παιχνιδιού:'
                        : 'اختر نوع اللعبة:',
                    textDirection:
                        isGreek ? TextDirection.ltr : TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: brightness == Brightness.light
                          ? const Color(0xFF6B7280)
                          : BrightnessColors.textSecondary(brightness),
                      fontSize: isGreek ? 12 : 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Guess Who card
                  _GameTypeCard(
                    titleAr: 'من هو؟',
                    titleEl: 'Ποιος είναι;',
                    subtitleAr: 'تعرّف على شخصيات الكنيسة من صورهم',
                    subtitleEl: 'Αναγνώρισε εκκλησιαστικά πρόσωπα',
                    icon: Icons.face_retouching_natural_outlined,
                    accentColor: const Color(0xFF3A6B4A),
                    isGreek: isGreek,
                    onTap: () => _launchGame(context, GameType.guessWho, isGreek),
                  ),

                  const SizedBox(height: 16),

                  // MCQ card
                  _GameTypeCard(
                    titleAr: 'اختبار',
                    titleEl: 'Κουίζ',
                    subtitleAr: 'أسئلة اختيار من متعدد عن الإيمان',
                    subtitleEl: 'Ερωτήσεις πολλαπλής επιλογής',
                    icon: Icons.quiz_outlined,
                    accentColor: const Color(0xFF5B3A9B),
                    isGreek: isGreek,
                    onTap: () => _launchGame(context, GameType.mcq, isGreek),
                  ),

                  const SizedBox(height: 32),

                  // Decorative divider
                  Row(children: [
                    Expanded(
                      child: Divider(
                        color: kGameGold.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '✦',
                        style: TextStyle(
                          color: kGameGold.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: kGameGold.withValues(alpha: 0.2),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchGame(
      BuildContext context, GameType type, bool isGreek) {
    final Widget screen = type == GameType.guessWho
        ? BlocProvider(
            create: (_) => GameCubit(sl<GameRepository>()),
            child: GuessWhoGameScreen(isGreek: isGreek),
          )
        : BlocProvider(
            create: (_) => GameCubit(sl<GameRepository>()),
            child: McqGameScreen(isGreek: isGreek),
          );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

// ── Game Type Card ────────────────────────────────────────────────────────────

class _GameTypeCard extends StatelessWidget {
  const _GameTypeCard({
    required this.titleAr,
    required this.titleEl,
    required this.subtitleAr,
    required this.subtitleEl,
    required this.icon,
    required this.accentColor,
    required this.isGreek,
    required this.onTap,
  });

  final String       titleAr;
  final String       titleEl;
  final String       subtitleAr;
  final String       subtitleEl;
  final IconData     icon;
  final Color        accentColor;
  final bool         isGreek;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = brightness == Brightness.light
        ? Colors.white
        : BrightnessColors.bgMid(brightness);
    final textPrimary = brightness == Brightness.light
        ? const Color(0xFF1B2A4A)
        : BrightnessColors.textPrimary(brightness);
    final textSub = brightness == Brightness.light
        ? const Color(0xFF6B7280)
        : BrightnessColors.textSecondary(brightness);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 32),
            ),
            const SizedBox(width: 18),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGreek ? titleEl : titleAr,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: textPrimary,
                      fontSize: isGreek ? 18 : 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGreek ? subtitleEl : subtitleAr,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: textSub,
                      fontSize: isGreek ? 11 : 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accentColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
