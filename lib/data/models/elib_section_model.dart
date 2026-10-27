// lib/data/models/elib_section_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Discriminator for which video/audio library a section belongs to.
/// Lets one generic sections/items architecture (see [ElibRepository]) serve
/// multiple independent home-screen entry points, mirroring the `PdfCategory`
/// pattern used for `pdf_contents`.
///
/// Existing Firestore docs written before this field existed have no
/// `libraryType` key at all — [ElibSectionModel.fromDoc] defaults those to
/// [general] so the original "Electronic Library" keeps showing them.
abstract class ElibLibraryType {
  static const String general = 'general';
}

class ElibSectionModel {
  final String id;
  final String titleAr;
  final String titleEl;
  final int order;
  final DateTime createdAt;
  final String libraryType;

  const ElibSectionModel({
    required this.id,
    this.titleAr = '',
    this.titleEl = '',
    this.order = 0,
    required this.createdAt,
    this.libraryType = ElibLibraryType.general,
  });

  ElibSectionModel copyWith({
    String? id,
    String? titleAr,
    String? titleEl,
    int? order,
    DateTime? createdAt,
    String? libraryType,
  }) => ElibSectionModel(
    id: id ?? this.id,
    titleAr: titleAr ?? this.titleAr,
    titleEl: titleEl ?? this.titleEl,
    order: order ?? this.order,
    createdAt: createdAt ?? this.createdAt,
    libraryType: libraryType ?? this.libraryType,
  );

  Map<String, dynamic> toMap() => {
    'titleAr': titleAr,
    'titleEl': titleEl,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'libraryType': libraryType,
  };

  factory ElibSectionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ElibSectionModel(
      id: doc.id,
      titleAr: d['titleAr'] as String? ?? '',
      titleEl: d['titleEl'] as String? ?? '',
      order: d['order'] as int? ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      libraryType: d['libraryType'] as String? ?? ElibLibraryType.general,
    );
  }
}
