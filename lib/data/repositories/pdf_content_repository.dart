// lib/data/repositories/pdf_content_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// CRUD + realtime streams for the `pdf_contents` Firestore collection.
// One collection, filtered by `category` field.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/pdf_content_model.dart';

class PdfContentRepository {
  PdfContentRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'pdf_contents';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  // ── Streams ──────────────────────────────────────────────────────────────

  /// All items for [category], ordered by sort_order (admin — all visibility).
  Stream<List<PdfContent>> watchAll(String category) => _col
      .where('category', isEqualTo: category)
      .orderBy('sort_order')
      .snapshots()
      .map((s) => s.docs.map(PdfContent.fromFirestore).toList());

  /// Visible items only (reader app).
  Stream<List<PdfContent>> watchVisible(String category) => _col
      .where('category', isEqualTo: category)
      .where('is_visible', isEqualTo: true)
      .orderBy('sort_order')
      .snapshots()
      .map((s) => s.docs.map(PdfContent.fromFirestore).toList());

  // ── Fetch (one-shot) ─────────────────────────────────────────────────────

  Future<List<PdfContent>> fetchVisible(String category) async {
    final snap = await _col
        .where('category', isEqualTo: category)
        .where('is_visible', isEqualTo: true)
        .orderBy('sort_order')
        .get();
    return snap.docs.map(PdfContent.fromFirestore).toList();
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> add(PdfContent item) async {
    // Assign sort_order = current count so it lands at the end
    final existing = await _col
        .where('category', isEqualTo: item.category)
        .count()
        .get();
    final order = existing.count ?? 0;
    await _col.doc().set({...item.toFirestore(), 'sort_order': order});
  }

  Future<void> update(PdfContent item) => _col.doc(item.id).update({
    'title_ar':          item.titleAr,
    'title_el':          item.titleEl,
    'pdf_url':           item.pdfUrl,
    'cloudinary_pdf_id': item.cloudinaryPdfId,
    'cover_url':         item.coverUrl,
    'is_visible':        item.isVisible,
  });

  Future<void> toggleVisibility(PdfContent item) =>
      _col.doc(item.id).update({'is_visible': !item.isVisible});

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Batch-write new sort_order values after drag-to-reorder.
  Future<void> reorder(List<PdfContent> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {'sort_order': i});
    }
    await batch.commit();
    debugPrint('[PdfContentRepo] Reordered ${ordered.length} items.');
  }
}
