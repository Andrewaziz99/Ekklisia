// lib/data/models/church_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// ChurchModel — represents a church.
//
// Firestore schema (collection: 'churches'):
//   nameAr        : String
//   nameEn        : String
//   mapsUrl       : String  — Google Maps link
//   isPublished   : bool
//   sortOrder     : int     — admin drag-to-reorder position (default 0)
//
// Priests used to be embedded here (a 'priests' array) but now live in their
// own top-level 'priests' collection — see PriestModel in priest_model.dart
// and PriestsRepository — so a priest can be edited without touching its
// church, and vice versa.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

class ChurchModel {
  const ChurchModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.mapsUrl,
    required this.isPublished,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String mapsUrl;
  final bool isPublished;
  final int sortOrder;

  ChurchModel copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? mapsUrl,
    bool? isPublished,
    int? sortOrder,
  }) {
    return ChurchModel(
      id:          id ?? this.id,
      nameAr:      nameAr ?? this.nameAr,
      nameEn:      nameEn ?? this.nameEn,
      mapsUrl:     mapsUrl ?? this.mapsUrl,
      isPublished: isPublished ?? this.isPublished,
      sortOrder:   sortOrder ?? this.sortOrder,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory ChurchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChurchModel(
      id:          doc.id,
      nameAr:      d['nameAr']  as String? ?? '',
      nameEn:      d['nameEn']  as String? ?? '',
      mapsUrl:     d['mapsUrl'] as String? ?? '',
      isPublished: d['isPublished'] as bool? ?? false,
      sortOrder:   d['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nameAr':      nameAr,
        'nameEn':      nameEn,
        'mapsUrl':     mapsUrl,
        'isPublished': isPublished,
        'sortOrder':   sortOrder,
      };
}
