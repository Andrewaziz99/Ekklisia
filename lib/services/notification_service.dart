import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../data/models/book_model.dart';

/// Top-level handler required by Firebase — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised in main.dart before this fires.
  debugPrint('[FCM Background] ${message.notification?.title}');
}

/// Centralised notification service.
///
/// Responsibilities:
///   1. Request permission + obtain FCM token
///   2. Show local notifications for foreground FCM messages
///   3. Trigger server-side push via Supabase edge function (admin only)
///   4. Handle notification tap navigation
class NotificationService {
  NotificationService({
    required FirebaseMessaging messaging,
    required SupabaseClient supabase,
  }) : _messaging = messaging,
       _supabase = supabase;

  final FirebaseMessaging _messaging;
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callbacks
  void Function(String bookId)? onNotificationTap;

  // ── Initialise ─────────────────────────────────────────────────────────

  Future<void> init() async {
    // 1. Local notifications channel setup
    const androidNewBook = AndroidNotificationChannel(
      AppConstants.newBookChannelId,
      AppConstants.newBookChannelName,
      description: AppConstants.newBookChannelDesc,
      importance: Importance.high,
      playSound: true,
    );

    const androidDailyVerse = AndroidNotificationChannel(
      AppConstants.dailyVerseChannelId,
      AppConstants.dailyVerseChannelName,
      description: AppConstants.dailyVerseChannelDesc,
      importance: Importance.high,
      playSound: true,
    );

    final androidImpl = _localPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.createNotificationChannel(androidNewBook);
    await androidImpl?.createNotificationChannel(androidDailyVerse);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 2. Request FCM permission
    await _requestPermission();

    // 3. Get token
    _fcmToken = await _messaging.getToken();
    debugPrint('[FCM] Token: $_fcmToken');

    // Refresh token listener
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      // Caller should save this to Firestore
    });

    // 4. Subscribe to the daily verse topic so this device receives 9AM pushes
    await _messaging.subscribeToTopic(AppConstants.dailyVerseTopic);
    debugPrint('[FCM] Subscribed to: ${AppConstants.dailyVerseTopic}');

    // 5. Register background handler (top-level)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 6. Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Notification open handler (app in background, user taps)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // 7. Check if app was opened from a terminated state via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationOpen(initial);
  }

  // ── Permission ─────────────────────────────────────────────────────────

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    return granted;
  }

  // ── Foreground Message ─────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final isDailyVerse = message.data['type'] == 'daily_verse';

    final channelId   = isDailyVerse
        ? AppConstants.dailyVerseChannelId
        : AppConstants.newBookChannelId;
    final channelName = isDailyVerse
        ? AppConstants.dailyVerseChannelName
        : AppConstants.newBookChannelName;
    final channelDesc = isDailyVerse
        ? AppConstants.dailyVerseChannelDesc
        : AppConstants.newBookChannelDesc;

    _localPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
          // Replace any earlier verse notification with the latest one
          tag: isDailyVerse ? 'daily_verse' : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Notification Tap ───────────────────────────────────────────────────

  void _handleNotificationOpen(RemoteMessage message) {
    final bookId = message.data['book_id'] as String?;
    if (bookId != null && bookId.isNotEmpty) {
      onNotificationTap?.call(bookId);
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final bookId = data['book_id'] as String?;
      if (bookId != null && bookId.isNotEmpty) {
        onNotificationTap?.call(bookId);
      }
    } catch (_) {}
  }

  // ── Admin: Send Push Notification ──────────────────────────────────────

  /// Triggers the Supabase `send-notifications` edge function.
  /// This function fetches all FCM tokens from Firestore and fans out
  /// the notification via Firebase Admin SDK on the server side.
  ///
  /// Call this immediately after [BooksRepository.addBook] succeeds.
  Future<void> sendNewBookNotification({
    required BookModel book,
    required List<String> fcmTokens,
    String? topic,
    String? title,
    String? body,
  }) async {
    final hasTopic = topic != null && topic.trim().isNotEmpty;
    if (fcmTokens.isEmpty && !hasTopic) {
      debugPrint('[Notifications] No FCM tokens or topic — skipping push.');
      return;
    }

    final resolvedTitle = _resolveNotificationTitle(book, title);
    final resolvedBody  = _resolveNotificationBody(book, body);
    final hasBookId     = book.id.trim().isNotEmpty;

    final data = <String, String>{
      if (hasBookId) 'type': 'new_book',
      if (hasBookId) 'book_id': book.id,
      if (hasBookId && book.category.trim().isNotEmpty)
        'category': book.category,
      if (hasBookId && book.coverUrl.trim().isNotEmpty)
        'cover_url': book.coverUrl,
    };

    final session = _supabase.auth.currentSession;
    final accessToken = session?.accessToken;

    try {
      await _supabase.functions.invoke(
        AppConstants.sendNotificationsFunction,
        body: {
          'title': resolvedTitle,
          'body': resolvedBody,
          if (fcmTokens.isNotEmpty) 'tokens': fcmTokens,
          if (hasTopic) 'topic': topic,
          if (data.isNotEmpty) 'data': data,
        },
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConstants.supabaseAnonKey,
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );
      if (fcmTokens.isNotEmpty) {
        debugPrint('[Notifications] Push sent to ${fcmTokens.length} devices.');
      } else {
        debugPrint('[Notifications] Push sent to topic: $topic');
      }
    } catch (e) {
      debugPrint('[Notifications] Edge function error: $e');
      rethrow;
    }
  }

  String _resolveNotificationTitle(BookModel book, String? title) {
    final custom = title?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final fallback = book.titleAr.trim().isNotEmpty
        ? book.titleAr.trim()
        : (book.titleCop.trim().isNotEmpty
            ? book.titleCop.trim()
            : (book.titleEl.trim().isNotEmpty
                ? book.titleEl.trim()
                : 'كتاب جديد'));
    return '📖 $fallback';
  }

  String _resolveNotificationBody(BookModel book, String? body) {
    final custom = body?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    if (book.descriptionAr.trim().isNotEmpty) {
      return book.descriptionAr.trim();
    }
    return 'كتاب جديد متاح الآن في المكتبة';
  }

  // ── Topic Subscription ─────────────────────────────────────────────────

  /// Subscribe device to a topic (e.g. 'new_books', 'category_bible').
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}