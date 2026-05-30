// lib/features/settings/cubit/settings_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/settings_service.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._service)
      : super(SettingsState(
    language:             _service.language,
    fontScale:            _service.fontScale,
    newBookNotifications: _service.newBookNotifications,
    prayerReminder:       _service.prayerReminderEnabled,
    keepScreenOn:         _service.keepScreenOn,
    themeMode:            _service.themeMode,
  ));

  final SettingsService _service;

  Future<void> setLanguage(AppLanguage lang) async {
    await _service.setLanguage(lang);
    emit(state.copyWith(language: lang));
  }

  Future<void> setFontScale(FontScale fs) async {
    await _service.setFontScale(fs);
    emit(state.copyWith(fontScale: fs));
  }

  Future<void> toggleNewBookNotifications() async {
    final val = !state.newBookNotifications;
    await _service.setNewBookNotifications(val);
    emit(state.copyWith(newBookNotifications: val));
  }

  Future<void> togglePrayerReminder() async {
    final val = !state.prayerReminder;
    await _service.setPrayerReminderEnabled(val);
    emit(state.copyWith(prayerReminder: val));
  }

  Future<void> toggleKeepScreenOn() async {
    final val = !state.keepScreenOn;
    await _service.setKeepScreenOn(val);
    emit(state.copyWith(keepScreenOn: val));
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _service.setThemeMode(mode);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> resetAll() async {
    await _service.resetAll();
    emit(const SettingsState());
  }
}