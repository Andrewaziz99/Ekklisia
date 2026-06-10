// lib/data/repositories/game_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// CRUD + realtime streams for the `game_questions` Firestore collection.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_model.dart';

class GameRepository {
  GameRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'game_questions';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  // ── Streams ──────────────────────────────────────────────────────────────

  /// All questions, optionally filtered by [type]. Admin use.
  Stream<List<GameQuestion>> watchAll({GameType? type}) {
    Query<Map<String, dynamic>> q = _col.orderBy('sort_order');
    if (type != null) q = q.where('type', isEqualTo: type.name);
    return q.snapshots().map(
      (s) => s.docs.map(GameQuestion.fromFirestore).toList(),
    );
  }

  /// Visible questions only, optionally filtered by [type]. Reader use.
  Stream<List<GameQuestion>> watchVisible({GameType? type}) {
    Query<Map<String, dynamic>> q = _col
        .where('is_visible', isEqualTo: true)
        .orderBy('sort_order');
    if (type != null) q = q.where('type', isEqualTo: type.name);
    return q.snapshots().map(
      (s) => s.docs.map(GameQuestion.fromFirestore).toList(),
    );
  }

  // ── Fetch (one-shot) ─────────────────────────────────────────────────────

  Future<List<GameQuestion>> fetchVisible(GameType type) async {
    final snap = await _col
        .where('type', isEqualTo: type.name)
        .where('is_visible', isEqualTo: true)
        .orderBy('sort_order')
        .get();
    return snap.docs.map(GameQuestion.fromFirestore).toList();
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> add(GameQuestion q) async {
    final count = await _col
        .where('type', isEqualTo: q.type.name)
        .count()
        .get();
    final order = count.count ?? 0;
    await _col.doc().set({...q.toFirestore(), 'sort_order': order});
  }

  Future<void> update(GameQuestion q) => _col.doc(q.id).update({
        'question_ar':         q.questionAr,
        'question_el':         q.questionEl,
        'image_url':           q.imageUrl,
        'cloudinary_image_id': q.cloudinaryImageId,
        'choices':             q.choices.map((c) => c.toMap()).toList(),
        'correct_index':       q.correctIndex,
        'category':            q.category,
        'is_visible':          q.isVisible,
      });

  Future<void> toggleVisibility(GameQuestion q) =>
      _col.doc(q.id).update({'is_visible': !q.isVisible});

  Future<void> delete(String id) => _col.doc(id).delete();
}
