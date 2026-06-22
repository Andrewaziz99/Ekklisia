// lib/features/churches/churches_state.dart
part of 'churches_cubit.dart';

abstract class ChurchesState {
  const ChurchesState();
}

class ChurchesInitial extends ChurchesState {
  const ChurchesInitial();
}

class ChurchesLoading extends ChurchesState {
  const ChurchesLoading();
}

class ChurchesLoaded extends ChurchesState {
  const ChurchesLoaded(this.churches);
  final List<ChurchModel> churches;
}

class ChurchesError extends ChurchesState {
  const ChurchesError(this.message);
  final String message;
}
