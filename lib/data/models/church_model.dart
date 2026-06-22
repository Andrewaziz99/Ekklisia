// lib/data/models/church_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// ChurchModel — represents a church with its priests.
//
// Firestore schema (collection: 'churches'):
//   nameAr        : String
//   nameEn        : String
//   mapsUrl       : String  — Google Maps link
//   isPublished   : bool
//   priests       : List<Map>  — embedded sub-documents
//     each map: { nameAr, nameEn, phone, imageUrl }
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

// ── PriestModel ───────────────────────────────────────────────────────────────

class PriestModel {
  const PriestModel({
    required this.nameAr,
    required this.nameEn,
    required this.phone,
    this.imageUrl = '',
  });

  final String nameAr;
  final String nameEn;
  final String phone;
  /// Optional photo URL (Storage or external).
  final String imageUrl;

  factory PriestModel.fromMap(Map<String, dynamic> m) => PriestModel(
        nameAr:   m['nameAr']   as String? ?? '',
        nameEn:   m['nameEn']   as String? ?? '',
        phone:    m['phone']    as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'nameAr':   nameAr,
        'nameEn':   nameEn,
        'phone':    phone,
        'imageUrl': imageUrl,
      };
}

// ── ChurchModel ───────────────────────────────────────────────────────────────

class ChurchModel {
  const ChurchModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.mapsUrl,
    required this.priests,
    required this.isPublished,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String mapsUrl;
  final List<PriestModel> priests;
  final bool isPublished;

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory ChurchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChurchModel(
      id:          doc.id,
      nameAr:      d['nameAr']  as String? ?? '',
      nameEn:      d['nameEn']  as String? ?? '',
      mapsUrl:     d['mapsUrl'] as String? ?? '',
      isPublished: d['isPublished'] as bool? ?? false,
      priests: (d['priests'] as List<dynamic>? ?? [])
          .map((e) => PriestModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nameAr':      nameAr,
        'nameEn':      nameEn,
        'mapsUrl':     mapsUrl,
        'isPublished': isPublished,
        'priests':     priests.map((p) => p.toMap()).toList(),
      };
}
