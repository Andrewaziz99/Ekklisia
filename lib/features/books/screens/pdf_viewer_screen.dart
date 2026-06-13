// lib/features/books/screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/book_model.dart';
import '../../../shared/widgets/cached_pdf_viewer.dart';

/// Full-screen PDF reader powered by Syncfusion PdfViewer.
///
/// Features:
///   • Loads PDF directly from Cloudinary URL (streaming, no local copy)
///   • Night / parchment reading modes
///   • Page indicator + jump-to-page
///   • Text selection (built-in Syncfusion)
///   • Zoom + scroll (built-in)
///   • Arabic RTL book title in app bar
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.book});
  final BookModel book;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _pdfController;
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();

  bool _showToolbar = true;
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 1;
  int _totalPages = 0;
  _ReadingMode _readingMode = _ReadingMode.dark;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  // ── Reading mode colors ─────────────────────────────────────────────────

  Color get _bgColor {
    switch (_readingMode) {
      case _ReadingMode.dark:
        return EkklisiaColors.bgPrimary;
      case _ReadingMode.parchment:
        return EkklisiaColors.bgParchment;
      case _ReadingMode.night:
        return const Color(0xFF060C14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: GestureDetector(
        onTap: () => setState(() => _showToolbar = !_showToolbar),
        child: Stack(
          children: [
            // ── PDF Viewer ───────────────────────────────────────────────
            Positioned.fill(
              child: CachedPdfViewer(
                url: widget.book.pdfUrl,
                pdfKey: _pdfKey,
                controller: _pdfController,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                scrollDirection: PdfScrollDirection.vertical,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                initialZoomLevel: 1.0,
                onDocumentLoaded: (details) {
                  setState(() {
                    _isLoading = false;
                    _totalPages = details.document.pages.count;
                  });
                },
                onDocumentLoadFailed: (details) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                  });
                  _showErrorSnack(details.description);
                },
                onPageChanged: (details) {
                  setState(() => _currentPage = details.newPageNumber);
                },
              ),
            ),

            // ── Loading overlay ──────────────────────────────────────────
            if (_isLoading) _buildLoadingOverlay(),

            // ── Error overlay ────────────────────────────────────────────
            if (_hasError) _buildErrorOverlay(),

            // ── Top toolbar ──────────────────────────────────────────────
            AnimatedSlide(
              offset: _showToolbar ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _buildTopBar(context),
            ),

            // ── Bottom toolbar ───────────────────────────────────────────
            if (_totalPages > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  offset: _showToolbar ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _buildBottomBar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EkklisiaColors.bgDeep,
            EkklisiaColors.bgDeep.withOpacity(0),
          ],
        ),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: EkklisiaColors.bgDeep.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: EkklisiaColors.gold,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.book.titleAr,
          style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.goldLight,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Reading mode toggle
          IconButton(
            tooltip: 'وضع القراءة',
            icon: Icon(_readingModeIcon, color: EkklisiaColors.gold),
            onPressed: _cycleReadingMode,
          ),
          // Bookmark (search)
          IconButton(
            tooltip: 'بحث',
            icon: const Icon(Icons.search, color: EkklisiaColors.gold),
            onPressed: () => _pdfKey.currentState?.openBookmarkView(),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar ──────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            EkklisiaColors.bgDeep,
            EkklisiaColors.bgDeep.withOpacity(0),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          // Previous page
          IconButton(
            icon: const Icon(Icons.chevron_left, color: EkklisiaColors.gold),
            onPressed: _currentPage > 1
                ? () => _pdfController.previousPage()
                : null,
          ),

          // Page indicator + slider
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: EkklisiaColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: EkklisiaColors.gold,
                    inactiveTrackColor: EkklisiaColors.goldBorder,
                    thumbColor: EkklisiaColors.gold,
                    overlayColor: EkklisiaColors.goldSubtle,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 1,
                    max: _totalPages.toDouble(),
                    onChanged: (v) {
                      _pdfController.jumpToPage(v.round());
                    },
                  ),
                ),
              ],
            ),
          ),

          // Next page
          IconButton(
            icon: const Icon(Icons.chevron_right, color: EkklisiaColors.gold),
            onPressed: _currentPage < _totalPages
                ? () => _pdfController.nextPage()
                : null,
          ),
        ],
      ),
    );
  }

  // ── Loading Overlay ─────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: EkklisiaColors.bgPrimary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Byzantine cross ornament
          const Text(
            '✦',
            style: TextStyle(color: EkklisiaColors.goldDim, fontSize: 32),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(EkklisiaColors.gold),
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          const Text(
            'جاري تحميل الكتاب…',
            style: TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: EkklisiaColors.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'تعذّر تحميل الكتاب',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: EkklisiaColors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصالك بالإنترنت وأعد المحاولة',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: EkklisiaColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() {
                _hasError = false;
                _isLoading = true;
              }),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _cycleReadingMode() {
    setState(() {
      _readingMode = _ReadingMode
          .values[(_readingMode.index + 1) % _ReadingMode.values.length];
    });
  }

  IconData get _readingModeIcon {
    switch (_readingMode) {
      case _ReadingMode.dark:
        return Icons.dark_mode_outlined;
      case _ReadingMode.parchment:
        return Icons.light_mode_outlined;
      case _ReadingMode.night:
        return Icons.nightlight_outlined;
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: EkklisiaColors.maroon,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

enum _ReadingMode { dark, parchment, night }
