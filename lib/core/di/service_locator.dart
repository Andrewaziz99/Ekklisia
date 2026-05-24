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
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/datasources/firebase/firestore_datasource.dart';
import '../../data/repositories/books_repository.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

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

    // ── Services ──────────────────────────────────────────────────────────
    sl.registerLazySingleton<AuthService>(
      () => AuthService(
        firebaseAuth: sl<FirebaseAuth>(),
        firestore:    sl<FirebaseFirestore>(),
      ),
    );
    sl.registerLazySingleton<NotificationService>(
      () => NotificationService(
        messaging: sl<FirebaseMessaging>(),
        supabase: sl<SupabaseClient>(),
      ),
    );
  }
}
