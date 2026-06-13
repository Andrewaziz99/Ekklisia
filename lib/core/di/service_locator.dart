// lib/core/di/service_locator.dart
// ─────────────────────────────────────────────────────────────────────────────
// Service Locator — registers every singleton and factory the app needs.
// Call ServiceLocator.init() once in main.dart before runApp().
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/auth_cubit.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/datasources/firebase/firestore_datasource.dart';
import '../../data/repositories/agbeya_repository.dart';
import '../../data/repositories/bible_repository.dart';
import '../../data/repositories/book_category_repository.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/pdf_content_repository.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/repositories/daily_verse_repository.dart';
import '../../data/repositories/saints_repository.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/session_service.dart';
import '../../features/settings/cubit/settings_cubit.dart';

final sl = GetIt.instance;

class ServiceLocator {
  ServiceLocator._();

  static Future<void> init() async {
    // ── External / Platform ──────────────────────────────────────────────
    sl.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );
    sl.registerLazySingleton<FirebaseAuth>(
      () => FirebaseAuth.instance,
    );
    sl.registerLazySingleton<FirebaseMessaging>(
      () => FirebaseMessaging.instance,
    );
    sl.registerLazySingleton<SupabaseClient>(
      () => Supabase.instance.client,
    );

    final prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(prefs);

    // ── Google Sign-In ────────────────────────────────────────────────────────
    // GoogleSignIn.instance provides platform-specific initialization
    sl.registerLazySingleton<GoogleSignIn>(
      () => GoogleSignIn(
        scopes: ['email', 'profile'],
        // Optional: specify clientId for web (from Google Cloud Console)
        //
      ),
    );

    // ── Dio HTTP Client ───────────────────────────────────────────────────
    sl.registerLazySingleton<Dio>(() {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ));
      // Logging interceptor (debug only)
      assert(() {
        dio.interceptors.add(LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) => print('[Dio] $obj'),
        ));
        return true;
      }());
      return dio;
    });

    // ── Data Sources ──────────────────────────────────────────────────────
    sl.registerLazySingleton<FirestoreDataSource>(
      () => FirestoreDataSource(sl<FirebaseFirestore>()),
    );
    sl.registerLazySingleton<CloudinaryDataSource>(
      () => CloudinaryDataSource(sl<Dio>()),
    );

    // ── Repositories ──────────────────────────────────────────────────────
    sl.registerLazySingleton<BooksRepository>(
      () => BooksRepository(
        firestoreDataSource: sl<FirestoreDataSource>(),
        cloudinaryDataSource: sl<CloudinaryDataSource>(),
      ),
    );
    sl.registerLazySingleton<DailyVerseRepository>(
      () => DailyVerseRepository(sl<FirebaseFirestore>()),
    );
    sl.registerLazySingleton<AgbeyaRepository>(
      () => AgbeyaRepository(sl<FirebaseFirestore>()),
    );
    sl.registerLazySingleton<BookCategoryRepository>(
      () => BookCategoryRepository(sl<FirebaseFirestore>()),
    );
    sl.registerLazySingleton<PdfContentRepository>(
      () => PdfContentRepository(sl<FirebaseFirestore>()),
    );
    sl.registerLazySingleton<GameRepository>(
      () => GameRepository(sl<FirebaseFirestore>()),
    );
    sl.registerLazySingleton<SaintsRepository>(
      () => SaintsRepository(sl<FirebaseFirestore>()),
    );

    // Configure BibleRepository singleton with Firestore + Dio so admin
    // features (remote XML, verse overrides) work after DI is ready.
    BibleRepository.instance.configure(
      sl<FirebaseFirestore>(),
      sl<Dio>(),
    );

    // ── Services ──────────────────────────────────────────────────────────
    sl.registerLazySingleton<AuthService>(
      () => AuthService(
        firebaseAuth: sl<FirebaseAuth>(),
        firestore:    sl<FirebaseFirestore>(),
        session:      sl<SessionService>(),
        googleSignIn: sl<GoogleSignIn>(),
      ),
    );
    sl.registerLazySingleton<NotificationService>(
      () => NotificationService(
        messaging: sl<FirebaseMessaging>(),
        supabase: sl<SupabaseClient>(),
      ),
    );
    sl.registerLazySingleton<SettingsService>(
      () => SettingsService(sl<SharedPreferences>()),
    );

    // ── Cubits ────────────────────────────────────────────────────────────
    sl.registerSingleton<SessionService>(
      SessionService(sl<SharedPreferences>()),
    );
    sl.registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(sl<SettingsService>()),
    );
    sl.registerFactory<AuthCubit>(
      () => AuthCubit(sl<AuthService>(), sl<SessionService>()),
    );

    await sl.allReady();
  }
}
