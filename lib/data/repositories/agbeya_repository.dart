// lib/data/repositories/agbeya_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Firestore repository for the Agbeya (Coptic Book of Hours).
//
// Collection: agbeya_hours
//   • Ordered by hour_number ascending (1 = Prime … 7 = Compline)
//   • Only published hours are exposed to the app
//
// Audio files live on Cloudinary; only the URL is stored here.
// Upload them via the Admin CMS (same flow as PDF books).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agbeya_model.dart';

class AgbeyaRepository {
  AgbeyaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('agbeya_hours');

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Real-time stream of ALL hours (published + drafts) — admin only.
  Stream<List<AgbeyaHour>> watchAllHours() => _col
      .orderBy('hour_number')
      .snapshots()
      .map((snap) => snap.docs.map(AgbeyaHour.fromFirestore).toList());

  /// Real-time stream of published hours ordered by [hourNumber].
  Stream<List<AgbeyaHour>> watchPublishedHours() => _col
      .where('is_published', isEqualTo: true)
      .orderBy('hour_number')
      .snapshots()
      .map((snap) => snap.docs.map(AgbeyaHour.fromFirestore).toList());

  /// One-time fetch (useful for offline-first or initial load).
  Future<List<AgbeyaHour>> fetchHours() async {
    final snap = await _col
        .where('is_published', isEqualTo: true)
        .orderBy('hour_number')
        .get();
    return snap.docs.map(AgbeyaHour.fromFirestore).toList();
  }

  Future<AgbeyaHour?> fetchHourById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AgbeyaHour.fromFirestore(doc);
  }

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
}
