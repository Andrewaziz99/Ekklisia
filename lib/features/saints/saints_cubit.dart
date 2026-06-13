// lib/features/saints/saints_cubit.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/saint_model.dart';
import '../../data/repositories/saints_repository.dart';

part 'saints_state.dart';

class SaintsCubit extends Cubit<SaintsState> {
  SaintsCubit(this._repo) : super(const SaintsInitial());

  final SaintsRepository _repo;
  StreamSubscription<List<SaintModel>>? _sub;

  void load() {
    emit(const SaintsLoading());
    _sub?.cancel();
    _sub = _repo.watchPublished().listen(
      (saints) => emit(SaintsLoaded(saints)),
      onError: (e) => emit(SaintsError(e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
