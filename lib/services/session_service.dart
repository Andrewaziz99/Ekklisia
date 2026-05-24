// lib/services/session_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// SessionService — persists auth session data to SharedPreferences so the
// splash screen can route instantly (Home / Admin / Login) without waiting
// for the Firebase token network round-trip.
//
// Strategy:
//   • On successful sign-in  → write uid, isAdmin, isAnon, signInMethod
//   • On sign-out            → clear session
//   • Splash reads prefs     → decides initial route
//   • Firebase authStateChanges still runs in parallel as ground-truth
// ─────────────────────────────────────────────────────────────────────────────
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService(this._prefs);
  final SharedPreferences _prefs;

  // ── Keys ─────────────────────────────────────────────────────────────────
  static const _kUid          = 'session_uid';
  static const _kIsAdmin      = 'session_is_admin';
  static const _kIsAnonymous  = 'session_is_anon';
  static const _kEmail        = 'session_email';
  static const _kDisplayName  = 'session_display_name';
  static const _kPhotoUrl     = 'session_photo_url';
  static const _kSignInMethod = 'session_sign_in_method'; // email|google|anonymous

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> saveSession({
    required String uid,
    required bool   isAdmin,
    required bool   isAnonymous,
    String  email        = '',
    String  displayName  = '',
    String  photoUrl     = '',
    String  signInMethod = 'email',
  }) async {
    await _prefs.setString(_kUid,          uid);
    await _prefs.setBool  (_kIsAdmin,      isAdmin);
    await _prefs.setBool  (_kIsAnonymous,  isAnonymous);
    await _prefs.setString(_kEmail,        email);
    await _prefs.setString(_kDisplayName,  displayName);
    await _prefs.setString(_kPhotoUrl,     photoUrl);
    await _prefs.setString(_kSignInMethod, signInMethod);
  }

  Future<void> clearSession() async {
    await _prefs.remove(_kUid);
    await _prefs.remove(_kIsAdmin);
    await _prefs.remove(_kIsAnonymous);
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kDisplayName);
    await _prefs.remove(_kPhotoUrl);
    await _prefs.remove(_kSignInMethod);
  }

  // ── Read ────────────────────────────────────────────────────────────────

  bool   get hasSession    => uid.isNotEmpty;
  String get uid           => _prefs.getString(_kUid)          ?? '';
  bool   get isAdmin       => _prefs.getBool(_kIsAdmin)         ?? false;
  bool   get isAnonymous   => _prefs.getBool(_kIsAnonymous)     ?? false;
  String get email         => _prefs.getString(_kEmail)         ?? '';
  String get displayName   => _prefs.getString(_kDisplayName)   ?? '';
  String get photoUrl      => _prefs.getString(_kPhotoUrl)      ?? '';
  String get signInMethod  => _prefs.getString(_kSignInMethod)  ?? 'email';

  /// Returns the route the splash screen should navigate to based on
  /// the persisted session — called before Firebase resolves.
  ///
  ///   No session   → '/login'
  ///   Admin        → '/admin/dashboard'
  ///   Regular user → '/home'
  String get initialRoute {
    if (!hasSession)  return '/login';
    if (isAnonymous)  return '/home';
    if (isAdmin)      return '/admin/dashboard';
    return '/home';
  }
}