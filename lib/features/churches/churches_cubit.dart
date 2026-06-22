// lib/features/churches/churches_cubit.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/church_model.dart';
import '../../data/repositories/churches_repository.dart';

part 'churches_state.dart';

class ChurchesCubit extends Cubit<ChurchesState> {
  ChurchesCubit(this._repo) : super(const ChurchesInitial());

  final ChurchesRepository _repo;
  StreamSubscription<List<ChurchModel>>? _sub;

  void load() {
    emit(const ChurchesLoading());
    _sub?.cancel();
    _sub = _repo.watchPublished().listen(
      (churches) => emit(ChurchesLoaded(churches)),
      onError: (e) => emit(ChurchesError(e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
