// lib/data/repositories/book_category_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// CRUD + realtime stream for the `categories` Firestore collection.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/book_category_model.dart';
import '../../core/constants/app_constants.dart';

class BookCategoryRepository {
  BookCategoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.categoriesCollection);

  // ── Streams ─────────────────────────────────────────────────────────────────

  /// All categories, ordered by sortOrder (live).
  Stream<List<BookCategory>> watchCategories() =>
      _col.orderBy('sort_order').snapshots().map(
        (snap) => snap.docs
            .map(BookCategory.fromFirestore)
            .toList(),
      );

  /// Visible categories only (for the reader app).
  Stream<List<BookCategory>> watchVisibleCategories() =>
      _col
          .where('is_visible', isEqualTo: true)
          .orderBy('sort_order')
          .snapshots()
          .map((snap) =>
              snap.docs.map(BookCategory.fromFirestore).toList());

  // ── Fetch (one-shot) ────────────────────────────────────────────────────────

  Future<List<BookCategory>> fetchCategories({bool visibleOnly = false}) async {
    Query<Map<String, dynamic>> q = _col.orderBy('sort_order');
    if (visibleOnly) q = q.where('is_visible', isEqualTo: true);
    final snap = await q.get();
    return snap.docs.map(BookCategory.fromFirestore).toList();
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Adds a category, throwing [StateError] if a document with the same slug
  /// already exists (prevents duplicate-value crashes in dropdowns).
  Future<void> addCategory(BookCategory cat) async {
    final existing = await _col
        .where('slug', isEqualTo: cat.slug)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('A category with slug "${cat.slug}" already exists.');
    }
    await _col.doc().set(cat.toFirestore());
  }

  Future<void> updateCategory(BookCategory cat) =>
      _col.doc(cat.id).update({
        'slug':       cat.slug,
        'name_ar':    cat.nameAr,
        'name_cop':   cat.nameCop,
        'name_el':    cat.nameEl,
        'sort_order': cat.sortOrder,
        'is_visible': cat.isVisible,
      });

  Future<void> deleteCategory(String id) => _col.doc(id).delete();

  Future<void> toggleVisibility(BookCategory cat) =>
      _col.doc(cat.id).update({'is_visible': !cat.isVisible});

  /// Batch-write new sortOrder values after a drag-to-reorder operation.
  Future<void> reorderCategories(List<BookCategory> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {'sort_order': i});
    }
    await batch.commit();
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  /// Creates the 9 default categories in Firestore if the collection is empty.
  Future<int> seedDefaults() async {
    final existing = await _col.limit(1).get();
    if (existing.docs.isNotEmpty) return 0; // already seeded

    final batch = _db.batch();
    for (var i = 0; i < kDefaultBookCategories.length; i++) {
      final c = kDefaultBookCategories[i];
      final doc = _col.doc();
      batch.set(doc, BookCategory(
        id:        doc.id,
        slug:      c.slug,
        nameAr:    c.nameAr,
        nameCop:   c.nameCop,
        nameEl:    c.nameEl,
        sortOrder: i,
        createdAt: DateTime.now(),
      ).toFirestore());
    }
    await batch.commit();
    debugPrint('[BookCategoryRepo] Seeded ${kDefaultBookCategories.length} default categories.');
    return kDefaultBookCategories.length;
  }
}
