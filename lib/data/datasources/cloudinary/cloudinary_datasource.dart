import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';

class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.publicId,
    required this.secureUrl,
    required this.format,
    required this.bytes,
    required this.resourceType,
  });

  final String publicId;
  final String secureUrl;
  final String format;
  final int bytes;
  final String resourceType; // 'raw' for PDF, 'image' for cover
}

/// Handles direct uploads to Cloudinary using the unsigned upload preset.
/// For signed uploads (admin), use the server-side approach via Supabase.
class CloudinaryDataSource {
  CloudinaryDataSource(this._dio);
  final Dio _dio;

  void _logDioError(DioException e) {
    final data = e.response?.data;
    if (data == null) return;
    debugPrint('[Cloudinary] error body: $data');
  }

  // ── PDF Upload ──────────────────────────────────────────────────────────

  /// Uploads a PDF file to Cloudinary and reports progress via [onProgress].
  /// Returns [CloudinaryUploadResult] on success, throws on failure.
  Future<CloudinaryUploadResult> uploadPdf({
    required File pdfFile,
    required String folder,          // e.g. 'ekklicia/books'
    void Function(double progress)? onProgress,
  }) async {
    final fileName = pdfFile.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        pdfFile.path,
        filename: fileName,
      ),
      'upload_preset': AppConstants.cloudinaryUploadPreset,
      'folder': folder,
      'resource_type': 'raw',
      // Auto-tag for organisation
      'tags': 'ekklicia,book,pdf',
    });

    final response = await _dio.post(
      AppConstants.cloudinaryUploadUrl,
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return CloudinaryUploadResult(
        publicId: data['public_id'] as String,
        secureUrl: data['secure_url'] as String,
        format: data['format'] ?? 'pdf',
        bytes: data['bytes'] as int,
        resourceType: data['resource_type'] as String,
      );
    }
    throw CloudinaryUploadException(
      'Upload failed: ${response.statusCode} — ${response.statusMessage}',
    );
  }

  // ── PDF Upload (bytes, web) ─────────────────────────────────────────────

  Future<CloudinaryUploadResult> uploadPdfBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
      'upload_preset': AppConstants.cloudinaryUploadPreset,
      'folder': folder,
      'resource_type': 'raw',
      'tags': 'ekklicia,book,pdf',
    });

    final response = await _dio.post(
      AppConstants.cloudinaryUploadUrl,
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return CloudinaryUploadResult(
        publicId: data['public_id'] as String,
        secureUrl: data['secure_url'] as String,
        format: data['format'] ?? 'pdf',
        bytes: data['bytes'] as int,
        resourceType: data['resource_type'] as String,
      );
    }
    throw CloudinaryUploadException(
      'Upload failed: ${response.statusCode} — ${response.statusMessage}',
    );
  }

  // ── Cover Image Upload ──────────────────────────────────────────────────

  Future<CloudinaryUploadResult> uploadCoverImage({
    required File imageFile,
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = imageFile.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
      'upload_preset': AppConstants.cloudinaryUploadPreset,
      'folder': '$folder/covers',
      'resource_type': 'image',
      'tags': 'ekklicia,book,cover',
    });

    try {
      final response = await _dio.post(
        AppConstants.cloudinaryImageUploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return CloudinaryUploadResult(
          publicId: data['public_id'] as String,
          secureUrl: data['secure_url'] as String,
          format: data['format'] as String,
          bytes: data['bytes'] as int,
          resourceType: data['resource_type'] as String,
        );
      }
      throw CloudinaryUploadException('Cover upload failed: ${response.statusCode}');
    } on DioException catch (e) {
      _logDioError(e);
      rethrow;
    }
  }

  // ── Cover Image Upload (bytes, web) ─────────────────────────────────────

  Future<CloudinaryUploadResult> uploadCoverImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
      'upload_preset': AppConstants.cloudinaryUploadPreset,
      'folder': '$folder/covers',
      'resource_type': 'image',
      'tags': 'ekklicia,book,cover',
    });

    try {
      final response = await _dio.post(
        AppConstants.cloudinaryImageUploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return CloudinaryUploadResult(
          publicId: data['public_id'] as String,
          secureUrl: data['secure_url'] as String,
          format: data['format'] as String,
          bytes: data['bytes'] as int,
          resourceType: data['resource_type'] as String,
        );
      }
      throw CloudinaryUploadException('Cover upload failed: ${response.statusCode}');
    } on DioException catch (e) {
      _logDioError(e);
      rethrow;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  /// Note: deletion requires a signed request (API secret).
  /// This should be handled server-side via the Supabase edge function.
  /// Kept here as a reference — do NOT expose the API secret client-side.
  Future<void> deleteAsset(String publicId, {bool isRaw = false}) async {
    // Call your Supabase edge function instead:
    // await supabase.functions.invoke('delete-cloudinary-asset', body: {
    //   'public_id': publicId,
    //   'resource_type': isRaw ? 'raw' : 'image',
    // });
    throw UnimplementedError(
      'Asset deletion must be handled server-side. '
          'Use the Supabase delete-cloudinary-asset edge function.',
    );
  }

  // ── URL helpers ─────────────────────────────────────────────────────────

  /// Generates an optimised thumbnail URL for a Cloudinary image.
  static String thumbnailUrl(String publicId, {int width = 280, int height = 400}) =>
      'https://res.cloudinary.com/${AppConstants.cloudinaryCloudName}'
          '/image/upload/c_fill,w_$width,h_$height,q_auto,f_auto/$publicId';

  /// Returns the direct download URL for a raw (PDF) asset.
  static String pdfDownloadUrl(String publicId) =>
      'https://res.cloudinary.com/${AppConstants.cloudinaryCloudName}'
          '/raw/upload/$publicId';
}

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message);
  final String message;
  @override
  String toString() => 'CloudinaryUploadException: $message';
}