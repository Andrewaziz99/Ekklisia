import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';

/// Centralised authentication service.
///
/// Admin detection:
///   1. Firebase Custom Claims  — `request.auth.token.admin == true`
///      (preferred — set via Firebase Admin SDK on server)
///   2. Firestore fallback      — `/users/{uid}.is_admin == true`
///      (used in Phase 1 before a backend function is set up)
class AuthService {
  AuthService({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _auth      = firebaseAuth,
        _firestore = firestore;

  final FirebaseAuth      _auth;
  final FirebaseFirestore _firestore;

  // ── Stream ─────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User?         get currentUser      => _auth.currentUser;
  bool          get isSignedIn       => _auth.currentUser != null && !(_auth.currentUser!.isAnonymous);

  // ── Sign In ────────────────────────────────────────────────────────────

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email:    email.trim(),
      password: password,
    );
    return _buildUserModel(cred.user!);
  }

  // ── Anonymous Sign-In (read-only users) ───────────────────────────────

  Future<UserModel> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return _buildUserModel(cred.user!);
  }

  // ── Sign Out ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Admin check ────────────────────────────────────────────────────────

  /// Checks admin status via custom claims first, then Firestore fallback.
  Future<bool> checkIsAdmin() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    // 1. Custom claims (fastest, no Firestore read needed)
    final token = await user.getIdTokenResult(true); // force refresh
    if (token.claims?['admin'] == true) return true;

    // 2. Firestore fallback
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

  // ── Persist / sync user doc ────────────────────────────────────────────

  Future<UserModel> _buildUserModel(User firebaseUser) async {
    final uid = firebaseUser.uid;

    // Check admin
    bool isAdmin = false;
    if (!firebaseUser.isAnonymous) {
      isAdmin = await checkIsAdmin();
    }

    final model = UserModel(
      uid:         uid,
      email:       firebaseUser.email        ?? '',
      displayName: firebaseUser.displayName  ?? '',
      photoUrl:    firebaseUser.photoURL     ?? '',
      isAdmin:     isAdmin,
      isAnonymous: firebaseUser.isAnonymous,
    );

    // Sync to Firestore (upsert)
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(model.toFirestore(), SetOptions(merge: true));

    return model;
  }

  // ── Password reset ─────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Error messages (Arabic) ───────────────────────────────────────────

  String arabicError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':      return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':      return 'كلمة المرور غير صحيحة';
      case 'invalid-email':       return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':       return 'هذا الحساب موقوف';
      case 'too-many-requests':   return 'محاولات كثيرة، حاول لاحقاً';
      case 'network-request-failed': return 'تحقق من اتصالك بالإنترنت';
      default:                    return 'حدث خطأ، حاول مجدداً (${e.code})';
    }
  }
}