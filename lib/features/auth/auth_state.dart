// lib/features/auth/cubit/auth_state.dart
import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Tracks which provider the user last authenticated with.
/// Used in the settings screen to show the correct badge and options.
enum SignInMethod { email, google, anonymous, unknown }

extension SignInMethodX on SignInMethod {
  /// Human-readable display label
  String get label {
    switch (this) {
      case SignInMethod.email:     return 'Email';
      case SignInMethod.google:    return 'Google';
      case SignInMethod.anonymous: return 'Guest';
      case SignInMethod.unknown:   return '—';
    }
  }

  /// Icon associated with each provider
  String get iconAsset {
    switch (this) {
      case SignInMethod.google: return 'G';
      default:                  return '✉';
    }
  }

  static SignInMethod fromString(String s) {
    switch (s) {
      case 'google':    return SignInMethod.google;
      case 'anonymous': return SignInMethod.anonymous;
      case 'email':     return SignInMethod.email;
      default:          return SignInMethod.unknown;
    }
  }
}

class AuthState extends Equatable {
  const AuthState({
    this.status          = AuthStatus.initial,
    this.user,
    this.signInMethod    = SignInMethod.unknown,
    this.errorMessage,
    this.isCheckingAdmin = false,
  });

  final AuthStatus   status;
  final UserModel?   user;
  final SignInMethod  signInMethod;
  final String?      errorMessage;
  final bool         isCheckingAdmin;

  // ── Computed helpers ──────────────────────────────────────────────────────
  bool get isLoading       => status == AuthStatus.loading || isCheckingAdmin;
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isAdmin         => isAuthenticated && (user?.isAdmin ?? false);
  bool get isAnonymous     => user?.isAnonymous ?? false;
  bool get isGoogleUser    => signInMethod == SignInMethod.google;
  bool get isEmailUser     => signInMethod == SignInMethod.email;

  AuthState copyWith({
    AuthStatus?  status,
    UserModel?   user,
    SignInMethod? signInMethod,
    String?      errorMessage,
    bool?        isCheckingAdmin,
  }) => AuthState(
    status:          status          ?? this.status,
    user:            user            ?? this.user,
    signInMethod:    signInMethod    ?? this.signInMethod,
    errorMessage:    errorMessage,
    isCheckingAdmin: isCheckingAdmin ?? this.isCheckingAdmin,
  );

  @override
  List<Object?> get props =>
      [status, user, signInMethod, errorMessage, isCheckingAdmin];
}