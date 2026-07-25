// lib/data/repositories/churches_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// ChurchesRepository — Firestore CRUD for the churches collection.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/church_model.dart';
import 'priests_repository.dart';

class ChurchesRepository {
  ChurchesRepository(this._db, [this._priestsRepo]);

  final FirebaseFirestore _db;

  /// Optional — when set, church renames/deletes keep every linked priest's
  /// denormalized church name in sync (or unlink them on delete) instead of
  /// leaving stale references behind.
  final PriestsRepository? _priestsRepo;

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
      await _priestsRepo?.renameChurch(church.id, church.nameEn);
    }
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
    await _priestsRepo?.unlinkChurch(id);
  }

  Future<void> togglePublished(String id, bool value) =>
      _col.doc(id).update({'isPublished': value});
}
