// lib/data/repositories/agbeya_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Firestore repository for the Agbeya (Coptic Book of Hours).
//
// Collection: agbeya_hours
//   • Display order comes from sort_order (drag-to-reorder in the admin CMS),
//     falling back to hour_number for documents written before that field
//     existed — see AgbeyaHour.fromFirestore.
//   • The underlying Firestore query still orders by hour_number, which every
//     document is guaranteed to have; sort_order is applied client-side so a
//     document that hasn't been backfilled yet never silently drops out of
//     an orderBy('sort_order') query.
//   • Only published hours are exposed to the app.
//
// Audio files live on Cloudinary; only the URL is stored here.
// Upload them via the Admin CMS (same flow as PDF books).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/agbeya_model.dart';

class AgbeyaRepository {
  AgbeyaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('agbeya_hours');

  /// Fixed document ID for the singleton "whole Agbeya book" entry — stored
  /// in the same collection as the 7 canonical hours (so it can reuse the
  /// exact same model/upload/reader flow) but always excluded from the
  /// numbered hour lists below by filtering out this one ID.
  static const String wholeBookDocId = 'whole_book';

  DocumentReference<Map<String, dynamic>> get _wholeBookRef =>
      _col.doc(wholeBookDocId);

  /// Ascending by sortOrder, tie-broken by hourNumber for determinism.
  List<AgbeyaHour> _bySortOrder(List<AgbeyaHour> hours) {
    final sorted = [...hours];
    sorted.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.hourNumber.compareTo(b.hourNumber);
    });
    return sorted;
  }

  List<AgbeyaHour> _excludingWholeBook(Iterable<AgbeyaHour> hours) =>
      hours.where((h) => h.id != wholeBookDocId).toList();

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Real-time stream of ALL hours (published + drafts) — admin only.
  Stream<List<AgbeyaHour>> watchAllHours() => _col
      .orderBy('hour_number')
      .snapshots()
      .map((snap) => _bySortOrder(
          _excludingWholeBook(snap.docs.map(AgbeyaHour.fromFirestore))));

  /// Real-time stream of published hours ordered by [sortOrder].
  Stream<List<AgbeyaHour>> watchPublishedHours() => _col
      .where('is_published', isEqualTo: true)
      .orderBy('hour_number')
      .snapshots()
      .map((snap) => _bySortOrder(
          _excludingWholeBook(snap.docs.map(AgbeyaHour.fromFirestore))));

  /// One-time fetch (useful for offline-first or initial load).
  Future<List<AgbeyaHour>> fetchHours() async {
    final snap = await _col
        .where('is_published', isEqualTo: true)
        .orderBy('hour_number')
        .get();
    return _bySortOrder(
        _excludingWholeBook(snap.docs.map(AgbeyaHour.fromFirestore)));
  }

  Future<AgbeyaHour?> fetchHourById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AgbeyaHour.fromFirestore(doc);
  }

  // ── Whole book (singleton) ──────────────────────────────────────────────────

  /// Real-time stream of the single "whole Agbeya book" entry (title, PDF
  /// and/or audio), or null if the admin hasn't set it up yet.
  Stream<AgbeyaHour?> watchWholeBook() => _wholeBookRef.snapshots().map(
        (doc) => doc.exists ? AgbeyaHour.fromFirestore(doc) : null,
      );

  Future<AgbeyaHour?> fetchWholeBook() async {
    final doc = await _wholeBookRef.get();
    return doc.exists ? AgbeyaHour.fromFirestore(doc) : null;
  }

  /// Creates/updates the singleton whole-book document. Always writes to the
  /// fixed [wholeBookDocId] regardless of `hour.id`, so it can never collide
  /// with — or leak into — the 7 canonical hour documents.
  Future<void> saveWholeBook(AgbeyaHour hour) => _wholeBookRef.set({
        ...hour.toFirestore(),
        'hour_number': 0,
        'sort_order': -1,
      });

  // ── Write (Admin) ───────────────────────────────────────────────────────────

  Future<String> addHour(AgbeyaHour hour) async {
    final ref = await _col.add(hour.toFirestore());
    return ref.id;
  }

  Future<void> updateHour(AgbeyaHour hour) => _col.doc(hour.id).update({
        ...hour.toFirestore(),
        'updated_at': FieldValue.serverTimestamp(),
      });

  Future<void> deleteHour(String id) => _col.doc(id).delete();

  Future<void> togglePublish(String id, {required bool published}) =>
      _col.doc(id).update({
        'is_published': published,
        'updated_at': FieldValue.serverTimestamp(),
      });

  /// Batch-write new sort_order values after drag-to-reorder in the admin
  /// list. Does NOT touch hour_number — the canonical hour identity (used
  /// for names/colors in both the admin UI and the app) stays fixed.
  Future<void> reorder(List<AgbeyaHour> ordered) async {
    final batch = _firestore.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {'sort_order': i});
    }
    await batch.commit();
    debugPrint('[AgbeyaRepository] Reordered ${ordered.length} hour(s).');
  }
}
