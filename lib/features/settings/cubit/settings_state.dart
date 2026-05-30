// lib/features/settings/cubit/settings_state.dart
import 'package:equatable/equatable.dart';
import '../../../services/settings_service.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.language            = AppLanguage.arabic,
    this.fontScale           = FontScale.medium,
    this.newBookNotifications = true,
    this.prayerReminder      = false,
    this.keepScreenOn        = true,
    this.themeMode           = AppThemeMode.dark,
  });

  final AppLanguage language;
  final FontScale   fontScale;
  final bool        newBookNotifications;
  final bool        prayerReminder;
  final bool        keepScreenOn;
  final AppThemeMode themeMode;

  SettingsState copyWith({
    AppLanguage? language,
    FontScale?   fontScale,
    bool?        newBookNotifications,
    bool?        prayerReminder,
    bool?        keepScreenOn,
    AppThemeMode? themeMode,
  }) => SettingsState(
    language:             language             ?? this.language,
    fontScale:            fontScale            ?? this.fontScale,
    newBookNotifications: newBookNotifications ?? this.newBookNotifications,
    prayerReminder:       prayerReminder       ?? this.prayerReminder,
    keepScreenOn:         keepScreenOn         ?? this.keepScreenOn,
    themeMode:            themeMode            ?? this.themeMode,
  );

  @override
  List<Object?> get props => [
    language, fontScale,
    newBookNotifications, prayerReminder, keepScreenOn, themeMode,
  ];
}