// lib/data/repositories/category_label_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// CRUD for the `category_labels` Firestore collection — one doc per
// PdfCategory slug, admin-editable override of that section's display name.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_label_model.dart';

class CategoryLabelRepository {
  CategoryLabelRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'category_labels';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  /// Live override for [category], or null if no doc exists yet.
  Stream<CategoryLabel?> watch(String category) => _col
      .doc(category)
      .snapshots()
      .map((d) => d.exists ? CategoryLabel.fromFirestore(d) : null);

  Future<CategoryLabel?> fetch(String category) async {
    final doc = await _col.doc(category).get();
    return doc.exists ? CategoryLabel.fromFirestore(doc) : null;
  }

  Future<void> save(CategoryLabel label) =>
      _col.doc(label.category).set(label.toFirestore());
}
