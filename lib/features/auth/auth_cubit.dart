import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/session_service.dart';
import '../../../core/di/service_locator.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authService, SessionService sessionService) : super(const AuthState()) {
    _listenToAuthState();
  }

  final AuthService _authService;
  StreamSubscription<User?>? _authSub;

  // ── Firebase auth-state stream (ground truth) ─────────────────────────────
  void _listenToAuthState() {
    _authSub = _authService.authStateChanges.listen(
          (firebaseUser) async {
        if (firebaseUser == null) {
          emit(const AuthState(status: AuthStatus.unauthenticated));
          return;
        }

        emit(state.copyWith(
          status:          AuthStatus.loading,
          isCheckingAdmin: true,
        ));

        final isAdmin = await _authService.checkIsAdmin();

        // Prefer the already-built UserModel if it matches (avoids rebuilding
        // on every authStateChanges tick after a sign-in).
        final existing = state.user;
        final user = (existing != null && existing.uid == firebaseUser.uid)
            ? existing.copyWith(isAdmin: isAdmin)
            : _modelFromFirebase(firebaseUser, isAdmin);

        // Resolve sign-in method from persisted session (set by AuthService
        // on every successful sign-in).
        final method = SignInMethodX.fromString(
            sl<SessionService>().signInMethod);

        emit(AuthState(
          status:          AuthStatus.authenticated,
          user:            user,
          signInMethod:    firebaseUser.isAnonymous
              ? SignInMethod.anonymous
              : method,
          isCheckingAdmin: false,
        ));
      },
      onError: (_) =>
          emit(const AuthState(status: AuthStatus.unauthenticated)),
    );
  }

  // ── Email / Password ──────────────────────────────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      final user = await _authService.signInWithEmail(
          email: email, password: password);
      emit(AuthState(
        status:       AuthStatus.authenticated,
        user:         user,
        signInMethod: SignInMethod.email,
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: _authService.arabicError(e),
      ));
    } catch (_) {
      emit(const AuthState(
        status:       AuthStatus.error,
        errorMessage: 'حدث خطأ غير متوقع',
      ));
    }
  }

  // ── Google sign-in ────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    print('[AuthCubit] signInWithGoogle() called');
    _setLoading();
    try {
      print('[AuthCubit] Calling AuthService.signInWithGoogle()...');
      final user = await _authService.signInWithGoogle();
      print('[AuthCubit] AuthService.signInWithGoogle() returned user: ${user.uid}');
      emit(AuthState(
        status:       AuthStatus.authenticated,
        user:         user,
        signInMethod: SignInMethod.google,
      ));
    } on GoogleSignInCancelledException {
      print('[AuthCubit] Google Sign-In cancelled by user');
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } on UnimplementedError catch (e) {
      print('[AuthCubit] UnimplementedError: ${e.toString()}');
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: 'دخول Google غير مُفعّل حالياً. يرجى تكوين البيانات الأساسية.',
      ));
    } on PlatformException catch (e) {
      print('[AuthCubit] PlatformException: ${e.code} - ${e.message}');
      final errorMsg = _googleSignInErrorMessage(e);
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: errorMsg,
      ));
    } on FirebaseAuthException catch (e) {
      print('[AuthCubit] FirebaseAuthException: ${e.code} - ${e.message}');
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: _authService.arabicError(e),
      ));
    } catch (e) {
      print('[AuthCubit] Caught error in signInWithGoogle: ${e.runtimeType} - ${e.toString()}');
      emit(AuthState(
        status:       AuthStatus.error,
        errorMessage: 'فشل تسجيل الدخول بـ Google: ${e.toString()}',
      ));
    }
  }

  // ── Anonymous ─────────────────────────────────────────────────────────────
  Future<void> signInAnonymously() async {
    _setLoading();
    try {
      final user = await _authService.signInAnonymously();
      emit(AuthState(
        status:       AuthStatus.authenticated,
        user:         user,
        signInMethod: SignInMethod.anonymous,
      ));
    } catch (_) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  // ── Password reset ────────────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Change password (email users only) ───────────────────────────────────
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
          currentPassword: currentPassword, newPassword: newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setLoading() =>
      emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

  /// Parse Google Sign-In PlatformException error codes to user-friendly messages
  String _googleSignInErrorMessage(PlatformException e) {
    // Google Play Services error codes: https://developers.google.com/android/reference/com/google/android/gms/common/ConnectionResult
    switch (e.code) {
      case '10':  // DEVELOPER_ERROR
        return 'تكوين Google غير صحيح. تحقق من SHA-1 وواجهة Firebase Console';
      case '8':   // SERVICE_VERSION_UPDATE_REQUIRED
        return 'يتطلب تحديث خدمات Google Play';
      case '3':   // SERVICE_UNAVAILABLE
        return 'خدمات Google Play غير متاحة حالياً';
      case '1':   // SERVICE_MISSING
        return 'خدمات Google Play غير مثبتة على الجهاز';
      case '2':   // SERVICE_VERSION_UPDATE_REQUIRED (alternative)
        return 'يتطلب تحديث تطبيق Google Play Services';
      default:
        return 'فشل دخول Google: ${e.code} - ${e.message ?? "Unknown error"}';
    }
  }

  UserModel _modelFromFirebase(User u, bool isAdmin) => UserModel(
    uid:         u.uid,
    email:       u.email        ?? '',
    displayName: u.displayName  ?? '',
    photoUrl:    u.photoURL     ?? '',
    isAdmin:     isAdmin,
    isAnonymous: u.isAnonymous,
    createdAt:   u.metadata.creationTime,
    lastSeenAt:  DateTime.now(),
  );

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}