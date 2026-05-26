import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';
import 'session_service.dart';

/// Centralised Firebase Authentication service.
///
/// Sign-in methods supported:
///   • Email + Password
///   • Google (via google_sign_in + FirebaseAuth credential)
///   • Anonymous (read-only guest access)
///   • Anonymous → Google account linking (upgrade guest account)
///
/// Admin detection order:
///   1. Firebase custom claim  `admin: true`  (set via Admin SDK / Cloud Function)
///   2. Firestore fallback     `users/{uid}.is_admin == true`  (Phase 1 manual)
class AuthService {
  AuthService({
    required FirebaseAuth      firebaseAuth,
    required FirebaseFirestore firestore,
    required SessionService    session,
    required GoogleSignIn      googleSignIn,
  })  : _auth         = firebaseAuth,
        _firestore    = firestore,
        _session      = session,
        _googleSignIn = googleSignIn;

  final FirebaseAuth      _auth;
  final FirebaseFirestore _firestore;
  final SessionService    _session;
  final GoogleSignIn      _googleSignIn;

  // ── Getters ───────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User?         get currentUser      => _auth.currentUser;
  bool          get isSignedIn       =>
      _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  // ── Email / Password ──────────────────────────────────────────────────────
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return _buildAndPersist(cred.user!, method: 'email');
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  // Flow:
  //   1. google_sign_in shows the native account picker
  //   2. We exchange the Google tokens for a Firebase credential
  //   3. Firebase signs the user in (creates account on first time)
  //
  // Platform setup required:
  //   Android → SHA-1 fingerprint in Firebase console + google-services.json
  //   iOS     → URL scheme in Info.plist + GoogleService-Info.plist
  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw const GoogleSignInCancelledException();

    final googleAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(cred);
    return _buildAndPersist(userCred.user!, method: 'google');
  }

  // ── Anonymous ─────────────────────────────────────────────────────────────
  Future<UserModel> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return _buildAndPersist(cred.user!, method: 'anonymous');
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut().catchError((_) {});
    await _auth.signOut();
    await _session.clearSession();
  }

  // ── Change password (email users only) ───────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No email user signed in');
    }
    // Re-authenticate first (required by Firebase for sensitive operations)
    final cred = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  // ── Admin detection ───────────────────────────────────────────────────────
  Future<bool> checkIsAdmin() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    try {
      // 1. Custom claim (set by Firebase Admin SDK / Cloud Function)
      final token = await user.getIdTokenResult(true);
      if (token.claims?['admin'] == true) return true;
    } catch (_) {}

    // 2. Firestore fallback (works in Phase 1 before server-side claim setup)
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();
      return doc.data()?['is_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Admin management (Firestore) ──────────────────────────────────────────
  Future<void> setAdminStatus(String uid, {required bool isAdmin}) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'is_admin':   isAdmin,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserRecord(String uid) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .delete();
    await _firestore
        .collection(AppConstants.fcmTokensCollection)
        .doc(uid)
        .delete()
        .catchError((_) {});
  }

  // ── Password reset ────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Build UserModel + persist session ────────────────────────────────────
  Future<UserModel> _buildAndPersist(
      User firebaseUser, {
        required String method,
      }) async {
    bool isAdmin = false;
    if (!firebaseUser.isAnonymous) isAdmin = await checkIsAdmin();

    final model = UserModel(
      uid:         firebaseUser.uid,
      email:       firebaseUser.email        ?? '',
      displayName: firebaseUser.displayName  ?? '',
      photoUrl:    firebaseUser.photoURL     ?? '',
      isAdmin:     isAdmin,
      isAnonymous: firebaseUser.isAnonymous,
      createdAt:   firebaseUser.metadata.creationTime,
      lastSeenAt:  DateTime.now(),
    );

    // Upsert Firestore doc (creates on first sign-in)
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(model.uid)
        .set(model.toFirestore(), SetOptions(merge: true));

    // Persist to SharedPreferences for fast splash routing
    await _session.saveSession(
      uid:          model.uid,
      isAdmin:      isAdmin,
      isAnonymous:  firebaseUser.isAnonymous,
      email:        model.email,
      displayName:  model.displayName,
      photoUrl:     model.photoUrl,
      signInMethod: method,
    );

    return model;
  }

  // ── Arabic error messages ─────────────────────────────────────────────────
  String arabicError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'هذا الحساب موقوف';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'credential-already-in-use':
        return 'هذا الحساب مرتبط بمستخدم آخر';
      case 'account-exists-with-different-credential':
        return 'هذا البريد مرتبط بطريقة دخول أخرى';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت';
      default:
        return 'حدث خطأ (${e.code})';
    }
  }
}

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
  @override
  String toString() => 'Google sign-in was cancelled.';
}