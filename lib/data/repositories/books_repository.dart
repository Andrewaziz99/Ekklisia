import 'dart:io';
import 'dart:typed_data';

import '../datasources/cloudinary/cloudinary_datasource.dart';
import '../datasources/firebase/firestore_datasource.dart';
import '../models/book_model.dart';

/// Books repository — orchestrates Firestore + Cloudinary.
///
/// Upload flow:
///   1. Upload PDF to Cloudinary → get secureUrl + publicId
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
    File? coverImageFile,
    Uint8List? coverImageBytes,
    String coverImageName = 'cover.jpg',
    required String titleAr,
    String titleCop = '',
    String titleEl = '',
    String descriptionAr = '',
    String descriptionEl = '',
    required String category,
    required String addedByUid,
    List<String> tags = const [],
    void Function(String step, double progress)? onProgress,
  }) async {
    if (pdfFile == null && pdfBytes == null) {
      throw ArgumentError('pdfFile or pdfBytes must be provided');
    }

    onProgress?.call('Uploading PDF…', 0.0);

    // 1. Upload PDF to Cloudinary
    final pdfResult = pdfBytes != null
        ? await cloudinaryDataSource.uploadPdfBytes(
            bytes: pdfBytes,
            fileName: pdfName,
            folder: 'Ekklisia/books/$category',
            onProgress: (p) => onProgress?.call('Uploading PDF…', p * 0.6),
          )
        : await cloudinaryDataSource.uploadPdf(
            pdfFile: pdfFile!,
            folder: 'Ekklisia/books/$category',
            onProgress: (p) => onProgress?.call('Uploading PDF…', p * 0.6),
          );

    String coverUrl = '';
    if (coverImageFile != null || coverImageBytes != null) {
      onProgress?.call('Uploading cover…', 0.65);
      final coverResult = coverImageBytes != null
          ? await cloudinaryDataSource.uploadCoverImageBytes(
              bytes: coverImageBytes,
              fileName: coverImageName,
              folder: 'Ekklisia/books/$category',
              onProgress: (p) => onProgress?.call('Uploading cover…', 0.65 + p * 0.2),
            )
          : await cloudinaryDataSource.uploadCoverImage(
              imageFile: coverImageFile!,
              folder: 'Ekklisia/books/$category',
              onProgress: (p) => onProgress?.call('Uploading cover…', 0.65 + p * 0.2),
            );
      coverUrl = coverResult.secureUrl;
    }

    onProgress?.call('Saving to database…', 0.9);

    // 2. Build and save model
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
      addedByUid: addedByUid,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );

    final docId = await firestoreDataSource.addBook(book);
    onProgress?.call('Done', 1.0);

    return book.copyWith(id: docId);
  }

  // ── Admin: Update ──────────────────────────────────────────────────────

  Future<void> updateBook(BookModel book) {
    return firestoreDataSource.updateBook(book);
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
