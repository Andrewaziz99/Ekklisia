// lib/features/games/cubit/game_cubit.dart
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/game_model.dart';
import '../../../data/repositories/game_repository.dart';
import 'game_state.dart';

class GameCubit extends Cubit<GameState> {
  GameCubit(this._repo) : super(const GameState());

  final GameRepository _repo;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadQuestions(GameType type) async {
    emit(state.copyWith(
      phase:             GamePhase.loading,
      gameType:          type,
      questions:         const [],
      currentIndex:      0,
      score:             0,
      clearSelectedIndex: true,
    ));
    try {
      final questions = await _repo.fetchVisible(type);
      if (questions.isEmpty) {
        emit(state.copyWith(
          phase:        GamePhase.error,
          errorMessage: 'لا توجد أسئلة متاحة حالياً.\nNo questions available yet.',
        ));
        return;
      }
      final shuffled = List<GameQuestion>.from(questions)..shuffle(Random());
      emit(state.copyWith(
        phase:             GamePhase.playing,
        questions:         shuffled,
        currentIndex:      0,
        score:             0,
        clearSelectedIndex: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        phase:        GamePhase.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ── Play ──────────────────────────────────────────────────────────────────

  void selectAnswer(int index) {
    if (state.isAnswered || !state.isPlaying) return;
    final isCorrect = index == (state.currentQuestion?.correctIndex ?? -1);
    emit(state.copyWith(
      selectedIndex: index,
      score: isCorrect ? state.score + 1 : state.score,
    ));
  }

  void nextQuestion() {
    if (!state.isAnswered) return;
    if (state.isLastQuestion) {
      emit(state.copyWith(phase: GamePhase.complete));
    } else {
      emit(state.copyWith(
        currentIndex:       state.currentIndex + 1,
        clearSelectedIndex: true,
      ));
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void resetGame() {
    final type = state.gameType;
    if (type != null) {
      loadQuestions(type);
    } else {
      emit(const GameState());
    }
  }

  void goHome() => emit(const GameState());
}
