// lib/data/repositories/saints_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// SaintsRepository — Firestore CRUD for the saints collection.
// Cloudinary uploads are handled by the admin CMS directly.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/saint_model.dart';

class SaintsRepository {
  SaintsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.saintsCollection);

  // ── Streams ────────────────────────────────────────────────────────────────

  /// All published saints — ordered by nameEn for user-facing screens.
  Stream<List<SaintModel>> watchPublished() => _col
      .where('isPublished', isEqualTo: true)
      .orderBy('nameEn')
      .snapshots()
      .map((s) => s.docs.map(SaintModel.fromFirestore).toList());

  /// All saints (including drafts) — for the admin CMS.
  Stream<List<SaintModel>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SaintModel.fromFirestore).toList());

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> save(SaintModel saint) async {
    if (saint.id.isEmpty) {
      await _col.add(saint.toFirestore());
    } else {
      await _col.doc(saint.id).update(saint.toFirestore());
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<SaintModel?> fetchById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return SaintModel.fromFirestore(doc);
  }

  /// Toggle published status without a full round-trip.
  Future<void> togglePublished(String id, bool value) =>
      _col.doc(id).update({'isPublished': value, 'updatedAt': DateTime.now()});
}
