// lib/data/models/bookmark_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Per-user bookmarks. One model covers two kinds of saved reference:
//   • 'content' — a PdfContent item (Psalmody, Liturgies, Readings, Hymns,
//     Occasions, Theses, Christian/Service Books). [page] is 0 for a
//     whole-item bookmark, or a specific 1-indexed PDF page.
//   • 'bible'   — a Bible reference. [verse] is 0 for a whole-chapter
//     bookmark, or a specific verse number.
//
// Firestore collection: bookmarks, doc id is deterministic (see
// BookmarkRepository) so toggling on/off never creates duplicates.
// Display fields (titles, cover, pdf url, book names) are denormalized at
// save time so the Bookmarks screen can render + deep-link without extra
// reads.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

abstract class BookmarkType {
  static const String content = 'content';
  static const String bible = 'bible';
}

class BookmarkModel extends Equatable {
  const BookmarkModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.createdAt,
    this.contentId = '',
    this.category = '',
    this.page = 0,
    this.titleAr = '',
    this.titleEl = '',
    this.coverUrl = '',
    this.pdfUrl = '',
    this.bookNumber = 0,
    this.bookNameAr = '',
    this.bookNameEl = '',
    this.chapter = 0,
    this.verse = 0,
    this.textAr = '',
    this.textEl = '',
  });

  final String id;
  final String userId;
  final String type; // BookmarkType.content | BookmarkType.bible
  final DateTime createdAt;

  // ── Content bookmark fields ────────────────────────────────────────────
  final String contentId;
  final String category;

  /// 0 = whole item, >0 = a specific page within the PDF.
  final int page;
  final String titleAr;
  final String titleEl;
  final String coverUrl;
  final String pdfUrl;

  // ── Bible bookmark fields ──────────────────────────────────────────────
  final int bookNumber;
  final String bookNameAr;
  final String bookNameEl;
  final int chapter;

  /// 0 = whole chapter, >0 = a specific verse.
  final int verse;

  /// Verse text in both languages, denormalized at bookmark time (verse
  /// bookmarks only — whole-chapter bookmarks leave these empty since a
  /// full chapter is too long to preview as a snippet).
  final String textAr;
  final String textEl;

  bool get isBible => type == BookmarkType.bible;
  bool get isContentPage => type == BookmarkType.content && page > 0;
  bool get isVerse => type == BookmarkType.bible && verse > 0;

  factory BookmarkModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    return BookmarkModel(
      id: doc.id,
      userId: (d['user_id'] as String? ?? ''),
      type: (d['type'] as String? ?? BookmarkType.content),
      contentId: (d['content_id'] as String? ?? ''),
      category: (d['category'] as String? ?? ''),
      page: (d['page'] as num? ?? 0).toInt(),
      titleAr: (d['title_ar'] as String? ?? ''),
      titleEl: (d['title_el'] as String? ?? ''),
      coverUrl: (d['cover_url'] as String? ?? ''),
      pdfUrl: (d['pdf_url'] as String? ?? ''),
      bookNumber: (d['book_number'] as num? ?? 0).toInt(),
      bookNameAr: (d['book_name_ar'] as String? ?? ''),
      bookNameEl: (d['book_name_el'] as String? ?? ''),
      chapter: (d['chapter'] as num? ?? 0).toInt(),
      verse: (d['verse'] as num? ?? 0).toInt(),
      textAr: (d['text_ar'] as String? ?? ''),
      textEl: (d['text_el'] as String? ?? ''),
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'type': type,
    'content_id': contentId,
    'category': category,
    'page': page,
    'title_ar': titleAr,
    'title_el': titleEl,
    'cover_url': coverUrl,
    'pdf_url': pdfUrl,
    'book_number': bookNumber,
    'book_name_ar': bookNameAr,
    'book_name_el': bookNameEl,
    'chapter': chapter,
    'verse': verse,
    'text_ar': textAr,
    'text_el': textEl,
    'created_at': Timestamp.fromDate(createdAt),
  };

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    contentId,
    page,
    bookNumber,
    chapter,
    verse,
  ];
}
