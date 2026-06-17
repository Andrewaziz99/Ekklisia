// lib/data/models/elib_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ElibMediaType { video, audio }

extension ElibMediaTypeX on ElibMediaType {
  String get value => name; // 'video' | 'audio'
  static ElibMediaType fromString(String? s) =>
      s == 'audio' ? ElibMediaType.audio : ElibMediaType.video;
}

class ElibItemModel {
  final String id;
  final String sectionId;
  final String titleAr;
  final String titleEl;
  final String mediaUrl;
  final String cloudinaryId;
  final ElibMediaType mediaType;
  final bool isPublished;
  final DateTime createdAt;
  final String createdBy;
  final int order;

  const ElibItemModel({
    required this.id,
    this.sectionId = '',
    this.titleAr = '',
    this.titleEl = '',
    this.mediaUrl = '',
    this.cloudinaryId = '',
    this.mediaType = ElibMediaType.video,
    this.isPublished = true,
    required this.createdAt,
    this.createdBy = '',
    this.order = 0,
  });

  bool get hasMedia => mediaUrl.isNotEmpty;

  ElibItemModel copyWith({
    String? id,
    String? sectionId,
    String? titleAr,
    String? titleEl,
    String? mediaUrl,
    String? cloudinaryId,
    ElibMediaType? mediaType,
    bool? isPublished,
    DateTime? createdAt,
    String? createdBy,
    int? order,
  }) => ElibItemModel(
    id: id ?? this.id,
    sectionId: sectionId ?? this.sectionId,
    titleAr: titleAr ?? this.titleAr,
    titleEl: titleEl ?? this.titleEl,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    cloudinaryId: cloudinaryId ?? this.cloudinaryId,
    mediaType: mediaType ?? this.mediaType,
    isPublished: isPublished ?? this.isPublished,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
    order: order ?? this.order,
  );

  Map<String, dynamic> toMap() => {
    'sectionId': sectionId,
    'titleAr': titleAr,
    'titleEl': titleEl,
    'mediaUrl': mediaUrl,
    'cloudinaryId': cloudinaryId,
    'mediaType': mediaType.value,
    'isPublished': isPublished,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'order': order,
  };

  factory ElibItemModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ElibItemModel(
      id: doc.id,
      sectionId: d['sectionId'] as String? ?? '',
      titleAr: d['titleAr'] as String? ?? '',
      titleEl: d['titleEl'] as String? ?? '',
      mediaUrl: d['mediaUrl'] as String? ?? '',
      cloudinaryId: d['cloudinaryId'] as String? ?? '',
      mediaType: ElibMediaTypeX.fromString(d['mediaType'] as String?),
      isPublished: d['isPublished'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
      order: d['order'] as int? ?? 0,
    );
  }
}
