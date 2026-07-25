// lib/data/repositories/priests_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// PriestsRepository — Firestore CRUD for the top-level 'priests' collection.
//
// Priests used to be embedded inside each church document (church.priests).
// They're now their own collection so admins can edit a priest without
// touching its church, and vice versa. [migrateFromChurchesIfNeeded] performs
// a one-time, idempotent copy of any still-embedded priests the first time
// this runs against a given Firestore project.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/priest_model.dart';

class PriestsRepository {
  PriestsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.priestsCollection);

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<PriestModel>> watchAll() => _col
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(PriestModel.fromFirestore).toList());

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> save(PriestModel priest) async {
    if (priest.id.isEmpty) {
      await _col.add(priest.toFirestore());
    } else {
      await _col.doc(priest.id).update(priest.toFirestore());
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Keeps every priest's [PriestModel.churchName] in sync when a church is
  /// renamed. Cheap no-op when nothing points at [churchId].
  Future<void> renameChurch(String churchId, String newName) async {
    final linked = await _col.where('churchId', isEqualTo: churchId).get();
    if (linked.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in linked.docs) {
      batch.update(doc.reference, {'churchName': newName});
    }
    await batch.commit();
  }

  /// Unlinks (but does not delete) every priest pointing at a church that's
  /// about to be deleted — they keep their last-known church name as plain
  /// text instead of dangling on a nonexistent churchId.
  Future<void> unlinkChurch(String churchId) async {
    final linked = await _col.where('churchId', isEqualTo: churchId).get();
    if (linked.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in linked.docs) {
      batch.update(doc.reference, {'churchId': null});
    }
    await batch.commit();
  }

  // ── One-time migration ────────────────────────────────────────────────────

  /// Copies any priests still embedded in church documents (the pre-migration
  /// schema) into this top-level collection, linked to their church. Safe to
  /// call on every app start: it claims a Firestore flag doc atomically so
  /// the copy only ever runs once, even with concurrent admins.
  Future<void> migrateFromChurchesIfNeeded() async {
    final flagRef = _db.collection('meta').doc('migrations');
    final claimed = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(flagRef);
      if (snap.data()?['priestsFromChurches'] == true) return false;
      tx.set(flagRef, {'priestsFromChurches': true}, SetOptions(merge: true));
      return true;
    });
    if (!claimed) return;

    try {
      final churches =
          await _db.collection(AppConstants.churchesCollection).get();
      final batch = _db.batch();
      var count = 0;
      for (final doc in churches.docs) {
        final raw = doc.data()['priests'] as List<dynamic>? ?? [];
        for (final entry in raw) {
          final m = entry as Map<String, dynamic>;
          final nameEn = (m['nameEn'] as String? ?? '').trim();
          final nameAr = (m['nameAr'] as String? ?? '').trim();
          final name = nameEn.isNotEmpty ? nameEn : nameAr;
          if (name.isEmpty) continue;
          final ref = _col.doc();
          batch.set(ref, {
            'name':       name,
            'nameAr':     nameAr,
            'phone':      m['phone']    as String? ?? '',
            'imageUrl':   m['imageUrl'] as String? ?? '',
            'churchId':   doc.id,
            'churchName': doc.data()['nameEn'] as String? ?? '',
          });
          count++;
        }
      }
      if (count > 0) await batch.commit();
    } catch (_) {
      // Best-effort: if this fails (e.g. offline on first launch), the flag
      // is already claimed so it won't retry — the admin can still add
      // priests manually going forward. Old embedded data isn't lost either
      // way since church documents are untouched by this migration.
    }
  }
}
