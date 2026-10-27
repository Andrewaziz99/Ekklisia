// lib/features/books/screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/book_model.dart';
import '../../../shared/widgets/cached_pdf_viewer.dart';
import '../../../shared/widgets/pdf_nav_tools.dart';

/// Full-screen PDF reader powered by pdfx (platform-native rendering).
///
/// Performance notes:
///   • pdfx renders each page as a native bitmap (PDFKit/PdfRenderer) — no
///     inter-page lag or vector re-rasterization on scroll.
///   • onPageChanged updates a ValueNotifier, NOT setState on the whole screen.
///   • Slider uses onChangeEnd (not onChanged) — no jumpToPage spam while dragging.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.book});
  final BookModel book;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // Set by CachedPdfViewer once the document is open
  PdfScrollController? _pdfCtrl;

  // Page tracking via ValueNotifier — only rebuilds _BottomBar, not the screen
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(1);

  int _totalPages = 0;
  _ReadingMode _readingMode = _ReadingMode.dark;

  @override
  void dispose() {
    // _pdfCtrl lifecycle is owned by CachedPdfViewer — do NOT dispose here
    _pageNotifier.dispose();
    super.dispose();
  }

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
      // A real AppBar (not a Positioned/Stack overlay) reserves its own
      // layout space, so it never paints over the PDF page content —
      // unlike the previous floating-gradient-bar approach.
      appBar: _buildAppBar(context),
      body: CachedPdfViewer(
        url: widget.book.pdfUrl,
        scrollDirection: Axis.vertical,
        pageSnapping: false,
        onControllerReady: (ctrl) {
          // Don't call setState — just store the reference
          _pdfCtrl = ctrl;
        },
        onDocumentLoaded: (totalPages) {
          setState(() => _totalPages = totalPages);
        },
        onDocumentLoadFailed: (error) {
          _showErrorSnack('تعذّر عرض هذه الصفحة، حاول مرة أخرى.');
        },
        onPageChanged: (page) {
          _pageNotifier.value = page;
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: EkklisiaColors.bgDeep,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: EkklisiaColors.gold,
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
        if (_totalPages > 0 && _pdfCtrl != null)
          IconButton(
            key: const ValueKey('book_pdf_gotopage_btn'),
            tooltip: 'الانتقال إلى صفحة',
            icon: const Icon(Icons.numbers, color: EkklisiaColors.gold),
            onPressed: () => showPdfGoToPageDialog(
              context,
              controller: _pdfCtrl!,
              totalPages: _totalPages,
              currentPage: _pdfCtrl!.currentPage,
            ),
          ),
        if (_totalPages > 0 && _pdfCtrl != null)
          IconButton(
            key: const ValueKey('book_pdf_search_btn'),
            tooltip: 'بحث في الملف',
            icon: const Icon(Icons.search, color: EkklisiaColors.gold),
            onPressed: () => showPdfSearchSheet(
              context,
              controller: _pdfCtrl!,
            ),
          ),
        IconButton(
          key: const ValueKey('book_pdf_mode_btn'),
          tooltip: 'وضع القراءة',
          icon: Icon(_readingModeIcon, color: EkklisiaColors.gold),
          onPressed: _cycleReadingMode,
        ),
      ],
      // Page prev/next + tap-to-jump indicator — part of the same AppBar
      // (via PreferredSize) rather than a second floating bar, so it too
      // reserves its own space instead of sitting over the last page.
      bottom: _totalPages > 0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: ValueListenableBuilder<int>(
                valueListenable: _pageNotifier,
                builder: (_, page, __) => _PageNavRow(
                  page: page,
                  totalPages: _totalPages,
                  getCtrl: () => _pdfCtrl,
                ),
              ),
            )
          : null,
    );
  }

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

// ── Page nav row — lives in AppBar.bottom, isolated so page changes only
// rebuild this row (not the whole screen).

class _PageNavRow extends StatelessWidget {
  const _PageNavRow({
    required this.page,
    required this.totalPages,
    required this.getCtrl,
  });

  final int page;
  final int totalPages;
  // Getter so we always get the current (possibly null) controller reference
  final PdfScrollController? Function() getCtrl;

  @override
  Widget build(BuildContext context) {
    final ctrl = getCtrl();
    return Container(
      color: EkklisiaColors.bgDeep,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: EkklisiaColors.gold),
            onPressed: (ctrl != null && page > 1)
                ? () => ctrl.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: ctrl == null
                    ? null
                    : () => showPdfGoToPageDialog(
                          context,
                          controller: ctrl,
                          totalPages: totalPages,
                          currentPage: page,
                        ),
                child: Text(
                  '$page / $totalPages',
                  style: const TextStyle(
                    color: EkklisiaColors.gold,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: EkklisiaColors.goldBorder,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: EkklisiaColors.gold),
            onPressed: (ctrl != null && page < totalPages)
                ? () => ctrl.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

enum _ReadingMode { dark, parchment, night }
