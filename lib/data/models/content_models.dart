// lib/data/models/content_models.dart
// ─────────────────────────────────────────────────────────────────────────────
// Content models for CMS CRUD operations
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════════════════════
// BIBLE MODEL
// ════════════════════════════════════════════════════════════════════════════
class BibleModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String language;
  final String version;
  final String? translator;
  final String? pdfUrl;
  final String? coverUrl;
  final int bookCount;
  final int chapterCount;
  final int verseCount;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  BibleModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.language,
    required this.version,
    this.translator,
    this.pdfUrl,
    this.coverUrl,
    this.bookCount = 0,
    this.chapterCount = 0,
    this.verseCount = 0,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toFirestore() => {
    'titleAr': titleAr,
    'titleEn': titleEn,
    'descriptionAr': descriptionAr,
    'descriptionEn': descriptionEn,
    'language': language,
    'version': version,
    'translator': translator,
    'pdfUrl': pdfUrl,
    'coverUrl': coverUrl,
    'bookCount': bookCount,
    'chapterCount': chapterCount,
    'verseCount': verseCount,
    'isPublished': isPublished,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? DateTime.now(),
    'createdBy': createdBy,
  };

  factory BibleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BibleModel(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      descriptionAr: data['descriptionAr'],
      descriptionEn: data['descriptionEn'],
      language: data['language'] ?? 'en',
      version: data['version'] ?? '',
      translator: data['translator'],
      pdfUrl: data['pdfUrl'],
      coverUrl: data['coverUrl'],
      bookCount: data['bookCount'] ?? 0,
      chapterCount: data['chapterCount'] ?? 0,
      verseCount: data['verseCount'] ?? 0,
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HYMN MODEL
// ════════════════════════════════════════════════════════════════════════════
class HymnModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String? titleCoptic;
  final String? textAr;
  final String? textCoptic;
  final String? textGreek;
  final String? composer;
  final String? musician;
  final List<String> categories;
  final List<String> occasions;
  final String? season;
  final String? audioUrl;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  HymnModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.titleCoptic,
    this.textAr,
    this.textCoptic,
    this.textGreek,
    this.composer,
    this.musician,
    this.categories = const [],
    this.occasions = const [],
    this.season,
    this.audioUrl,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toFirestore() => {
    'titleAr': titleAr,
    'titleEn': titleEn,
    'titleCoptic': titleCoptic,
    'textAr': textAr,
    'textCoptic': textCoptic,
    'textGreek': textGreek,
    'composer': composer,
    'musician': musician,
    'categories': categories,
    'occasions': occasions,
    'season': season,
    'audioUrl': audioUrl,
    'isPublished': isPublished,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? DateTime.now(),
    'createdBy': createdBy,
  };

  factory HymnModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HymnModel(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      titleCoptic: data['titleCoptic'],
      textAr: data['textAr'],
      textCoptic: data['textCoptic'],
      textGreek: data['textGreek'],
      composer: data['composer'],
      musician: data['musician'],
      categories: List<String>.from(data['categories'] ?? []),
      occasions: List<String>.from(data['occasions'] ?? []),
      season: data['season'],
      audioUrl: data['audioUrl'],
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRAYER MODEL
// ════════════════════════════════════════════════════════════════════════════
class PrayerModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String? titleCoptic;
  final String? textAr;
  final String? textCoptic;
  final String? textGreek;
  final String? author;
  final String? occasion;
  final List<String> categories;
  final String? season;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  PrayerModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.titleCoptic,
    this.textAr,
    this.textCoptic,
    this.textGreek,
    this.author,
    this.occasion,
    this.categories = const [],
    this.season,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toFirestore() => {
    'titleAr': titleAr,
    'titleEn': titleEn,
    'titleCoptic': titleCoptic,
    'textAr': textAr,
    'textCoptic': textCoptic,
    'textGreek': textGreek,
    'author': author,
    'occasion': occasion,
    'categories': categories,
    'season': season,
    'isPublished': isPublished,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? DateTime.now(),
    'createdBy': createdBy,
  };

  factory PrayerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrayerModel(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      titleCoptic: data['titleCoptic'],
      textAr: data['textAr'],
      textCoptic: data['textCoptic'],
      textGreek: data['textGreek'],
      author: data['author'],
      occasion: data['occasion'],
      categories: List<String>.from(data['categories'] ?? []),
      season: data['season'],
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LITURGY MODEL
// ════════════════════════════════════════════════════════════════════════════
class LiturgyModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String? titleCoptic;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? textAr;
  final String? textCoptic;
  final String? season;
  final List<String> occasions;
  final String? liturgyType; // Liturgy of St. Basil, etc.
  final String? pdfUrl;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  LiturgyModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.titleCoptic,
    this.descriptionAr,
    this.descriptionEn,
    this.textAr,
    this.textCoptic,
    this.season,
    this.occasions = const [],
    this.liturgyType,
    this.pdfUrl,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toFirestore() => {
    'titleAr': titleAr,
    'titleEn': titleEn,
    'titleCoptic': titleCoptic,
    'descriptionAr': descriptionAr,
    'descriptionEn': descriptionEn,
    'textAr': textAr,
    'textCoptic': textCoptic,
    'season': season,
    'occasions': occasions,
    'liturgyType': liturgyType,
    'pdfUrl': pdfUrl,
    'isPublished': isPublished,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? DateTime.now(),
    'createdBy': createdBy,
  };

  factory LiturgyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiturgyModel(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      titleCoptic: data['titleCoptic'],
      descriptionAr: data['descriptionAr'],
      descriptionEn: data['descriptionEn'],
      textAr: data['textAr'],
      textCoptic: data['textCoptic'],
      season: data['season'],
      occasions: List<String>.from(data['occasions'] ?? []),
      liturgyType: data['liturgyType'],
      pdfUrl: data['pdfUrl'],
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SAINT MODEL
// ════════════════════════════════════════════════════════════════════════════
class SaintModel {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? nameCoptic;
  final String? biographyAr;
  final String? biographyEn;
  final String? feastDate; // MM-DD format
  final List<String> categories;
  final String? imageUrl;
  final String? patronOfAr;
  final String? patronOfEn;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  SaintModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.nameCoptic,
    this.biographyAr,
    this.biographyEn,
    this.feastDate,
    this.categories = const [],
    this.imageUrl,
    this.patronOfAr,
    this.patronOfEn,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toFirestore() => {
    'nameAr': nameAr,
    'nameEn': nameEn,
    'nameCoptic': nameCoptic,
    'biographyAr': biographyAr,
    'biographyEn': biographyEn,
    'feastDate': feastDate,
    'categories': categories,
    'imageUrl': imageUrl,
    'patronOfAr': patronOfAr,
    'patronOfEn': patronOfEn,
    'isPublished': isPublished,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? DateTime.now(),
    'createdBy': createdBy,
  };

  factory SaintModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaintModel(
      id: doc.id,
      nameAr: data['nameAr'] ?? '',
      nameEn: data['nameEn'] ?? '',
      nameCoptic: data['nameCoptic'],
      biographyAr: data['biographyAr'],
      biographyEn: data['biographyEn'],
      feastDate: data['feastDate'],
      categories: List<String>.from(data['categories'] ?? []),
      imageUrl: data['imageUrl'],
      patronOfAr: data['patronOfAr'],
      patronOfEn: data['patronOfEn'],
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CALENDAR EVENT MODEL
// ════════════════════════════════════════════════════════════════════════════
class CalendarEventModel {
  final String id;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final DateTime date;
  final String season; // Resurrection, Nativity, Regular, etc.
  final String type; // Feast, Memorial, Fast, Regular
  final String? color; // Hex color
  final List<String> readings;
  final List<String> hymns;
  final List<String> prayers;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  CalendarEventModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.date,
    required this.season,
    required this.type,
    this.color,
    this.readings = const [],
    this.hymns = const [],
    this.prayers = const [],
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toFirestore() => {
    'titleAr': titleAr,
    'titleEn': titleEn,
    'descriptionAr': descriptionAr,
    'descriptionEn': descriptionEn,
    'date': date,
    'season': season,
    'type': type,
    'color': color,
    'readings': readings,
    'hymns': hymns,
    'prayers': prayers,
    'isPublished': isPublished,
    'createdAt': createdAt,
    'updatedAt': updatedAt ?? DateTime.now(),
    'createdBy': createdBy,
  };

  factory CalendarEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarEventModel(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      descriptionAr: data['descriptionAr'],
      descriptionEn: data['descriptionEn'],
      date: (data['date'] as Timestamp).toDate(),
      season: data['season'] ?? 'Regular',
      type: data['type'] ?? 'Regular',
      color: data['color'],
      readings: List<String>.from(data['readings'] ?? []),
      hymns: List<String>.from(data['hymns'] ?? []),
      prayers: List<String>.from(data['prayers'] ?? []),
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
    );
  }
}