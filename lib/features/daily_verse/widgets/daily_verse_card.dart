// lib/features/daily_verse/widgets/daily_verse_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// A self-contained card that reads from DailyVerseCubit and renders
// the daily Bible verse with the app's gold/Byzantine aesthetic.
// Fully compatible with light and dark themes.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../features/settings/cubit/settings_cubit.dart';
import '../../../features/settings/cubit/settings_state.dart';
import '../../../services/settings_service.dart';
import '../daily_verse_cubit.dart';
import '../daily_verse_state.dart';

class DailyVerseCard extends StatelessWidget {
  const DailyVerseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyVerseCubit, DailyVerseState>(
      builder: (context, state) {
        if (state.isLoading) return const _VerseShimmer();
        if (state.hasError)  return _VerseError(message: state.errorMessage);
        if (!state.hasVerse) return const SizedBox.shrink();
        return _VerseContent(state: state);
      },
    );
  }
}

// ── Actual verse content ──────────────────────────────────────────────────────

class _VerseContent extends StatelessWidget {
  const _VerseContent({required this.state});
  final DailyVerseState state;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgMid      = BrightnessColors.bgMid(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldLight  = BrightnessColors.goldLight(brightness);
    final goldDim    = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    // Pick language-appropriate verse text
    final l = context.l10n;
    final isGreek   = !l.isAr;
    final verse     = state.verse!;
    final verseText = isGreek && verse.verseEl.isNotEmpty
        ? verse.verseEl
        : verse.verseAr;
    final reference = isGreek && verse.referenceEl.isNotEmpty
        ? verse.referenceEl
        : verse.referenceAr;
    final textDir   = l.dir;
    final crossAlign = isGreek
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;
    final fontFamily = l.bodyFont;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header band ────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.12),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
                border: Border(
                    bottom: BorderSide(color: goldBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  Text('✦', style: TextStyle(color: goldDim, fontSize: 10)),
                  const SizedBox(width: 6),
                  Text(
                    l.dailyVerseTitle,
                    textDirection: textDir,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: goldLight,
                      fontSize: isGreek ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Verse body ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: crossAlign,
                children: [
                  // Opening quotation mark
                  Text(
                    isGreek ? '«' : '«',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor.withOpacity(0.4),
                      fontSize: 28,
                      height: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Verse text — scales down if too long to fit
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final baseFontSize = isGreek ? 15.0 : 18.0;
                      // Compute a scaled-down size based on character count
                      final len = verseText.length;
                      final double fontSize;
                      if (len > 300) {
                        fontSize = baseFontSize * 0.72;
                      } else if (len > 200) {
                        fontSize = baseFontSize * 0.82;
                      } else if (len > 120) {
                        fontSize = baseFontSize * 0.91;
                      } else {
                        fontSize = baseFontSize;
                      }
                      return Text(
                        verseText,
                        textDirection: textDir,
                        textAlign:
                            isGreek ? TextAlign.left : TextAlign.right,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: BrightnessColors.textPrimary(brightness),
                          fontSize: fontSize,
                          height: 1.7,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Reference
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: goldBorder, width: 0.5),
                    ),
                    child: Text(
                      reference,
                      textDirection: textDir,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: goldLight,
                        fontSize: isGreek ? 11 : 13,
                        fontWeight: FontWeight.w700,
                      ),
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

// ── Error state ───────────────────────────────────────────────────────────────

class _VerseError extends StatelessWidget {
  const _VerseError({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgMid      = BrightnessColors.bgMid(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message ?? 'Could not load verse',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _VerseShimmer extends StatefulWidget {
  const _VerseShimmer();

  @override
  State<_VerseShimmer> createState() => _VerseShimmerState();
}

class _VerseShimmerState extends State<_VerseShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgMid      = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: bgMid,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: goldBorder, width: 0.5),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _shimmerLine(bgElevated, 0.5),
                const SizedBox(height: 12),
                _shimmerLine(bgElevated, 1.0),
                const SizedBox(height: 8),
                _shimmerLine(bgElevated, 0.85),
                const SizedBox(height: 8),
                _shimmerLine(bgElevated, 0.6),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: _shimmerLine(bgElevated, 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shimmerLine(Color c, double w) => FractionallySizedBox(
        widthFactor: w,
        child: Container(
          height: 11,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}
