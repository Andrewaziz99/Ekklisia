// lib/data/models/artwork_section_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Artwork section — admin-editable sub-grouping for the Art Works category
// (PdfCategory.artworks). Lets the admin split artwork items into named
// sections (e.g. Icons / Paintings) without a code change — mirrors
// [BookCategory], scoped to this one category.
//
// Firestore collection: `artwork_sections`.
// Document shape:
//   {
//     name_ar:    string,
//     name_el:    string,
//     sort_order: int,
//     created_at: Timestamp,
//   }
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ArtworkSection extends Equatable {
  final String id;
  final String nameAr;
  final String nameEl;
  final int sortOrder;
  final DateTime createdAt;

  const ArtworkSection({
    required this.id,
    required this.nameAr,
    this.nameEl = '',
    this.sortOrder = 0,
    required this.createdAt,
  });

  String nameFor(String langCode) {
    switch (langCode) {
      case 'el':
        return nameEl.isNotEmpty ? nameEl : nameAr;
      default:
        return nameAr;
    }
  }

  factory ArtworkSection.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ArtworkSection(
      id: doc.id,
      nameAr: d['name_ar'] as String? ?? '',
      nameEl: d['name_el'] as String? ?? '',
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name_ar': nameAr,
    'name_el': nameEl,
    'sort_order': sortOrder,
    'created_at': Timestamp.fromDate(createdAt),
  };

  ArtworkSection copyWith({
    String? nameAr,
    String? nameEl,
    int? sortOrder,
  }) => ArtworkSection(
    id: id,
    nameAr: nameAr ?? this.nameAr,
    nameEl: nameEl ?? this.nameEl,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, nameAr, nameEl, sortOrder];
}
