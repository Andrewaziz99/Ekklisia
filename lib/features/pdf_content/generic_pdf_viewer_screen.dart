// lib/features/pdf_content/generic_pdf_viewer_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Standalone PDF viewer — takes a URL and titles directly.
// Does NOT require BookModel. Works for any category PDF.
//
// Optional: pass [audioTracks] + [contentId] to show a persistent audio strip
// at the bottom (same pattern as AgbeyaPdfReaderScreen).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../data/models/pdf_content_model.dart';
import '../agbeya/cubit/audio_player_cubit.dart';
import '../agbeya/cubit/audio_player_state.dart';

// ── Palette (always dark — reading context) ───────────────────────────────────
const _kBgDeep    = Color(0xFF08111C);
const _kBgPrimary = Color(0xFF0D1B2A);
const _kNavy      = Color(0xFF1B2A4A);
const _kCrimson   = Color(0xFF6B1A1A);
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
    this.audioTracks = const [],
    this.contentId   = '',
  });

  final String url;
  final String titleAr;
  final String titleEl;

  /// Optional audio tracks. When non-empty, a persistent strip appears.
  final List<ContentAudioTrack> audioTracks;

  /// Unique ID used to detect whether this content is currently playing.
  /// Use PdfContent.id when available.
  final String contentId;

  bool get hasAudio => audioTracks.isNotEmpty;

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
    final stripH = widget.hasAudio ? _ContentAudioStrip.height : 0.0;

    return Scaffold(
      backgroundColor: _kBgPrimary,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _onBodyTap,
        child: Stack(
          children: [
            // ── PDF Viewer ───────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: stripH,
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

            // ── Page indicator (bottom, above audio strip) ───────────────
            if (_totalPages > 0 && !_hasError && !_isLoading)
              Positioned(
                left: 0,
                right: 0,
                bottom: stripH,
                child: AnimatedOpacity(
                  opacity: _showToolbar ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showToolbar,
                    child: _buildPageIndicator(context),
                  ),
                ),
              ),

            // ── Persistent audio strip ───────────────────────────────────
            if (widget.hasAudio)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ContentAudioStrip(
                  tracks:    widget.audioTracks,
                  contentId: widget.contentId.isNotEmpty
                      ? widget.contentId
                      : widget.url,
                  titleAr:   widget.titleAr,
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
          _PageNavButton(
            icon: Icons.chevron_left,
            enabled: _currentPage > 1,
            onPressed: () => _pdfController.previousPage(),
          ),
          const SizedBox(width: 16),
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

// ── Content Audio Strip ───────────────────────────────────────────────────────
// Persistent bar pinned at the bottom of the PDF viewer.
// Mirrors the pattern from AgbeyaPdfReaderScreen._AudioStrip.

class _ContentAudioStrip extends StatelessWidget {
  const _ContentAudioStrip({
    required this.tracks,
    required this.contentId,
    required this.titleAr,
  });

  final List<ContentAudioTrack> tracks;
  final String contentId;
  final String titleAr;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, state) {
        final cubit     = context.read<AudioPlayerCubit>();
        final isCurrent = state.currentItem?.extras?['contentId'] == contentId;
        final isPlaying = isCurrent && state.isPlaying;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: _kNavy,
            border: Border(
              top: BorderSide(
                  color: _kGold.withValues(alpha: 0.4), width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: _audioRow(context, cubit, state, isCurrent, isPlaying),
          ),
        );
      },
    );
  }

  Widget _audioRow(
    BuildContext context,
    AudioPlayerCubit cubit,
    AudioPlayerState state,
    bool isCurrent,
    bool isPlaying,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress micro-bar (only when this content is playing)
        if (isCurrent && state.duration > Duration.zero)
          LinearProgressIndicator(
            value: state.progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(_kGold),
            minHeight: 2,
          ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              // Cross decoration
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _kGold.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Center(
                  child: Text('✦',
                      style: TextStyle(
                          color: _kGold.withValues(alpha: 0.6),
                          fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),

              // Title + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titleAr,
                      textDirection: TextDirection.rtl,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isCurrent && state.duration > Duration.zero)
                      Text(
                        '${state.positionLabel} / ${state.durationLabel}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(width: 3),
                          Text(
                            '${tracks.length} ${tracks.length == 1 ? 'تسجيل' : 'تسجيلات'}',
                            style: TextStyle(
                              fontFamily: 'Scheherazade',
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ⏪ -10s
              _StripBtn(
                icon: Icons.replay_10,
                onTap: isCurrent ? cubit.skipBackward : null,
              ),

              // ▶ / ❚❚
              _PlayPauseBtn(
                state:     state,
                isCurrent: isCurrent,
                onTap: () async {
                  if (!isCurrent) {
                    await _playOrPick(context, cubit);
                  } else {
                    await cubit.togglePlayPause();
                  }
                },
              ),

              // ⏩ +30s
              _StripBtn(
                icon: Icons.forward_30,
                onTap: isCurrent ? cubit.skipForward : null,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _playOrPick(BuildContext context, AudioPlayerCubit cubit) async {
    if (tracks.isEmpty) return;
    if (tracks.length == 1) {
      await cubit.play(_mediaItem(tracks.first));
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ContentTrackPickerSheet(
          tracks:    tracks,
          contentId: contentId,
          titleAr:   titleAr,
        ),
      ),
    );
  }

  MediaItem _mediaItem(ContentAudioTrack track) => MediaItem(
    id:       track.url,
    title:    track.labelAr.isNotEmpty ? track.labelAr : titleAr,
    album:    titleAr,
    duration: track.durationSeconds > 0
        ? Duration(seconds: track.durationSeconds)
        : null,
    extras: {'contentId': contentId},
  );
}

// ── Strip sub-widgets ─────────────────────────────────────────────────────────

class _StripBtn extends StatelessWidget {
  const _StripBtn({required this.icon, required this.onTap});
  final IconData      icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 22,
        color: onTap != null
            ? _kGold
            : _kGold.withValues(alpha: 0.3)),
    onPressed: onTap,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}

class _PlayPauseBtn extends StatelessWidget {
  const _PlayPauseBtn({
    required this.state,
    required this.isCurrent,
    required this.onTap,
  });
  final AudioPlayerState state;
  final bool             isCurrent;
  final VoidCallback     onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color:  _kCrimson,
        shape:  BoxShape.circle,
        border: Border.all(
            color: _kGold.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Center(
        child: state.isBuffering && isCurrent
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: _kGold, strokeWidth: 2),
              )
            : Icon(
                isCurrent && state.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: _kGold,
                size: 22,
              ),
      ),
    ),
  );
}

// ── Content Track Picker Sheet ────────────────────────────────────────────────

class _ContentTrackPickerSheet extends StatelessWidget {
  const _ContentTrackPickerSheet({
    required this.tracks,
    required this.contentId,
    required this.titleAr,
  });

  final List<ContentAudioTrack> tracks;
  final String contentId;
  final String titleAr;

  @override
  Widget build(BuildContext context) {
    const sheetBg = Color(0xFF0D1825);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: _kGold.withValues(alpha: 0.2), width: 0.8),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kCrimson.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _kGold.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: const Icon(Icons.headphones,
                      color: _kGold, size: 18),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('اختر تسجيل',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(titleAr,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      )),
                ]),
              ]),
              const SizedBox(height: 16),
              Divider(color: _kGold.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 14),

              // Track cards
              ...tracks.asMap().entries.map((e) {
                final idx   = e.key;
                final track = e.value;
                const accents = [_kGold, Color(0xFF7EB8C9)];
                final accent  = accents[idx % accents.length];

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.read<AudioPlayerCubit>().play(MediaItem(
                      id:       track.url,
                      title:    track.labelAr.isNotEmpty ? track.labelAr : titleAr,
                      album:    titleAr,
                      duration: track.durationSeconds > 0
                          ? Duration(seconds: track.durationSeconds)
                          : null,
                      extras: {'contentId': contentId},
                    ));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color:        accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Row(children: [
                      // Index badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:  accent.withValues(alpha: 0.15),
                          shape:  BoxShape.circle,
                          border: Border.all(
                              color: accent.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Center(
                          child: Text('${idx + 1}',
                              style: TextStyle(
                                  color:      accent,
                                  fontSize:   14,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Label + duration
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              track.labelAr.isNotEmpty
                                  ? track.labelAr
                                  : 'تسجيل ${idx + 1}',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily:  'Scheherazade',
                                color:       Colors.white,
                                fontSize:    17,
                                fontWeight:  FontWeight.w700,
                              ),
                            ),
                            if (track.formattedDuration.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.timer_outlined,
                                      color: Colors.white
                                          .withValues(alpha: 0.4),
                                      size: 12),
                                  const SizedBox(width: 4),
                                  Text(track.formattedDuration,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
                                        fontSize: 11,
                                      )),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Play icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:  accent.withValues(alpha: 0.2),
                          shape:  BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow,
                            color: accent, size: 22),
                      ),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
