// lib/features/games/screens/guess_who_game_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// "Guess Who?" game — player sees a photo and picks the correct name from
// 4 choices. Correct answer revealed in green; wrong in red.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/brightness_colors.dart';
import '../../../data/models/game_model.dart';
import '../../../shared/widgets/cached_image.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_screen_base.dart';

class GuessWhoGameScreen extends StatefulWidget {
  const GuessWhoGameScreen({super.key, required this.isGreek});
  final bool isGreek;

  @override
  State<GuessWhoGameScreen> createState() => _GuessWhoGameScreenState();
}

class _GuessWhoGameScreenState extends State<GuessWhoGameScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GameCubit>().loadQuestions(GameType.guessWho);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      builder: (context, state) {
        if (state.isLoading) {
          return GameLoadingView(isGreek: widget.isGreek);
        }
        if (state.phase == GamePhase.error) {
          return GameErrorView(
            message: state.errorMessage ?? '',
            isGreek: widget.isGreek,
            onBack: () => Navigator.pop(context),
          );
        }
        if (state.isComplete) {
          return GameResultView(
            score: state.score,
            total: state.questions.length,
            isGreek: widget.isGreek,
            onPlayAgain: () => context.read<GameCubit>().resetGame(),
            onBack: () => Navigator.pop(context),
          );
        }
        if (state.currentQuestion == null) return const SizedBox.shrink();

        return _GuessWhoPlayView(
          state: state,
          isGreek: widget.isGreek,
        );
      },
    );
  }
}

// ── Play view ─────────────────────────────────────────────────────────────────

class _GuessWhoPlayView extends StatelessWidget {
  const _GuessWhoPlayView({
    required this.state,
    required this.isGreek,
  });

  final GameState state;
  final bool      isGreek;

  @override
  Widget build(BuildContext context) {
    final q          = state.currentQuestion!;
    final brightness = Theme.of(context).brightness;
    final bodyBg     = brightness == Brightness.light
        ? const Color(0xFFF5F0E8)
        : BrightnessColors.bgDeep(brightness);

    return Scaffold(
      backgroundColor: bodyBg,
      body: Column(
        children: [
          // Header + progress
          GameHeader(
            titleAr: 'من هو؟',
            titleEl: 'Ποιος είναι;',
            currentIndex: state.currentIndex,
            total: state.questions.length,
            score: state.score,
            isGreek: isGreek,
          ),

          // Photo
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: kGameGold.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedImage(
                    url: q.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: const _ImagePlaceholder(isLoading: true),
                    errorWidget: const _ImagePlaceholder(isLoading: false),
                  ),
                ),
              ),
            ),
          ),

          // Question prompt
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              isGreek
                  ? (q.questionEl.isNotEmpty
                      ? q.questionEl
                      : 'Ποιος είναι αυτός το πρόσωπο;')
                  : (q.questionAr.isNotEmpty
                      ? q.questionAr
                      : 'من هذا الشخص؟'),
              textDirection:
                  isGreek ? TextDirection.ltr : TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: brightness == Brightness.light
                    ? const Color(0xFF1B2A4A)
                    : BrightnessColors.textPrimary(brightness),
                fontSize: isGreek ? 15 : 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Choices grid
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Column(
                children: List.generate(
                  (q.choices.length.clamp(0, 4) / 2).ceil(),
                  (row) {
                    final a = row * 2;
                    final b = row * 2 + 1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            if (a < q.choices.length)
                              Expanded(
                                child: ChoiceButton(
                                  text: isGreek
                                      ? (q.choices[a].textEl.isNotEmpty
                                          ? q.choices[a].textEl
                                          : q.choices[a].textAr)
                                      : q.choices[a].textAr,
                                  index: a,
                                  correctIndex: q.correctIndex,
                                  selectedIndex: state.selectedIndex,
                                  isGreek: isGreek,
                                  onTap: state.isAnswered
                                      ? null
                                      : () => context
                                          .read<GameCubit>()
                                          .selectAnswer(a),
                                ),
                              ),
                            if (b < q.choices.length) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceButton(
                                  text: isGreek
                                      ? (q.choices[b].textEl.isNotEmpty
                                          ? q.choices[b].textEl
                                          : q.choices[b].textAr)
                                      : q.choices[b].textAr,
                                  index: b,
                                  correctIndex: q.correctIndex,
                                  selectedIndex: state.selectedIndex,
                                  isGreek: isGreek,
                                  onTap: state.isAnswered
                                      ? null
                                      : () => context
                                          .read<GameCubit>()
                                          .selectAnswer(b),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Next / Results button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.isAnswered
                ? Padding(
                    key: const ValueKey('next'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGameNavy,
                          foregroundColor: kGameGold,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () =>
                            context.read<GameCubit>().nextQuestion(),
                        child: Text(
                          state.isLastQuestion
                              ? (isGreek ? 'Αποτελέσματα' : 'النتائج')
                              : (isGreek ? 'Επόμενο →' : '← التالي'),
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            fontSize: isGreek ? 14 : 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 24),
          ),
        ],
      ),
    );
  }
}

// ── Image placeholder ─────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1B2A),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kGameGold),
                strokeWidth: 2,
              )
            : const Icon(Icons.person_outline,
                color: Color(0xFF3A5A70), size: 72),
      ),
    );
  }
}
