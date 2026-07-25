// lib/data/models/priest_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// PriestModel — a priest as its own top-level entity, independent of any
// church document. This lets admins edit a priest without touching the
// church they belong to, and vice versa.
//
// Firestore schema (collection: 'priests'):
//   name       : String   — Greek/English name
//   nameAr     : String   — Arabic name (optional)
//   phone      : String
//   imageUrl   : String
//   churchId   : String?  — set only when linked to a real doc in
//                            'churches'; null/absent for a free-typed name.
//   churchName : String   — always populated: either the linked church's
//                            display name (kept in sync at save time), or
//                            whatever text the admin typed.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

class PriestModel {
  const PriestModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.churchName,
    this.nameAr = '',
    this.churchId,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String nameAr;
  final String phone;

  /// Non-null only when linked to an existing document in 'churches'.
  final String? churchId;

  /// Always populated — the linked church's name, or free-typed text.
  final String churchName;

  final String imageUrl;

  /// Whether this priest is tied to a real church document (vs. a
  /// free-typed church name with no backing record).
  bool get isLinkedToChurch => churchId != null && churchId!.isNotEmpty;

  factory PriestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PriestModel(
      id:         doc.id,
      name:       d['name']       as String? ?? '',
      nameAr:     d['nameAr']     as String? ?? '',
      phone:      d['phone']      as String? ?? '',
      churchId:   d['churchId']   as String?,
      churchName: d['churchName'] as String? ?? '',
      imageUrl:   d['imageUrl']   as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name':       name,
        'nameAr':     nameAr,
        'phone':      phone,
        'churchId':   churchId,
        'churchName': churchName,
        'imageUrl':   imageUrl,
      };

  PriestModel copyWith({
    String? name,
    String? nameAr,
    String? phone,
    String? churchName,
    String? imageUrl,
    // Explicit setter since churchId legitimately needs to go from a value
    // back to null (switching from a linked church to free-typed text).
    Object? churchId = _unset,
  }) =>
      PriestModel(
        id:         id,
        name:       name       ?? this.name,
        nameAr:     nameAr     ?? this.nameAr,
        phone:      phone      ?? this.phone,
        churchName: churchName ?? this.churchName,
        imageUrl:   imageUrl   ?? this.imageUrl,
        churchId:   identical(churchId, _unset)
            ? this.churchId
            : churchId as String?,
      );
}

const _unset = Object();
