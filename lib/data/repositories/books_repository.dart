import 'dart:io';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../datasources/cloudinary/cloudinary_datasource.dart';
import '../datasources/firebase/firestore_datasource.dart';
import '../models/book_model.dart';

/// Books repository — orchestrates Firestore + Cloudinary.
///
/// Upload flow:
///   1. Upload file to Cloudinary → get secureUrl + publicId
///   2. Upload cover image (optional) → get coverUrl
///   3. Create BookModel with Cloudinary URLs
///   4. Save to Firestore → get docId
///   5. Return completed BookModel
class BooksRepository {
  BooksRepository({
    required this.firestoreDataSource,
    required this.cloudinaryDataSource,
  });

  final FirestoreDataSource firestoreDataSource;
  final CloudinaryDataSource cloudinaryDataSource;

  /// Converts an arbitrary category slug into a Cloudinary-safe folder segment.
  ///
  /// Cloudinary folder names must be ASCII and must not contain characters like
  /// Arabic letters, spaces, or most punctuation. This replaces every character
  /// that is not a letter (a-z / A-Z), digit, hyphen or dot with an underscore,
  /// collapses consecutive underscores, and lowercases the result.
  ///
  /// Examples:
  ///   'bible'          → 'bible'
  ///   'كتب مسيحية'    → 'other'  (falls back when all chars are stripped)
  ///   'coptic books'   → 'coptic_books'
  /// Counts pages using Syncfusion's PDF parser — reliable for all
  /// well-formed PDFs.  Returns 0 on any parse failure so uploads never block.
  static int _countPdfPages(Uint8List bytes) {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (_) {
      return 0;
    }
  }

  static String _safeFolder(String category) {
    final sanitized = category
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    return sanitized.isNotEmpty ? sanitized : 'other';
  }

  // ── Read ───────────────────────────────────────────────────────────────

  Stream<List<BookModel>> watchBooks({String? category}) {
    return firestoreDataSource.watchPublishedBooks(category: category);
  }

  Stream<List<BookModel>> watchAllBooks() {
    return firestoreDataSource.watchAllBooks();
  }

  Future<List<BookModel>> fetchBooks({String? category}) {
    return firestoreDataSource.fetchBooks(category: category);
  }

  Future<BookModel?> fetchBookById(String id) {
    return firestoreDataSource.fetchBookById(id);
  }

  // ── Admin: Create ──────────────────────────────────────────────────────

  Future<BookModel> addBook({
    File? pdfFile,
    Uint8List? pdfBytes,
    required String pdfName,
    /// When set, skips Cloudinary upload and stores this URL directly as
    /// [BookModel.pdfUrl].  Useful for Google Drive links (>10 MB free-tier cap).
    String? pdfDirectUrl,
    File? coverImageFile,
    Uint8List? coverImageBytes,
    String coverImageName = 'cover.jpg',
    required String titleAr,
    String titleCop = '',
    String titleEl = '',
    String descriptionAr = '',
    String descriptionEl = '',
    required String category,
    /// Human-readable category name used for the Cloudinary folder path.
    /// Falls back to [category] (the Firestore ID) when omitted.
    String? categoryFolder,
    required String addedByUid,
    List<String> tags = const [],
    void Function(String step, double progress)? onProgress,
  }) async {
    if (pdfFile == null && pdfBytes == null && pdfDirectUrl == null) {
      throw ArgumentError('pdfFile, pdfBytes, or pdfDirectUrl must be provided');
    }

    final safeCategory = _safeFolder(categoryFolder ?? category);

    // ── Branch A: Google Drive / external URL — skip Cloudinary upload ──────
    if (pdfDirectUrl != null) {
      onProgress?.call('Saving to database…', 0.5);

      String coverUrl = '';
      if (coverImageFile != null || coverImageBytes != null) {
        onProgress?.call('Uploading cover…', 0.55);
        final coverResult = coverImageBytes != null
            ? await cloudinaryDataSource.uploadCoverImageBytes(
                bytes: coverImageBytes,
                fileName: coverImageName,
                folder: 'Ekklisia/books/$safeCategory',
                onProgress: (p) => onProgress?.call('Uploading cover…', 0.55 + p * 0.35),
              )
            : await cloudinaryDataSource.uploadCoverImage(
                imageFile: coverImageFile!,
                folder: 'Ekklisia/books/$safeCategory',
                onProgress: (p) => onProgress?.call('Uploading cover…', 0.55 + p * 0.35),
              );
        coverUrl = coverResult.secureUrl;
      }

      onProgress?.call('Saving to database…', 0.95);
      final now = DateTime.now();
      final book = BookModel(
        id: '',
        titleAr: titleAr,
        titleCop: titleCop,
        titleEl: titleEl,
        descriptionAr: descriptionAr,
        descriptionEl: descriptionEl,
        category: category,
        pdfUrl: pdfDirectUrl,
        coverUrl: coverUrl,
        cloudinaryPdfId: '',   // no Cloudinary asset
        fileSizeMb: 0,
        pageCount: 0,
        addedByUid: addedByUid,
        createdAt: now,
        updatedAt: now,
        tags: tags,
      );
      final docId = await firestoreDataSource.addBook(book);
      onProgress?.call('Done', 1.0);
      return book.copyWith(id: docId);
    }

    // ── Branch B: file upload to Cloudinary ──────────────────────────────────
    onProgress?.call('Uploading PDF…', 0.0);

    // 1. Read bytes for page-counting (file path case) before uploading.
    final Uint8List resolvedBytes = pdfBytes ?? await pdfFile!.readAsBytes();

    // 2. Upload PDF to Cloudinary
    final pdfResult = pdfBytes != null
        ? await cloudinaryDataSource.uploadPdfBytes(
            bytes: resolvedBytes,
            fileName: pdfName,
            folder: 'Ekklisia/books/$safeCategory',
            onProgress: (p) => onProgress?.call('Uploading PDF…', p * 0.6),
          )
        : await cloudinaryDataSource.uploadPdf(
            pdfFile: pdfFile!,
            folder: 'Ekklisia/books/$safeCategory',
            onProgress: (p) => onProgress?.call('Uploading PDF…', p * 0.6),
          );

    // 3. Count pages from the bytes we already have in memory.
    final pageCount = _countPdfPages(resolvedBytes);

    String coverUrl = '';
    if (coverImageFile != null || coverImageBytes != null) {
      onProgress?.call('Uploading cover…', 0.65);
      final coverResult = coverImageBytes != null
          ? await cloudinaryDataSource.uploadCoverImageBytes(
              bytes: coverImageBytes,
              fileName: coverImageName,
              folder: 'Ekklisia/books/$safeCategory',
              onProgress: (p) => onProgress?.call('Uploading cover…', 0.65 + p * 0.2),
            )
          : await cloudinaryDataSource.uploadCoverImage(
              imageFile: coverImageFile!,
              folder: 'Ekklisia/books/$safeCategory',
              onProgress: (p) => onProgress?.call('Uploading cover…', 0.65 + p * 0.2),
            );
      coverUrl = coverResult.secureUrl;
    }

    onProgress?.call('Saving to database…', 0.9);

    // 4. Build and save model
    final now = DateTime.now();
    final book = BookModel(
      id: '', // will be replaced by Firestore auto-id
      titleAr: titleAr,
      titleCop: titleCop,
      titleEl: titleEl,
      descriptionAr: descriptionAr,
      descriptionEl: descriptionEl,
      category: category,
      pdfUrl: pdfResult.secureUrl,
      coverUrl: coverUrl,
      cloudinaryPdfId: pdfResult.publicId,
      fileSizeMb: pdfResult.bytes / (1024 * 1024),
      pageCount: pageCount,
      addedByUid: addedByUid,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );

    final docId = await firestoreDataSource.addBook(book);
    onProgress?.call('Done', 1.0);

    return book.copyWith(id: docId);
  }

  // ── Admin: Create (video / audio) ──────────────────────────────────────

  Future<BookModel> addMediaFile({
    File? file,
    Uint8List? fileBytes,
    required String fileName,
    required BookMediaType mediaType,
    File? coverImageFile,
    Uint8List? coverImageBytes,
    String coverImageName = 'cover.jpg',
    required String titleAr,
    String titleCop = '',
    String titleEl = '',
    String descriptionAr = '',
    required String category,
    /// Human-readable category name used for the Cloudinary folder path.
    /// Falls back to [category] (the Firestore ID) when omitted.
    String? categoryFolder,
    required String addedByUid,
    List<String> tags = const [],
    void Function(String step, double progress)? onProgress,
  }) async {
    if (file == null && fileBytes == null) {
      throw ArgumentError('file or fileBytes must be provided');
    }

    final folder = 'Ekklisia/${mediaType.value}/${_safeFolder(categoryFolder ?? category)}';
    final label  = mediaType == BookMediaType.video ? 'video' : 'audio';

    onProgress?.call('Uploading $label…', 0.0);

    // 1. Upload media file to Cloudinary
    late CloudinaryUploadResult fileResult;
    if (mediaType == BookMediaType.video) {
      fileResult = fileBytes != null
          ? await cloudinaryDataSource.uploadVideoBytes(
              bytes: fileBytes, fileName: fileName, folder: folder,
              onProgress: (p) => onProgress?.call('Uploading $label…', p * 0.6))
          : await cloudinaryDataSource.uploadVideo(
              videoFile: file!, folder: folder,
              onProgress: (p) => onProgress?.call('Uploading $label…', p * 0.6));
    } else {
      fileResult = fileBytes != null
          ? await cloudinaryDataSource.uploadAudioBytes(
              bytes: fileBytes, fileName: fileName, folder: folder,
              onProgress: (p) => onProgress?.call('Uploading $label…', p * 0.6))
          : await cloudinaryDataSource.uploadAudio(
              audioFile: file!, folder: folder,
              onProgress: (p) => onProgress?.call('Uploading $label…', p * 0.6));
    }

    // 2. Upload optional cover
    String coverUrl = '';
    if (coverImageFile != null || coverImageBytes != null) {
      onProgress?.call('Uploading cover…', 0.65);
      final coverResult = coverImageBytes != null
          ? await cloudinaryDataSource.uploadCoverImageBytes(
              bytes: coverImageBytes, fileName: coverImageName, folder: folder,
              onProgress: (p) => onProgress?.call('Uploading cover…', 0.65 + p * 0.2))
          : await cloudinaryDataSource.uploadCoverImage(
              imageFile: coverImageFile!, folder: folder,
              onProgress: (p) => onProgress?.call('Uploading cover…', 0.65 + p * 0.2));
      coverUrl = coverResult.secureUrl;
    }

    onProgress?.call('Saving to database…', 0.9);

    final now  = DateTime.now();
    final book = BookModel(
      id: '',
      titleAr: titleAr,
      titleCop: titleCop,
      titleEl: titleEl,
      descriptionAr: descriptionAr,
      category: category,
      pdfUrl: fileResult.secureUrl,
      coverUrl: coverUrl,
      cloudinaryPdfId: fileResult.publicId,
      fileSizeMb: fileResult.bytes / (1024 * 1024),
      addedByUid: addedByUid,
      createdAt: now,
      updatedAt: now,
      tags: tags,
      mediaType: mediaType,
    );

    final docId = await firestoreDataSource.addBook(book);
    onProgress?.call('Done', 1.0);
    return book.copyWith(id: docId);
  }

  // ── Admin: Bulk upload ─────────────────────────────────────────────────

  /// Uploads [items] one at a time.  [onItemProgress] fires for every item
  /// with (itemIndex, totalItems, step, progress).
  Future<List<BookModel>> bulkAddFiles({
    required List<BulkUploadItem> items,
    required String addedByUid,
    void Function(int index, int total, String step, double progress)?
        onItemProgress,
  }) async {
    final results = <BookModel>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        final BookModel book;
        if (item.mediaType == BookMediaType.pdf) {
          book = await addBook(
            pdfFile:        item.file,
            pdfBytes:       item.fileBytes,
            pdfName:        item.fileName,
            titleAr:        item.titleAr,
            category:       item.category,
            categoryFolder: item.categoryFolder,
            addedByUid:     addedByUid,
            tags:           item.tags,
            onProgress: (step, p) =>
                onItemProgress?.call(i, items.length, step, p),
          );
        } else {
          book = await addMediaFile(
            file:           item.file,
            fileBytes:      item.fileBytes,
            fileName:       item.fileName,
            mediaType:      item.mediaType,
            titleAr:        item.titleAr,
            category:       item.category,
            categoryFolder: item.categoryFolder,
            addedByUid:     addedByUid,
            tags:           item.tags,
            onProgress: (step, p) =>
                onItemProgress?.call(i, items.length, step, p),
          );
        }
        results.add(book);
      } catch (_) {
        rethrow;
      }
    }
    return results;
  }

  // ── Admin: Update ──────────────────────────────────────────────────────

  Future<void> updateBook(BookModel book) {
    return firestoreDataSource.updateBook(book);
  }

  /// Uploads a new cover image to Cloudinary and returns its secure URL.
  /// Call this before [updateBook] when the admin replaces a book's cover.
  Future<String> uploadCoverOnly({
    required Uint8List bytes,
    required String fileName,
    required String category,
    void Function(double)? onProgress,
  }) async {
    final result = await cloudinaryDataSource.uploadCoverImageBytes(
      bytes:      bytes,
      fileName:   fileName,
      folder:     'Ekklisia/books/${_safeFolder(category)}',
      onProgress: onProgress,
    );
    return result.secureUrl;
  }

  Future<void> togglePublish(String id, {required bool published}) {
    return firestoreDataSource.togglePublish(id, published: published);
  }

  Future<void> deleteBook(String id) {
    // Note: also clean up Cloudinary asset via edge function in production
    return firestoreDataSource.deleteBook(id);
  }

  // ── FCM Tokens ─────────────────────────────────────────────────────────

  Future<void> saveOrUpdateFcmToken({
    required String userId,
    required String token,
    required String platform,
  }) {
    return firestoreDataSource.saveOrUpdateFcmToken(
      userId: userId,
      token: token,
      platform: platform,
    );
  }

  Future<List<String>> fetchAllFcmTokens() {
    return firestoreDataSource.fetchAllFcmTokens();
  }
}

// ── Data class for a single bulk-upload item ──────────────────────────────────

class BulkUploadItem {
  BulkUploadItem({
    required this.fileName,
    required this.titleAr,
    required this.category,
    required this.mediaType,
    this.categoryFolder,
    this.file,
    this.fileBytes,
    this.tags = const [],
    this.fileSizeMb = 0,
  }) : assert(file != null || fileBytes != null,
           'BulkUploadItem requires file or fileBytes');

  final String        fileName;
  String              titleAr;        // mutable — user can edit in the UI
  String              category;       // mutable — Firestore category ID
  /// Human-readable name used for the Cloudinary folder.
  /// Set by the bulk-upload screen from the chosen [BookCategory.nameAr].
  String?             categoryFolder; // mutable
  final BookMediaType mediaType;
  final File?         file;
  final Uint8List?    fileBytes;
  final List<String>  tags;
  final double        fileSizeMb;
}
