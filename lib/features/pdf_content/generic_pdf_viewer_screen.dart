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

import '../../core/theme/brightness_colors.dart';
import '../../shared/widgets/cached_pdf_viewer.dart';
import '../../shared/widgets/video_player_widget.dart';

import '../../data/models/pdf_content_model.dart';
import '../agbeya/cubit/audio_player_cubit.dart';
import '../agbeya/cubit/audio_player_state.dart';

class GenericPdfViewerScreen extends StatefulWidget {
  const GenericPdfViewerScreen({
    super.key,
    required this.url,
    required this.titleAr,
    this.titleEl = '',
    this.audioTracks = const [],
    this.contentId   = '',
    this.videoUrl    = '',
  });

  final String url;
  final String titleAr;
  final String titleEl;

  /// Optional audio tracks. When non-empty, a persistent strip appears.
  final List<ContentAudioTrack> audioTracks;

  /// Unique ID used to detect whether this content is currently playing.
  /// Use PdfContent.id when available.
  final String contentId;

  /// Optional video URL. When non-empty, a videocam icon appears in the AppBar.
  final String videoUrl;

  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;

  @override
  State<GenericPdfViewerScreen> createState() => _GenericPdfViewerScreenState();
}

class _GenericPdfViewerScreenState extends State<GenericPdfViewerScreen> {
  // Set by CachedPdfViewer once the document is open
  PdfScrollController? _pdfCtrl;

  bool _showToolbar = true;
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(1);
  int _totalPages = 0;

  @override
  void dispose() {
    // _pdfCtrl lifecycle owned by CachedPdfViewer
    _pageNotifier.dispose();
    super.dispose();
  }

  void _onBodyTap(TapUpDetails details) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final x = details.globalPosition.dx;
    final y = details.globalPosition.dy;
    if (x > w * 0.25 && x < w * 0.75 && y > h * 0.25 && y < h * 0.75) {
      setState(() => _showToolbar = !_showToolbar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final stripH = widget.hasAudio ? _ContentAudioStrip.height : 0.0;

    return Scaffold(
      backgroundColor: BrightnessColors.bgPrimary(brightness),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _onBodyTap,
        child: Stack(
          children: [
            // ── PDF Viewer (or inline video / placeholder) ───────────────
            Positioned(
              top: 0, left: 0, right: 0, bottom: stripH,
              child: widget.url.isEmpty
                  ? (widget.hasVideo
                      ? _InlineVideoView(
                          videoUrl: widget.videoUrl,
                          titleAr:  widget.titleAr,
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
                      },
                      onPageChanged: (page) {
                        _pageNotifier.value = page;
                      },
                    ),
            ),

            // ── AppBar — always visible so video button is always reachable
            AnimatedOpacity(
              opacity: _showToolbar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showToolbar,
                child: _buildAppBar(context),
              ),
            ),

            // ── Page indicator (only once pages are known) ───────────────
            if (_totalPages > 0)
              Positioned(
                left: 0, right: 0, bottom: stripH,
                child: AnimatedOpacity(
                  opacity: _showToolbar ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showToolbar,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _pageNotifier,
                      builder: (ctx, page, _) =>
                          _buildPageIndicator(ctx, page),
                    ),
                  ),
                ),
              ),

            // ── Persistent audio strip ───────────────────────────────────
            if (widget.hasAudio)
              Positioned(
                left: 0, right: 0, bottom: 0,
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
    final brightness  = Theme.of(context).brightness;
    final bgDeep      = BrightnessColors.bgDeep(brightness);
    final gold        = BrightnessColors.gold(brightness);
    final goldBorder  = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final topPadding  = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgDeep,
            bgDeep.withOpacity(0.95),
            bgDeep.withOpacity(0),
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
              color: bgDeep.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: goldBorder, width: 0.5),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 15, color: gold),
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
          // Show video icon only when there IS a PDF — otherwise the video
          // is already displayed inline in the body.
          if (widget.hasVideo && widget.url.isNotEmpty)
            IconButton(
              icon: Icon(Icons.videocam_outlined, color: gold, size: 22),
              tooltip: 'مشاهدة الفيديو',
              onPressed: () => showVideoSheet(
                context,
                widget.videoUrl,
                titleAr: widget.titleAr,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: goldBorder),
        ),
      ),
    );
  }

  // ── Page Indicator ───────────────────────────────────────────────────────

  Widget _buildPageIndicator(BuildContext context, int page) {
    final brightness    = Theme.of(context).brightness;
    final bgDeep        = BrightnessColors.bgDeep(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            bgDeep,
            bgDeep.withOpacity(0.9),
            bgDeep.withOpacity(0),
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: bgDeep.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: goldBorder, width: 0.5),
            ),
            child: Text(
              'صفحة $page / $_totalPages',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: textSecondary,
                fontSize: 13,
                height: 1.2,
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
              // Cross decoration
              Builder(builder: (ctx) {
                final gold = BrightnessColors.gold(Theme.of(ctx).brightness);
                final bgDeep = BrightnessColors.bgDeep(Theme.of(ctx).brightness);
                return Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: bgDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gold.withOpacity(0.4), width: 0.8),
                  ),
                  child: Center(
                    child: Text('✦',
                        style: TextStyle(color: gold.withOpacity(0.6), fontSize: 16)),
                  ),
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
  });

  final List<ContentAudioTrack> tracks;
  final String contentId;
  final String titleAr;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sheetBg = BrightnessColors.bgDeep(brightness);

    return Container(
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
                  child: Icon(Icons.headphones,
                      color: BrightnessColors.gold(brightness), size: 18),
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
              Divider(color: BrightnessColors.gold(brightness).withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 14),

              // Track cards
              ...tracks.asMap().entries.map((e) {
                final idx   = e.key;
                final track = e.value;
                final accents = [BrightnessColors.gold(brightness), const Color(0xFF7EB8C9)];
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
