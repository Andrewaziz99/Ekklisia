// lib/features/agbeya/cubit/agbeya_state.dart
import 'package:equatable/equatable.dart';
import '../../../data/models/agbeya_model.dart';

enum AgbeyaStatus { initial, loading, loaded, error }

class AgbeyaState extends Equatable {
  final AgbeyaStatus status;
  final List<AgbeyaHour> hours;
  final String errorMessage;

  const AgbeyaState({
    this.status = AgbeyaStatus.initial,
    this.hours = const [],
    this.errorMessage = '',
  });

  bool get isLoading => status == AgbeyaStatus.loading;
  bool get isLoaded  => status == AgbeyaStatus.loaded;
  bool get hasError  => status == AgbeyaStatus.error;

  AgbeyaState copyWith({
    AgbeyaStatus? status,
    List<AgbeyaHour>? hours,
    String? errorMessage,
  }) =>
      AgbeyaState(
        status: status ?? this.status,
        hours: hours ?? this.hours,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, hours, errorMessage];
}
