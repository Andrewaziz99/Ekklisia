// lib/data/models/elib_section_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ElibSectionModel {
  final String id;
  final String titleAr;
  final String titleEl;
  final int order;
  final DateTime createdAt;

  const ElibSectionModel({
    required this.id,
    this.titleAr = '',
    this.titleEl = '',
    this.order = 0,
    required this.createdAt,
  });

  ElibSectionModel copyWith({
    String? id,
    String? titleAr,
    String? titleEl,
    int? order,
    DateTime? createdAt,
  }) => ElibSectionModel(
    id: id ?? this.id,
    titleAr: titleAr ?? this.titleAr,
    titleEl: titleEl ?? this.titleEl,
    order: order ?? this.order,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'titleAr': titleAr,
    'titleEl': titleEl,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory ElibSectionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ElibSectionModel(
      id: doc.id,
      titleAr: d['titleAr'] as String? ?? '',
      titleEl: d['titleEl'] as String? ?? '',
      order: d['order'] as int? ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
