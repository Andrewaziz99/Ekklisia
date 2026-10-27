// lib/data/repositories/social_links_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reads/writes the singleton `config/social_links` doc. Uses the existing
// `config/{docId}` Firestore rule (read: signed-in, write: admin) — no rules
// changes needed.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/social_links_model.dart';

class SocialLinksRepository {
  SocialLinksRepository(this._db);

  final FirebaseFirestore _db;

  static const String _collection = 'config';
  static const String _docId = 'social_links';

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(_collection).doc(_docId);

  Stream<SocialLinksModel> watch() => _doc.snapshots().map(
        (snap) => snap.exists
            ? SocialLinksModel.fromFirestore(snap)
            : SocialLinksModel.empty,
      );

  Future<SocialLinksModel> fetch() async {
    final snap = await _doc.get();
    return snap.exists
        ? SocialLinksModel.fromFirestore(snap)
        : SocialLinksModel.empty;
  }

  Future<void> save(SocialLinksModel links) =>
      _doc.set(links.toFirestore(), SetOptions(merge: true));
}
