// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Available app languages.
enum AppLanguage { arabic, coptic, greek, english }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.arabic:  return 'ar';
      case AppLanguage.coptic:  return 'cop';
      case AppLanguage.greek:   return 'el';
      case AppLanguage.english: return 'en';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.arabic:  return 'العربية';
      case AppLanguage.coptic:  return 'ⲙⲉⲧⲣⲉⲙⲛ̀ⲭⲏⲙⲓ';
      case AppLanguage.greek:   return 'Ελληνικά';
      case AppLanguage.english: return 'English';
    }
  }

  String get flagEmoji {
    switch (this) {
      case AppLanguage.arabic:  return '🇸🇦';
      case AppLanguage.coptic:  return '🇪🇬';
      case AppLanguage.greek:   return '🇬🇷';
      case AppLanguage.english: return '🇬🇧';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'ar':  return AppLanguage.arabic;
      case 'cop': return AppLanguage.coptic;
      case 'el':  return AppLanguage.greek;
      default:    return AppLanguage.arabic;
    }
  }
}

/// Available font scale levels.
enum FontScale { small, medium, large, extraLarge }

extension FontScaleX on FontScale {
  String get label {
    switch (this) {
      case FontScale.small:      return 'صغير';
      case FontScale.medium:     return 'متوسط';
      case FontScale.large:      return 'كبير';
      case FontScale.extraLarge: return 'كبير جداً';
    }
  }

  double get scale {
    switch (this) {
      case FontScale.small:      return 0.85;
      case FontScale.medium:     return 1.0;
      case FontScale.large:      return 1.2;
      case FontScale.extraLarge: return 1.4;
    }
  }
}

class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  // ── Keys ─────────────────────────────────────────────────────────────────
  static const _kLanguage       = 'pref_language';
  static const _kFontScale      = 'pref_font_scale';
  static const _kNotifBooks     = 'pref_notif_books';
  static const _kNotifReminders = 'pref_notif_reminders';
  static const _kPrayerReminder = 'pref_prayer_reminder';
  static const _kKeepScreen     = 'pref_keep_screen';

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
  bool get newBookNotifications     => _prefs.getBool(_kNotifBooks)     ?? true;
  bool get prayerReminderEnabled    => _prefs.getBool(_kNotifReminders) ?? false;

  Future<void> setNewBookNotifications(bool v) =>
      _prefs.setBool(_kNotifBooks, v);
  Future<void> setPrayerReminderEnabled(bool v) =>
      _prefs.setBool(_kNotifReminders, v);

  // ── Reading ───────────────────────────────────────────────────────────────
  bool get keepScreenOn => _prefs.getBool(_kKeepScreen) ?? true;

  Future<void> setKeepScreenOn(bool v) => _prefs.setBool(_kKeepScreen, v);

  // ── Reset ─────────────────────────────────────────────────────────────────
  Future<void> resetAll() async {
    await _prefs.remove(_kLanguage);
    await _prefs.remove(_kFontScale);
    await _prefs.remove(_kNotifBooks);
    await _prefs.remove(_kNotifReminders);
    await _prefs.remove(_kKeepScreen);
  }
}