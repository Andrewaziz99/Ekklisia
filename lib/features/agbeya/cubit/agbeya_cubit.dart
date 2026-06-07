// lib/features/agbeya/cubit/agbeya_cubit.dart
// ─────────────────────────────────────────────────────────────────────────────
// Cubit for loading and streaming the list of Agbeya hours from Firestore.
// Each AgbeyaHomeScreen creates its own instance (provided via BlocProvider).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/agbeya_model.dart';
import '../../../data/repositories/agbeya_repository.dart';
import 'agbeya_state.dart';

class AgbeyaCubit extends Cubit<AgbeyaState> {
  AgbeyaCubit(this._repo) : super(const AgbeyaState());

  final AgbeyaRepository _repo;
  StreamSubscription<List<AgbeyaHour>>? _sub;

  /// Subscribe to real-time Firestore updates for published hours.
  void watchHours() {
    if (_sub != null) return; // already watching
    emit(state.copyWith(status: AgbeyaStatus.loading));
    _sub = _repo.watchPublishedHours().listen(
      (hours) => emit(state.copyWith(
        status: AgbeyaStatus.loaded,
        hours: hours,
      )),
      onError: (Object e) => emit(state.copyWith(
        status: AgbeyaStatus.error,
        errorMessage: e.toString(),
      )),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
