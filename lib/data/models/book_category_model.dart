// lib/data/models/book_category_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Book category — stored in the `categories` Firestore collection.
//
// Firestore document shape:
//   {
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
  final String nameAr;
  final String nameCop;
  final String nameEl;
  final int sortOrder;
  final bool isVisible;
  final DateTime createdAt;

  const BookCategory({
    required this.id,
    required this.nameAr,
    this.nameCop = '',
    this.nameEl = '',
    this.sortOrder = 0,
    this.isVisible = true,
    required this.createdAt,
  });

  // ── Display helpers ─────────────────────────────────────────────────────────

  String nameFor(String langCode) {
    switch (langCode) {
      case 'cop':
        return nameCop.isNotEmpty ? nameCop : nameAr;
      case 'el':
        return nameEl.isNotEmpty ? nameEl : nameAr;
      default:
        return nameAr;
    }
  }

  // ── Firestore ───────────────────────────────────────────────────────────────

  factory BookCategory.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BookCategory(
      id: doc.id,
      nameAr: d['name_ar'] as String? ?? '',
      nameCop: d['name_cop'] as String? ?? '',
      nameEl: d['name_el'] as String? ?? '',
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
      isVisible: d['is_visible'] as bool? ?? true,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name_ar': nameAr,
    'name_cop': nameCop,
    'name_el': nameEl,
    'sort_order': sortOrder,
    'is_visible': isVisible,
    'created_at': Timestamp.fromDate(createdAt),
  };

  BookCategory copyWith({
    String? nameAr,
    String? nameCop,
    String? nameEl,
    int? sortOrder,
    bool? isVisible,
  }) => BookCategory(
    id: id,
    nameAr: nameAr ?? this.nameAr,
    nameCop: nameCop ?? this.nameCop,
    nameEl: nameEl ?? this.nameEl,
    sortOrder: sortOrder ?? this.sortOrder,
    isVisible: isVisible ?? this.isVisible,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, nameAr, sortOrder, isVisible];
}

// ── Default seed data ─────────────────────────────────────────────────────────
// Used by the admin to populate an empty Firestore collection on first setup.

const kDefaultBookCategories = [
  (nameAr: 'الإنجيل', nameCop: '', nameEl: 'Βίβλος'),
  (nameAr: 'الصلوات', nameCop: '', nameEl: 'Προσευχές'),
  (nameAr: 'القداس', nameCop: '', nameEl: 'Λειτουργία'),
  (nameAr: 'الترانيم', nameCop: '', nameEl: 'Ψαλμωδία'),
  (nameAr: 'القديسون', nameCop: '', nameEl: 'Άγιοι'),
  (nameAr: 'الآباء', nameCop: '', nameEl: 'Πατέρες'),
  (nameAr: 'الشروحات', nameCop: '', nameEl: 'Σχόλια'),
  (nameAr: 'الدراسات', nameCop: '', nameEl: 'Μελέτες'),
  (nameAr: 'أخرى', nameCop: '', nameEl: 'Άλλα'),
];
