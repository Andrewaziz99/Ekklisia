// lib/features/saints/saints_state.dart
part of 'saints_cubit.dart';

abstract class SaintsState {
  const SaintsState();
}

class SaintsInitial extends SaintsState {
  const SaintsInitial();
}

class SaintsLoading extends SaintsState {
  const SaintsLoading();
}

class SaintsLoaded extends SaintsState {
  const SaintsLoaded(this.saints);
  final List<SaintModel> saints;
}

class SaintsError extends SaintsState {
  const SaintsError(this.message);
  final String message;
}
