// lib/features/settings/cubit/settings_state.dart
import 'package:equatable/equatable.dart';
import '../../../services/settings_service.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.language             = AppLanguage.arabic,
    this.isLanguageSelected   = false,
    this.fontScale            = FontScale.medium,
    this.newBookNotifications = true,
    this.prayerReminder       = false,
    this.keepScreenOn         = true,
    this.themeMode            = AppThemeMode.dark,
    this.offlineMode          = false,
  });

  final AppLanguage  language;
  final bool         isLanguageSelected;
  final FontScale    fontScale;
  final bool         newBookNotifications;
  final bool         prayerReminder;
  final bool         keepScreenOn;
  final AppThemeMode themeMode;
  final bool         offlineMode;

  SettingsState copyWith({
    AppLanguage?  language,
    bool?         isLanguageSelected,
    FontScale?    fontScale,
    bool?         newBookNotifications,
    bool?         prayerReminder,
    bool?         keepScreenOn,
    AppThemeMode? themeMode,
    bool?         offlineMode,
  }) => SettingsState(
    language:             language             ?? this.language,
    isLanguageSelected:   isLanguageSelected   ?? this.isLanguageSelected,
    fontScale:            fontScale            ?? this.fontScale,
    newBookNotifications: newBookNotifications ?? this.newBookNotifications,
    prayerReminder:       prayerReminder       ?? this.prayerReminder,
    keepScreenOn:         keepScreenOn         ?? this.keepScreenOn,
    themeMode:            themeMode            ?? this.themeMode,
    offlineMode:          offlineMode          ?? this.offlineMode,
  );

  @override
  List<Object?> get props => [
    language, isLanguageSelected, fontScale,
    newBookNotifications, prayerReminder, keepScreenOn, themeMode, offlineMode,
  ];
}