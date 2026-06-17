// lib/app.dart — ALTERNATIVE VERSION using BlocBuilder
// Use this if context.select() isn't reliably picking up font scale changes
import 'package:ekklicia/services/session_service.dart';
import 'package:ekklicia/services/settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'data/repositories/books_repository.dart';
import 'data/repositories/daily_verse_repository.dart';
import 'features/agbeya/cubit/audio_player_cubit.dart';
import 'features/auth/auth_cubit.dart';
import 'features/books/cubit/books_cubit.dart';
import 'features/daily_verse/daily_verse_cubit.dart';
import 'features/settings/cubit/settings_cubit.dart';
import 'features/settings/cubit/settings_state.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

class EkklisiaApp extends StatefulWidget {
  const EkklisiaApp({super.key});

  @override
  State<EkklisiaApp> createState() => _EkklisiaAppState();
}

class _EkklisiaAppState extends State<EkklisiaApp> {
  final _notificationService = sl<NotificationService>();
  final _booksRepository = sl<BooksRepository>();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _notificationService.init();
    _notificationService.onNotificationTap = (bookId) {
      AppRouter.router.push('/home/book/$bookId');
    };
    await _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    final token = _notificationService.fcmToken;
    if (token == null) return;

    String userId;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      userId = cred.user!.uid;
    }

    if (!mounted) return;

    final platform = Theme.of(context).platform == TargetPlatform.iOS
        ? 'ios'
        : 'android';

    await _booksRepository.saveOrUpdateFcmToken(
      userId: userId,
      token: token,
      platform: platform,
    );

    await _notificationService.subscribeToTopic('new_books');
    await _notificationService.subscribeToTopic('daily_verse');
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(sl<AuthService>(), sl<SessionService>()),
          lazy: false,
        ),
        BlocProvider<BooksCubit>(
          create: (_) => BooksCubit(sl<BooksRepository>())..watchBooks(),
        ),
        BlocProvider<SettingsCubit>(
          create: (_) => sl<SettingsCubit>(),
          lazy: false,
        ),
        BlocProvider<DailyVerseCubit>(
          create: (_) =>
              DailyVerseCubit(sl<DailyVerseRepository>())..loadTodayVerse(),
          lazy: false,
        ),
        // Global audio player — singleton so state persists across all screens
        BlocProvider<AudioPlayerCubit>(
          create: (_) => sl<AudioPlayerCubit>(),
          lazy: false,
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        bloc: sl<SettingsCubit>(),
        builder: (context, settings) {
          // Determine theme mode from settings
          final themeMode = settings.themeMode == AppThemeMode.light
              ? ThemeMode.light
              : ThemeMode.dark;

          // Determine locale and text direction from selected language
          final locale = _localeFromLanguage(settings.language);
          final textDir = _textDirFromLanguage(settings.language);

          return MaterialApp.router(
            title: 'إكليسيا',
            debugShowCheckedModeBanner: false,
            routerConfig: AppRouter.router,

            // Use dynamic theme builders
            theme: EkklisiaTheme.buildTheme(Brightness.light),
            darkTheme: EkklisiaTheme.buildTheme(Brightness.dark),
            themeMode: themeMode,

            locale: locale,
            supportedLocales: const [Locale('ar'), Locale('el'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              final isLight = brightness == Brightness.light;

              // Update system UI colors based on current theme
              _updateSystemUIOverlay(brightness);

              return Directionality(
                textDirection: textDir,
                child: Container(
                  decoration: isLight
                      ? EkklisiaTheme.lightBackgroundDecoration
                      : null,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(settings.fontScale.scale),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Returns the [Locale] for the given [AppLanguage].
  static Locale _localeFromLanguage(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.greek:
        return const Locale('el');
      case AppLanguage.arabic:
        return const Locale('ar');
    }
  }

  /// Returns LTR for Greek/English, RTL for Arabic/Coptic.
  static TextDirection _textDirFromLanguage(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.greek:
        return TextDirection.ltr;
      case AppLanguage.arabic:
        return TextDirection.rtl;
    }
  }

  /// Update system UI overlay (status bar, nav bar) based on brightness
  void _updateSystemUIOverlay(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDark
            ? const Color(0xFF08111C) // Dark: bgDeep
            : const Color(0xFFFAF8F4), // Light: lightBgDeep
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? const Color(0xFF08111C) // Dark: bgDeep
            : const Color(0xFFFAF8F4), // Light: lightBgDeep
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }
}
