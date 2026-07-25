// lib/data/models/agbeya_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Agbeya (Coptic Book of Hours) data models.
//
// Mirrors BookModel architecture:
//   • Firestore collection: agbeya_hours
//   • Audio hosted on Cloudinary (audio_url field)
//   • Multi-language text embedded as sections array
//
// Firestore document shape:
//   {
//     hour_number: int,          // 1–7 (canonical hour identity — DO NOT reuse
//                                //      for display order; see sort_order)
//     sort_order: int,           // Display/drag-reorder position. Falls back
//                                //      to hour_number when absent so existing
//                                //      documents keep their original order
//                                //      until an admin explicitly reorders.
//     title_ar: string,
//     title_cop: string,
//     title_el: string,
//     description_ar: string,
//     audio_url: string,         // Cloudinary audio URL
//     cover_url: string,
//     duration_seconds: int,
//     sections: [                // Ordered prayer sections
//       {
//         title_ar, title_cop, title_el,
//         text_ar, text_cop, text_el
//       }
//     ],
//     is_published: bool,
//     created_at: Timestamp,
//     updated_at: Timestamp,
//   }
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ── AgbeyaSection ─────────────────────────────────────────────────────────────
// A single prayer block within an hour (e.g. the Lord's Prayer, a psalm, etc.)

class AgbeyaSection extends Equatable {
  final String titleAr;
  final String titleCop;
  final String titleEl;
  final String textAr;
  final String textCop;
  final String textEl;

  const AgbeyaSection({
    this.titleAr = '',
    this.titleCop = '',
    this.titleEl = '',
    this.textAr = '',
    this.textCop = '',
    this.textEl = '',
  });

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

  String textFor(String langCode) {
    switch (langCode) {
      case 'cop':
        return textCop.isNotEmpty ? textCop : textAr;
      case 'el':
        return textEl.isNotEmpty ? textEl : textAr;
      default:
        return textAr;
    }
  }

  factory AgbeyaSection.fromMap(Map<String, dynamic> m) => AgbeyaSection(
        titleAr: m['title_ar'] as String? ?? '',
        titleCop: m['title_cop'] as String? ?? '',
        titleEl: m['title_el'] as String? ?? '',
        textAr: m['text_ar'] as String? ?? '',
        textCop: m['text_cop'] as String? ?? '',
        textEl: m['text_el'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'title_ar': titleAr,
        'title_cop': titleCop,
        'title_el': titleEl,
        'text_ar': textAr,
        'text_cop': textCop,
        'text_el': textEl,
      };

  @override
  List<Object?> get props => [titleAr, textAr, textCop, textEl];
}

// ── AgbeyaAudioTrack ─────────────────────────────────────────────────────────
// One audio recording for an Agbeya hour.
// An hour can have up to 2 tracks (e.g. Deacon voice / Priest voice).

class AgbeyaAudioTrack extends Equatable {
  final String labelAr;  // e.g. "الشماس"
  final String labelCop;
  final String labelEl;
  final String url;            // Cloudinary video (audio) URL
  final int    durationSeconds;

  const AgbeyaAudioTrack({
    this.labelAr         = '',
    this.labelCop        = '',
    this.labelEl         = '',
    required this.url,
    this.durationSeconds = 0,
  });

  String labelFor(String langCode) {
    switch (langCode) {
      case 'cop': return labelCop.isNotEmpty ? labelCop : labelAr;
      case 'el':  return labelEl.isNotEmpty  ? labelEl  : labelAr;
      default:    return labelAr;
    }
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory AgbeyaAudioTrack.fromMap(Map<String, dynamic> m) => AgbeyaAudioTrack(
        labelAr:         m['label_ar']  as String? ?? '',
        labelCop:        m['label_cop'] as String? ?? '',
        labelEl:         m['label_el']  as String? ?? '',
        url:             m['url']       as String? ?? '',
        durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'label_ar':         labelAr,
        'label_cop':        labelCop,
        'label_el':         labelEl,
        'url':              url,
        'duration_seconds': durationSeconds,
      };

  @override
  List<Object?> get props => [url, labelAr];
}

// ── AgbeyaHour ────────────────────────────────────────────────────────────────
// One of the seven canonical hours of the Coptic Agbeya.

class AgbeyaHour extends Equatable {
  final String id;
  final int hourNumber; // 1–7 (canonical hour identity — used for names/colors)
  final int sortOrder;  // display/drag-reorder position (independent of hourNumber)
  final String titleAr;
  final String titleCop;
  final String titleEl;
  final String descriptionAr;
  // Legacy single-track field — kept for backward compatibility.
  // New hours should use audioTracks instead.
  final String audioUrl;
  final String coverUrl;
  final String pdfUrl;          // Cloudinary PDF URL (Phase 1)
  final String cloudinaryPdfId;
  final int durationSeconds;    // Legacy — use audioTracks[i].durationSeconds
  // Multi-track audio (up to 2 tracks; admin sets labels like "الشماس" / "الكاهن")
  final List<AgbeyaAudioTrack> audioTracks;
  final List<AgbeyaSection> sections;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String videoUrl;
  final String cloudinaryVideoId;

  const AgbeyaHour({
    required this.id,
    required this.hourNumber,
    required this.sortOrder,
    required this.titleAr,
    this.titleCop = '',
    this.titleEl = '',
    this.descriptionAr = '',
    this.audioUrl = '',
    this.coverUrl = '',
    this.pdfUrl = '',
    this.cloudinaryPdfId = '',
    this.durationSeconds = 0,
    this.audioTracks = const [],
    this.sections = const [],
    this.isPublished = true,
    required this.createdAt,
    required this.updatedAt,
    this.videoUrl = '',
    this.cloudinaryVideoId = '',
  });

  // ── Display helpers ─────────────────────────────────────────────────────────

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

  /// e.g. "23:47"
  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get hasPdf   => pdfUrl.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;

  /// True if there is at least one playable audio track.
  bool get hasAudio => audioTracks.isNotEmpty || audioUrl.isNotEmpty;

  /// True when multiple tracks are available and user should be prompted to pick.
  bool get isMultiTrack => audioTracks.length > 1;

  /// The tracks to offer for playback.
  /// Falls back to the legacy [audioUrl] for documents created before multi-track.
  List<AgbeyaAudioTrack> get effectiveTracks {
    if (audioTracks.isNotEmpty) return audioTracks;
    if (audioUrl.isNotEmpty) {
      return [
        AgbeyaAudioTrack(
          labelAr: titleAr,
          url: audioUrl,
          durationSeconds: durationSeconds,
        )
      ];
    }
    return const [];
  }

  // ── Firestore serialization ─────────────────────────────────────────────────

  factory AgbeyaHour.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final hourNumber = (d['hour_number'] as num?)?.toInt() ?? 0;
    return AgbeyaHour(
      id: doc.id,
      hourNumber: hourNumber,
      // Falls back to hourNumber for documents written before drag-reorder
      // support existed, so their display order doesn't change until an
      // admin explicitly reorders them.
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? hourNumber,
      titleAr: d['title_ar'] as String? ?? '',
      titleCop: d['title_cop'] as String? ?? '',
      titleEl: d['title_el'] as String? ?? '',
      descriptionAr: d['description_ar'] as String? ?? '',
      audioUrl: d['audio_url'] as String? ?? '',
      coverUrl: d['cover_url'] as String? ?? '',
      pdfUrl: d['pdf_url'] as String? ?? '',
      cloudinaryPdfId: d['cloudinary_pdf_id'] as String? ?? '',
      durationSeconds: (d['duration_seconds'] as num?)?.toInt() ?? 0,
      audioTracks: (d['audio_tracks'] as List<dynamic>? ?? [])
          .map((t) => AgbeyaAudioTrack.fromMap(t as Map<String, dynamic>))
          .toList(),
      sections: (d['sections'] as List<dynamic>? ?? [])
          .map((s) => AgbeyaSection.fromMap(s as Map<String, dynamic>))
          .toList(),
      isPublished: d['is_published'] as bool? ?? true,
      createdAt:
          (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (d['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      videoUrl:          d['video_url']           as String? ?? '',
      cloudinaryVideoId: d['cloudinary_video_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'hour_number': hourNumber,
        'sort_order': sortOrder,
        'title_ar': titleAr,
        'title_cop': titleCop,
        'title_el': titleEl,
        'description_ar': descriptionAr,
        'audio_url': audioUrl,
        'cover_url': coverUrl,
        'pdf_url': pdfUrl,
        'cloudinary_pdf_id': cloudinaryPdfId,
        'duration_seconds': durationSeconds,
        'audio_tracks': audioTracks.map((t) => t.toMap()).toList(),
        'sections': sections.map((s) => s.toMap()).toList(),
        'is_published': isPublished,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'video_url':           videoUrl,
        'cloudinary_video_id': cloudinaryVideoId,
      };

  AgbeyaHour copyWith({
    String? id,
    int? hourNumber,
    int? sortOrder,
    String? titleAr,
    String? titleCop,
    String? titleEl,
    String? descriptionAr,
    String? audioUrl,
    String? coverUrl,
    String? pdfUrl,
    String? cloudinaryPdfId,
    int? durationSeconds,
    List<AgbeyaAudioTrack>? audioTracks,
    List<AgbeyaSection>? sections,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? videoUrl,
    String? cloudinaryVideoId,
  }) =>
      AgbeyaHour(
        id: id ?? this.id,
        hourNumber: hourNumber ?? this.hourNumber,
        sortOrder: sortOrder ?? this.sortOrder,
        titleAr: titleAr ?? this.titleAr,
        titleCop: titleCop ?? this.titleCop,
        titleEl: titleEl ?? this.titleEl,
        descriptionAr: descriptionAr ?? this.descriptionAr,
        audioUrl: audioUrl ?? this.audioUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        pdfUrl: pdfUrl ?? this.pdfUrl,
        cloudinaryPdfId: cloudinaryPdfId ?? this.cloudinaryPdfId,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        audioTracks: audioTracks ?? this.audioTracks,
        sections: sections ?? this.sections,
        isPublished: isPublished ?? this.isPublished,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        videoUrl:          videoUrl          ?? this.videoUrl,
        cloudinaryVideoId: cloudinaryVideoId ?? this.cloudinaryVideoId,
      );

  @override
  List<Object?> get props => [
        id,
        hourNumber,
        sortOrder,
        titleAr,
        audioUrl,
        isPublished,
        createdAt,
      ];
}
