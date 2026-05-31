// lib/features/daily_verse/daily_verse_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Represents a single daily Bible verse stored in Firestore.
//
// Firestore collection : daily_verses
// Document ID          : auto-generated (Firestore push ID)
//
// Fields
//   order        — integer 1-N; the rotation sequence set by the admin
//   verse_ar     — verse text in Arabic
//   reference_ar — scripture reference in Arabic
//   verse_el     — verse text in Greek (optional)
//   reference_el — scripture reference in Greek (optional)
//   is_active    — hidden from users when false
//   sent_date    — "YYYY-MM-DD" written by the edge function when sent;
//                  empty string means "not yet sent"
// ─────────────────────────────────────────────────────────────────────────────

class DailyVerseModel {
  const DailyVerseModel({
    required this.id,
    required this.order,
    required this.verseAr,
    required this.referenceAr,
    this.verseEl    = '',
    this.referenceEl = '',
    this.isActive   = true,
    this.sentDate   = '',
  });

  /// Firestore document ID (auto-generated).
  final String id;

  /// Rotation order (1 = first verse to send, 2 = second, …).
  final int order;

  final String verseAr;
  final String referenceAr;
  final String verseEl;
  final String referenceEl;
  final bool   isActive;

  /// ISO date "YYYY-MM-DD" set by the edge function when this verse was sent.
  /// Empty string means the verse has not been sent yet.
  final String sentDate;

  bool get isSent => sentDate.isNotEmpty;

  // ── Firestore serialisation ───────────────────────────────────────────────

  factory DailyVerseModel.fromMap(String id, Map<String, dynamic> map) {
    return DailyVerseModel(
      id:           id,
      order:        (map['order']        as num?)?.toInt() ?? 0,
      verseAr:      map['verse_ar']      as String?        ?? '',
      referenceAr:  map['reference_ar']  as String?        ?? '',
      verseEl:      map['verse_el']      as String?        ?? '',
      referenceEl:  map['reference_el']  as String?        ?? '',
      isActive:     map['is_active']     as bool?          ?? true,
      sentDate:     map['sent_date']     as String?        ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'order':        order,
    'verse_ar':     verseAr,
    'reference_ar': referenceAr,
    'verse_el':     verseEl,
    'reference_el': referenceEl,
    'is_active':    isActive,
    'sent_date':    sentDate,
  };

  DailyVerseModel copyWith({
    int?    order,
    String? verseAr,
    String? referenceAr,
    String? verseEl,
    String? referenceEl,
    bool?   isActive,
    String? sentDate,
  }) =>
      DailyVerseModel(
        id:           id,
        order:        order        ?? this.order,
        verseAr:      verseAr      ?? this.verseAr,
        referenceAr:  referenceAr  ?? this.referenceAr,
        verseEl:      verseEl      ?? this.verseEl,
        referenceEl:  referenceEl  ?? this.referenceEl,
        isActive:     isActive     ?? this.isActive,
        sentDate:     sentDate     ?? this.sentDate,
      );
}
