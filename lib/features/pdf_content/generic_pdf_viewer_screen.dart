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

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../shared/widgets/cached_image.dart';
import '../../shared/widgets/cached_pdf_viewer.dart';
import '../../shared/widgets/pdf_nav_tools.dart';
import '../../shared/widgets/video_player_widget.dart';

import '../../data/models/pdf_content_model.dart';
import '../agbeya/cubit/audio_player_cubit.dart';
import '../agbeya/cubit/audio_player_state.dart';

// ── MediaItem builders ──────────────────────────────────────────────────────
// Shared by every "start playing this content's audio" call site below
// (auto-play on open, strip tap, picker-sheet tap) so they all build the
// exact same bilingual extras and — critically — the exact same [playlist]
// list, which AudioPlayerCubit now uses to auto-advance through every part
// of a Holy Mass on its own (see audio_player_cubit.dart._advanceIfQueued).
// That auto-advance lives on the app-wide singleton cubit rather than in a
// screen widget, so it keeps working whichever screen is on top, and
// through the device screen locking — audio_service's foreground service /
// background-audio session keeps the isolate running through both.

MediaItem _contentMediaItem({
  required ContentAudioTrack track,
  required String contentId,
  required String titleAr,
  required String titleEl,
  required String coverUrl,
}) => MediaItem(
  id: track.url,
  title: track.labelAr.isNotEmpty ? track.labelAr : titleAr,
  album: titleAr,
  artUri: coverUrl.isNotEmpty ? Uri.tryParse(coverUrl) : null,
  duration: track.durationSeconds > 0
      ? Duration(seconds: track.durationSeconds)
      : null,
  extras: {
    'contentId': contentId,
    'titleAr':
        track.labelFor('ar').isNotEmpty ? track.labelFor('ar') : titleAr,
    'titleEl':
        track.labelFor('el').isNotEmpty ? track.labelFor('el') : titleEl,
    'albumAr': titleAr,
    'albumEl': titleEl,
  },
);

List<MediaItem> _contentPlaylist({
  required List<ContentAudioTrack> tracks,
  required String contentId,
  required String titleAr,
  required String titleEl,
  required String coverUrl,
}) =>
    tracks
        .map((t) => _contentMediaItem(
              track: t,
              contentId: contentId,
              titleAr: titleAr,
              titleEl: titleEl,
              coverUrl: coverUrl,
            ))
        .toList();

class GenericPdfViewerScreen extends StatefulWidget {
  const GenericPdfViewerScreen({
    super.key,
    required this.url,
    required this.titleAr,
    this.titleEl = '',
    this.audioTracks = const [],
    this.contentId   = '',
    this.category    = '',
    this.videoUrl    = '',
    this.coverUrl    = '',
    this.initialPage = 0,
  });

  final String url;
  final String titleAr;
  final String titleEl;

  /// Optional audio tracks. When non-empty, a persistent strip appears.
  final List<ContentAudioTrack> audioTracks;

  /// Unique ID used to detect whether this content is currently playing.
  /// Use PdfContent.id when available.
  final String contentId;

  /// PdfCategory slug — only needed so a page-level bookmark saved from this
  /// screen can be grouped correctly on the Bookmarks screen.
  final String category;

  /// Optional video URL. When non-empty, a videocam icon appears in the AppBar.
  final String videoUrl;

  /// Optional cover image — shown on the audio strip and as the artwork in
  /// the full-screen player / lock-screen media notification.
  final String coverUrl;

  /// When set (>1), jumps to this page once the document finishes loading —
  /// used when opening from a page-level bookmark.
  final int initialPage;

  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;

  @override
  State<GenericPdfViewerScreen> createState() => _GenericPdfViewerScreenState();
}

class _GenericPdfViewerScreenState extends State<GenericPdfViewerScreen> {
  // Set by CachedPdfViewer once the document is open
  PdfScrollController? _pdfCtrl;

  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(1);
  int _totalPages = 0;

  String get _audioId =>
      widget.contentId.isNotEmpty ? widget.contentId : widget.url;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame — same pattern as
    // AgbeyaPdfReaderScreen._autoStartAudio — so the ancestor
    // BlocProvider<AudioPlayerCubit> is guaranteed mounted before we read it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartAudio());
  }

  /// Auto-plays the FIRST track in [widget.audioTracks] as soon as the
  /// screen opens — no picker, straight into playback. Once that track
  /// finishes, AudioPlayerCubit itself (see `_advanceIfQueued`) advances
  /// through the rest of the [playlist] on its own — not tied to this
  /// screen's widget tree — so opening a Liturgy plays through all of its
  /// audio parts back-to-back even if the user navigates elsewhere or the
  /// device screen locks.
  ///
  /// Skipped if this same content is already the cubit's current item —
  /// e.g. the user backed out and re-opened the same Liturgy — so we don't
  /// yank playback back to track 1 mid-listen.
  Future<void> _autoStartAudio() async {
    if (!mounted || !widget.hasAudio) return;
    final cubit = context.read<AudioPlayerCubit>();
    final isCurrent = cubit.state.currentItem?.extras?['contentId'] == _audioId;
    if (isCurrent) return;

    final playlist = _contentPlaylist(
      tracks: widget.audioTracks,
      contentId: _audioId,
      titleAr: widget.titleAr,
      titleEl: widget.titleEl,
      coverUrl: widget.coverUrl,
    );
    // playlist: the cubit auto-advances through the rest on its own as each
    // part finishes — including with the screen locked or this screen no
    // longer on top — so opening a Liturgy plays through all of its audio
    // parts back-to-back with no further taps.
    await cubit.play(playlist.first, playlist: playlist);
  }

  @override
  void dispose() {
    // _pdfCtrl lifecycle owned by CachedPdfViewer
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: BrightnessColors.bgPrimary(brightness),
      // A real AppBar (not a Positioned/Stack overlay) reserves its own
      // layout space, so it never paints over the PDF page content — same
      // for the audio strip, now docked via bottomNavigationBar instead of
      // floating over the last page.
      appBar: _buildAppBar(context),
      body: widget.url.isEmpty
          ? (widget.hasVideo
              ? _InlineVideoView(
                  videoUrl: widget.videoUrl,
                  titleAr: widget.titleAr,
                )
              : _NoPdfPlaceholder(hasVideo: false))
          : CachedPdfViewer(
              url: widget.url,
              scrollDirection: Axis.vertical,
              pageSnapping: false,
              onControllerReady: (ctrl) {
                _pdfCtrl = ctrl;
              },
              onDocumentLoaded: (totalPages) {
                if (mounted) setState(() => _totalPages = totalPages);
                if (widget.initialPage > 1) {
                  _pdfCtrl?.jumpToPage(widget.initialPage);
                }
              },
              onPageChanged: (page) {
                _pageNotifier.value = page;
              },
            ),
      bottomNavigationBar: widget.hasAudio
          ? _ContentAudioStrip(
              tracks: widget.audioTracks,
              contentId: _audioId,
              titleAr: widget.titleAr,
              titleEl: widget.titleEl,
              coverUrl: widget.coverUrl,
            )
          : null,
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgDeep      = BrightnessColors.bgDeep(brightness);
    final gold        = BrightnessColors.gold(brightness);
    final goldBorder  = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return AppBar(
      backgroundColor: bgDeep,
      elevation: 2,
      leadingWidth: 56,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: gold),
        onPressed: () => Navigator.pop(context),
        tooltip: 'رجوع',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.titleAr,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              color: textPrimary,
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
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        // Bookmark the current page — only meaningful once we know which
        // content item and page we're on.
        if (widget.contentId.isNotEmpty && _totalPages > 0)
          IconButton(
            key: const ValueKey('generic_pdf_bookmark_page_btn'),
            icon: Icon(Icons.bookmark_add_outlined, color: gold, size: 22),
            tooltip: 'إضافة إشارة مرجعية لهذه الصفحة',
            onPressed: () async {
              final page = _pdfCtrl?.currentPage ?? _pageNotifier.value;
              try {
                final added = await sl<BookmarkRepository>()
                    .toggleContentBookmark(
                  contentId: widget.contentId,
                  category:  widget.category,
                  titleAr:   widget.titleAr,
                  titleEl:   widget.titleEl,
                  coverUrl:  widget.coverUrl,
                  pdfUrl:    widget.url,
                  page:      page,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(added
                      ? 'تم حفظ إشارة مرجعية للصفحة $page'
                      : 'تم حذف إشارة الصفحة $page'),
                  duration: const Duration(seconds: 2),
                ));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('تعذّر حفظ الإشارة المرجعية: $e'),
                  backgroundColor: Colors.red.shade800,
                ));
              }
            },
          ),
        // Show video icon only when there IS a PDF — otherwise the video
        // is already displayed inline in the body.
        if (widget.hasVideo && widget.url.isNotEmpty)
          IconButton(
            key: const ValueKey('generic_pdf_video_btn'),
            icon: Icon(Icons.videocam_outlined, color: gold, size: 22),
            tooltip: 'مشاهدة الفيديو',
            onPressed: () => showVideoSheet(
              context,
              widget.videoUrl,
              titleAr: widget.titleAr,
            ),
          ),
        if (_totalPages > 0 && _pdfCtrl != null)
          IconButton(
            key: const ValueKey('generic_pdf_gotopage_btn'),
            icon: Icon(Icons.numbers, color: gold, size: 22),
            tooltip: 'الانتقال إلى صفحة',
            onPressed: () => showPdfGoToPageDialog(
              context,
              controller: _pdfCtrl!,
              totalPages: _totalPages,
              currentPage: _pdfCtrl!.currentPage,
            ),
          ),
        if (_totalPages > 0 && _pdfCtrl != null)
          IconButton(
            key: const ValueKey('generic_pdf_search_btn'),
            icon: Icon(Icons.search, color: gold, size: 22),
            tooltip: 'بحث في الملف',
            onPressed: () => showPdfSearchSheet(
              context,
              controller: _pdfCtrl!,
            ),
          ),
      ],
      // Page prev/next + tap-to-jump indicator — part of the same AppBar
      // (via PreferredSize) rather than a separate floating bar; falls back
      // to a plain divider once page count isn't known yet.
      bottom: _totalPages > 0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: ValueListenableBuilder<int>(
                valueListenable: _pageNotifier,
                builder: (ctx, page, _) =>
                    _buildPageNavRow(bgDeep, gold, goldBorder, page),
              ),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: goldBorder),
            ),
    );
  }

  // ── Page navigation row ──────────────────────────────────────────────────────

  Widget _buildPageNavRow(
    Color bgDeep,
    Color gold,
    Color goldBorder,
    int page,
  ) {
    return Container(
      color: bgDeep,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageNavButton(
            icon: Icons.chevron_left,
            enabled: _pdfCtrl != null && page > 1,
            onPressed: () => _pdfCtrl?.previousPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _pdfCtrl == null
                ? null
                : () => showPdfGoToPageDialog(
                      context,
                      controller: _pdfCtrl!,
                      totalPages: _totalPages,
                      currentPage: page,
                    ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: bgDeep.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: goldBorder, width: 0.5),
              ),
              child: Text(
                'صفحة $page / $_totalPages',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: gold,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _PageNavButton(
            icon: Icons.chevron_right,
            enabled: _pdfCtrl != null && page < _totalPages,
            onPressed: () => _pdfCtrl?.nextPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

}

// ── Inline video view ─────────────────────────────────────────────────────────
// Shown when there is no PDF but a video URL exists.
// Displays the video player directly in the body (no bottom-sheet modal).

class _InlineVideoView extends StatelessWidget {
  const _InlineVideoView({required this.videoUrl, required this.titleAr});
  final String videoUrl;
  final String titleAr;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ColoredBox(
      color: BrightnessColors.bgPrimary(brightness),
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: EkklisiaVideoPlayer(url: videoUrl, titleAr: titleAr),
        ),
      ),
    );
  }
}

// ── No-PDF placeholder ────────────────────────────────────────────────────────
// Shown when the content has neither a PDF nor a video URL.

class _NoPdfPlaceholder extends StatelessWidget {
  const _NoPdfPlaceholder({required this.hasVideo});
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
        color: BrightnessColors.bgPrimary(brightness),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasVideo
                    ? Icons.play_circle_outline_rounded
                    : Icons.picture_as_pdf_outlined,
                size: 64,
                color: BrightnessColors.gold(brightness).withOpacity(0.4),
              ),
              const SizedBox(height: 20),
              Text(
                hasVideo
                    ? 'اضغط على أيقونة الفيديو أعلاه لمشاهدة المحتوى'
                    : 'لا يوجد ملف PDF لهذا المحتوى',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: BrightnessColors.textSecondary(brightness),
                  fontSize: 16,
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
    final brightness = Theme.of(context).brightness;
    final bgDeep     = BrightnessColors.bgDeep(brightness);
    final gold       = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: bgDeep.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? goldBorder : goldBorder.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? gold : gold.withOpacity(0.3),
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
    this.titleEl = '',
    this.coverUrl = '',
  });

  final List<ContentAudioTrack> tracks;
  final String contentId;
  final String titleAr;
  final String titleEl;
  final String coverUrl;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    // Auto-advance to the next track now lives on AudioPlayerCubit itself
    // (see _advanceIfQueued) — not here — so it isn't lost if this widget
    // gets unmounted (user navigates away) or the screen locks. A plain
    // BlocBuilder is all this strip needs now.
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, state) {
        final cubit     = context.read<AudioPlayerCubit>();
        final isCurrent = state.currentItem?.extras?['contentId'] == contentId;
        final isPlaying = isCurrent && state.isPlaying;

        final brightness = Theme.of(context).brightness;
        final gold       = BrightnessColors.gold(brightness);
        final bgMid      = BrightnessColors.bgMid(brightness);

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: bgMid,
            border: Border(
              top: BorderSide(color: gold.withOpacity(0.4), width: 0.8),
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
    final l = context.l10n;
    final isGreek = !l.isAr;
    // Prefer the currently-playing item's own (bilingual) title when this
    // content is the one actually playing, so a specific track's label
    // (e.g. "Deacon") shows instead of the generic content title — same
    // language-aware fallback pattern as AudioPlayerBar.
    final displayTitle = isCurrent
        ? ((isGreek
                ? (state.currentItem?.extras?['titleEl'] as String?)
                : (state.currentItem?.extras?['titleAr'] as String?)) ??
            (isGreek && titleEl.isNotEmpty ? titleEl : titleAr))
        : (isGreek && titleEl.isNotEmpty ? titleEl : titleAr);
    final trackCountLabel = tracks.length == 1
        ? (isGreek ? 'κομμάτι' : 'تسجيل')
        : (isGreek ? 'κομμάτια' : 'تسجيلات');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress micro-bar (only when this content is playing)
        if (isCurrent && state.duration > Duration.zero)
          LinearProgressIndicator(
            value: state.progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(
                BrightnessColors.gold(Theme.of(context).brightness)),
            minHeight: 2,
          ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              // Cover thumbnail (falls back to a cross glyph)
              Builder(builder: (ctx) {
                final gold = BrightnessColors.gold(Theme.of(ctx).brightness);
                final bgDeep = BrightnessColors.bgDeep(Theme.of(ctx).brightness);
                Widget cross() => Center(
                      child: Text('✦',
                          style: TextStyle(
                              color: gold.withOpacity(0.6), fontSize: 16)),
                    );
                return Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: bgDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gold.withOpacity(0.4), width: 0.8),
                  ),
                  child: coverUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedImage(
                            url: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: cross(),
                          ),
                        )
                      : cross(),
                );
              }),
              const SizedBox(width: 10),

              // Title + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayTitle,
                      textDirection: l.dir,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: l.bodyFont,
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
                            '${tracks.length} $trackCountLabel',
                            style: TextStyle(
                              fontFamily: l.bodyFont,
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

              // Browse all tracks — always reachable, not just when idle
              if (tracks.length > 1)
                _StripBtn(
                  icon: Icons.queue_music,
                  onTap: () => _openPicker(context, cubit),
                ),

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
      await cubit.play(_mediaItem(tracks.first), playlist: _playlist);
      return;
    }
    await _openPicker(context, cubit);
  }

  /// Opens the full, scrollable track list — reachable at any time (not just
  /// before playback starts) via the queue icon in the strip.
  Future<void> _openPicker(BuildContext context, AudioPlayerCubit cubit) async {
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ContentTrackPickerSheet(
          tracks:    tracks,
          contentId: contentId,
          titleAr:   titleAr,
          titleEl:   titleEl,
          coverUrl:  coverUrl,
        ),
      ),
    );
  }

  MediaItem _mediaItem(ContentAudioTrack track) => _contentMediaItem(
    track: track,
    contentId: contentId,
    titleAr: titleAr,
    titleEl: titleEl,
    coverUrl: coverUrl,
  );

  /// Full ordered list — passed to `cubit.play(..., playlist:)` so the
  /// cubit can auto-advance through the rest regardless of which track the
  /// user actually started from.
  List<MediaItem> get _playlist => _contentPlaylist(
    tracks: tracks,
    contentId: contentId,
    titleAr: titleAr,
    titleEl: titleEl,
    coverUrl: coverUrl,
  );
}

// ── Strip sub-widgets ─────────────────────────────────────────────────────────

class _StripBtn extends StatelessWidget {
  const _StripBtn({required this.icon, required this.onTap});
  final IconData      icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gold = BrightnessColors.gold(Theme.of(context).brightness);
    return IconButton(
      icon: Icon(icon, size: 22,
          color: onTap != null ? gold : gold.withOpacity(0.3)),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
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
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gold   = BrightnessColors.gold(brightness);
    final maroon = BrightnessColors.maroon(brightness);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: maroon,
          shape: BoxShape.circle,
          border: Border.all(color: gold.withOpacity(0.5), width: 0.8),
        ),
        child: Center(
          child: state.isBuffering && isCurrent
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: gold, strokeWidth: 2),
                )
              : Icon(
                  isCurrent && state.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: gold, size: 22,
                ),
        ),
      ),
    );
  }
}

// ── Content Track Picker Sheet ────────────────────────────────────────────────

class _ContentTrackPickerSheet extends StatelessWidget {
  const _ContentTrackPickerSheet({
    required this.tracks,
    required this.contentId,
    required this.titleAr,
    this.titleEl = '',
    this.coverUrl = '',
  });

  final List<ContentAudioTrack> tracks;
  final String contentId;
  final String titleAr;
  final String titleEl;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sheetBg = BrightnessColors.bgDeep(brightness);
    final l = context.l10n;
    final isGreek = !l.isAr;
    final displayTitle = isGreek && titleEl.isNotEmpty ? titleEl : titleAr;

    return ConstrainedBox(
      // Cap the sheet's height so a long track list scrolls instead of
      // overflowing off the top of the screen.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: BrightnessColors.gold(brightness).withValues(alpha: 0.2), width: 0.8),
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
                    color: BrightnessColors.gold(brightness).withValues(alpha: 0.35),
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
                      color: BrightnessColors.maroon(brightness).withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: BrightnessColors.gold(brightness).withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: coverUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedImage(
                              url: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: Icon(Icons.headphones,
                                  color: BrightnessColors.gold(brightness), size: 18),
                            ),
                          )
                        : Icon(Icons.headphones,
                            color: BrightnessColors.gold(brightness), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.pickTrack,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text(displayTitle,
                          textDirection: l.dir,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: l.bodyFont,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          )),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Divider(color: BrightnessColors.gold(brightness).withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 14),

                // Track cards — scrollable so long lists never overflow
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(children: [
                      ...tracks.asMap().entries.map((e) {
                        final idx   = e.key;
                        final track = e.value;
                        final accents = [BrightnessColors.gold(brightness), const Color(0xFF7EB8C9)];
                        final accent  = accents[idx % accents.length];

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            final playlist = _contentPlaylist(
                              tracks: tracks,
                              contentId: contentId,
                              titleAr: titleAr,
                              titleEl: titleEl,
                              coverUrl: coverUrl,
                            );
                            // Picking a track mid-list still keeps auto-
                            // advance going for whatever comes after it.
                            context.read<AudioPlayerCubit>().play(
                                  playlist[idx],
                                  playlist: playlist,
                                );
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
                              track.labelFor(isGreek ? 'el' : 'ar').isNotEmpty
                                  ? track.labelFor(isGreek ? 'el' : 'ar')
                                  : '${l.trackLabelFallback} ${idx + 1}',
                              textDirection: l.dir,
                              style: TextStyle(
                                fontFamily:  l.bodyFont,
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
            ],
          ),
        ),
      ),
    ),
  );
  }
}
