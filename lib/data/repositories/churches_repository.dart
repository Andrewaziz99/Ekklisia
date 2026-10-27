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

  /// All published churches — ordered by admin drag order (falls back to
  /// nameEn for churches saved before [ChurchModel.sortOrder] existed).
  Stream<List<ChurchModel>> watchPublished() => _col
      .where('isPublished', isEqualTo: true)
      .orderBy('nameEn')
      .snapshots()
      .map((s) => _bySortOrder(s.docs.map(ChurchModel.fromFirestore).toList()));

  /// All churches (including drafts) — for admin CMS, ordered by admin drag
  /// order.
  Stream<List<ChurchModel>> watchAll() => _col
      .orderBy('nameEn')
      .snapshots()
      .map((s) => _bySortOrder(s.docs.map(ChurchModel.fromFirestore).toList()));

  /// Sorts by [ChurchModel.sortOrder] using a *stable* sort, so churches
  /// written before that field existed (all defaulting to 0) keep the
  /// alphabetical order the Firestore query already gave them, instead of
  /// being silently dropped the way an `orderBy('sortOrder')` query would
  /// drop any document missing that field.
  List<ChurchModel> _bySortOrder(List<ChurchModel> churches) {
    final sorted = List<ChurchModel>.of(churches);
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

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

  /// Admin: persist a new display order after drag-to-reorder in the CMS
  /// churches manager. [ordered] is the full church list in the desired
  /// order — every item gets a fresh sequential `sortOrder`.
  Future<void> reorder(List<ChurchModel> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {'sortOrder': i});
    }
    await batch.commit();
  }
}
