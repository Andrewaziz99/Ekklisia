// lib/data/repositories/bishop_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// BishopRepository — reads and writes the single bishop document.
//
// Firestore path: config/bishop
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bishop_model.dart';

class BishopRepository {
  BishopRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('config').doc('bishop');

  /// Stream the bishop document (re-emits on every Firestore write).
  Stream<BishopModel?> watch() => _doc.snapshots().map(
        (snap) => snap.exists ? BishopModel.fromFirestore(snap) : null,
      );

  /// Overwrite (or create) the bishop document.
  Future<void> save(BishopModel bishop) =>
      _doc.set(bishop.toFirestore());
}
