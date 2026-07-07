// lib/features/agbeya/screens/agbeya_pdf_reader_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 1 reader: PDF viewer (pdfx) + persistent audio strip.
//
// Layout:
//   • Full-screen pdfx PDF viewer — platform-native bitmap rendering, no lag
//   • Auto-starts the hour's audio on open (if not already playing it)
//   • Persistent audio strip pinned at the bottom — always visible
//   • Tap the audio strip → opens FullAudioPlayerSheet for full controls
//   • Navigating away (back) leaves audio running in the background
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/agbeya_model.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/cached_pdf_viewer.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../cubit/audio_player_cubit.dart';
import '../cubit/audio_player_state.dart';
import '../widgets/full_audio_player_sheet.dart';
import '../widgets/track_picker_sheet.dart';

const _kNavy = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold = Color(0xFFC9A84C);

class AgbeyaPdfReaderScreen extends StatefulWidget {
  const AgbeyaPdfReaderScreen({super.key, required this.hour});
  final AgbeyaHour hour;

  @override
  State<AgbeyaPdfReaderScreen> createState() => _AgbeyaPdfReaderScreenState();
}

class _AgbeyaPdfReaderScreenState extends State<AgbeyaPdfReaderScreen> {
  // Set by CachedPdfViewer once document is open
  PdfScrollController? _pdfCtrl;

  // Page tracking — ValueNotifier avoids full-screen rebuilds on every scroll
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(1);

  bool _showToolbar = true;
  int _totalPages = 0;
  _ReadingMode _mode = _ReadingMode.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartAudio());
  }

  @override
  void dispose() {
    // _pdfCtrl lifecycle owned by CachedPdfViewer
    _pageNotifier.dispose();
    super.dispose();
  }

  Future<void> _autoStartAudio() async {
    if (!mounted || !widget.hour.hasAudio) return;
    final cubit = context.read<AudioPlayerCubit>();
    final isCurrent =
        cubit.state.currentItem?.extras?['hourId'] == widget.hour.id;
    if (!isCurrent) {
      await playOrPickTrack(context, widget.hour, cubit);
    }
  }

  Color get _bgColor {
    switch (_mode) {
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
            // ── PDF Viewer ──────────────────────────────────────────────────
            Positioned.fill(
              child: Padding(
                // Leave room for the persistent audio strip at the bottom
                padding: const EdgeInsets.only(bottom: _AudioStrip.height),
                child: CachedPdfViewer(
                  url: widget.hour.pdfUrl,
                  scrollDirection: Axis.vertical,
                  pageSnapping: false,
                  onControllerReady: (ctrl) {
                    _pdfCtrl = ctrl;
                  },
                  onDocumentLoaded: (totalPages) {
                    setState(() => _totalPages = totalPages);
                  },
                  onDocumentLoadFailed: (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error.toString()),
                          backgroundColor: EkklisiaColors.maroon,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  onPageChanged: (page) {
                    _pageNotifier.value = page;
                  },
                ),
              ),
            ),

            // ── Top toolbar (auto-hides on tap) ─────────────────────────────
            AnimatedSlide(
              offset: _showToolbar ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _buildTopBar(context),
            ),

            // ── Page nav bar (auto-hides, sits above audio strip) ───────────
            if (_totalPages > 0)
              Positioned(
                bottom: _AudioStrip.height,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  offset: _showToolbar ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pageNotifier,
                    builder: (_, page, __) => _buildPageBar(page),
                  ),
                ),
              ),

            // ── Persistent audio strip ──────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _AudioStrip(hour: widget.hour),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EkklisiaColors.bgDeep, EkklisiaColors.bgDeep.withOpacity(0)],
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
          widget.hour.titleAr,
          style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.goldLight,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.hour.hasVideo)
            IconButton(
              tooltip: 'مشاهدة الفيديو',
              icon: const Icon(Icons.videocam_outlined,
                  color: EkklisiaColors.gold),
              onPressed: () => showVideoSheet(
                context,
                widget.hour.videoUrl,
                titleAr: widget.hour.titleAr,
              ),
            ),
          IconButton(
            tooltip: 'وضع القراءة',
            icon: Icon(_modeIcon, color: EkklisiaColors.gold),
            onPressed: () => setState(() {
              _mode = _ReadingMode
                  .values[(_mode.index + 1) % _ReadingMode.values.length];
            }),
          ),
        ],
      ),
    );
  }

  // ── Page navigation bar ────────────────────────────────────────────────────

  Widget _buildPageBar(int page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [EkklisiaColors.bgDeep, EkklisiaColors.bgDeep.withOpacity(0)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: EkklisiaColors.gold),
            onPressed: (_pdfCtrl != null && page > 1)
                ? () => _pdfCtrl!.previousPage(
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
                  '$page / $_totalPages',
                  style: const TextStyle(
                    color: EkklisiaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
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
                    max: _totalPages.toDouble(),
                    // Visual-only during drag — jumpToPage only on release
                    onChanged: (_) {},
                    onChangeEnd: (v) => _pdfCtrl?.jumpToPage(v.round()),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: EkklisiaColors.gold),
            onPressed: (_pdfCtrl != null && page < _totalPages)
                ? () => _pdfCtrl!.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
        ],
      ),
    );
  }

  IconData get _modeIcon {
    switch (_mode) {
      case _ReadingMode.dark:
        return Icons.dark_mode_outlined;
      case _ReadingMode.parchment:
        return Icons.light_mode_outlined;
      case _ReadingMode.night:
        return Icons.nightlight_outlined;
    }
  }
}

// ── Audio Strip ────────────────────────────────────────────────────────────────

class _AudioStrip extends StatelessWidget {
  const _AudioStrip({required this.hour});
  final AgbeyaHour hour;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, state) {
        final cubit = context.read<AudioPlayerCubit>();
        final isCurrent = state.currentItem?.extras?['hourId'] == hour.id;
        final isPlaying = isCurrent && state.isPlaying;
        final hasAudio = hour.hasAudio;

        return GestureDetector(
          onTap: hasAudio ? () => _openFullPlayer(context, cubit) : null,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: _kNavy,
              border: Border(
                top: BorderSide(
                  color: _kGold.withValues(alpha: 0.4),
                  width: 0.8,
                ),
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
              child: hasAudio
                  ? _audioRow(context, cubit, state, isCurrent, isPlaying)
                  : _noAudioRow(),
            ),
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
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _kGold.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: hour.coverUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedImage(
                            url: hour.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: _cross(),
                          ),
                        )
                      : _cross(),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hour.titleAr,
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
                        Text(
                          'الأجبية',
                          style: TextStyle(
                            fontFamily: 'Scheherazade',
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                _StripBtn(
                  icon: Icons.replay_10,
                  onTap: isCurrent ? cubit.skipBackward : null,
                ),

                _PlayPauseBtn(
                  state: state,
                  isCurrent: isCurrent,
                  onTap: () async {
                    if (!isCurrent) {
                      await playOrPickTrack(context, hour, cubit);
                    } else {
                      await cubit.togglePlayPause();
                    }
                  },
                ),

                _StripBtn(
                  icon: Icons.forward_30,
                  onTap: isCurrent ? cubit.skipForward : null,
                ),

                const Icon(Icons.expand_less, color: _kGold, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _noAudioRow() => Center(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_off_outlined,
          color: Colors.white.withValues(alpha: 0.3),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'لا يوجد صوت لهذه الساعة',
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  Widget _cross() => Center(
    child: Text(
      '✦',
      style: TextStyle(color: _kGold.withValues(alpha: 0.6), fontSize: 16),
    ),
  );

  void _openFullPlayer(BuildContext context, AudioPlayerCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: FullAudioPlayerSheet(hour: hour),
      ),
    );
  }
}

// ── Strip sub-widgets ─────────────────────────────────────────────────────────

class _PlayPauseBtn extends StatelessWidget {
  const _PlayPauseBtn({
    required this.state,
    required this.isCurrent,
    required this.onTap,
  });
  final AudioPlayerState state;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _kCrimson,
        shape: BoxShape.circle,
        border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Center(
        child: state.isBuffering && isCurrent
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: _kGold, strokeWidth: 2),
              )
            : Icon(
                isCurrent && state.isPlaying ? Icons.pause : Icons.play_arrow,
                color: _kGold,
                size: 22,
              ),
      ),
    ),
  );
}

class _StripBtn extends StatelessWidget {
  const _StripBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(
      icon,
      color: onTap != null
          ? _kGold.withValues(alpha: 0.85)
          : _kGold.withValues(alpha: 0.25),
      size: 22,
    ),
    onPressed: onTap,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  );
}

enum _ReadingMode { dark, parchment, night }
