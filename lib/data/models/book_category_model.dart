// lib/data/models/book_category_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Book category — stored in the `categories` Firestore collection.
//
// Firestore document shape:
//   {
//     slug:       string,   // stable key used in books.category field
//     name_ar:    string,
//     name_cop:   string,
//     name_el:    string,
//     sort_order: int,      // position in list (0-based)
//     is_visible: bool,     // admin can hide without deleting
//     created_at: Timestamp,
//   }
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class BookCategory extends Equatable {
  final String id;
  final String slug;      // stable key, e.g. 'bible', 'prayers'
  final String nameAr;
  final String nameCop;
  final String nameEl;
  final int sortOrder;
  final bool isVisible;
  final DateTime createdAt;

  const BookCategory({
    required this.id,
    required this.slug,
    required this.nameAr,
    this.nameCop    = '',
    this.nameEl     = '',
    this.sortOrder  = 0,
    this.isVisible  = true,
    required this.createdAt,
  });

  // ── Display helpers ─────────────────────────────────────────────────────────

  String nameFor(String langCode) {
    switch (langCode) {
      case 'cop': return nameCop.isNotEmpty ? nameCop : nameAr;
      case 'el':  return nameEl.isNotEmpty  ? nameEl  : nameAr;
      default:    return nameAr;
    }
  }

  // ── Firestore ───────────────────────────────────────────────────────────────

  factory BookCategory.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BookCategory(
      id:         doc.id,
      slug:       d['slug']       as String?   ?? '',
      nameAr:     d['name_ar']    as String?   ?? '',
      nameCop:    d['name_cop']   as String?   ?? '',
      nameEl:     d['name_el']    as String?   ?? '',
      sortOrder:  (d['sort_order'] as num?)?.toInt() ?? 0,
      isVisible:  d['is_visible'] as bool?     ?? true,
      createdAt:  (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'slug':       slug,
    'name_ar':    nameAr,
    'name_cop':   nameCop,
    'name_el':    nameEl,
    'sort_order': sortOrder,
    'is_visible': isVisible,
    'created_at': Timestamp.fromDate(createdAt),
  };

  BookCategory copyWith({
    String? slug,
    String? nameAr,
    String? nameCop,
    String? nameEl,
    int?    sortOrder,
    bool?   isVisible,
  }) =>
      BookCategory(
        id:         id,
        slug:       slug       ?? this.slug,
        nameAr:     nameAr     ?? this.nameAr,
        nameCop:    nameCop    ?? this.nameCop,
        nameEl:     nameEl     ?? this.nameEl,
        sortOrder:  sortOrder  ?? this.sortOrder,
        isVisible:  isVisible  ?? this.isVisible,
        createdAt:  createdAt,
      );

  @override
  List<Object?> get props => [id, slug, nameAr, sortOrder, isVisible];
}

// ── Default seed data ─────────────────────────────────────────────────────────
// Used by the admin to populate an empty Firestore collection on first setup.

const kDefaultBookCategories = [
  (slug: 'bible',        nameAr: 'الإنجيل',    nameCop: '',           nameEl: 'Βίβλος'),
  (slug: 'prayers',      nameAr: 'الصلوات',    nameCop: '',           nameEl: 'Προσευχές'),
  (slug: 'liturgy',      nameAr: 'القداس',     nameCop: '',           nameEl: 'Λειτουργία'),
  (slug: 'hymns',        nameAr: 'التسابيح',   nameCop: '',           nameEl: 'Ψαλμωδία'),
  (slug: 'saints',       nameAr: 'القديسون',   nameCop: '',           nameEl: 'Άγιοι'),
  (slug: 'fathers',      nameAr: 'الآباء',     nameCop: '',           nameEl: 'Πατέρες'),
  (slug: 'commentaries', nameAr: 'الشروحات',   nameCop: '',           nameEl: 'Σχόλια'),
  (slug: 'studies',      nameAr: 'الدراسات',   nameCop: '',           nameEl: 'Μελέτες'),
  (slug: 'other',        nameAr: 'أخرى',        nameCop: '',           nameEl: 'Άλλα'),
];
