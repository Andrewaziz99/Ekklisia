// lib/data/repositories/home_layout_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reads/writes the singleton `config/home_layout` doc (tile names + cover
// images, header banner, section titles). Uses the existing `config/{docId}`
// Firestore rule (read: signed-in, write: admin) — no rules changes needed.
//
// Image uploads go to Cloudinary (same unsigned preset as book covers) under
// the `home_layout` folder; only the resulting secure URL is stored here.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../datasources/cloudinary/cloudinary_datasource.dart';
import '../models/home_layout_model.dart';

class HomeLayoutRepository {
  HomeLayoutRepository(this._db, this._cloudinary);

  final FirebaseFirestore _db;
  final CloudinaryDataSource _cloudinary;

  static const String _collection = 'config';
  static const String _docId = 'home_layout';
  static const String _uploadFolder = 'home_layout';

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(_collection).doc(_docId);

  /// Live layout. Emits [HomeLayoutModel.empty] when no doc exists yet, and
  /// also on read errors so the home screen always falls back to defaults.
  Stream<HomeLayoutModel> watch() => _doc
      .snapshots()
      .map(
        (snap) => snap.exists
            ? HomeLayoutModel.fromFirestore(snap)
            : HomeLayoutModel.empty,
      )
      .handleError((_) {});

  Future<HomeLayoutModel> fetch() async {
    final snap = await _doc.get();
    return snap.exists
        ? HomeLayoutModel.fromFirestore(snap)
        : HomeLayoutModel.empty;
  }

  /// Full overwrite — the admin screen always edits the whole layout, so
  /// cleared overrides are removed instead of lingering from a merge.
  Future<void> save(HomeLayoutModel layout) => _doc.set(layout.toFirestore());

  /// Uploads a tile / banner image and returns its public URL.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final res = await _cloudinary.uploadCoverImageBytes(
      bytes: bytes,
      fileName: fileName,
      folder: _uploadFolder,
      onProgress: onProgress,
    );
    return res.secureUrl;
  }
}
