// lib/features/auth/cubit/auth_cubit.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authService) : super(const AuthState()) {
    _listenToAuthState();
  }

  final AuthService _authService;
  StreamSubscription<User?>? _authSub;

  // ── Listen to Firebase auth state ─────────────────────────────────────

  void _listenToAuthState() {
    _authSub = _authService.authStateChanges.listen(
          (user) async {
        if (user == null) {
          emit(const AuthState(status: AuthStatus.unauthenticated));
        } else {
          emit(state.copyWith(
            status:          AuthStatus.loading,
            isCheckingAdmin: true,
          ));
          final isAdmin = await _authService.checkIsAdmin();
          final currentUser = state.user?.copyWith(isAdmin: isAdmin);
          emit(state.copyWith(
            status:          AuthStatus.authenticated,
            isCheckingAdmin: false,
            user:            currentUser,
          ));
        }
      },
      onError: (e) => emit(const AuthState(status: AuthStatus.unauthenticated)),
    );
  }

  // ── Email / Password Sign In ──────────────────────────────────────────

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final user = await _authService.signInWithEmail(
        email:    email,
        password: password,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on FirebaseAuthException catch (e) {
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: _authService.arabicError(e),
      ));
    } catch (e) {
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: 'حدث خطأ غير متوقع',
      ));
    }
  }

  // ── Anonymous sign-in (reader mode) ──────────────────────────────────

  Future<void> signInAnonymously() async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authService.signInAnonymously();
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (_) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  // ── Password Reset ────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}