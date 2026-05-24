// lib/app.dart
// ─────────────────────────────────────────────────────────────────────────────
// Root application widget.
//
// Provides at the very top of the widget tree:
//   • AuthCubit   — must be above LoginScreen and AdminShell
//   • BooksCubit  — used by both HomeScreen and AdminDashboardScreen
//
// Also wires:
//   • go_router   (AppRouter)
//   • Ekklecia dark theme
//   • Arabic / Coptic / Greek localisation delegates
//   • Notification tap handler → deep-link to tapped book
//   • FCM token registration on first launch
// ─────────────────────────────────────────────────────────────────────────────
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'data/repositories/books_repository.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/auth_state.dart';
import 'features/books/cubit/books_cubit.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

class EkkleiciaApp extends StatefulWidget {
  const EkkleiciaApp({super.key});

  @override
  State<EkkleiciaApp> createState() => _EkkleiciaAppState();
}

class _EkkleiciaAppState extends State<EkkleiciaApp> {
  final _notificationService = sl<NotificationService>();
  final _booksRepository     = sl<BooksRepository>();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await _notificationService.init();

    // Navigate to the tapped book when user opens a push notification
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

    final platform =
        Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    await _booksRepository.saveOrUpdateFcmToken(
      userId:   userId,
      token:    token,
      platform: platform,
    );

    await _notificationService.subscribeToTopic('new_books');
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // ── AuthCubit: top-level so LoginScreen + AdminShell can find it ──
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(sl<AuthService>()),
          lazy: false,   // start listening to authStateChanges immediately
        ),

        // ── BooksCubit: shared between HomeScreen and AdminDashboard ──────
        BlocProvider<BooksCubit>(
          create: (_) => BooksCubit(sl<BooksRepository>())..watchBooks(),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        // When auth state changes, tell the router notifier to re-evaluate
        // the admin flag (handles sign-in / sign-out without page reload).
        listenWhen: (prev, curr) =>
            prev.isAdmin != curr.isAdmin ||
            prev.isAuthenticated != curr.isAuthenticated,
        listener: (_, state) async {
          if (state.isAdmin) {
            AppRouter.router.refresh();
          }
        },
        child: MaterialApp.router(
          title:                    'إكليسيا',
          debugShowCheckedModeBanner: false,

          // ── Router ──────────────────────────────────────────────────────
          routerConfig: AppRouter.router,

          // ── Theme ────────────────────────────────────────────────────────
          theme:     EkkleciaTheme.darkTheme,
          themeMode: ThemeMode.dark,

          // ── Localisation ─────────────────────────────────────────────────
          locale: const Locale('ar'),
          supportedLocales: const [
            Locale('ar'),
            Locale('el'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // ── RTL (Arabic) ──────────────────────────────────────────────────
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
