// lib/data/repositories/gallery_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// GalleryRepository — manages the 'gallery' Firestore collection and
// Cloudinary image uploads.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/gallery_item_model.dart';

class GalleryRepository {
  GalleryRepository({
    required FirebaseFirestore firestore,
    required CloudinaryDataSource cloudinary,
  })  : _db = firestore,
        _cloudinary = cloudinary;

  final FirebaseFirestore _db;
  final CloudinaryDataSource _cloudinary;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.galleryCollection);

  // ── Read ──────────────────────────────────────────────────────────────────

  Stream<List<GalleryItemModel>> watchPublished() => _col
      .where('isPublished', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(GalleryItemModel.fromDoc).toList());

  Stream<List<GalleryItemModel>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(GalleryItemModel.fromDoc).toList());

  Future<List<GalleryItemModel>> fetchAll() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs.map(GalleryItemModel.fromDoc).toList();
  }

  // ── Upload image + save ───────────────────────────────────────────────────

  /// Uploads image file to Cloudinary, then saves metadata to Firestore.
  Future<GalleryItemModel> uploadAndSave({
    required File imageFile,
    required String titleAr,
    required String titleEl,
    required String createdBy,
    void Function(double)? onProgress,
  }) async {
    final result = await _cloudinary.uploadCoverImage(
      imageFile: imageFile,
      folder: 'Ekklisia/gallery',
      onProgress: onProgress,
    );
    final item = GalleryItemModel(
      id: '',
      titleAr: titleAr,
      titleEl: titleEl,
      imageUrl: result.secureUrl,
      cloudinaryId: result.publicId,
      isPublished: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    return _saveNew(item);
  }

  /// Web variant — takes bytes instead of File.
  Future<GalleryItemModel> uploadAndSaveBytes({
    required Uint8List bytes,
    required String fileName,
    required String titleAr,
    required String titleEl,
    required String createdBy,
    void Function(double)? onProgress,
  }) async {
    final result = await _cloudinary.uploadCoverImageBytes(
      bytes: bytes,
      fileName: fileName,
      folder: 'Ekklisia/gallery',
      onProgress: onProgress,
    );
    final item = GalleryItemModel(
      id: '',
      titleAr: titleAr,
      titleEl: titleEl,
      imageUrl: result.secureUrl,
      cloudinaryId: result.publicId,
      isPublished: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    return _saveNew(item);
  }

  // ── Save (create / update) ────────────────────────────────────────────────

  Future<GalleryItemModel> save(GalleryItemModel item) async {
    if (item.id.isEmpty) return _saveNew(item);
    await _col.doc(item.id).update(item.toMap());
    return item;
  }

  Future<GalleryItemModel> _saveNew(GalleryItemModel item) async {
    final ref = await _col.add(item.toMap());
    return item.copyWith(id: ref.id);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> setPublished(String id, {required bool published}) =>
      _col.doc(id).update({'isPublished': published});
}
