import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../models/book_model.dart';

/// Low-level Firestore operations.
/// Never called directly by UI — always through a Repository.
class FirestoreDataSource {
  FirestoreDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _books =>
      _firestore.collection(AppConstants.booksCollection);

  CollectionReference<Map<String, dynamic>> get _fcmTokens =>
      _firestore.collection(AppConstants.fcmTokensCollection);

  // ── Books ──────────────────────────────────────────────────────────────

  /// Real-time stream of published books, newest first.
  Stream<List<BookModel>> watchPublishedBooks({String? category}) {
    Query<Map<String, dynamic>> query = _books
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
      (snap) => snap.docs.map(BookModel.fromFirestore).toList(),
    );
  }

  /// One-time fetch (used for offline fallback or search).
  Future<List<BookModel>> fetchBooks({String? category}) async {
    Query<Map<String, dynamic>> query = _books
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    final snap = await query.get();
    return snap.docs.map(BookModel.fromFirestore).toList();
  }

  Future<BookModel?> fetchBookById(String id) async {
    final doc = await _books.doc(id).get();
    if (!doc.exists) return null;
    return BookModel.fromFirestore(doc);
  }

  /// Admin: create a new book document.
  /// Returns the auto-generated Firestore document ID.
  Future<String> addBook(BookModel book) async {
    final ref = _books.doc(); // auto-id
    final bookWithId = book.copyWith(id: ref.id);
    await ref.set(bookWithId.toFirestore());
    return ref.id;
  }

  Future<void> updateBook(BookModel book) async {
    await _books.doc(book.id).update({
      ...book.toFirestore(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBook(String id) async {
    await _books.doc(id).delete();
  }

  Future<void> togglePublish(String id, {required bool published}) async {
    await _books.doc(id).update({
      'is_published': published,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ── All books (admin view — includes unpublished) ──────────────────────

  Stream<List<BookModel>> watchAllBooks() {
    return _books
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BookModel.fromFirestore).toList());
  }

  // ── FCM Token Registry ─────────────────────────────────────────────────

  /// Saves a user's FCM token so the edge function can fan-out notifications.
  Future<void> saveOrUpdateFcmToken({
    required String userId,
    required String token,
    required String platform, // 'android' | 'ios'
  }) async {
    await _fcmTokens.doc(userId).set({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes a token on logout or token refresh.
  Future<void> deleteFcmToken(String userId) async {
    await _fcmTokens.doc(userId).delete();
  }

  /// Returns all active FCM tokens (used by the Supabase edge function caller).
  Future<List<String>> fetchAllFcmTokens() async {
    final snap = await _fcmTokens.get();
    return snap.docs
        .map((d) => d.data()['token'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
