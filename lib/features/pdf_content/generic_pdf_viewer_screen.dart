// lib/features/pdf_content/generic_pdf_viewer_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Standalone PDF viewer — takes a URL and titles directly.
// Does NOT require BookModel. Works for any category PDF.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ── Palette (always dark — reading context) ───────────────────────────────────
// These are kept local and constant because the PDF viewer is intentionally
// always dark regardless of the app-level theme.
const _kBgDeep    = Color(0xFF08111C);
const _kBgPrimary = Color(0xFF0D1B2A);
const _kGold      = Color(0xFFC8A84B);
const _kGoldBorder= Color(0x59C8A84B);
const _kTextPrimary   = Color(0xFFF0E6C8);
const _kTextSecondary = Color(0xFFA89060);

class GenericPdfViewerScreen extends StatefulWidget {
  const GenericPdfViewerScreen({
    super.key,
    required this.url,
    required this.titleAr,
    this.titleEl = '',
  });

  final String url;
  final String titleAr;
  final String titleEl;

  @override
  State<GenericPdfViewerScreen> createState() => _GenericPdfViewerScreenState();
}

class _GenericPdfViewerScreenState extends State<GenericPdfViewerScreen> {
  late final PdfViewerController _pdfController;
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();

  bool _showToolbar = true;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorDescription = '';
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    // Keep the status bar visible but tinted dark for immersion
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _kBgDeep,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  // ── Toggle toolbar on center tap ─────────────────────────────────────────

  void _onBodyTap(TapUpDetails details) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final x = details.globalPosition.dx;
    final y = details.globalPosition.dy;

    // Only toggle if tap is within the middle 50% of the screen
    final inCenterX = x > w * 0.25 && x < w * 0.75;
    final inCenterY = y > h * 0.25 && y < h * 0.75;

    if (inCenterX && inCenterY) {
      setState(() => _showToolbar = !_showToolbar);
    }
  }

  // ── Retry ────────────────────────────────────────────────────────────────

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgPrimary,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _onBodyTap,
        child: Stack(
          children: [
            // ── PDF Viewer ───────────────────────────────────────────────
            Positioned.fill(
              child: SfPdfViewer.network(
                widget.url,
                key: _pdfKey,
                controller: _pdfController,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                canShowScrollHead: true,
                canShowScrollStatus: false,
                scrollDirection: PdfScrollDirection.vertical,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                initialZoomLevel: 1.0,
                onDocumentLoaded: (details) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _totalPages = details.document.pages.count;
                    });
                  }
                },
                onDocumentLoadFailed: (details) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                      _errorDescription = details.description;
                    });
                  }
                },
                onPageChanged: (details) {
                  if (mounted) {
                    setState(() => _currentPage = details.newPageNumber);
                  }
                },
              ),
            ),

            // ── Loading overlay ──────────────────────────────────────────
            if (_isLoading) _buildLoadingOverlay(),

            // ── Error overlay ────────────────────────────────────────────
            if (_hasError) _buildErrorOverlay(),

            // ── AppBar (animated) ────────────────────────────────────────
            if (!_hasError && !_isLoading)
              AnimatedOpacity(
                opacity: _showToolbar ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showToolbar,
                  child: _buildAppBar(context),
                ),
              ),

            // ── Page indicator (bottom) ──────────────────────────────────
            if (_totalPages > 0 && !_hasError && !_isLoading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _showToolbar ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showToolbar,
                    child: _buildPageIndicator(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kBgDeep,
            _kBgDeep.withOpacity(0.95),
            _kBgDeep.withOpacity(0),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kBgDeep.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: _kGoldBorder, width: 0.5),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 15,
              color: _kGold,
            ),
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'رجوع',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.titleAr,
              style: const TextStyle(
                fontFamily: 'Scheherazade',
                color: _kTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.titleEl.isNotEmpty)
              Text(
                widget.titleEl,
                style: const TextStyle(
                  color: _kTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _kGoldBorder),
        ),
      ),
    );
  }

  // ── Page Indicator ───────────────────────────────────────────────────────

  Widget _buildPageIndicator(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _kBgDeep,
            _kBgDeep.withOpacity(0.9),
            _kBgDeep.withOpacity(0),
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous page button
          _PageNavButton(
            icon: Icons.chevron_left,
            enabled: _currentPage > 1,
            onPressed: () => _pdfController.previousPage(),
          ),
          const SizedBox(width: 16),

          // Page label: "صفحة X / Y"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _kBgDeep.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kGoldBorder, width: 0.5),
            ),
            child: Text(
              'صفحة $_currentPage / $_totalPages',
              style: const TextStyle(
                fontFamily: 'Scheherazade',
                color: _kTextSecondary,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Next page button
          _PageNavButton(
            icon: Icons.chevron_right,
            enabled: _currentPage < _totalPages,
            onPressed: () => _pdfController.nextPage(),
          ),
        ],
      ),
    );
  }

  // ── Loading Overlay ──────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: _kBgPrimary,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✦',
              style: TextStyle(color: _kTextSecondary, fontSize: 28),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_kGold),
              strokeWidth: 2,
            ),
            SizedBox(height: 16),
            Text(
              'جارٍ التحميل...',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: _kTextSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error Overlay ────────────────────────────────────────────────────────

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: _kBgPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 56,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'تعذّر تحميل الملف',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: _kTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصالك بالإنترنت وأعد المحاولة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: _kTextSecondary,
                fontSize: 14,
              ),
            ),
            if (_errorDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextSecondary,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 16, color: _kGold),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: _kGold,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGold,
                side: const BorderSide(color: _kGoldBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'رجوع',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: _kTextSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page navigation button ────────────────────────────────────────────────────

class _PageNavButton extends StatelessWidget {
  const _PageNavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _kBgDeep.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? _kGoldBorder : _kGoldBorder.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? _kGold : _kGold.withOpacity(0.3),
        ),
      ),
    );
  }
}
