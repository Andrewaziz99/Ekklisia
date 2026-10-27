// lib/shared/widgets/cached_pdf_viewer.dart
// ─────────────────────────────────────────────────────────────────────────────
// Drop-in PDF viewer that:
//   1. Downloads & caches the PDF (shows progress bar on first open).
//   2. Renders the document via pdfrx's native PdfViewer widget — PDFium-
//      backed, continuous vertical scroll, built-in pinch/double-tap zoom
//      over the whole document (not per-page), keyboard navigation, and
//      native internal-link ("jump to page") handling.
//   3. Exposes [PdfScrollController] (via onControllerReady) for page
//      navigation — same public API as before the pdfx→pdfrx migration, so
//      every call site (reader screens, pdf_nav_tools.dart) is untouched.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, compute, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../../admin/utils/drive_link_utils.dart';
import '../../core/theme/colors.dart';
import '../../services/cache_service.dart';
import 'pdf_text_search.dart';

export 'pdf_text_search.dart' show PdfSearchMatch;

// ═════════════════════════════════════════════════════════════════════════════
// PUBLIC CONTROLLER
// ═════════════════════════════════════════════════════════════════════════════

/// Navigation controller for [CachedPdfViewer].
///
/// Lifecycle is owned by [CachedPdfViewer] — do NOT call [dispose] from the
/// parent. Store the reference received in [CachedPdfViewer.onControllerReady].
class PdfScrollController {
  PdfScrollController();

  /// Backing pdfrx controller, handed to the pdfrx [PdfViewer] widget via
  /// its `controller:` param. Page layout/scroll position tracking all
  /// lives inside pdfrx now — this class is a thin, stable-API wrapper
  /// around it so callers never had to change when the rendering engine
  /// (pdfx → pdfrx) was swapped underneath.
  final PdfViewerController _pdf = PdfViewerController();

  // Raw document bytes — kept around (already downloaded for rendering) so
  // search can run without a second network fetch. Set once by
  // CachedPdfViewer right after the document opens.
  Uint8List? _sourceBytes;

  /// Total page count (0 before the document finishes loading).
  int get totalPages => _pdf.isReady ? _pdf.pageCount : 0;

  /// Last known visible page (1-indexed).
  int get currentPage => _pdf.isReady ? (_pdf.pageNumber ?? 1) : 1;

  // ── public API ────────────────────────────────────────────────────────────

  void jumpToPage(int page) => _goTo(page, Duration.zero);

  /// [curve] is accepted for API compatibility with existing call sites but
  /// ignored — pdfrx's own page-to-page animation doesn't take a custom
  /// curve (matches the [CachedPdfViewer.scrollDirection]/[pageSnapping]
  /// "kept but ignored" pattern already used in this file).
  void nextPage({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) => _goTo(currentPage + 1, duration);

  void previousPage({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) => _goTo(currentPage - 1, duration);

  /// Public, animated jump — used by the "go to page" UI. Silently clamps
  /// to the valid page range.
  void animateToPage(
    int page, {
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeInOut,
  }) => _goTo(page, duration);

  void _goTo(int page, Duration duration) {
    if (!_pdf.isReady || _pdf.pageCount == 0) return;
    final target = page.clamp(1, _pdf.pageCount);
    _pdf.goToPage(pageNumber: target, duration: duration);
  }

  // ── Text search ──────────────────────────────────────────────────────────
  // Pages are still matched via a background-isolate text extraction pass
  // (see pdf_text_search.dart) rather than pdfrx's own PdfTextSearcher, so
  // the search UI (pdf_nav_tools.dart) — built around "which pages matched"
  // — didn't need to change either. Only the actual page-jump underneath
  // now goes through pdfrx's controller instead of manual scroll math.

  List<PdfSearchMatch> searchResults = const [];
  int searchResultIndex = -1;

  PdfSearchMatch? get currentSearchMatch =>
      (searchResultIndex >= 0 && searchResultIndex < searchResults.length)
          ? searchResults[searchResultIndex]
          : null;

  /// Searches the document for [query] on a background isolate and jumps to
  /// the first match. Returns the matches found (also stored in
  /// [searchResults] for a caller to render a results list).
  Future<List<PdfSearchMatch>> search(String query) async {
    final bytes = _sourceBytes;
    if (bytes == null || query.trim().isEmpty) {
      searchResults = const [];
      searchResultIndex = -1;
      return searchResults;
    }
    final results = await compute(
      searchPdfText,
      PdfSearchArgs(bytes: bytes, query: query),
    );
    searchResults = results;
    searchResultIndex = results.isEmpty ? -1 : 0;
    if (results.isNotEmpty) animateToPage(results.first.pageNumber);
    return results;
  }

  void goToSearchResult(int index) {
    if (index < 0 || index >= searchResults.length) return;
    searchResultIndex = index;
    animateToPage(searchResults[index].pageNumber);
  }

  void nextSearchResult() {
    if (searchResults.isEmpty) return;
    goToSearchResult((searchResultIndex + 1) % searchResults.length);
  }

  void previousSearchResult() {
    if (searchResults.isEmpty) return;
    goToSearchResult(
      (searchResultIndex - 1 + searchResults.length) % searchResults.length,
    );
  }

  void clearSearch() {
    searchResults = const [];
    searchResultIndex = -1;
  }

  // NOTE: PdfViewerController has no dispose() method of its own — even
  // pdfrx's own PdfViewer widget doesn't call one on the controllers it
  // auto-creates internally (verified against the package source: its
  // State.dispose() only detaches via `_controller?._attach(null)`).
  // Nothing here currently holds a resource that needs manual releasing,
  // so this is a no-op kept for API compatibility with existing callers
  // (_CachedPdfViewerState._cleanup() still calls ctrl?.dispose()).
  void dispose() {}
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
    // pdfrx always lays the document out as a continuous vertical scroll.
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
  PdfScrollController? _ctrl;
  String? _errorMessage;

  // What pdfrx actually opens: a local file path (native/IO — reused from
  // our own disk cache) or raw bytes (web, where there's no filesystem to
  // point pdfrx at). Exactly one of these is set once _phase is ready.
  String? _filePath;
  Uint8List? _fileBytes;

  // Google Drive sends no CORS headers, which breaks the direct fetch below
  // on Flutter Web — route Drive URLs through the drive-proxy edge function.
  // Non-Drive URLs pass through unchanged. Used for every actual network/
  // cache-key access below; [widget.url] itself is left untouched so
  // [didUpdateWidget]'s equality check still reflects the real input prop.
  String get _effectiveUrl => resolveDriveUrl(widget.url);

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
        _filePath = null;
        _fileBytes = null;
      });
      _loadPdf();
    }
  }

  void _cleanup() {
    _ctrl?.dispose();
    _ctrl = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  // ── Download / cache ────────────────────────────────────────────────────────

  Future<void> _loadPdf() {
    // flutter_cache_manager's disk cache (used below) needs a real
    // filesystem, backed by path_provider — which has no web implementation
    // at all, so any call into it throws MissingPluginException in a
    // browser. Skip it there and just fetch bytes straight into memory;
    // pdfrx opens those directly via PdfViewer.data.
    if (kIsWeb) return _loadPdfWeb();
    return _loadPdfIO();
  }

  Future<void> _loadPdfWeb() async {
    try {
      final response = await http.get(Uri.parse(_effectiveUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.tryParse(_effectiveUrl),
        );
      }
      _finishOpen(bytes: response.bodyBytes);
    } catch (e) {
      // The old message here was a blanket "no internet connection", shown
      // for ANY failure — including a reachable-but-erroring server (e.g.
      // the drive-proxy edge function rejecting/failing a request), which
      // is misleading when the device genuinely has a connection. Logged so
      // the real cause is visible in the console/logcat, and the on-screen
      // message now only claims "offline" for an actual connectivity error.
      debugPrint('[CachedPdfViewer] Failed to load $_effectiveUrl: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(e);
        _phase = _Phase.error;
      });
    }
  }

  /// Only genuine connectivity failures (DNS/socket errors) get the
  /// "you're offline" copy — everything else (bad HTTP status from the
  /// server/proxy, timeouts, malformed responses, etc.) gets a distinct
  /// "couldn't download" message so the two very different failure modes
  /// aren't conflated in the UI.
  String _messageFor(Object e) {
    if (e is SocketException) {
      return 'لا يوجد اتصال بالإنترنت ولم يتم تنزيل هذا الملف بعد.';
    }
    return 'تعذّر تحميل الملف. حاول مرة أخرى لاحقاً.';
  }

  Future<void> _loadPdfIO() async {
    final manager = CacheService.instance.pdf;
    try {
      final info = await manager.getFileFromCache(_effectiveUrl);
      if (info != null && await info.file.exists()) {
        await _openFile(info.file);
        return;
      }
      await for (final result in manager.getFileStream(
        _effectiveUrl,
        withProgress: true,
      )) {
        if (!mounted) return;
        if (result is DownloadProgress) {
          setState(() => _progress = result.progress ?? 0);
        } else if (result is FileInfo) {
          await _openFile(result.file);
          return;
        }
      }
    } catch (e) {
      debugPrint('[CachedPdfViewer] Failed to download $_effectiveUrl: $e');
      if (!mounted) return;
      try {
        final stale = await manager.getFileFromCache(_effectiveUrl);
        if (stale != null && await stale.file.exists()) {
          await _openFile(stale.file);
          return;
        }
      } catch (_) {}
      setState(() {
        _errorMessage = _messageFor(e);
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _openFile(File file) async {
    if (!mounted) return;
    Uint8List? bytes;
    try {
      // Only needed for text search (see pdf_text_search.dart) — pdfrx
      // renders straight off the file path below regardless of whether
      // this read succeeds.
      bytes = await file.readAsBytes();
    } catch (_) {
      // Search will just be unavailable for this document; rendering is
      // unaffected.
    }
    _finishOpen(filePath: file.path, bytes: bytes);
  }

  void _finishOpen({String? filePath, Uint8List? bytes}) {
    if (!mounted) return;
    final ctrl = PdfScrollController().._sourceBytes = bytes;
    setState(() {
      _ctrl = ctrl;
      _filePath = filePath;
      _fileBytes = bytes;
      _phase = _Phase.ready;
    });
    widget.onControllerReady?.call(ctrl);
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
          child: _PdfrxHost(
            filePath: _filePath,
            bytes: _fileBytes,
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
// PDFRX HOST — wires the pdfrx PdfViewer widget to our controller/callbacks
// ═════════════════════════════════════════════════════════════════════════════

class _PdfrxHost extends StatefulWidget {
  const _PdfrxHost({
    this.filePath,
    this.bytes,
    required this.ctrl,
    this.onDocumentLoaded,
    this.onDocumentLoadFailed,
    this.onPageChanged,
  });

  /// Local cache file path (native/IO). Null on web.
  final String? filePath;

  /// Raw document bytes. Always set on web; also kept on IO for search, but
  /// [filePath] takes priority there since pdfrx can stream straight off
  /// disk instead of holding the whole file in memory again.
  final Uint8List? bytes;

  final PdfScrollController ctrl;
  final void Function(int)? onDocumentLoaded;
  final void Function(Object)? onDocumentLoadFailed;
  final void Function(int)? onPageChanged;

  @override
  State<_PdfrxHost> createState() => _PdfrxHostState();
}

class _PdfrxHostState extends State<_PdfrxHost> {
  // Stable method references (not fresh closures rebuilt every frame) so
  // PdfViewerParams' equality check never sees a "changed" callback and
  // triggers pdfrx to needlessly reload the document.

  void _onDocumentChanged(PdfDocument? document) {
    if (document != null) widget.onDocumentLoaded?.call(document.pages.length);
  }

  void _onPageChanged(int? page) {
    if (page != null) widget.onPageChanged?.call(page);
  }

  void _onDocumentLoadFinished(PdfDocumentRef documentRef, bool succeeded) {
    if (succeeded) return;
    final error =
        documentRef.resolveListenable().error ?? 'Failed to open document';
    widget.onDocumentLoadFailed?.call(error);
  }

  Widget _loadingBanner(BuildContext context, int bytesDownloaded, int? totalBytes) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(EkklisiaColors.gold),
        ),
      ),
    );
  }

  Widget _errorBanner(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
    PdfDocumentRef documentRef,
  ) {
    return Container(
      color: EkklisiaColors.bgPrimary,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'تعذّر فتح الملف.',
            textAlign: TextAlign.center,
            style: TextStyle(color: EkklisiaColors.textPrimary, fontSize: 16),
          ),
        ),
      ),
    );
  }

  /// Internal ("jump to page") links only — external URLs are intentionally
  /// ignored here, matching the previous implementation, since opening an
  /// arbitrary URL from inside a PDF without prompting the user first is a
  /// phishing vector (see pdfrx's own security note on link handling).
  void _onLinkTap(PdfLink link) {
    if (link.dest != null) widget.ctrl._pdf.goToDest(link.dest);
  }

  @override
  Widget build(BuildContext context) {
    final params = PdfViewerParams(
      backgroundColor: EkklisiaColors.bgPrimary,
      margin: 0,
      pageDropShadow: null,
      // pdfrx enables text selection by default (it has a real text layer,
      // unlike pdfx's flat bitmaps). That repurposes a single-finger drag
      // as a text-selection gesture instead of a scroll/pan — which reads
      // as "can't scroll or zoom the page" for a touch-first reading app
      // where we never wanted text selection in the first place.
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      onDocumentChanged: _onDocumentChanged,
      onPageChanged: _onPageChanged,
      onDocumentLoadFinished: _onDocumentLoadFinished,
      loadingBannerBuilder: _loadingBanner,
      errorBannerBuilder: _errorBanner,
      // linkColor/enableAutoLinkDetection: pdfrx's defaults paint a visible
      // tinted box over every detected link, including plain text that
      // merely *looks* like a URL (ISBNs, emails in credits pages, etc).
      // The old pdfx-based overlay was an invisible tap target with no
      // visual box at all — match that look, since we only act on `.dest`
      // (internal jump links) and deliberately ignore `.url` taps anyway.
      linkHandlerParams: PdfLinkHandlerParams(
        onLinkTap: _onLinkTap,
        linkColor: Colors.transparent,
        enableAutoLinkDetection: false,
      ),
    );

    final filePath = widget.filePath;
    if (filePath != null) {
      return PdfViewer.file(
        filePath,
        controller: widget.ctrl._pdf,
        params: params,
      );
    }
    return PdfViewer.data(
      widget.bytes!,
      sourceName: 'document.pdf',
      controller: widget.ctrl._pdf,
      params: params,
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
