// lib/data/models/bishop_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// BishopModel — the single bishop/metropolitan displayed at the top of the
// Churches screen.
//
// Firestore path: config/bishop  (single document)
//   titleEl  : String  — Greek title + name
//   titleAr  : String  — Arabic title + name
//   imageUrl : String  — Optional photo URL (Cloudinary or external)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

class BishopModel {
  const BishopModel({
    required this.titleEl,
    required this.titleAr,
    this.imageUrl = '',
  });

  final String titleEl;
  final String titleAr;
  final String imageUrl;

  factory BishopModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BishopModel(
      titleEl:  d['titleEl']  as String? ?? '',
      titleAr:  d['titleAr']  as String? ?? '',
      imageUrl: d['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'titleEl':  titleEl,
        'titleAr':  titleAr,
        'imageUrl': imageUrl,
      };

  bool get isEmpty => titleEl.isEmpty && titleAr.isEmpty;
}
