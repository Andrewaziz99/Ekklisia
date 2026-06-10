// lib/features/games/screens/game_screen_base.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets used by both GuessWhoGameScreen and McqGameScreen.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/theme/brightness_colors.dart';

const kGameNavy    = Color(0xFF1B2A4A);
const kGameGold    = Color(0xFFC9A84C);
const kGameCrimson = Color(0xFF6B1A1A);
const kGameGreen   = Color(0xFF2E7D52);
const kGameRed     = Color(0xFF8C2B2B);

// ── GameHeader ────────────────────────────────────────────────────────────────

class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.titleAr,
    required this.titleEl,
    required this.currentIndex,
    required this.total,
    required this.score,
    required this.isGreek,
  });

  final String titleAr;
  final String titleEl;
  final int    currentIndex;
  final int    total;
  final int    score;
  final bool   isGreek;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (currentIndex + 1) / total : 0.0;

    return Container(
      color: kGameNavy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
              child: Row(
                children: [
                  // Back
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white, size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Text(
                      isGreek ? titleEl : titleAr,
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: kGameGold,
                        fontSize: isGreek ? 16 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kGameGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: kGameGold.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: kGameGold, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$score',
                          style: const TextStyle(
                            color: kGameGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar + counter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.12),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(kGameGold),
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${currentIndex + 1} / $total',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ChoiceButton ──────────────────────────────────────────────────────────────

class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.text,
    required this.index,
    required this.correctIndex,
    required this.selectedIndex,
    required this.isGreek,
    required this.onTap,
  });

  final String        text;
  final int           index;
  final int           correctIndex;
  final int?          selectedIndex;
  final bool          isGreek;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final isAnswered  = selectedIndex != null;
    final isSelected  = selectedIndex == index;
    final isCorrectAns = index == correctIndex;

    late Color bgColor;
    late Color borderColor;
    late Color textColor;
    IconData? trailingIcon;

    if (!isAnswered) {
      bgColor = brightness == Brightness.light
          ? Colors.white
          : BrightnessColors.bgMid(brightness);
      borderColor = kGameGold.withValues(alpha: 0.28);
      textColor = brightness == Brightness.light
          ? const Color(0xFF1B2A4A)
          : BrightnessColors.textPrimary(brightness);
    } else if (isCorrectAns) {
      bgColor = kGameGreen.withValues(alpha: 0.15);
      borderColor = kGameGreen;
      textColor = kGameGreen;
      trailingIcon = Icons.check_circle_rounded;
    } else if (isSelected) {
      bgColor = kGameRed.withValues(alpha: 0.15);
      borderColor = kGameRed;
      textColor = kGameRed;
      trailingIcon = Icons.cancel_rounded;
    } else {
      final base = brightness == Brightness.light
          ? const Color(0xFF1B2A4A)
          : BrightnessColors.textPrimary(brightness);
      bgColor = brightness == Brightness.light
          ? const Color(0xFFF9F7F3)
          : BrightnessColors.bgMid(brightness).withValues(alpha: 0.5);
      borderColor = kGameGold.withValues(alpha: 0.12);
      textColor = base.withValues(alpha: 0.35);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: isAnswered && isCorrectAns
              ? [
                  BoxShadow(
                    color: kGameGreen.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Index label (A, B, C, D)
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor.withValues(alpha: 0.15),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                textDirection:
                    isGreek ? TextDirection.ltr : TextDirection.rtl,
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: textColor,
                  fontSize: isGreek ? 12 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, color: textColor, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ── GameResultView ────────────────────────────────────────────────────────────

class GameResultView extends StatelessWidget {
  const GameResultView({
    super.key,
    required this.score,
    required this.total,
    required this.isGreek,
    required this.onPlayAgain,
    required this.onBack,
  });

  final int          score;
  final int          total;
  final bool         isGreek;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.light
        ? const Color(0xFFF5F0E8)
        : BrightnessColors.bgDeep(brightness);
    final pct = total > 0 ? score / total : 0.0;
    final emoji = pct >= 0.8 ? '🎉' : pct >= 0.5 ? '👏' : '💪';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trophy icon
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGameGold.withValues(alpha: 0.1),
                    border: Border.all(
                        color: kGameGold.withValues(alpha: 0.35), width: 2),
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 46)),
                  ),
                ),
                const SizedBox(height: 24),

                // Score
                Text(
                  '$score / $total',
                  style: TextStyle(
                    color: kGameGold,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGreek ? 'Σωστές απαντήσεις' : 'إجابات صحيحة',
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: brightness == Brightness.light
                        ? const Color(0xFF6B7280)
                        : BrightnessColors.textSecondary(brightness),
                    fontSize: isGreek ? 14 : 18,
                  ),
                ),
                const SizedBox(height: 32),

                // Percentage bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: kGameGold.withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kGameGold),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(pct * 100).round()}%',
                  style: const TextStyle(
                    color: kGameGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 40),

                // Play again
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGameNavy,
                      foregroundColor: kGameGold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onPlayAgain,
                    child: Text(
                      isGreek ? 'Παίξε Ξανά' : 'العب مجددًا',
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        fontSize: isGreek ? 14 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Back to home
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGameGold,
                      side: BorderSide(
                          color: kGameGold.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onBack,
                    child: Text(
                      isGreek ? 'Αλλαγή Παιχνιδιού' : 'تغيير اللعبة',
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        fontSize: isGreek ? 13 : 17,
                      ),
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

// ── GameLoadingView ───────────────────────────────────────────────────────────

class GameLoadingView extends StatelessWidget {
  const GameLoadingView({super.key, required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F0E8)
          : BrightnessColors.bgDeep(brightness),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kGameGold),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 20),
            Text(
              isGreek ? 'Φόρτωση ερωτήσεων…' : 'جارٍ تحميل الأسئلة…',
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: kGameGold.withValues(alpha: 0.7),
                fontSize: isGreek ? 13 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GameErrorView ─────────────────────────────────────────────────────────────

class GameErrorView extends StatelessWidget {
  const GameErrorView({
    super.key,
    required this.message,
    required this.isGreek,
    required this.onBack,
  });

  final String       message;
  final bool         isGreek;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F0E8)
          : BrightnessColors.bgDeep(brightness),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_outlined,
                  color: kGameGold.withValues(alpha: 0.5), size: 56),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: brightness == Brightness.light
                      ? const Color(0xFF6B7280)
                      : BrightnessColors.textSecondary(brightness),
                  fontSize: isGreek ? 13 : 16,
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGameGold,
                  side: BorderSide(color: kGameGold.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onBack,
                child: Text(
                  isGreek ? 'Πίσω' : 'رجوع',
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    fontSize: isGreek ? 13 : 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
