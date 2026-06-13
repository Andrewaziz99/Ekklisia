// lib/features/games/screens/mcq_game_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// MCQ (Multiple Choice Question) game screen.
// Shows a text question (with optional image) and 4 answer choices.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/brightness_colors.dart';
import '../../../data/models/game_model.dart';
import '../../../shared/widgets/cached_image.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_screen_base.dart';

class McqGameScreen extends StatefulWidget {
  const McqGameScreen({super.key, required this.isGreek});
  final bool isGreek;

  @override
  State<McqGameScreen> createState() => _McqGameScreenState();
}

class _McqGameScreenState extends State<McqGameScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GameCubit>().loadQuestions(GameType.mcq);
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

        return _McqPlayView(state: state, isGreek: widget.isGreek);
      },
    );
  }
}

// ── Play view ─────────────────────────────────────────────────────────────────

class _McqPlayView extends StatelessWidget {
  const _McqPlayView({required this.state, required this.isGreek});

  final GameState state;
  final bool      isGreek;

  @override
  Widget build(BuildContext context) {
    final q          = state.currentQuestion!;
    final brightness = Theme.of(context).brightness;
    final bodyBg     = brightness == Brightness.light
        ? const Color(0xFFF5F0E8)
        : BrightnessColors.bgDeep(brightness);
    final cardBg     = brightness == Brightness.light
        ? Colors.white
        : BrightnessColors.bgMid(brightness);
    final textPrimary = brightness == Brightness.light
        ? const Color(0xFF1B2A4A)
        : BrightnessColors.textPrimary(brightness);

    return Scaffold(
      backgroundColor: bodyBg,
      body: Column(
        children: [
          // Header + progress
          GameHeader(
            titleAr: 'اختبار',
            titleEl: 'Κουίζ',
            currentIndex: state.currentIndex,
            total: state.questions.length,
            score: state.score,
            isGreek: isGreek,
          ),

          // Question card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kGameGold.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Optional image
                  if (q.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedImage(
                        url: q.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Question number badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGameGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kGameGold.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isGreek
                              ? 'Ερώτηση ${state.currentIndex + 1}'
                              : 'سؤال ${state.currentIndex + 1}',
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: kGameGold,
                            fontSize: isGreek ? 10 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Question text
                  Text(
                    isGreek
                        ? (q.questionEl.isNotEmpty
                            ? q.questionEl
                            : q.questionAr)
                        : q.questionAr,
                    textDirection:
                        isGreek ? TextDirection.ltr : TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: textPrimary,
                      fontSize: isGreek ? 15 : 19,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Answer choices
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: q.choices.length.clamp(0, 4),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => ChoiceButton(
                  text: isGreek
                      ? (q.choices[i].textEl.isNotEmpty
                          ? q.choices[i].textEl
                          : q.choices[i].textAr)
                      : q.choices[i].textAr,
                  index: i,
                  correctIndex: q.correctIndex,
                  selectedIndex: state.selectedIndex,
                  isGreek: isGreek,
                  onTap: state.isAnswered
                      ? null
                      : () => context.read<GameCubit>().selectAnswer(i),
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
