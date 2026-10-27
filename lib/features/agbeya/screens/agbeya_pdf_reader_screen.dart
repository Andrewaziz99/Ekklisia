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

import '../../../core/l10n/app_l10n.dart';
import '../../../core/theme/colors.dart';
import '../../../data/models/agbeya_model.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/cached_pdf_viewer.dart';
import '../../../shared/widgets/pdf_nav_tools.dart';
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
      // A real AppBar (not a Positioned/Stack overlay) reserves its own
      // layout space, so it never paints over the PDF page content — same
      // for the audio strip, now docked via bottomNavigationBar instead of
      // floating over the last page.
      appBar: _buildAppBar(context),
      body: CachedPdfViewer(
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
                content: Text(context.l10nOnce.pdfLoadError),
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
      bottomNavigationBar: _AudioStrip(hour: widget.hour),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final l = context.l10n;
    final isGreek = !l.isAr;
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
        widget.hour.titleFor(isGreek ? 'el' : 'ar'),
        textDirection: l.dir,
        style: TextStyle(
          fontFamily: l.bodyFont,
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
            key: const ValueKey('agbeya_pdf_video_btn'),
            tooltip: l.video,
            icon: const Icon(Icons.videocam_outlined,
                color: EkklisiaColors.gold),
            onPressed: () => showVideoSheet(
              context,
              widget.hour.videoUrl,
              titleAr: widget.hour.titleFor(isGreek ? 'el' : 'ar'),
              isGreek: isGreek,
            ),
          ),
        if (_totalPages > 0)
          IconButton(
            key: const ValueKey('agbeya_pdf_gotopage_btn'),
            tooltip: l.goToPageTooltip,
            icon: const Icon(Icons.numbers, color: EkklisiaColors.gold),
            onPressed: () => showPdfGoToPageDialog(
              context,
              controller: _pdfCtrl!,
              totalPages: _totalPages,
              currentPage: _pdfCtrl!.currentPage,
              isGreek: isGreek,
            ),
          ),
        if (_totalPages > 0)
          IconButton(
            key: const ValueKey('agbeya_pdf_search_btn'),
            tooltip: l.search,
            icon: const Icon(Icons.search, color: EkklisiaColors.gold),
            onPressed: () => showPdfSearchSheet(
              context,
              controller: _pdfCtrl!,
              isGreek: isGreek,
            ),
          ),
        IconButton(
          key: const ValueKey('agbeya_pdf_mode_btn'),
          tooltip: l.readingModeTooltip,
          icon: Icon(_modeIcon, color: EkklisiaColors.gold),
          onPressed: () => setState(() {
            _mode = _ReadingMode
                .values[(_mode.index + 1) % _ReadingMode.values.length];
          }),
        ),
      ],
      // Page prev/next + tap-to-jump indicator — part of the same AppBar
      // (via PreferredSize) rather than a second floating bar.
      bottom: _totalPages > 0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: ValueListenableBuilder<int>(
                valueListenable: _pageNotifier,
                builder: (_, page, __) => _buildPageBar(page, isGreek),
              ),
            )
          : null,
    );
  }

  // ── Page navigation row ──────────────────────────────────────────────────────

  Widget _buildPageBar(int page, bool isGreek) {
    return Container(
      color: EkklisiaColors.bgDeep,
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
            child: Center(
              child: GestureDetector(
                onTap: _pdfCtrl == null
                    ? null
                    : () => showPdfGoToPageDialog(
                          context,
                          controller: _pdfCtrl!,
                          totalPages: _totalPages,
                          currentPage: page,
                          isGreek: isGreek,
                        ),
                child: Text(
                  '$page / $_totalPages',
                  style: const TextStyle(
                    color: EkklisiaColors.gold,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: EkklisiaColors.goldBorder,
                  ),
                ),
              ),
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
    final l = context.l10n;
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
                  ? _audioRow(context, l, cubit, state, isCurrent, isPlaying)
                  : _noAudioRow(l),
            ),
          ),
        );
      },
    );
  }

  Widget _audioRow(
    BuildContext context,
    AppL10n l,
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
                        hour.titleFor(l.isAr ? 'ar' : 'el'),
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
                        Text(
                          l.agbeya,
                          textDirection: l.dir,
                          style: TextStyle(
                            fontFamily: l.bodyFont,
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

  Widget _noAudioRow(AppL10n l) => Center(
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
          l.noAudioForHour,
          textDirection: l.dir,
          style: TextStyle(
            fontFamily: l.bodyFont,
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
