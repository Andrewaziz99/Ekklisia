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
  final int durationSeconds;

  String labelFor(String langCode) {
    switch (langCode) {
      case 'el':
        return labelEl.isNotEmpty ? labelEl : labelAr;
      default:
        return labelAr;
    }
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory ContentAudioTrack.fromMap(Map<String, dynamic> m) =>
      ContentAudioTrack(
        labelAr: m['label_ar'] as String? ?? '',
        labelEl: m['label_el'] as String? ?? '',
        url: m['url'] as String? ?? '',
        cloudinaryAudioId: m['cloudinary_audio_id'] as String? ?? '',
        durationSeconds: m['duration_seconds'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'label_ar': labelAr,
    'label_el': labelEl,
    'url': url,
    'cloudinary_audio_id': cloudinaryAudioId,
    'duration_seconds': durationSeconds,
  };

  @override
  List<Object?> get props => [
    labelAr,
    labelEl,
    url,
    cloudinaryAudioId,
    durationSeconds,
  ];
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
    this.videoUrl = '',
    this.cloudinaryVideoId = '',
    this.level = '',
    this.descriptionAr = '',
    this.descriptionEl = '',
    this.sectionId = '',
  });

  final String id;
  final String titleAr;
  final String titleEl;
  final String
  category; // 'psalmody' | 'liturgy' | 'readings' | 'hymns' | 'occasions'
  final String pdfUrl;
  final String cloudinaryPdfId;
  final String coverUrl;
  final int sortOrder;
  final bool isVisible;
  final DateTime createdAt;
  final List<ContentAudioTrack> audioTracks;
  final String videoUrl;
  final String cloudinaryVideoId;

  /// Bilingual description shown on the item's detail view. Used by the
  /// [PdfCategory.artworks] category in place of a PDF — tapping an artwork
  /// card shows the cover image plus this text instead of opening a file.
  final String descriptionAr;
  final String descriptionEl;

  bool get hasDescription =>
      descriptionAr.isNotEmpty || descriptionEl.isNotEmpty;

  String descriptionFor(String langCode) {
    switch (langCode) {
      case 'el':
        return descriptionEl.isNotEmpty ? descriptionEl : descriptionAr;
      default:
        return descriptionAr.isNotEmpty ? descriptionAr : descriptionEl;
    }
  }

  /// Only meaningful for [PdfCategory.theses] — see [ThesisLevel]. Empty for
  /// every other category, and for theses items uploaded before this field
  /// existed (the list screen buckets those into a fallback "unspecified"
  /// section rather than hiding them).
  final String level;

  /// Only meaningful for [PdfCategory.artworks] — id of an [ArtworkSection]
  /// document (admin-editable, see ArtworkSectionRepository). Empty when
  /// unset — the list screen buckets those into a fallback "unspecified"
  /// section rather than hiding them.
  final String sectionId;

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
      id: doc.id,
      titleAr: (d['title_ar'] as String? ?? ''),
      titleEl: (d['title_el'] as String? ?? ''),
      category: (d['category'] as String? ?? ''),
      pdfUrl: (d['pdf_url'] as String? ?? ''),
      cloudinaryPdfId: (d['cloudinary_pdf_id'] as String? ?? ''),
      coverUrl: (d['cover_url'] as String? ?? ''),
      sortOrder: (d['sort_order'] as int? ?? 0),
      isVisible: (d['is_visible'] as bool? ?? true),
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      audioTracks: tracks,
      videoUrl: (d['video_url'] as String? ?? ''),
      cloudinaryVideoId: (d['cloudinary_video_id'] as String? ?? ''),
      level: (d['level'] as String? ?? ''),
      descriptionAr: (d['description_ar'] as String? ?? ''),
      descriptionEl: (d['description_el'] as String? ?? ''),
      sectionId: (d['section_id'] as String? ?? ''),
    );
  }

  // ── To Firestore ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'title_ar': titleAr,
    'title_el': titleEl,
    'category': category,
    'pdf_url': pdfUrl,
    'cloudinary_pdf_id': cloudinaryPdfId,
    'cover_url': coverUrl,
    'sort_order': sortOrder,
    'is_visible': isVisible,
    'created_at': FieldValue.serverTimestamp(),
    'audio_tracks': audioTracks.map((t) => t.toMap()).toList(),
    'video_url': videoUrl,
    'cloudinary_video_id': cloudinaryVideoId,
    'level': level,
    'description_ar': descriptionAr,
    'description_el': descriptionEl,
    'section_id': sectionId,
  };

  // ── CopyWith ─────────────────────────────────────────────────────────────

  PdfContent copyWith({
    String? titleAr,
    String? titleEl,
    String? pdfUrl,
    String? cloudinaryPdfId,
    String? coverUrl,
    int? sortOrder,
    bool? isVisible,
    List<ContentAudioTrack>? audioTracks,
    String? videoUrl,
    String? cloudinaryVideoId,
    String? level,
    String? descriptionAr,
    String? descriptionEl,
    String? sectionId,
  }) => PdfContent(
    id: id,
    titleAr: titleAr ?? this.titleAr,
    titleEl: titleEl ?? this.titleEl,
    category: category,
    pdfUrl: pdfUrl ?? this.pdfUrl,
    cloudinaryPdfId: cloudinaryPdfId ?? this.cloudinaryPdfId,
    coverUrl: coverUrl ?? this.coverUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    isVisible: isVisible ?? this.isVisible,
    createdAt: createdAt,
    audioTracks: audioTracks ?? this.audioTracks,
    videoUrl: videoUrl ?? this.videoUrl,
    cloudinaryVideoId: cloudinaryVideoId ?? this.cloudinaryVideoId,
    level: level ?? this.level,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEl: descriptionEl ?? this.descriptionEl,
    sectionId: sectionId ?? this.sectionId,
  );

  @override
  List<Object?> get props => [
    id,
    titleAr,
    titleEl,
    category,
    pdfUrl,
    cloudinaryPdfId,
    coverUrl,
    sortOrder,
    isVisible,
    createdAt,
    audioTracks,
    videoUrl,
    cloudinaryVideoId,
    level,
    descriptionAr,
    descriptionEl,
    sectionId,
  ];
}

// ── Section description (constant top-of-screen card, per category) ──────────
// Editable from the admin CMS — describes the whole category (e.g. Art
// Works) rather than a single item. Optional bilingual body text plus a list
// of "available at" link buttons (e.g. a partner church, an external shop).
//
// Firestore collection: section_descriptions, doc id == category slug.

class SectionLink extends Equatable {
  const SectionLink({
    required this.labelAr,
    required this.labelEl,
    required this.url,
  });

  final String labelAr;
  final String labelEl;
  final String url;

  String labelFor(String langCode) {
    switch (langCode) {
      case 'el':
        return labelEl.isNotEmpty ? labelEl : labelAr;
      default:
        return labelAr.isNotEmpty ? labelAr : labelEl;
    }
  }

  factory SectionLink.fromMap(Map<String, dynamic> m) => SectionLink(
        labelAr: m['label_ar'] as String? ?? '',
        labelEl: m['label_el'] as String? ?? '',
        url: m['url'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'label_ar': labelAr,
        'label_el': labelEl,
        'url': url,
      };

  @override
  List<Object?> get props => [labelAr, labelEl, url];
}

class SectionDescription extends Equatable {
  const SectionDescription({
    required this.category,
    this.descriptionAr = '',
    this.descriptionEl = '',
    this.links = const [],
  });

  final String category;
  final String descriptionAr;
  final String descriptionEl;
  final List<SectionLink> links;

  bool get hasDescription =>
      descriptionAr.isNotEmpty || descriptionEl.isNotEmpty;
  bool get hasLinks => links.isNotEmpty;
  bool get isEmpty => !hasDescription && !hasLinks;

  factory SectionDescription.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawLinks = d['links'];
    final links = rawLinks is List
        ? rawLinks
            .whereType<Map<String, dynamic>>()
            .map(SectionLink.fromMap)
            .toList()
        : const <SectionLink>[];
    return SectionDescription(
      category: doc.id,
      descriptionAr: d['description_ar'] as String? ?? '',
      descriptionEl: d['description_el'] as String? ?? '',
      links: links,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'description_ar': descriptionAr,
        'description_el': descriptionEl,
        'links': links.map((l) => l.toMap()).toList(),
      };

  SectionDescription copyWith({
    String? descriptionAr,
    String? descriptionEl,
    List<SectionLink>? links,
  }) =>
      SectionDescription(
        category: category,
        descriptionAr: descriptionAr ?? this.descriptionAr,
        descriptionEl: descriptionEl ?? this.descriptionEl,
        links: links ?? this.links,
      );

  @override
  List<Object?> get props => [category, descriptionAr, descriptionEl, links];
}

// ── Thesis level (only meaningful for PdfCategory.theses) ─────────────────────

abstract class ThesisLevel {
  static const String masters = 'masters';
  static const String doctoral = 'doctoral';
}

// ── Category slugs ────────────────────────────────────────────────────────────

abstract class PdfCategory {
  static const String psalmody = 'psalmody';
  static const String liturgy = 'liturgy';
  static const String readings = 'readings';
  static const String hymns = 'hymns';
  static const String occasions = 'occasions';
  static const String theses = 'theses';
  static const String christianBooks = 'christian_books';
  static const String serviceBooks = 'service_books';
  static const String artworks = 'artworks';

  static const Map<String, String> labelAr = {
    psalmody: 'الترانيم',
    liturgy: 'القداسات',
    readings: 'كتب ليتورجية',
    hymns: 'الألحان',
    occasions: 'أسبوع الآلام',
    theses: 'رسائل الدكتوراه والماجستير',
    christianBooks: 'الكتب المسيحية',
    serviceBooks: 'كتب الخدمة',
    artworks: 'أعمال فنية',
  };

  static const Map<String, String> labelEl = {
    psalmody: 'Ψαλμωδία',
    liturgy: 'Λειτουργία',
    readings: 'Λειτουργικά βιβλία',
    hymns: 'Ύμνοι',
    occasions: 'Εβδομάδα Μ.',
    theses: 'Διδακτορικά και Μεταπτυχιακές Εργασίες',
    christianBooks: 'Χριστιανικά Βιβλία',
    serviceBooks: 'Βιβλία Διακονίας',
    artworks: 'Έργα τέχνης',
  };
}
