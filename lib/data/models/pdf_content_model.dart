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
//     audio_tracks:        List<Map>, // optional audio tracks
//   }
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ── ContentAudioTrack ─────────────────────────────────────────────────────────

class ContentAudioTrack extends Equatable {
  const ContentAudioTrack({
    required this.labelAr,
    required this.labelEl,
    required this.url,
    required this.cloudinaryAudioId,
    required this.durationSeconds,
  });

  final String labelAr;
  final String labelEl;
  final String url;
  final String cloudinaryAudioId;
  final int    durationSeconds;

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory ContentAudioTrack.fromMap(Map<String, dynamic> m) => ContentAudioTrack(
    labelAr:           m['label_ar']             as String? ?? '',
    labelEl:           m['label_el']             as String? ?? '',
    url:               m['url']                  as String? ?? '',
    cloudinaryAudioId: m['cloudinary_audio_id']  as String? ?? '',
    durationSeconds:   m['duration_seconds']     as int?    ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'label_ar':            labelAr,
    'label_el':            labelEl,
    'url':                 url,
    'cloudinary_audio_id': cloudinaryAudioId,
    'duration_seconds':    durationSeconds,
  };

  @override
  List<Object?> get props => [labelAr, labelEl, url, cloudinaryAudioId, durationSeconds];
}

// ── PdfContent ────────────────────────────────────────────────────────────────

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
    this.audioTracks = const [],
    this.videoUrl          = '',
    this.cloudinaryVideoId = '',
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
  final List<ContentAudioTrack> audioTracks;
  final String   videoUrl;
  final String   cloudinaryVideoId;

  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;

  // ── From Firestore ───────────────────────────────────────────────────────

  factory PdfContent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawTracks = d['audio_tracks'];
    final tracks = rawTracks is List
        ? rawTracks
            .whereType<Map<String, dynamic>>()
            .map(ContentAudioTrack.fromMap)
            .toList()
        : const <ContentAudioTrack>[];
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
      audioTracks:          tracks,
      videoUrl:             (d['video_url']           as String? ?? ''),
      cloudinaryVideoId:    (d['cloudinary_video_id'] as String? ?? ''),
    );
  }

  // ── To Firestore ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'title_ar':             titleAr,
    'title_el':             titleEl,
    'category':             category,
    'pdf_url':              pdfUrl,
    'cloudinary_pdf_id':    cloudinaryPdfId,
    'cover_url':            coverUrl,
    'sort_order':           sortOrder,
    'is_visible':           isVisible,
    'created_at':           FieldValue.serverTimestamp(),
    'audio_tracks':         audioTracks.map((t) => t.toMap()).toList(),
    'video_url':            videoUrl,
    'cloudinary_video_id':  cloudinaryVideoId,
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
    List<ContentAudioTrack>? audioTracks,
    String?   videoUrl,
    String?   cloudinaryVideoId,
  }) => PdfContent(
    id:                   id,
    titleAr:              titleAr              ?? this.titleAr,
    titleEl:              titleEl              ?? this.titleEl,
    category:             category,
    pdfUrl:               pdfUrl               ?? this.pdfUrl,
    cloudinaryPdfId:      cloudinaryPdfId      ?? this.cloudinaryPdfId,
    coverUrl:             coverUrl             ?? this.coverUrl,
    sortOrder:            sortOrder            ?? this.sortOrder,
    isVisible:            isVisible            ?? this.isVisible,
    createdAt:            createdAt,
    audioTracks:          audioTracks          ?? this.audioTracks,
    videoUrl:             videoUrl             ?? this.videoUrl,
    cloudinaryVideoId:    cloudinaryVideoId    ?? this.cloudinaryVideoId,
  );

  @override
  List<Object?> get props => [
    id, titleAr, titleEl, category, pdfUrl, cloudinaryPdfId,
    coverUrl, sortOrder, isVisible, createdAt, audioTracks,
    videoUrl, cloudinaryVideoId,
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
