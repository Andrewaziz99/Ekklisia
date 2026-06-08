// lib/data/repositories/bible_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bible content repository.
//
// Primary source  : bundled XML assets (assets/bible/arabic.xml / greek.xml)
// Remote override : admin may upload a new XML to Cloudinary; the URL is stored
//                   in Firestore bible_config/{ar|el}.  loadBooks() fetches the
//                   remote XML when available (Dio HTTP GET) instead of the asset.
// Verse overrides : individual verse edits saved to bible_verse_overrides collection.
//                   Keyed by "{langCode}_{bookNum}_{chapterNum}_{verseNum}".
//
// configure(db, dio) MUST be called once (from ServiceLocator) before using
// any remote / override features.  Asset-only usage works without configure().
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/bible_model.dart';

// ── Firestore collection names ────────────────────────────────────────────────
const _kConfigCol    = 'bible_config';        // docs: 'ar' | 'el'
const _kOverridesCol = 'bible_verse_overrides'; // doc id: '{lang}_{b}_{c}_{v}'

class BibleRepository {
  BibleRepository._();
  static final instance = BibleRepository._();

  // ── Injected after configure() ────────────────────────────────────────────
  FirebaseFirestore? _db;
  Dio?              _dio;

  /// Called once from ServiceLocator after Firebase + Dio are ready.
  void configure(FirebaseFirestore db, Dio dio) {
    _db  = db;
    _dio = dio;
  }

  // ── Caches ─────────────────────────────────────────────────────────────────
  final Map<String, List<BibleBook>> _booksCache = {};
  // overrideKey → text
  final Map<String, Map<String, String>> _overrideCache = {};

  // ── Public read API ────────────────────────────────────────────────────────

  Future<List<BibleBook>> loadBooks(String langCode) async {
    if (_booksCache.containsKey(langCode)) {
      return _applyOverrides(langCode, _booksCache[langCode]!);
    }
    final books = await _parseBooks(langCode);
    _booksCache[langCode] = books;
    return _applyOverrides(langCode, books);
  }

  Future<List<BibleBook>> loadOldTestament(String langCode) async {
    final all = await loadBooks(langCode);
    return all.where((b) => b.testament == 'Old').toList();
  }

  Future<List<BibleBook>> loadNewTestament(String langCode) async {
    final all = await loadBooks(langCode);
    return all.where((b) => b.testament == 'New').toList();
  }

  Future<bool> isAvailable(String langCode) async {
    try {
      final cfg = await _remoteConfig(langCode);
      if (cfg != null) return true;
      await rootBundle.loadString(_assetPath(langCode));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears all in-memory caches (call after uploading new XML or saving override).
  void clearCache([String? langCode]) {
    if (langCode != null) {
      _booksCache.remove(langCode);
      _overrideCache.remove(langCode);
    } else {
      _booksCache.clear();
      _overrideCache.clear();
    }
  }

  // ── Remote XML config ──────────────────────────────────────────────────────

  /// Stream of the current XML config doc for admin UI.
  Stream<Map<String, dynamic>?> watchConfig(String langCode) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return db
        .collection(_kConfigCol)
        .doc(langCode)
        .snapshots()
        .map((s) => s.data());
  }

  /// Saves a new XML URL (after Cloudinary upload) to Firestore.
  Future<void> saveXmlConfig({
    required String langCode,
    required String xmlUrl,
    required String cloudinaryId,
  }) async {
    final db = _db;
    if (db == null) throw StateError('BibleRepository not configured');
    await db.collection(_kConfigCol).doc(langCode).set({
      'xml_url':       xmlUrl,
      'cloudinary_id': cloudinaryId,
      'updated_at':    FieldValue.serverTimestamp(),
    });
    clearCache(langCode);
  }

  /// Removes the remote XML config so the bundled asset is used again.
  Future<void> clearXmlConfig(String langCode) async {
    final db = _db;
    if (db == null) return;
    await db.collection(_kConfigCol).doc(langCode).delete();
    clearCache(langCode);
  }

  // ── Verse overrides ────────────────────────────────────────────────────────

  /// Watch all overrides for a language (for admin list view).
  Stream<List<BibleVerseOverride>> watchOverrides(String langCode) {
    final db = _db;
    if (db == null) return const Stream.empty();
    return db
        .collection(_kOverridesCol)
        .where('lang', isEqualTo: langCode)
        .orderBy('book_num')
        .snapshots()
        .map((s) => s.docs.map(BibleVerseOverride.fromDoc).toList());
  }

  /// Save an individual verse edit.
  Future<void> saveVerseOverride({
    required String langCode,
    required int    bookNum,
    required int    chapterNum,
    required int    verseNum,
    required String text,
  }) async {
    final db = _db;
    if (db == null) throw StateError('BibleRepository not configured');
    final docId = '${langCode}_${bookNum}_${chapterNum}_$verseNum';
    await db.collection(_kOverridesCol).doc(docId).set({
      'lang':        langCode,
      'book_num':    bookNum,
      'chapter_num': chapterNum,
      'verse_num':   verseNum,
      'text':        text,
      'updated_at':  FieldValue.serverTimestamp(),
    });
    _overrideCache.remove(langCode); // invalidate cache for this lang
  }

  /// Delete a verse override (reverts to XML source).
  Future<void> deleteVerseOverride({
    required String langCode,
    required int    bookNum,
    required int    chapterNum,
    required int    verseNum,
  }) async {
    final db = _db;
    if (db == null) return;
    final docId = '${langCode}_${bookNum}_${chapterNum}_$verseNum';
    await db.collection(_kOverridesCol).doc(docId).delete();
    _overrideCache.remove(langCode);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static String _assetPath(String langCode) =>
      'assets/bible/${langCode == 'el' ? 'greek' : 'arabic'}.xml';

  /// Returns the Firestore config for [langCode], or null if none.
  Future<Map<String, dynamic>?> _remoteConfig(String langCode) async {
    final db = _db;
    if (db == null) return null;
    try {
      final doc = await db.collection(_kConfigCol).doc(langCode).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data?['xml_url'] == null) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Parses books from either remote URL (if configured) or bundled asset.
  Future<List<BibleBook>> _parseBooks(String langCode) async {
    String xmlString;

    final config = await _remoteConfig(langCode);
    if (config != null) {
      try {
        final url = config['xml_url'] as String;
        final resp = await _dio!.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        xmlString = resp.data ?? '';
        debugPrint('[BibleRepo] Loaded $langCode from remote URL');
      } catch (e) {
        debugPrint('[BibleRepo] Remote fetch failed ($e), falling back to asset');
        xmlString = await rootBundle.loadString(_assetPath(langCode));
      }
    } else {
      xmlString = await rootBundle.loadString(_assetPath(langCode));
      debugPrint('[BibleRepo] Loaded $langCode from asset');
    }

    return _parseXml(xmlString);
  }

  List<BibleBook> _parseXml(String xmlString) {
    final doc  = XmlDocument.parse(xmlString);
    final bibleEl = doc.findElements('bible').first;
    final books   = <BibleBook>[];

    for (final testamentEl in bibleEl.findElements('testament')) {
      final testamentName = testamentEl.getAttribute('name') ?? 'Old';
      for (final bookEl in testamentEl.findElements('book')) {
        final bookNum = int.tryParse(bookEl.getAttribute('number') ?? '') ?? 0;
        final nameAr  = kBibleBookNamesAr[bookNum] ?? 'كتاب $bookNum';
        final nameEl  = kBibleBookNamesEl[bookNum] ?? 'Βιβλίο $bookNum';
        final chapters = <BibleChapter>[];
        for (final chapterEl in bookEl.findElements('chapter')) {
          final chapNum = int.tryParse(chapterEl.getAttribute('number') ?? '') ?? 0;
          final verses  = <BibleVerse>[];
          for (final verseEl in chapterEl.findElements('verse')) {
            final vNum = int.tryParse(verseEl.getAttribute('number') ?? '') ?? 0;
            verses.add(BibleVerse(number: vNum, text: verseEl.innerText.trim()));
          }
          chapters.add(BibleChapter(number: chapNum, verses: verses));
        }
        books.add(BibleBook(
          number:    bookNum,
          testament: testamentName,
          nameAr:    nameAr,
          nameEl:    nameEl,
          chapters:  chapters,
        ));
      }
    }
    return books;
  }

  /// Fetches verse overrides for [langCode] from Firestore, caches result.
  Future<Map<String, String>> _getOverrides(String langCode) async {
    if (_overrideCache.containsKey(langCode)) {
      return _overrideCache[langCode]!;
    }
    final db = _db;
    if (db == null) return const {};
    try {
      final snap = await db
          .collection(_kOverridesCol)
          .where('lang', isEqualTo: langCode)
          .get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final d       = doc.data();
        final bookNum = d['book_num'] as int;
        final chapNum = d['chapter_num'] as int;
        final vNum    = d['verse_num'] as int;
        map['${bookNum}_${chapNum}_$vNum'] = d['text'] as String;
      }
      _overrideCache[langCode] = map;
      return map;
    } catch (e) {
      debugPrint('[BibleRepo] Could not load overrides: $e');
      return const {};
    }
  }

  /// Returns a new list of BibleBooks with verse overrides applied.
  Future<List<BibleBook>> _applyOverrides(
      String langCode, List<BibleBook> books) async {
    final overrides = await _getOverrides(langCode);
    if (overrides.isEmpty) return books;

    return books.map((book) {
      final chapters = book.chapters.map((chapter) {
        final verses = chapter.verses.map((verse) {
          final key = '${book.number}_${chapter.number}_${verse.number}';
          final overriddenText = overrides[key];
          if (overriddenText == null) return verse;
          return BibleVerse(number: verse.number, text: overriddenText);
        }).toList();
        return BibleChapter(number: chapter.number, verses: verses);
      }).toList();
      return BibleBook(
        number:    book.number,
        testament: book.testament,
        nameAr:    book.nameAr,
        nameEl:    book.nameEl,
        chapters:  chapters,
      );
    }).toList();
  }
}

// ── Override model ─────────────────────────────────────────────────────────────

class BibleVerseOverride {
  const BibleVerseOverride({
    required this.docId,
    required this.lang,
    required this.bookNum,
    required this.chapterNum,
    required this.verseNum,
    required this.text,
    this.updatedAt,
  });

  final String    docId;
  final String    lang;
  final int       bookNum;
  final int       chapterNum;
  final int       verseNum;
  final String    text;
  final DateTime? updatedAt;

  factory BibleVerseOverride.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BibleVerseOverride(
      docId:      doc.id,
      lang:       d['lang']        as String? ?? '',
      bookNum:    d['book_num']    as int?    ?? 0,
      chapterNum: d['chapter_num'] as int?    ?? 0,
      verseNum:   d['verse_num']   as int?    ?? 0,
      text:       d['text']        as String? ?? '',
      updatedAt:  (d['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  String get bookName => kBibleBookNamesAr[bookNum] ?? 'كتاب $bookNum';
  String get bookNameEl => kBibleBookNamesEl[bookNum] ?? 'Book $bookNum';
  String get reference => '$bookName $chapterNum:$verseNum';
}
