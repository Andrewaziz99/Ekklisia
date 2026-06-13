// lib/shared/widgets/cached_pdf_viewer.dart
// ─────────────────────────────────────────────────────────────────────────────
// Drop-in replacement for SfPdfViewer.network() that:
//  1. Checks the local cache first (instant open on repeat visits).
//  2. Downloads and caches the PDF on first open, showing a progress bar.
//  3. Falls back gracefully when offline and not yet cached.
//
// Usage:
//   CachedPdfViewer(
//     url: pdfUrl,
//     pdfKey: _pdfKey,
//     controller: _pdfCtrl,
//     onDocumentLoaded: (d) { ... },
//     onDocumentLoadFailed: (d) { ... },
//     onPageChanged: (d) { ... },
//   )
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/theme/colors.dart';
import '../../services/cache_service.dart';

class CachedPdfViewer extends StatefulWidget {
  const CachedPdfViewer({
    super.key,
    required this.url,
    this.pdfKey,
    this.controller,
    this.enableDoubleTapZooming = true,
    this.enableTextSelection = true,
    this.canShowScrollHead = true,
    this.canShowScrollStatus = true,
    this.scrollDirection = PdfScrollDirection.vertical,
    this.pageLayoutMode = PdfPageLayoutMode.continuous,
    this.initialZoomLevel = 1.0,
    this.onDocumentLoaded,
    this.onDocumentLoadFailed,
    this.onPageChanged,
  });

  final String url;
  final GlobalKey<SfPdfViewerState>? pdfKey;
  final PdfViewerController? controller;
  final bool enableDoubleTapZooming;
  final bool enableTextSelection;
  final bool canShowScrollHead;
  final bool canShowScrollStatus;
  final PdfScrollDirection scrollDirection;
  final PdfPageLayoutMode pageLayoutMode;
  final double initialZoomLevel;
  final void Function(PdfDocumentLoadedDetails)? onDocumentLoaded;
  final void Function(PdfDocumentLoadFailedDetails)? onDocumentLoadFailed;
  final void Function(PdfPageChangedDetails)? onPageChanged;

  @override
  State<CachedPdfViewer> createState() => _CachedPdfViewerState();
}

class _CachedPdfViewerState extends State<CachedPdfViewer> {
  _LoadState _state = _LoadState.loading;
  File? _cachedFile;
  double _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void didUpdateWidget(CachedPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _state = _LoadState.loading;
        _cachedFile = null;
        _progress = 0;
        _errorMessage = null;
      });
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    final manager = CacheService.instance.pdf;

    try {
      // Check if already cached (FileInfo with valid file).
      final info = await manager.getFileFromCache(widget.url);
      if (info != null && await info.file.exists()) {
        if (mounted) {
          setState(() {
            _cachedFile = info.file;
            _state = _LoadState.ready;
          });
        }
        return;
      }

      // Not cached — download with progress.
      await for (final result
          in manager.getFileStream(widget.url, withProgress: true)) {
        if (!mounted) return;

        if (result is DownloadProgress) {
          setState(() {
            _progress = result.progress ?? 0;
          });
        } else if (result is FileInfo) {
          setState(() {
            _cachedFile = result.file;
            _state = _LoadState.ready;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;

      // Offline fallback: try the stale cache entry.
      try {
        final stale = await manager.getFileFromCache(widget.url);
        if (stale != null && await stale.file.exists()) {
          setState(() {
            _cachedFile = stale.file;
            _state = _LoadState.ready;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _errorMessage = 'لا يوجد اتصال بالإنترنت ولم يتم تنزيل هذا الملف بعد.';
        _state = _LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return _DownloadingOverlay(progress: _progress);

      case _LoadState.error:
        return _OfflineErrorView(
          message: _errorMessage,
          onRetry: () {
            setState(() {
              _state = _LoadState.loading;
              _progress = 0;
              _errorMessage = null;
            });
            _loadPdf();
          },
        );

      case _LoadState.ready:
        return SfPdfViewer.file(
          _cachedFile!,
          key: widget.pdfKey,
          controller: widget.controller,
          enableDoubleTapZooming: widget.enableDoubleTapZooming,
          enableTextSelection: widget.enableTextSelection,
          canShowScrollHead: widget.canShowScrollHead,
          canShowScrollStatus: widget.canShowScrollStatus,
          scrollDirection: widget.scrollDirection,
          pageLayoutMode: widget.pageLayoutMode,
          initialZoomLevel: widget.initialZoomLevel,
          onDocumentLoaded: widget.onDocumentLoaded,
          onDocumentLoadFailed: widget.onDocumentLoadFailed,
          onPageChanged: widget.onPageChanged,
        );
    }
  }
}

// ── State enum ─────────────────────────────────────────────────────────────

enum _LoadState { loading, ready, error }

// ── Downloading overlay ────────────────────────────────────────────────────

class _DownloadingOverlay extends StatelessWidget {
  const _DownloadingOverlay({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(0);
    return Container(
      color: EkklisiaColors.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 3,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(EkklisiaColors.gold),
                backgroundColor: EkklisiaColors.bgElevated,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              progress > 0 ? '$pct%' : 'جارٍ التحميل...',
              style: const TextStyle(
                color: EkklisiaColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (progress > 0) ...[
              const SizedBox(height: 8),
              const Text(
                'يتم تنزيل الملف للمرة الأولى',
                style: TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Offline error view ─────────────────────────────────────────────────────

class _OfflineErrorView extends StatelessWidget {
  const _OfflineErrorView({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EkklisiaColors.bgPrimary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: EkklisiaColors.textSecondary,
              ),
              const SizedBox(height: 20),
              Text(
                message ?? 'تعذّر تحميل الملف',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EkklisiaColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'تأكد من الاتصال بالإنترنت وحاول مرة أخرى.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EkklisiaColors.gold,
                  side: const BorderSide(color: EkklisiaColors.goldBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
