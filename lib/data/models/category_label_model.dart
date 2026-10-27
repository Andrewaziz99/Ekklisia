// lib/data/models/category_label_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin-editable override for a PdfContent category's display name (the
// section's "tile"/drawer-entry title and list-screen header). Falls back to
// the compiled-in PdfCategory.labelAr/labelEl constants when no doc exists
// or a field is left blank — see CategoryLabelRepository.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CategoryLabel extends Equatable {
  const CategoryLabel({
    required this.category,
    this.labelAr = '',
    this.labelEl = '',
  });

  final String category;
  final String labelAr;
  final String labelEl;

  bool get isEmpty => labelAr.isEmpty && labelEl.isEmpty;

  factory CategoryLabel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return CategoryLabel(
      category: doc.id,
      labelAr:  d['label_ar'] as String? ?? '',
      labelEl:  d['label_el'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'label_ar': labelAr,
        'label_el': labelEl,
      };

  @override
  List<Object?> get props => [category, labelAr, labelEl];
}
