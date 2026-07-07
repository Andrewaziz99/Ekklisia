// lib/shared/widgets/cached_pdf_viewer.dart
// ─────────────────────────────────────────────────────────────────────────────
// Drop-in PDF viewer that:
//   1. Downloads & caches the PDF (shows progress bar on first open).
//   2. Renders every page into a ListView at full screen width — no PhotoView
//      letterboxing, no gaps between pages.
//   3. Exposes [PdfScrollController] (via onControllerReady) for page navigation.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/colors.dart';
import '../../services/cache_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PUBLIC CONTROLLER
// ═════════════════════════════════════════════════════════════════════════════

/// Navigation controller for [CachedPdfViewer].
///
/// Lifecycle is owned by [CachedPdfViewer] — do NOT call [dispose] from the
/// parent. Store the reference received in [CachedPdfViewer.onControllerReady].
class PdfScrollController {
  PdfScrollController();

  final ScrollController _scroll = ScrollController();

  // Per-page heights (logical px). Filled lazily as pages render.
  final List<double> _heights = [];
  double _fallback = 0; // used before a real height is known
  int _totalPages = 0;
  int _currentPage = 1;

  // ── internal API used by CachedPdfViewer ────────────────────────────────

  void _init(int total) => _totalPages = total;

  void _recordHeight(int pageIndex, double h) {
    // Grow list to fit
    while (_heights.length < pageIndex) _heights.add(0);
    _heights[pageIndex - 1] = h;
    if (_fallback == 0 && h > 0) _fallback = h;
  }

  void _updateCurrentPage(int page) => _currentPage = page;

  // ── offset helpers ────────────────────────────────────────────────────────

  double _offsetFor(int page) {
    double sum = 0;
    for (int i = 0; i < page - 1; i++) {
      sum += (i < _heights.length && _heights[i] > 0) ? _heights[i] : _fallback;
    }
    return sum;
  }

  int _pageForOffset(double offset) {
    double sum = 0;
    for (int i = 0; i < _totalPages; i++) {
      final h = (i < _heights.length && _heights[i] > 0)
          ? _heights[i]
          : _fallback;
      if (h == 0) break;
      if (sum + h > offset) return i + 1;
      sum += h;
    }
    return _totalPages.clamp(1, _totalPages.isFinite ? _totalPages : 1);
  }

  // ── public API ────────────────────────────────────────────────────────────

  void jumpToPage(int page) {
    if (!_scroll.hasClients || _fallback == 0) return;
    final offset = _offsetFor(
      page,
    ).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(offset);
  }

  void nextPage({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) => _animateTo(_currentPage + 1, duration, curve);

  void previousPage({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) => _animateTo(_currentPage - 1, duration, curve);

  void _animateTo(int page, Duration duration, Curve curve) {
    if (!_scroll.hasClients || _fallback == 0) return;
    final target = page.clamp(1, _totalPages);
    final offset = _offsetFor(
      target,
    ).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(offset, duration: duration, curve: curve);
  }

  void dispose() => _scroll.dispose();
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGET
// ═════════════════════════════════════════════════════════════════════════════

class CachedPdfViewer extends StatefulWidget {
  const CachedPdfViewer({
    super.key,
    required this.url,
    this.onControllerReady,
    this.onDocumentLoaded,
    this.onDocumentLoadFailed,
    this.onPageChanged,
    // scrollDirection / pageSnapping kept for API compatibility but ignored:
    // the ListView always scrolls vertically without snapping.
    this.scrollDirection = Axis.vertical,
    this.pageSnapping = false,
  });

  final String url;

  /// Called once the [PdfScrollController] is ready. Store the reference; do
  /// NOT dispose it.
  final void Function(PdfScrollController controller)? onControllerReady;

  final void Function(int totalPages)? onDocumentLoaded;
  final void Function(Object error)? onDocumentLoadFailed;

  /// Called when the visible page number changes (1-indexed).
  final void Function(int page)? onPageChanged;

  final Axis scrollDirection;
  final bool pageSnapping;

  @override
  State<CachedPdfViewer> createState() => _CachedPdfViewerState();
}

// ── State ─────────────────────────────────────────────────────────────────────

enum _Phase { downloading, ready, error }

class _CachedPdfViewerState extends State<CachedPdfViewer> {
  _Phase _phase = _Phase.downloading;
  double _progress = 0;
  PdfDocument? _doc;
  PdfScrollController? _ctrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void didUpdateWidget(CachedPdfViewer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _cleanup();
      setState(() {
        _phase = _Phase.downloading;
        _progress = 0;
        _errorMessage = null;
      });
      _loadPdf();
    }
  }

  void _cleanup() {
    _ctrl?.dispose();
    _ctrl = null;
    _doc?.close();
    _doc = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  // ── Download / cache ────────────────────────────────────────────────────────

  Future<void> _loadPdf() async {
    final manager = CacheService.instance.pdf;
    try {
      final info = await manager.getFileFromCache(widget.url);
      if (info != null && await info.file.exists()) {
        await _openDocument(info.file);
        return;
      }
      await for (final result in manager.getFileStream(
        widget.url,
        withProgress: true,
      )) {
        if (!mounted) return;
        if (result is DownloadProgress) {
          setState(() => _progress = result.progress ?? 0);
        } else if (result is FileInfo) {
          await _openDocument(result.file);
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      try {
        final stale = await manager.getFileFromCache(widget.url);
        if (stale != null && await stale.file.exists()) {
          await _openDocument(stale.file);
          return;
        }
      } catch (_) {}
      setState(() {
        _errorMessage = 'لا يوجد اتصال بالإنترنت ولم يتم تنزيل هذا الملف بعد.';
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _openDocument(File file) async {
    if (!mounted) return;
    try {
      final doc = await PdfDocument.openFile(file.path);
      if (!mounted) {
        doc.close();
        return;
      }
      final ctrl = PdfScrollController().._init(doc.pagesCount);
      setState(() {
        _doc = doc;
        _ctrl = ctrl;
        _phase = _Phase.ready;
      });
      widget.onControllerReady?.call(ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذّر فتح الملف.';
        _phase = _Phase.error;
      });
      widget.onDocumentLoadFailed?.call(e);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.downloading:
        return _DownloadingOverlay(progress: _progress);

      case _Phase.error:
        return _OfflineErrorView(
          message: _errorMessage,
          onRetry: () {
            setState(() {
              _phase = _Phase.downloading;
              _progress = 0;
              _errorMessage = null;
            });
            _loadPdf();
          },
        );

      case _Phase.ready:
        return RepaintBoundary(
          child: _PageListView(
            document: _doc!,
            ctrl: _ctrl!,
            onDocumentLoaded: widget.onDocumentLoaded,
            onDocumentLoadFailed: widget.onDocumentLoadFailed,
            onPageChanged: widget.onPageChanged,
          ),
        );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CONTINUOUS LIST VIEW
// ═════════════════════════════════════════════════════════════════════════════

class _PageListView extends StatefulWidget {
  const _PageListView({
    required this.document,
    required this.ctrl,
    this.onDocumentLoaded,
    this.onDocumentLoadFailed,
    this.onPageChanged,
  });

  final PdfDocument document;
  final PdfScrollController ctrl;
  final void Function(int)? onDocumentLoaded;
  final void Function(Object)? onDocumentLoadFailed;
  final void Function(int)? onPageChanged;

  @override
  State<_PageListView> createState() => _PageListViewState();
}

class _PageListViewState extends State<_PageListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onDocumentLoaded?.call(widget.document.pagesCount),
    );
    widget.ctrl._scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.ctrl._scroll.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.ctrl._fallback == 0) return;
    final page = widget.ctrl
        ._pageForOffset(widget.ctrl._scroll.offset)
        .clamp(1, widget.document.pagesCount);
    if (page != widget.ctrl._currentPage) {
      widget.ctrl._updateCurrentPage(page);
      widget.onPageChanged?.call(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.ctrl._scroll,
      itemCount: widget.document.pagesCount,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) => _PdfPageTile(
        document: widget.document,
        pageIndex: index + 1,
        onSized: (h) => widget.ctrl._recordHeight(index + 1, h),
        onError: widget.onDocumentLoadFailed,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SINGLE PAGE TILE
// ═════════════════════════════════════════════════════════════════════════════

class _PdfPageTile extends StatefulWidget {
  const _PdfPageTile({
    required this.document,
    required this.pageIndex,
    required this.onSized,
    this.onError,
  });

  final PdfDocument document;
  final int pageIndex;
  final void Function(double height) onSized;
  final void Function(Object)? onError;

  @override
  State<_PdfPageTile> createState() => _PdfPageTileState();
}

class _PdfPageTileState extends State<_PdfPageTile> {
  PdfPageImage? _image;
  double? _height;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _render();
    }
  }

  Future<void> _render() async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final screenW = MediaQuery.of(context).size.width;
    final double pixelW = (screenW * dpr).roundToDouble();

    try {
      final page = await widget.document.getPage(widget.pageIndex);
      final double ratio = page.width.toDouble() / page.height.toDouble();
      final double pixelH = (pixelW / ratio).roundToDouble();
      final logicalH = screenW / ratio;

      final image = await page.render(
        width: pixelW,
        height: pixelH,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
        quality: 92,
      );
      await page.close();

      if (!mounted) return;

      widget.onSized(logicalH);
      setState(() {
        _image = image;
        _height = logicalH;
      });
    } catch (e) {
      if (mounted) widget.onError?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    if (_image == null) {
      // A4 placeholder until the page renders
      return SizedBox(
        width: screenW,
        height: screenW * 1.414,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(EkklisiaColors.goldDim),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: screenW,
      height: _height,
      child: Image.memory(
        _image!.bytes,
        width: screenW,
        height: _height,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OVERLAYS
// ═════════════════════════════════════════════════════════════════════════════

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
                valueColor: const AlwaysStoppedAnimation<Color>(
                  EkklisiaColors.gold,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
