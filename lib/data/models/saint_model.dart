// lib/data/models/saint_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// SaintModel — standalone model for the Saints section.
// Supports optional cover image, PDF, audio and video via Cloudinary.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

class SaintModel {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? nameCoptic;
  final String? biographyAr;
  final String? biographyEn;
  final String? feastDate;        // MM-DD format
  final List<String> categories;

  // ── Cover image ────────────────────────────────────────────────────────────
  final String imageUrl;
  final String cloudinaryImageId;

  // ── PDF (optional) ─────────────────────────────────────────────────────────
  final String pdfUrl;
  final String cloudinaryPdfId;

  // ── Audio (optional, single track) ────────────────────────────────────────
  final String audioUrl;
  final String cloudinaryAudioId;

  // ── Video (optional, direct URL or YouTube) ───────────────────────────────
  final String videoUrl;
  final String cloudinaryVideoId;

  // ── Extra ──────────────────────────────────────────────────────────────────
  final String? patronOfAr;
  final String? patronOfEn;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const SaintModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.nameCoptic,
    this.biographyAr,
    this.biographyEn,
    this.feastDate,
    this.categories = const [],
    this.imageUrl = '',
    this.cloudinaryImageId = '',
    this.pdfUrl = '',
    this.cloudinaryPdfId = '',
    this.audioUrl = '',
    this.cloudinaryAudioId = '',
    this.videoUrl = '',
    this.cloudinaryVideoId = '',
    this.patronOfAr,
    this.patronOfEn,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // ── Convenience getters ────────────────────────────────────────────────────
  bool get hasImage => imageUrl.isNotEmpty;
  bool get hasPdf   => pdfUrl.isNotEmpty;
  bool get hasAudio => audioUrl.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;

  // ── Serialisation ──────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
    'nameAr':             nameAr,
    'nameEn':             nameEn,
    'nameCoptic':         nameCoptic,
    'biographyAr':        biographyAr,
    'biographyEn':        biographyEn,
    'feastDate':          feastDate,
    'categories':         categories,
    'imageUrl':           imageUrl,
    'cloudinaryImageId':  cloudinaryImageId,
    'pdfUrl':             pdfUrl,
    'cloudinaryPdfId':    cloudinaryPdfId,
    'audioUrl':           audioUrl,
    'cloudinaryAudioId':  cloudinaryAudioId,
    'videoUrl':           videoUrl,
    'cloudinaryVideoId':  cloudinaryVideoId,
    'patronOfAr':         patronOfAr,
    'patronOfEn':         patronOfEn,
    'isPublished':        isPublished,
    'createdAt':          createdAt,
    'updatedAt':          DateTime.now(),
    'createdBy':          createdBy,
  };

  factory SaintModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SaintModel(
      id:                 doc.id,
      nameAr:             d['nameAr'] ?? '',
      nameEn:             d['nameEn'] ?? '',
      nameCoptic:         d['nameCoptic'],
      biographyAr:        d['biographyAr'],
      biographyEn:        d['biographyEn'],
      feastDate:          d['feastDate'],
      categories:         List<String>.from(d['categories'] ?? []),
      // cover — fall back to legacy 'imageUrl' key from content_models era
      imageUrl:           d['imageUrl'] as String? ?? '',
      cloudinaryImageId:  d['cloudinaryImageId'] as String? ?? '',
      pdfUrl:             d['pdfUrl'] as String? ?? '',
      cloudinaryPdfId:    d['cloudinaryPdfId'] as String? ?? '',
      audioUrl:           d['audioUrl'] as String? ?? '',
      cloudinaryAudioId:  d['cloudinaryAudioId'] as String? ?? '',
      videoUrl:           d['videoUrl'] as String? ?? '',
      cloudinaryVideoId:  d['cloudinaryVideoId'] as String? ?? '',
      patronOfAr:         d['patronOfAr'],
      patronOfEn:         d['patronOfEn'],
      isPublished:        d['isPublished'] ?? false,
      createdAt:          (d['createdAt'] as Timestamp).toDate(),
      updatedAt:          d['updatedAt'] != null
                            ? (d['updatedAt'] as Timestamp).toDate()
                            : null,
      createdBy:          d['createdBy'] ?? '',
    );
  }

  SaintModel copyWith({
    String? nameAr,
    String? nameEn,
    String? nameCoptic,
    String? biographyAr,
    String? biographyEn,
    String? feastDate,
    List<String>? categories,
    String? imageUrl,
    String? cloudinaryImageId,
    String? pdfUrl,
    String? cloudinaryPdfId,
    String? audioUrl,
    String? cloudinaryAudioId,
    String? videoUrl,
    String? cloudinaryVideoId,
    String? patronOfAr,
    String? patronOfEn,
    bool? isPublished,
  }) => SaintModel(
    id:                this.id,
    nameAr:            nameAr            ?? this.nameAr,
    nameEn:            nameEn            ?? this.nameEn,
    nameCoptic:        nameCoptic        ?? this.nameCoptic,
    biographyAr:       biographyAr       ?? this.biographyAr,
    biographyEn:       biographyEn       ?? this.biographyEn,
    feastDate:         feastDate         ?? this.feastDate,
    categories:        categories        ?? this.categories,
    imageUrl:          imageUrl          ?? this.imageUrl,
    cloudinaryImageId: cloudinaryImageId ?? this.cloudinaryImageId,
    pdfUrl:            pdfUrl            ?? this.pdfUrl,
    cloudinaryPdfId:   cloudinaryPdfId   ?? this.cloudinaryPdfId,
    audioUrl:          audioUrl          ?? this.audioUrl,
    cloudinaryAudioId: cloudinaryAudioId ?? this.cloudinaryAudioId,
    videoUrl:          videoUrl          ?? this.videoUrl,
    cloudinaryVideoId: cloudinaryVideoId ?? this.cloudinaryVideoId,
    patronOfAr:        patronOfAr        ?? this.patronOfAr,
    patronOfEn:        patronOfEn        ?? this.patronOfEn,
    isPublished:       isPublished       ?? this.isPublished,
    createdAt:         this.createdAt,
    updatedAt:         DateTime.now(),
    createdBy:         this.createdBy,
  );
}
