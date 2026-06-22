// lib/data/repositories/churches_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// ChurchesRepository — Firestore CRUD for the churches collection.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/church_model.dart';

class ChurchesRepository {
  ChurchesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.churchesCollection);

  // ── Streams ────────────────────────────────────────────────────────────────

  /// All published churches — ordered by nameEn.
  Stream<List<ChurchModel>> watchPublished() => _col
      .where('isPublished', isEqualTo: true)
      .orderBy('nameEn')
      .snapshots()
      .map((s) => s.docs.map(ChurchModel.fromFirestore).toList());

  /// All churches (including drafts) — for admin CMS.
  Stream<List<ChurchModel>> watchAll() => _col
      .orderBy('nameEn')
      .snapshots()
      .map((s) => s.docs.map(ChurchModel.fromFirestore).toList());

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> save(ChurchModel church) async {
    if (church.id.isEmpty) {
      await _col.add(church.toFirestore());
    } else {
      await _col.doc(church.id).update(church.toFirestore());
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> togglePublished(String id, bool value) =>
      _col.doc(id).update({'isPublished': value});
}
