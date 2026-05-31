// lib/features/daily_verse/daily_verse_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/daily_verse_repository.dart';
import 'daily_verse_state.dart';

class DailyVerseCubit extends Cubit<DailyVerseState> {
  DailyVerseCubit(this._repository) : super(const DailyVerseState());

  final DailyVerseRepository _repository;

  /// Fetch today's verse from Firestore.
  /// Falls back to the lowest-order active verse if the edge function
  /// hasn't run yet today (so the card is never empty).
  Future<void> loadTodayVerse() async {
    if (state.isLoading) return;
    emit(state.copyWith(status: DailyVerseStatus.loading));
    try {
      final verse = await _repository.fetchTodayVerse()
          ?? await _repository.fetchFallbackVerse();
      if (verse == null) {
        emit(state.copyWith(status: DailyVerseStatus.empty));
      } else {
        emit(state.copyWith(status: DailyVerseStatus.loaded, verse: verse));
      }
    } catch (e) {
      emit(state.copyWith(
        status: DailyVerseStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Reload (e.g. after admin saves a new verse).
  Future<void> refresh() => loadTodayVerse();
}
