// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Available app languages.
enum AppLanguage { arabic, greek }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.greek:
        return 'el';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.arabic:
        return 'العربية';
      case AppLanguage.greek:
        return 'Ελληνικά';
    }
  }

  String get flagEmoji {
    switch (this) {
      case AppLanguage.arabic:
        return '🇪🇬';
      case AppLanguage.greek:
        return '🇬🇷';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'ar':
        return AppLanguage.arabic;
      case 'el':
        return AppLanguage.greek;
      default:
        return AppLanguage.arabic;
    }
  }
}

/// Available font scale levels.
enum FontScale { small, medium, large, extraLarge }

extension FontScaleX on FontScale {
  String get label {
    switch (this) {
      case FontScale.small:
        return 'صغير';
      case FontScale.medium:
        return 'متوسط';
      case FontScale.large:
        return 'كبير';
      case FontScale.extraLarge:
        return 'كبير جداً';
    }
  }

  double get scale {
    switch (this) {
      case FontScale.small:
        return 0.85;
      case FontScale.medium:
        return 1.0;
      case FontScale.large:
        return 1.2;
      case FontScale.extraLarge:
        return 1.4;
    }
  }
}

/// Available app theme modes.
enum AppThemeMode { light, dark }

extension AppThemeModeX on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.light:
        return 'فاتح';
      case AppThemeMode.dark:
        return 'داكن';
    }
  }

  String get code {
    switch (this) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }

  static AppThemeMode fromCode(String code) {
    switch (code) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
      default:
        return AppThemeMode.dark;
    }
  }
}

class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  // ── Keys ─────────────────────────────────────────────────────────────────
  static const _kLanguage = 'pref_language';
  static const _kLanguageSelected = 'pref_language_selected';
  static const _kFontScale = 'pref_font_scale';
  static const _kNotifBooks = 'pref_notif_books';
  static const _kNotifReminders = 'pref_notif_reminders';
  static const _kPrayerReminder = 'pref_prayer_reminder';
  static const _kKeepScreen = 'pref_keep_screen';
  static const _kThemeMode = 'pref_theme_mode';
  static const _kOfflineMode = 'pref_offline_mode';

  // ── First-launch language selection ─────────────────────────────────────
  /// True once the user has explicitly chosen a language on first launch.
  bool get isLanguageSelected => _prefs.getBool(_kLanguageSelected) ?? false;

  Future<void> markLanguageSelected() =>
      _prefs.setBool(_kLanguageSelected, true);

  // ── Language ─────────────────────────────────────────────────────────────
  AppLanguage get language =>
      AppLanguageX.fromCode(_prefs.getString(_kLanguage) ?? 'ar');

  Future<void> setLanguage(AppLanguage lang) =>
      _prefs.setString(_kLanguage, lang.code);

  // ── Font scale ────────────────────────────────────────────────────────────
  FontScale get fontScale {
    final i = _prefs.getInt(_kFontScale) ?? 1;
    return FontScale.values[i.clamp(0, FontScale.values.length - 1)];
  }

  Future<void> setFontScale(FontScale fs) =>
      _prefs.setInt(_kFontScale, fs.index);

  // ── Notifications ─────────────────────────────────────────────────────────
  bool get newBookNotifications => _prefs.getBool(_kNotifBooks) ?? true;
  bool get prayerReminderEnabled => _prefs.getBool(_kNotifReminders) ?? false;

  Future<void> setNewBookNotifications(bool v) =>
      _prefs.setBool(_kNotifBooks, v);
  Future<void> setPrayerReminderEnabled(bool v) =>
      _prefs.setBool(_kNotifReminders, v);

  // ── Reading ───────────────────────────────────────────────────────────────
  bool get keepScreenOn => _prefs.getBool(_kKeepScreen) ?? true;

  Future<void> setKeepScreenOn(bool v) => _prefs.setBool(_kKeepScreen, v);

  // ── Theme mode ────────────────────────────────────────────────────────────
  AppThemeMode get themeMode =>
      AppThemeModeX.fromCode(_prefs.getString(_kThemeMode) ?? 'dark');

  Future<void> setThemeMode(AppThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.code);

  // ── Offline mode ──────────────────────────────────────────────────────────
  /// When true the app skips waiting for Firebase auth on startup and runs
  /// entirely from local/cached data.
  bool get offlineMode => _prefs.getBool(_kOfflineMode) ?? false;

  Future<void> setOfflineMode(bool v) => _prefs.setBool(_kOfflineMode, v);

  // ── Reset ─────────────────────────────────────────────────────────────────
  Future<void> resetAll() async {
    await _prefs.remove(_kLanguage);
    await _prefs.remove(_kLanguageSelected);
    await _prefs.remove(_kFontScale);
    await _prefs.remove(_kNotifBooks);
    await _prefs.remove(_kNotifReminders);
    await _prefs.remove(_kKeepScreen);
    await _prefs.remove(_kThemeMode);
    await _prefs.remove(_kOfflineMode);
  }
}
