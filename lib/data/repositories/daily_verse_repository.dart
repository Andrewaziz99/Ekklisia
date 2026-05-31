// ─────────────────────────────────────────────────────────────────────────────
// Reads and writes daily verses to/from Firestore.
//
// Collection : daily_verses
// Doc ID     : Firestore auto-generated push ID
//
// Rotation logic lives in the Supabase edge function (send-daily-verse).
// The edge function sets `sent_date` on the chosen verse each day.
// Flutter queries for the verse whose `sent_date` matches today.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_verse_model.dart';

class DailyVerseRepository {
  DailyVerseRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const _collection = 'daily_verses';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(_collection);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns today's verse — the document whose [sentDate] equals today.
  /// Returns null if the edge function has not run yet today.
  Future<DailyVerseModel?> fetchTodayVerse() async {
    final today = _todayKey();
    final snap  = await _col
        .where('sent_date', isEqualTo: today)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DailyVerseModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Fallback: returns the lowest-order active verse regardless of [sentDate].
  /// Used when the edge function hasn't run yet for today.
  Future<DailyVerseModel?> fetchFallbackVerse() async {
    final snap = await _col
        .where('is_active', isEqualTo: true)
        .orderBy('order')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DailyVerseModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// All verses ordered by [order] ascending (for admin listing).
  Future<List<DailyVerseModel>> fetchAllVerses() async {
    final snap = await _col.orderBy('order').get();
    return snap.docs
        .map((d) => DailyVerseModel.fromMap(d.id, d.data()))
        .toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Save a verse.
  /// • New verse  (id is empty) → Firestore generates the document ID.
  /// • Existing   (id set)      → overwrites that document.
  Future<void> saveVerse(DailyVerseModel verse) async {
    if (verse.id.isEmpty) {
      await _col.add(verse.toMap());
    } else {
      await _col.doc(verse.id).set(verse.toMap());
    }
  }

  /// Toggle [is_active] for a verse by its document ID.
  Future<void> toggleActive(String id, bool isActive) async {
    await _col.doc(id).update({'is_active': isActive});
  }

  /// Delete a verse by its document ID.
  Future<void> deleteVerse(String id) async {
    await _col.doc(id).delete();
  }

  /// Mark a verse as sent today (called by the edge function via REST;
  /// exposed here for completeness / admin override).
  Future<void> markAsSent(String id, String date) async {
    await _col.doc(id).update({'sent_date': date});
  }

  /// Reset a verse so it can be sent again (admin override).
  Future<void> resetSentDate(String id) async {
    await _col.doc(id).update({'sent_date': ''});
  }

  /// Reset ALL sent verses so the 200-verse cycle restarts from verse #1.
  /// Uses a Firestore batch for atomicity (max 500 writes per batch).
  Future<void> resetAllSentDates() async {
    const batchLimit = 400;
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await _col
          .where('sent_date', isNotEqualTo: '')
          .limit(batchLimit)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'sent_date': ''});
      }
      await batch.commit();
    } while (snap.docs.length == batchLimit); // keep going if there are more
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
