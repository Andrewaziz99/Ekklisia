// lib/data/models/gallery_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which gallery instance an image belongs to — lets one `gallery`
/// collection back multiple named photo sections in the app (general church
/// gallery, Saints' lives, …) without duplicating the whole feature.
/// Mirrors [ElibLibraryType] — filtering is done in memory (see
/// GalleryRepository), so docs written before this field existed default to
/// [general] rather than disappearing.
abstract class GalleryType {
  static const String general = 'general';
  static const String saintsLives = 'saints_lives';
}

class GalleryItemModel {
  final String id;
  final String titleAr;
  final String titleEl;
  final String imageUrl;
  final String cloudinaryId;
  final bool isPublished;
  final DateTime createdAt;
  final String createdBy;
  final String galleryType;

  const GalleryItemModel({
    required this.id,
    this.titleAr = '',
    this.titleEl = '',
    this.imageUrl = '',
    this.cloudinaryId = '',
    this.isPublished = true,
    required this.createdAt,
    this.createdBy = '',
    this.galleryType = GalleryType.general,
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
    String? galleryType,
  }) => GalleryItemModel(
    id: id ?? this.id,
    titleAr: titleAr ?? this.titleAr,
    titleEl: titleEl ?? this.titleEl,
    imageUrl: imageUrl ?? this.imageUrl,
    cloudinaryId: cloudinaryId ?? this.cloudinaryId,
    isPublished: isPublished ?? this.isPublished,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
    galleryType: galleryType ?? this.galleryType,
  );

  Map<String, dynamic> toMap() => {
    'titleAr': titleAr,
    'titleEl': titleEl,
    'imageUrl': imageUrl,
    'cloudinaryId': cloudinaryId,
    'isPublished': isPublished,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'galleryType': galleryType,
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
      galleryType: d['galleryType'] as String? ?? GalleryType.general,
    );
  }
}
