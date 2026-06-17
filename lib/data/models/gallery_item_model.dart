// lib/data/models/gallery_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GalleryItemModel {
  final String id;
  final String titleAr;
  final String titleEl;
  final String imageUrl;
  final String cloudinaryId;
  final bool isPublished;
  final DateTime createdAt;
  final String createdBy;

  const GalleryItemModel({
    required this.id,
    this.titleAr = '',
    this.titleEl = '',
    this.imageUrl = '',
    this.cloudinaryId = '',
    this.isPublished = true,
    required this.createdAt,
    this.createdBy = '',
  });

  bool get hasImage => imageUrl.isNotEmpty;

  GalleryItemModel copyWith({
    String? id,
    String? titleAr,
    String? titleEl,
    String? imageUrl,
    String? cloudinaryId,
    bool? isPublished,
    DateTime? createdAt,
    String? createdBy,
  }) => GalleryItemModel(
    id: id ?? this.id,
    titleAr: titleAr ?? this.titleAr,
    titleEl: titleEl ?? this.titleEl,
    imageUrl: imageUrl ?? this.imageUrl,
    cloudinaryId: cloudinaryId ?? this.cloudinaryId,
    isPublished: isPublished ?? this.isPublished,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );

  Map<String, dynamic> toMap() => {
    'titleAr': titleAr,
    'titleEl': titleEl,
    'imageUrl': imageUrl,
    'cloudinaryId': cloudinaryId,
    'isPublished': isPublished,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
  };

  factory GalleryItemModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GalleryItemModel(
      id: doc.id,
      titleAr: d['titleAr'] as String? ?? '',
      titleEl: d['titleEl'] as String? ?? '',
      imageUrl: d['imageUrl'] as String? ?? '',
      cloudinaryId: d['cloudinaryId'] as String? ?? '',
      isPublished: d['isPublished'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }
}
