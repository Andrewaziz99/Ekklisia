// lib/features/daily_verse/daily_verse_state.dart
import 'package:equatable/equatable.dart';
import '../../data/models/daily_verse_model.dart';

enum DailyVerseStatus { initial, loading, loaded, empty, error }

class DailyVerseState extends Equatable {
  const DailyVerseState({
    this.status = DailyVerseStatus.initial,
    this.verse,
    this.errorMessage,
  });

  final DailyVerseStatus status;
  final DailyVerseModel?  verse;
  final String?           errorMessage;

  bool get isLoading => status == DailyVerseStatus.loading;
  bool get hasVerse  => status == DailyVerseStatus.loaded && verse != null;
  bool get isEmpty   => status == DailyVerseStatus.empty;
  bool get hasError  => status == DailyVerseStatus.error;

  DailyVerseState copyWith({
    DailyVerseStatus? status,
    DailyVerseModel?  verse,
    String?           errorMessage,
  }) =>
      DailyVerseState(
        status:       status       ?? this.status,
        verse:        verse        ?? this.verse,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, verse, errorMessage];
}
