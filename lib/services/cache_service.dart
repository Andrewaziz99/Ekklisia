// lib/services/cache_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Offline cache management for PDF files, images, and audio.
//
// Usage:
//   final service = CacheService.instance;
//   final file    = await service.pdf.getSingleFile(url);
//   final bytes   = await service.getSizeBytes();
//   await service.clearAll();
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

// ── Custom cache managers ──────────────────────────────────────────────────

/// Cache manager for PDF files — 30-day TTL, 200-file cap.
class PdfCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'ekklisiaPdfCache';
  static final PdfCacheManager _instance = PdfCacheManager._();

  factory PdfCacheManager() => _instance;

  PdfCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 200,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}

/// Cache manager for audio files — 14-day TTL, 100-file cap.
/// (just_audio's LockCachingAudioSource handles its own cache for streaming;
///  this manager is for pre-fetching audio files explicitly if needed.)
class AudioCacheManager extends CacheManager {
  static const key = 'ekklisiaAudioCache';
  static final AudioCacheManager _instance = AudioCacheManager._();

  factory AudioCacheManager() => _instance;

  AudioCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 14),
          maxNrOfCacheObjects: 100,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}

// ── CacheService facade ────────────────────────────────────────────────────

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  /// Cache manager for PDF files.
  final CacheManager pdf = PdfCacheManager();

  /// Cache manager for audio files (explicit pre-fetch).
  final CacheManager audio = AudioCacheManager();

  /// Default image cache manager (used by CachedNetworkImage internally).
  final CacheManager image = DefaultCacheManager();

  /// Total size of all caches in bytes.
  Future<int> getSizeBytes() async {
    int total = 0;
    try {
      final dir = await getApplicationCacheDirectory();
      total = await _dirSize(dir);
    } catch (e) {
      debugPrint('[CacheService] getSizeBytes error: $e');
    }
    return total;
  }

  /// Human-readable cache size string, e.g. "42.3 MB".
  Future<String> getSizeLabel() async {
    final bytes = await getSizeBytes();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Clear all cached files (PDF, audio, image).
  Future<void> clearAll() async {
    await Future.wait([
      pdf.emptyCache(),
      audio.emptyCache(),
      image.emptyCache(),
    ]);
    debugPrint('[CacheService] All caches cleared.');
  }

  /// Clear only PDF cache.
  Future<void> clearPdf() => pdf.emptyCache();

  /// Clear only audio cache.
  Future<void> clearAudio() => audio.emptyCache();

  /// Clear only image cache.
  Future<void> clearImages() => image.emptyCache();

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<int> _dirSize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          size += await entity.length().catchError((_) => 0);
        }
      }
    } catch (_) {}
    return size;
  }
}
