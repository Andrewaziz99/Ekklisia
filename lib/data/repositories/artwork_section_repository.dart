// lib/data/repositories/artwork_section_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// CRUD + realtime stream for the `artwork_sections` Firestore collection.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/artwork_section_model.dart';

class ArtworkSectionRepository {
  ArtworkSectionRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'artwork_sections';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<ArtworkSection>> watchSections() => _col
      .orderBy('sort_order')
      .snapshots()
      .map((snap) => snap.docs.map(ArtworkSection.fromFirestore).toList());

  // ── Fetch (one-shot) ─────────────────────────────────────────────────────

  Future<List<ArtworkSection>> fetchSections() async {
    final snap = await _col.orderBy('sort_order').get();
    return snap.docs.map(ArtworkSection.fromFirestore).toList();
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> addSection(ArtworkSection section) async {
    await _col.doc().set(section.toFirestore());
  }

  Future<void> updateSection(ArtworkSection section) => _col
      .doc(section.id)
      .update({
        'name_ar': section.nameAr,
        'name_el': section.nameEl,
        'sort_order': section.sortOrder,
      });

  Future<void> deleteSection(String id) => _col.doc(id).delete();

  /// Batch-write new sort_order values after drag-to-reorder.
  Future<void> reorderSections(List<ArtworkSection> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {'sort_order': i});
    }
    await batch.commit();
  }
}
