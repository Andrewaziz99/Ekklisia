import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a PDF book stored in Firestore.
/// PDF files are hosted on Cloudinary; metadata lives in Firestore.
class BookModel extends Equatable {
  final String id;
  final String titleAr; // Arabic title
  final String titleCop; // Coptic title (may be empty)
  final String titleEl; // Greek title (may be empty)
  final String descriptionAr;
  final String descriptionEl;
  final String category; // See AppConstants.bookCategories
  final String pdfUrl; // Cloudinary raw URL
  final String coverUrl; // Cloudinary image URL (thumbnail)
  final String cloudinaryPdfId; // Cloudinary public_id for the PDF asset
  final int pageCount;
  final double fileSizeMb;
  final bool isPublished;
  final String addedByUid; // Admin UID
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final Map<String, dynamic> metadata; // flexible extra fields

  const BookModel({
    required this.id,
    required this.titleAr,
    this.titleCop = '',
    this.titleEl = '',
    this.descriptionAr = '',
    this.descriptionEl = '',
    required this.category,
    required this.pdfUrl,
    this.coverUrl = '',
    this.cloudinaryPdfId = '',
    this.pageCount = 0,
    this.fileSizeMb = 0,
    this.isPublished = true,
    required this.addedByUid,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.metadata = const {},
  });

  // ── Display helpers ─────────────────────────────────────────────────────

  /// Returns the best available title given a language code.
  String titleFor(String langCode) {
    switch (langCode) {
      case 'cop':
        return titleCop.isNotEmpty ? titleCop : titleAr;
      case 'el':
        return titleEl.isNotEmpty ? titleEl : titleAr;
      default:
        return titleAr;
    }
  }

  String descriptionFor(String langCode) {
    switch (langCode) {
      case 'el':
        return descriptionEl.isNotEmpty ? descriptionEl : descriptionAr;
      default:
        return descriptionAr;
    }
  }

  String get formattedSize {
    if (fileSizeMb < 1) return '${(fileSizeMb * 1024).toStringAsFixed(0)} KB';
    return '${fileSizeMb.toStringAsFixed(1)} MB';
  }

  // ── Firestore serialization ─────────────────────────────────────────────

  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookModel(
      id: doc.id,
      titleAr: data['title_ar'] ?? '',
      titleCop: data['title_cop'] ?? '',
      titleEl: data['title_el'] ?? '',
      descriptionAr: data['description_ar'] ?? '',
      descriptionEl: data['description_el'] ?? '',
      category: data['category'] ?? 'other',
      pdfUrl: data['pdf_url'] ?? '',
      coverUrl: data['cover_url'] ?? '',
      cloudinaryPdfId: data['cloudinary_pdf_id'] ?? '',
      pageCount: (data['page_count'] ?? 0) as int,
      fileSizeMb: (data['file_size_mb'] ?? 0).toDouble(),
      isPublished: data['is_published'] ?? true,
      addedByUid: data['added_by_uid'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title_ar': titleAr,
    'title_cop': titleCop,
    'title_el': titleEl,
    'description_ar': descriptionAr,
    'description_el': descriptionEl,
    'category': category,
    'pdf_url': pdfUrl,
    'cover_url': coverUrl,
    'cloudinary_pdf_id': cloudinaryPdfId,
    'page_count': pageCount,
    'file_size_mb': fileSizeMb,
    'is_published': isPublished,
    'added_by_uid': addedByUid,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    'tags': tags,
    'metadata': metadata,
  };

  BookModel copyWith({
    String? id,
    String? titleAr,
    String? titleCop,
    String? titleEl,
    String? descriptionAr,
    String? descriptionEl,
    String? category,
    String? pdfUrl,
    String? coverUrl,
    String? cloudinaryPdfId,
    int? pageCount,
    double? fileSizeMb,
    bool? isPublished,
    String? addedByUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) => BookModel(
    id: id ?? this.id,
    titleAr: titleAr ?? this.titleAr,
    titleCop: titleCop ?? this.titleCop,
    titleEl: titleEl ?? this.titleEl,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEl: descriptionEl ?? this.descriptionEl,
    category: category ?? this.category,
    pdfUrl: pdfUrl ?? this.pdfUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    cloudinaryPdfId: cloudinaryPdfId ?? this.cloudinaryPdfId,
    pageCount: pageCount ?? this.pageCount,
    fileSizeMb: fileSizeMb ?? this.fileSizeMb,
    isPublished: isPublished ?? this.isPublished,
    addedByUid: addedByUid ?? this.addedByUid,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tags: tags ?? this.tags,
    metadata: metadata ?? this.metadata,
  );

  @override
  List<Object?> get props => [
    id,
    titleAr,
    titleCop,
    titleEl,
    category,
    pdfUrl,
    coverUrl,
    isPublished,
    createdAt,
  ];
}
