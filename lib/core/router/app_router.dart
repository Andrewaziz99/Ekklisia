// lib/core/router/app_router.dart
// ─────────────────────────────────────────────────────────────────────────────
// Centralised routing — go_router with auth + admin guards.
//
// Route tree:
//   /                     SplashScreen
//   /login                LoginScreen
//   /home                 HomeScreen (reader, anonymous allowed)
//     book/:bookId        BookDetailScreen
//     pdf/:bookId         PdfViewerScreen
//   /admin                AdminShell  (requires isAdmin == true)
//     /admin              → redirects to /admin/dashboard
//     /admin/dashboard    AdminDashboardScreen
//     /admin/upload       UploadBookScreen
//     /admin/books        BooksManagerScreen
//     /admin/notify       AdminNotificationScreen
//     /admin/users        AdminUsersScreen
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../admin/admin_shell.dart';
import '../../admin/books/books_manager_screen.dart';
import '../../admin/books/upload_book_screen.dart';
import '../../admin/content/agbeya_manager.dart';
import '../../admin/content/bible_manager.dart';
import '../../admin/content/book_category_manager.dart';
import '../../admin/content/cms_additional_content.dart';
import '../../admin/content/daily_verse_manager.dart';
import '../../admin/content/game_manager_screen.dart';
import '../../admin/content/pdf_content_manager.dart';
import '../../data/models/pdf_content_model.dart';
import '../../admin/dashboard/dashboard_screen.dart';
import '../../admin/notifications/admin_notification_screen.dart';
import '../../admin/users/admin_users_screen.dart';
import '../../data/models/book_model.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/books/screens/book_detail_screen.dart';
import '../../features/books/screens/pdf_viewer_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/language_selection_screen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/books_repository.dart';
import '../../features/settings/settings_screen.dart';
import '../../services/settings_service.dart';


// ── Route constants ───────────────────────────────────────────────────────────
abstract class Routes {
  // Public
  static const String splash          = '/';
  static const String login           = '/login';
  static const String home            = '/home';

  // Onboarding
  static const String languageSelection = '/onboarding/language';

  // Admin
  static const String admin           = '/admin';
  static const String adminDashboard  = '/admin/dashboard';
  static const String adminUpload     = '/admin/upload';
  static const String adminBooks      = '/admin/books';
  static const String adminNotify     = '/admin/notify';
  static const String adminUsers      = '/admin/users';

  // CMS
  static const String adminCmsBibles      = '/admin/cms/bibles';
  static const String adminCmsHymns       = '/admin/cms/hymns';
  static const String adminCmsPrayers     = '/admin/cms/prayers';
  static const String adminCmsLiturgies   = '/admin/cms/liturgies';
  static const String adminCmsSaints      = '/admin/cms/saints';
  static const String adminCmsDailyVerse  = '/admin/cms/daily-verse';
  static const String adminCmsAgbeya      = '/admin/cms/agbeya';
  static const String adminCmsCategories  = '/admin/cms/categories';
  // PDF content managers
  static const String adminCmsPsalmody    = '/admin/cms/psalmody';
  static const String adminCmsReadings    = '/admin/cms/readings';
  static const String adminCmsOccasions   = '/admin/cms/occasions';
  static const String adminCmsGames       = '/admin/cms/games';

  // User content routes (pushed via Navigator, not go_router shell)
  static const String homeBible       = '/home/bible';
  static const String homePsalmody    = '/home/psalmody';
  static const String homeLiturgy     = '/home/liturgy';
  static const String homeReadings    = '/home/readings';
  static const String homeHymns       = '/home/hymns';
  static const String homeOccasions   = '/home/occasions';

  // Helpers
  static String bookDetailPath(String id) => '/home/book/$id';
  static String pdfViewerPath(String id)  => '/home/pdf/$id';

  // Settings
  static const String settings = '/settings';


}

// ── Router ────────────────────────────────────────────────────────────────────
class AppRouter {
  AppRouter._();

  static final _authNotifier = _AuthNotifier();

  static final GoRouter router = GoRouter(
    initialLocation:   Routes.splash,
    refreshListenable: _authNotifier,
    debugLogDiagnostics: true,

    // ── Global redirect guard ───────────────────────────────────────────
    redirect: (context, state) {
      final loc       = state.matchedLocation;
      final isReady   = _authNotifier.isReady;
      final loggedIn  = _authNotifier.isLoggedIn;
      final isAdmin   = _authNotifier.isAdmin;
      final isAnon    = _authNotifier.isAnonymous;

      // Wait on splash until Firebase resolves auth state
      if (!isReady) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      // ── Splash: check first-launch language selection ──────────────
      if (loc == Routes.splash) {
        final settingsService = sl<SettingsService>();
        if (!settingsService.isLanguageSelected) {
          return Routes.languageSelection;
        }
        return Routes.home;
      }

      // ── Language selection: skip if already done ───────────────────
      if (loc == Routes.languageSelection) {
        final settingsService = sl<SettingsService>();
        if (settingsService.isLanguageSelected) return Routes.home;
        return null;
      }

      // ── Admin routes: must be a real admin ─────────────────────────
      if (loc.startsWith('/admin')) {
        if (!loggedIn || isAnon)  return Routes.login;
        if (!isAdmin)             return Routes.home;
        // Bare /admin → dashboard
        if (loc == Routes.admin)  return Routes.adminDashboard;
        return null;
      }

      // ── Login page: already logged-in admins go to dashboard ───────
      if (loc == Routes.login) {
        if (loggedIn && !isAnon && isAdmin) return Routes.adminDashboard;
        if (loggedIn && !isAnon)            return Routes.home;
        return null;
      }

      return null;
    },

    routes: [
      // ── Splash ────────────────────────────────────────────────────────
      GoRoute(
        path:    Routes.splash,
        name:    'splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Language selection (first launch) ─────────────────────────────
      GoRoute(
        path:    Routes.languageSelection,
        name:    'languageSelection',
        builder: (_, __) => const LanguageSelectionScreen(),
      ),

      // ── Login ─────────────────────────────────────────────────────────
      GoRoute(
        path:    Routes.login,
        name:    'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Home (public, reader) ─────────────────────────────────────────
      GoRoute(
        path:    Routes.home,
        name:    'home',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path:    'book/:bookId',
            name:    'bookDetail',
            builder: (_, state) {
              final book   = state.extra as BookModel?;
              final bookId = state.pathParameters['bookId']!;
              return book != null
                  ? BookDetailScreen(book: book)
                  : _BookDetailLoader(bookId: bookId, openPdf: false);
            },
          ),
          GoRoute(
            path:    'pdf/:bookId',
            name:    'pdfViewer',
            builder: (_, state) {
              final book   = state.extra as BookModel?;
              final bookId = state.pathParameters['bookId']!;
              return book != null
                  ? PdfViewerScreen(book: book)
                  : _BookDetailLoader(bookId: bookId, openPdf: true);
            },
          ),
        ],
      ),

      // ── Admin shell (parent for all /admin/* routes) ──────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(
          child:       child,
          currentPath: state.matchedLocation,
        ),
        routes: [
          GoRoute(
            path:    Routes.adminDashboard,
            name:    'adminDashboard',
            builder: (_, __) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path:    Routes.adminUpload,
            name:    'adminUpload',
            builder: (_, __) => const UploadBookScreen(),
          ),
          GoRoute(
            path:    Routes.adminBooks,
            name:    'adminBooks',
            builder: (_, __) => const BooksManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminNotify,
            name:    'adminNotify',
            builder: (_, __) => const AdminNotificationScreen(),
          ),
          GoRoute(
            path:    Routes.adminUsers,
            name:    'adminUsers',
            builder: (_, __) => const AdminUsersScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsBibles,
            name:    'adminCmsBibles',
            builder: (_, __) => const BibleManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsHymns,
            name:    'adminCmsHymns',
            builder: (_, __) => PdfContentManagerScreen(
              category: PdfCategory.hymns,
              labelAr:  PdfCategory.labelAr[PdfCategory.hymns]!,
              labelEn:  'Hymns',
            ),
          ),
          GoRoute(
            path:    Routes.adminCmsPrayers,
            name:    'adminCmsPrayers',
            builder: (_, __) => const PrayersManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsLiturgies,
            name:    'adminCmsLiturgies',
            builder: (_, __) => PdfContentManagerScreen(
              category: PdfCategory.liturgy,
              labelAr:  PdfCategory.labelAr[PdfCategory.liturgy]!,
              labelEn:  'Liturgies',
            ),
          ),
          GoRoute(
            path:    Routes.adminCmsSaints,
            name:    'adminCmsSaints',
            builder: (_, __) => const SaintsManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsDailyVerse,
            name:    'adminCmsDailyVerse',
            builder: (_, __) => const DailyVerseManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsAgbeya,
            name:    'adminCmsAgbeya',
            builder: (_, __) => const AgbeyaManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsCategories,
            name:    'adminCmsCategories',
            builder: (_, __) => const BookCategoryManagerScreen(),
          ),
          GoRoute(
            path:    Routes.adminCmsPsalmody,
            name:    'adminCmsPsalmody',
            builder: (_, __) => PdfContentManagerScreen(
              category: PdfCategory.psalmody,
              labelAr:  PdfCategory.labelAr[PdfCategory.psalmody]!,
              labelEn:  'Psalmody',
            ),
          ),
          GoRoute(
            path:    Routes.adminCmsReadings,
            name:    'adminCmsReadings',
            builder: (_, __) => PdfContentManagerScreen(
              category: PdfCategory.readings,
              labelAr:  PdfCategory.labelAr[PdfCategory.readings]!,
              labelEn:  'Readings',
            ),
          ),
          GoRoute(
            path:    Routes.adminCmsOccasions,
            name:    'adminCmsOccasions',
            builder: (_, __) => PdfContentManagerScreen(
              category: PdfCategory.occasions,
              labelAr:  PdfCategory.labelAr[PdfCategory.occasions]!,
              labelEn:  'Occasions',
            ),
          ),
          GoRoute(
            path:    Routes.adminCmsGames,
            name:    'adminCmsGames',
            builder: (_, __) => const GameManagerScreen(),
          ),
        ],
      ),

      // ── Settings ─────────────────────────────
      GoRoute(
        path:    Routes.settings,
        name:    'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],

    // ── Error page ────────────────────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✦', style: TextStyle(
              color: Color(0xFF8B7035), fontSize: 32)),
          const SizedBox(height: 16),
          Text('Page not found',
              style: const TextStyle(color: Color(0xFFA89060), fontSize: 14)),
          const SizedBox(height: 4),
          Text(state.error?.message ?? '',
              style: const TextStyle(
                  color: Color(0xFF6B5830), fontSize: 11)),
        ]),
      ),
    ),
  );
}

// ── Auth state notifier ───────────────────────────────────────────────────────
// Listens to FirebaseAuth and exposes flags the redirect guard reads.
// Refreshes the router on every auth-state change.

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  bool _isReady    = false;
  bool _isLoggedIn = false;
  bool _isAdmin    = false;
  bool _isAnon     = false;

  bool get isReady     => _isReady;
  bool get isLoggedIn  => _isLoggedIn;
  bool get isAdmin     => _isAdmin;
  bool get isAnonymous => _isAnon;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _isReady = true; _isLoggedIn = false;
      _isAdmin = false; _isAnon = false;
    } else {
      _isLoggedIn = true;
      _isAnon     = user.isAnonymous;
      _isAdmin    = false;

      if (!user.isAnonymous) {
        // Check custom claim first (fast), then Firestore fallback
        try {
          final token = await user.getIdTokenResult(false);
          _isAdmin = token.claims?['admin'] == true;
        } catch (_) {
          _isAdmin = false;
        }

        if (!_isAdmin) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection(AppConstants.usersCollection)
                .doc(user.uid)
                .get();
            _isAdmin = doc.data()?['is_admin'] == true;
          } catch (_) {
            _isAdmin = false;
          }
        }
      }
      _isReady = true;
    }
    // Defer to next frame — Firebase can emit the cached auth state during
    // widget-tree finalisation, and calling notifyListeners() then triggers
    // the go_router redirect while the navigator is locked (!_debugLocked).
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  /// Called from AuthCubit after a successful sign-in to force-refresh
  /// admin status without waiting for the next authStateChanges event.
  Future<void> refreshAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final token = await user.getIdTokenResult(true); // force refresh
      _isAdmin = token.claims?['admin'] == true;
      if (!_isAdmin) {
        final doc = await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        _isAdmin = doc.data()?['is_admin'] == true;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } catch (_) {}
  }
}

// ── Fallback loader when book deep-link arrives without `extra` ───────────────
class _BookDetailLoader extends StatelessWidget {
  const _BookDetailLoader({this.bookId = '', this.openPdf = false});
  final String bookId;
  final bool openPdf;

  @override
  Widget build(BuildContext context) {
    if (bookId.trim().isEmpty) {
      return const _MessageScaffold(
        title: 'Invalid book link',
        message: 'No book id was provided for this link.',
      );
    }
    final repo = sl<BooksRepository>();
    return FutureBuilder<BookModel?>(
      future: repo.fetchBookById(bookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _LoadingScaffold(bookId: bookId);
        }
        if (snapshot.hasError) {
          return _MessageScaffold(
            title: 'Unable to load book',
            message: snapshot.error.toString(),
          );
        }
        final book = snapshot.data;
        if (book == null) {
          return const _MessageScaffold(
            title: 'Book not found',
            message: 'This book is no longer available.',
          );
        }
        return openPdf
            ? PdfViewerScreen(book: book)
            : BookDetailScreen(book: book);
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFC8A84B)),
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text('Loading $bookId…',
              style: const TextStyle(
                  color: Color(0xFFA89060), fontSize: 12)),
        ]),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFA89060), fontSize: 14)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF6B5830), fontSize: 11)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back',
                style: TextStyle(color: Color(0xFFC8A84B))),
          ),
        ]),
      ),
    );
  }
}
