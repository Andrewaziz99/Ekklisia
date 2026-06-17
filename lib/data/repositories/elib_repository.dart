// lib/data/repositories/elib_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// ElibRepository — manages 'elib_sections' and 'elib_items' Firestore
// collections and Cloudinary video/audio uploads.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/elib_item_model.dart';
import '../../data/models/elib_section_model.dart';

class ElibRepository {
  ElibRepository({
    required FirebaseFirestore firestore,
    required CloudinaryDataSource cloudinary,
  })  : _db = firestore,
        _cloudinary = cloudinary;

  final FirebaseFirestore _db;
  final CloudinaryDataSource _cloudinary;

  CollectionReference<Map<String, dynamic>> get _sections =>
      _db.collection(AppConstants.elibSectionsCollection);

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection(AppConstants.elibItemsCollection);

  // ── Sections ──────────────────────────────────────────────────────────────

  Stream<List<ElibSectionModel>> watchSections() => _sections
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(ElibSectionModel.fromDoc).toList());

  Future<List<ElibSectionModel>> fetchSections() async {
    final snap = await _sections.orderBy('order').get();
    return snap.docs.map(ElibSectionModel.fromDoc).toList();
  }

  Future<ElibSectionModel> saveSection(ElibSectionModel section) async {
    if (section.id.isEmpty) {
      // compute next order
      final snap = await _sections.orderBy('order', descending: true).limit(1).get();
      final nextOrder = snap.docs.isEmpty
          ? 0
          : ((snap.docs.first.data()['order'] as int? ?? 0) + 1);
      final ref = await _sections.add(section.copyWith(order: nextOrder).toMap());
      return section.copyWith(id: ref.id, order: nextOrder);
    }
    await _sections.doc(section.id).update(section.toMap());
    return section;
  }

  Future<void> deleteSection(String sectionId) async {
    // delete all items in section first
    final snap = await _items.where('sectionId', isEqualTo: sectionId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_sections.doc(sectionId));
    await batch.commit();
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  // Note: orderBy is intentionally excluded from the Firestore query to avoid
  // requiring a composite index. Sorting is done in memory by 'order' field.
  /// Watches ALL elib items across every section. Used for dashboard counts.
  Stream<List<ElibItemModel>> watchAllItems() => _items
      .snapshots()
      .map((s) => s.docs.map(ElibItemModel.fromDoc).toList());

  Stream<List<ElibItemModel>> watchItemsBySection(String sectionId) => _items
      .where('sectionId', isEqualTo: sectionId)
      .snapshots()
      .map((s) {
        final items = s.docs.map(ElibItemModel.fromDoc).toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        return items;
      });

  Stream<List<ElibItemModel>> watchPublishedBySection(String sectionId) => _items
      .where('sectionId', isEqualTo: sectionId)
      .where('isPublished', isEqualTo: true)
      .snapshots()
      .map((s) {
        final items = s.docs.map(ElibItemModel.fromDoc).toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        return items;
      });

  Future<ElibItemModel> saveItem(ElibItemModel item) async {
    if (item.id.isEmpty) {
      final ref = await _items.add(item.toMap());
      return item.copyWith(id: ref.id);
    }
    await _items.doc(item.id).update(item.toMap());
    return item;
  }

  Future<void> deleteItem(String id) => _items.doc(id).delete();

  Future<void> setItemPublished(String id, {required bool published}) =>
      _items.doc(id).update({'isPublished': published});

  /// Persist a new display order after the admin drags items around.
  /// [orderedIds] is the list of item IDs in the desired order.
  Future<void> reorderItems(List<String> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_items.doc(orderedIds[i]), {'order': i});
    }
    await batch.commit();
  }

  // ── Upload video + save ───────────────────────────────────────────────────

  Future<ElibItemModel> uploadVideoAndSave({
    required File file,
    required String sectionId,
    required String titleAr,
    required String titleEl,
    required String createdBy,
    void Function(double)? onProgress,
  }) async {
    final result = await _cloudinary.uploadVideo(
      videoFile: file,
      folder: 'Ekklisia/elib/video',
      onProgress: onProgress,
    );
    final item = ElibItemModel(
      id: '',
      sectionId: sectionId,
      titleAr: titleAr,
      titleEl: titleEl,
      mediaUrl: result.secureUrl,
      cloudinaryId: result.publicId,
      mediaType: ElibMediaType.video,
      isPublished: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    return saveItem(item);
  }

  Future<ElibItemModel> uploadVideoAndSaveBytes({
    required Uint8List bytes,
    required String fileName,
    required String sectionId,
    required String titleAr,
    required String titleEl,
    required String createdBy,
    void Function(double)? onProgress,
  }) async {
    final result = await _cloudinary.uploadVideoBytes(
      bytes: bytes,
      fileName: fileName,
      folder: 'Ekklisia/elib/video',
      onProgress: onProgress,
    );
    final item = ElibItemModel(
      id: '',
      sectionId: sectionId,
      titleAr: titleAr,
      titleEl: titleEl,
      mediaUrl: result.secureUrl,
      cloudinaryId: result.publicId,
      mediaType: ElibMediaType.video,
      isPublished: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    return saveItem(item);
  }

  // ── Upload audio + save ───────────────────────────────────────────────────

  Future<ElibItemModel> uploadAudioAndSave({
    required File file,
    required String sectionId,
    required String titleAr,
    required String titleEl,
    required String createdBy,
    void Function(double)? onProgress,
  }) async {
    final result = await _cloudinary.uploadAudio(
      audioFile: file,
      folder: 'Ekklisia/elib/audio',
      onProgress: onProgress,
    );
    final item = ElibItemModel(
      id: '',
      sectionId: sectionId,
      titleAr: titleAr,
      titleEl: titleEl,
      mediaUrl: result.secureUrl,
      cloudinaryId: result.publicId,
      mediaType: ElibMediaType.audio,
      isPublished: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    return saveItem(item);
  }

  Future<ElibItemModel> uploadAudioAndSaveBytes({
    required Uint8List bytes,
    required String fileName,
    required String sectionId,
    required String titleAr,
    required String titleEl,
    required String createdBy,
    void Function(double)? onProgress,
  }) async {
    final result = await _cloudinary.uploadAudioBytes(
      bytes: bytes,
      fileName: fileName,
      folder: 'Ekklisia/elib/audio',
      onProgress: onProgress,
    );
    final item = ElibItemModel(
      id: '',
      sectionId: sectionId,
      titleAr: titleAr,
      titleEl: titleEl,
      mediaUrl: result.secureUrl,
      cloudinaryId: result.publicId,
      mediaType: ElibMediaType.audio,
      isPublished: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    return saveItem(item);
  }
}
