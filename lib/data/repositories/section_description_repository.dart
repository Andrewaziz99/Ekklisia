// lib/data/repositories/section_description_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// CRUD + realtime stream for the `section_descriptions` Firestore collection.
//
// One doc per category slug (doc id == category, e.g. "artworks"). Holds a
// constant bilingual description card shown at the top of that category's
// list screen — plus a list of "available at" link buttons — editable from
// the admin CMS. Distinct from PdfContent, which is per-item.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pdf_content_model.dart';

class SectionDescriptionRepository {
  SectionDescriptionRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'section_descriptions';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  /// Streams the section description for [category]. Emits `null` when no
  /// doc has been saved yet (i.e. admin hasn't set one up) — callers should
  /// treat that as "show nothing".
  Stream<SectionDescription?> watch(String category) => _col
      .doc(category)
      .snapshots()
      .map((doc) => doc.exists ? SectionDescription.fromFirestore(doc) : null);

  Future<SectionDescription?> fetch(String category) async {
    final doc = await _col.doc(category).get();
    return doc.exists ? SectionDescription.fromFirestore(doc) : null;
  }

  Future<void> save(SectionDescription section) =>
      _col.doc(section.category).set(section.toFirestore());

  Future<void> delete(String category) => _col.doc(category).delete();
}
