// lib/features/games/cubit/game_state.dart
import 'package:equatable/equatable.dart';

import '../../../data/models/game_model.dart';

enum GamePhase { idle, loading, playing, complete, error }

class GameState extends Equatable {
  const GameState({
    this.phase = GamePhase.idle,
    this.gameType,
    this.questions = const [],
    this.currentIndex = 0,
    this.score = 0,
    this.selectedIndex,
    this.errorMessage,
  });

  final GamePhase          phase;
  final GameType?          gameType;
  final List<GameQuestion> questions;
  final int                currentIndex;
  final int                score;
  final int?               selectedIndex; // null = not answered yet
  final String?            errorMessage;

  bool get isLoading      => phase == GamePhase.loading;
  bool get isPlaying      => phase == GamePhase.playing;
  bool get isComplete     => phase == GamePhase.complete;
  bool get isAnswered     => selectedIndex != null;
  bool get isLastQuestion => currentIndex >= questions.length - 1;

  GameQuestion? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];

  bool get isCorrect =>
      selectedIndex != null &&
      currentQuestion != null &&
      selectedIndex == currentQuestion!.correctIndex;

  GameState copyWith({
    GamePhase?          phase,
    GameType?           gameType,
    List<GameQuestion>? questions,
    int?                currentIndex,
    int?                score,
    int?                selectedIndex,
    bool                clearSelectedIndex = false,
    String?             errorMessage,
  }) =>
      GameState(
        phase:         phase         ?? this.phase,
        gameType:      gameType      ?? this.gameType,
        questions:     questions     ?? this.questions,
        currentIndex:  currentIndex  ?? this.currentIndex,
        score:         score         ?? this.score,
        selectedIndex: clearSelectedIndex
            ? null
            : (selectedIndex ?? this.selectedIndex),
        errorMessage:  errorMessage  ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [
        phase, gameType, questions, currentIndex,
        score, selectedIndex, errorMessage,
      ];
}
