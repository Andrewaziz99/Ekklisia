// lib/data/repositories/agbeya_intro_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reads/writes the singleton `config/agbeya_intro` doc. Uses the existing
// `config/{docId}` Firestore rule (read: signed-in, write: admin) — no rules
// changes needed.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agbeya_intro_model.dart';

class AgbeyaIntroRepository {
  AgbeyaIntroRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'config';
  static const String _docId = 'agbeya_intro';

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(_collection).doc(_docId);

  Stream<AgbeyaIntroModel> watch() => _doc.snapshots().map(
        (snap) => snap.exists
            ? AgbeyaIntroModel.fromFirestore(snap)
            : AgbeyaIntroModel.empty,
      );

  Future<AgbeyaIntroModel> fetch() async {
    final snap = await _doc.get();
    return snap.exists
        ? AgbeyaIntroModel.fromFirestore(snap)
        : AgbeyaIntroModel.empty;
  }

  Future<void> save(AgbeyaIntroModel intro) =>
      _doc.set(intro.toFirestore(), SetOptions(merge: true));
}
