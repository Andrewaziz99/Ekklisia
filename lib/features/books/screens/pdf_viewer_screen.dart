// lib/features/books/screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/book_model.dart';
import '../../../shared/widgets/cached_pdf_viewer.dart';

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

  bool _showToolbar = true;
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (_) => setState(() => _showToolbar = !_showToolbar),
        child: Stack(
          children: [
            // ── PDF Viewer ───────────────────────────────────────────────
            Positioned.fill(
              child: CachedPdfViewer(
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
                  _showErrorSnack(error.toString());
                },
                onPageChanged: (page) {
                  _pageNotifier.value = page;
                },
              ),
            ),

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
                  child: _BottomBar(
                    pageNotifier: _pageNotifier,
                    totalPages: _totalPages,
                    getCtrl: () => _pdfCtrl,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
          IconButton(
            tooltip: 'وضع القراءة',
            icon: Icon(_readingModeIcon, color: EkklisiaColors.gold),
            onPressed: _cycleReadingMode,
          ),
        ],
      ),
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

// ── Bottom bar — isolated widget so page changes don't rebuild the whole screen

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pageNotifier,
    required this.totalPages,
    required this.getCtrl,
  });

  final ValueNotifier<int> pageNotifier;
  final int totalPages;
  // Getter so we always get the current (possibly null) controller reference
  final PdfScrollController? Function() getCtrl;

  @override
  Widget build(BuildContext context) {
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
      child: ValueListenableBuilder<int>(
        valueListenable: pageNotifier,
        builder: (_, page, __) {
          final ctrl = getCtrl();
          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: EkklisiaColors.gold),
                onPressed: (ctrl != null && page > 1)
                    ? () => ctrl.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$page / $totalPages',
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
                        value: page.toDouble(),
                        min: 1,
                        max: totalPages.toDouble(),
                        onChanged: (_) {},
                        onChangeEnd: (v) => ctrl?.jumpToPage(v.round()),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: EkklisiaColors.gold),
                onPressed: (ctrl != null && page < totalPages)
                    ? () => ctrl.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ReadingMode { dark, parchment, night }
