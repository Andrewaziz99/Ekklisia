import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  const AuthState({
    this.status      = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isCheckingAdmin = false,
  });

  final AuthStatus  status;
  final UserModel?  user;
  final String?     errorMessage;
  final bool        isCheckingAdmin;

  bool get isLoading        => status == AuthStatus.loading || isCheckingAdmin;
  bool get isAuthenticated  => status == AuthStatus.authenticated && user != null;
  bool get isAdmin          => isAuthenticated && (user?.isAdmin ?? false);
  bool get isAnonymous      => user?.isAnonymous ?? false;

  AuthState copyWith({
    AuthStatus? status,
    UserModel?  user,
    String?     errorMessage,
    bool?       isCheckingAdmin,
  }) => AuthState(
    status:          status          ?? this.status,
    user:            user            ?? this.user,
    errorMessage:    errorMessage,
    isCheckingAdmin: isCheckingAdmin ?? this.isCheckingAdmin,
  );

  @override
  List<Object?> get props => [status, user, errorMessage, isCheckingAdmin];
}