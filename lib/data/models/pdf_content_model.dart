// lib/data/models/pdf_content_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Generic PDF content item used for:
//   psalmody | liturgy | readings | hymns | occasions
//
// Firestore collection: pdf_contents
// Document shape:
//   {
//     title_ar:            string,
//     title_el:            string,
//     category:            string,   // slug: psalmody | liturgy | readings | hymns | occasions
//     pdf_url:             string,   // Cloudinary raw URL
//     cloudinary_pdf_id:   string,
//     cover_url:           string,   // optional cover image
//     sort_order:          int,
//     is_visible:          bool,
//     created_at:          Timestamp,
//   }
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class PdfContent extends Equatable {
  const PdfContent({
    required this.id,
    required this.titleAr,
    required this.titleEl,
    required this.category,
    required this.pdfUrl,
    required this.cloudinaryPdfId,
    required this.coverUrl,
    required this.sortOrder,
    required this.isVisible,
    required this.createdAt,
  });

  final String   id;
  final String   titleAr;
  final String   titleEl;
  final String   category;         // 'psalmody' | 'liturgy' | 'readings' | 'hymns' | 'occasions'
  final String   pdfUrl;
  final String   cloudinaryPdfId;
  final String   coverUrl;
  final int      sortOrder;
  final bool     isVisible;
  final DateTime createdAt;

  // ── From Firestore ───────────────────────────────────────────────────────

  factory PdfContent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PdfContent(
      id:              doc.id,
      titleAr:         (d['title_ar']          as String? ?? ''),
      titleEl:         (d['title_el']          as String? ?? ''),
      category:        (d['category']          as String? ?? ''),
      pdfUrl:          (d['pdf_url']           as String? ?? ''),
      cloudinaryPdfId: (d['cloudinary_pdf_id'] as String? ?? ''),
      coverUrl:        (d['cover_url']         as String? ?? ''),
      sortOrder:       (d['sort_order']        as int?    ?? 0),
      isVisible:       (d['is_visible']        as bool?   ?? true),
      createdAt:       (d['created_at']        as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── To Firestore ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'title_ar':          titleAr,
    'title_el':          titleEl,
    'category':          category,
    'pdf_url':           pdfUrl,
    'cloudinary_pdf_id': cloudinaryPdfId,
    'cover_url':         coverUrl,
    'sort_order':        sortOrder,
    'is_visible':        isVisible,
    'created_at':        FieldValue.serverTimestamp(),
  };

  // ── CopyWith ─────────────────────────────────────────────────────────────

  PdfContent copyWith({
    String?   titleAr,
    String?   titleEl,
    String?   pdfUrl,
    String?   cloudinaryPdfId,
    String?   coverUrl,
    int?      sortOrder,
    bool?     isVisible,
  }) => PdfContent(
    id:              id,
    titleAr:         titleAr         ?? this.titleAr,
    titleEl:         titleEl         ?? this.titleEl,
    category:        category,
    pdfUrl:          pdfUrl          ?? this.pdfUrl,
    cloudinaryPdfId: cloudinaryPdfId ?? this.cloudinaryPdfId,
    coverUrl:        coverUrl        ?? this.coverUrl,
    sortOrder:       sortOrder       ?? this.sortOrder,
    isVisible:       isVisible       ?? this.isVisible,
    createdAt:       createdAt,
  );

  @override
  List<Object?> get props => [
    id, titleAr, titleEl, category, pdfUrl, cloudinaryPdfId,
    coverUrl, sortOrder, isVisible, createdAt,
  ];
}

// ── Category slugs ────────────────────────────────────────────────────────────

abstract class PdfCategory {
  static const String psalmody  = 'psalmody';
  static const String liturgy   = 'liturgy';
  static const String readings  = 'readings';
  static const String hymns     = 'hymns';
  static const String occasions = 'occasions';

  static const Map<String, String> labelAr = {
    psalmody:  'التسابيح',
    liturgy:   'القداسات',
    readings:  'القراءات',
    hymns:     'الألحان',
    occasions: 'مناسبات',
  };

  static const Map<String, String> labelEl = {
    psalmody:  'Ψαλμωδία',
    liturgy:   'Λειτουργία',
    readings:  'Αναγνώσεις',
    hymns:     'Ύμνοι',
    occasions: 'Εορτές',
  };
}
