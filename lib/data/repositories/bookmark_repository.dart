// lib/data/repositories/bookmark_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Per-user bookmarks (PDF content items/pages + Bible chapters/verses).
// Every user is signed in anonymously (see auth_service.dart), so a uid is
// always available or obtainable — callers never need to pass one in.
//
// Doc ids are deterministic (built from uid + reference), so "bookmark this"
// is idempotent and a plain toggle: if the doc exists, remove it; otherwise
// create it. That also means watching a single doc's existence is enough to
// drive a live bookmark icon, with no composite query needed.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/bookmark_model.dart';

class BookmarkRepository {
  BookmarkRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('bookmarks');

  Future<String> _uid() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  String _contentDocId(String uid, String contentId, int page) => page > 0
      ? '${uid}_content_${contentId}_p$page'
      : '${uid}_content_$contentId';

  String _bibleDocId(String uid, int bookNumber, int chapter, int verse) =>
      verse > 0
          ? '${uid}_bible_${bookNumber}_${chapter}_v$verse'
          : '${uid}_bible_${bookNumber}_$chapter';

  // ── Read ──────────────────────────────────────────────────────────────────

  /// All of the current user's bookmarks, newest first.
  ///
  /// Sorted client-side (not via Firestore `orderBy`) so this doesn't need a
  /// composite index — a `where` on one field plus `orderBy` on another
  /// requires one, and a missing index makes the query fail silently from
  /// the UI's point of view (the stream just never emits data). Per-user
  /// bookmark counts are small, so sorting a few dozen docs in memory is
  /// effectively free.
  Stream<List<BookmarkModel>> watchAll() async* {
    final uid = await _uid();
    yield* _col
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(BookmarkModel.fromFirestore).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<bool> watchIsContentBookmarked({
    required String contentId,
    int page = 0,
  }) async* {
    final uid = await _uid();
    yield* _col
        .doc(_contentDocId(uid, contentId, page))
        .snapshots()
        .map((d) => d.exists);
  }

  Stream<bool> watchIsBibleBookmarked({
    required int bookNumber,
    required int chapter,
    int verse = 0,
  }) async* {
    final uid = await _uid();
    yield* _col
        .doc(_bibleDocId(uid, bookNumber, chapter, verse))
        .snapshots()
        .map((d) => d.exists);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Toggles a content bookmark on/off. Returns true if it is now bookmarked.
  Future<bool> toggleContentBookmark({
    required String contentId,
    required String category,
    required String titleAr,
    required String titleEl,
    String coverUrl = '',
    String pdfUrl = '',
    int page = 0,
  }) async {
    final uid = await _uid();
    final ref = _col.doc(_contentDocId(uid, contentId, page));
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set(
      BookmarkModel(
        id: ref.id,
        userId: uid,
        type: BookmarkType.content,
        contentId: contentId,
        category: category,
        page: page,
        titleAr: titleAr,
        titleEl: titleEl,
        coverUrl: coverUrl,
        pdfUrl: pdfUrl,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    return true;
  }

  /// Toggles a Bible chapter/verse bookmark on/off. Returns true if it is
  /// now bookmarked.
  Future<bool> toggleBibleBookmark({
    required int bookNumber,
    required String bookNameAr,
    required String bookNameEl,
    required int chapter,
    int verse = 0,
    String textAr = '',
    String textEl = '',
  }) async {
    final uid = await _uid();
    final ref = _col.doc(_bibleDocId(uid, bookNumber, chapter, verse));
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set(
      BookmarkModel(
        id: ref.id,
        userId: uid,
        type: BookmarkType.bible,
        bookNumber: bookNumber,
        bookNameAr: bookNameAr,
        bookNameEl: bookNameEl,
        chapter: chapter,
        verse: verse,
        textAr: textAr,
        textEl: textEl,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    return true;
  }

  Future<void> remove(String bookmarkId) => _col.doc(bookmarkId).delete();
}
