// lib/shared/widgets/audio_player_bar.dart
// ─────────────────────────────────────────────────────────────────────────────
// Persistent mini audio player bar.
// Displayed above the bottom navigation bar whenever a track is loaded.
//
// Shown/hidden in home_screen.dart:
//   BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
//     builder: (ctx, state) => state.hasTrack
//         ? const AudioPlayerBar()
//         : const SizedBox.shrink(),
//   )
//
// Tapping opens FullAudioPlayerSheet.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/app_l10n.dart';
import '../../data/models/agbeya_model.dart';
import '../../features/agbeya/cubit/audio_player_cubit.dart';
import '../../features/agbeya/cubit/audio_player_state.dart';
import '../../features/agbeya/widgets/full_audio_player_sheet.dart';
import 'cached_image.dart';

const _kNavy = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold = Color(0xFFC9A84C);

class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111E30) : _kNavy;

    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, state) {
        if (!state.hasTrack) return const SizedBox.shrink();

        final cubit = context.read<AudioPlayerCubit>();
        final item = state.currentItem!;
        final l = context.l10n;
        final isGreek = !l.isAr;
        final extras = item.extras;
        // Bilingual title/album live in extras (see track_picker_sheet.dart /
        // generic_pdf_viewer_screen.dart / full_audio_player_sheet.dart) so
        // this bar reacts to an app-language change immediately instead of
        // being stuck with whatever language was active when play() was
        // called. Falls back to the plain MediaItem fields for any track
        // played through a path that doesn't set them yet.
        final displayTitle = (isGreek
                ? (extras?['titleEl'] as String?)
                : (extras?['titleAr'] as String?)) ??
            item.title;
        final rawAlbum = (isGreek
                ? (extras?['albumEl'] as String?)
                : (extras?['albumAr'] as String?)) ??
            item.album;

        return GestureDetector(
          onTap: () => _openFullPlayer(context, cubit, item),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(
                  color: _kGold.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Thin progress bar ─────────────────────────────────────
                if (state.duration > Duration.zero)
                  LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                    minHeight: 2,
                  ),

                // ── Content row ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      // Cover thumbnail
                      _CoverThumb(artUri: item.artUri),
                      const SizedBox(width: 12),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayTitle,
                              textDirection: l.dir,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: l.bodyFont,
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (rawAlbum != null && rawAlbum.isNotEmpty)
                              Text(
                                rawAlbum,
                                textDirection: l.dir,
                                style: TextStyle(
                                  fontFamily: l.bodyFont,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Rewind
                      _MiniBtn(
                        icon: Icons.replay_10,
                        onTap: cubit.skipBackward,
                        enabled: true,
                      ),

                      // Play / Pause
                      _PlayPauseBtn(state: state, cubit: cubit),

                      // Forward
                      _MiniBtn(
                        icon: Icons.forward_30,
                        onTap: cubit.skipForward,
                        enabled: true,
                      ),

                      // Close / stop
                      _MiniBtn(
                        icon: Icons.close,
                        onTap: cubit.stop,
                        enabled: true,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFullPlayer(
    BuildContext context,
    AudioPlayerCubit cubit,
    MediaItem item,
  ) {
    // We need an AgbeyaHour stub to pass to FullAudioPlayerSheet.
    // Extract what we know from the MediaItem. Audio played from outside
    // the Agbeya hours (e.g. Holy Mass / other PDF content) is tagged with
    // 'contentId' instead of 'hourId' — fall back to that so the stub's id
    // still matches what's actually playing (see the isCurrent check in
    // FullAudioPlayerSheet).
    final hourId = item.extras?['hourId'] as String?;
    final contentId = item.extras?['contentId'] as String?;
    final isAgbeyaHour = hourId != null && hourId.isNotEmpty;

    final stub = AgbeyaHour(
      id: hourId ?? contentId ?? '',
      hourNumber: 0,
      sortOrder: 0,
      titleAr: item.extras?['titleAr'] as String? ?? item.title,
      titleEl: item.extras?['titleEl'] as String? ?? '',
      audioUrl: item.id,
      coverUrl: item.artUri?.toString() ?? '',
      durationSeconds: item.duration?.inSeconds ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: FullAudioPlayerSheet(
          hour: stub,
          // Real Agbeya hours keep the default l.agbeya brand eyebrow;
          // anything else shows its own album (e.g. the Mass/content title)
          // instead, in both languages, so the label matches what's
          // actually playing and stays correct if the user switches
          // app language while the sheet is open.
          sectionLabelAr: isAgbeyaHour
              ? null
              : (item.extras?['albumAr'] as String? ?? item.album),
          sectionLabelEl:
              isAgbeyaHour ? null : (item.extras?['albumEl'] as String?),
        ),
      ),
    );
  }
}

// ── Cover thumbnail ───────────────────────────────────────────────────────────

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.artUri});
  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: CachedImage(
          url: artUri?.toString() ?? '',
          fit: BoxFit.cover,
          errorWidget: _crossIcon(),
        ),
      ),
    );
  }

  Widget _crossIcon() => Center(
    child: Text(
      '✦',
      style: TextStyle(color: _kGold.withValues(alpha: 0.7), fontSize: 18),
    ),
  );
}

// ── Play / pause button ───────────────────────────────────────────────────────

class _PlayPauseBtn extends StatelessWidget {
  const _PlayPauseBtn({required this.state, required this.cubit});
  final AudioPlayerState state;
  final AudioPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cubit.togglePlayPause,
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
          child: state.isBuffering
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: _kGold,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: _kGold,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

// ── Mini icon button ──────────────────────────────────────────────────────────

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.color,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(
      icon,
      color: enabled
          ? (color ?? _kGold.withValues(alpha: 0.85))
          : _kGold.withValues(alpha: 0.25),
      size: 22,
    ),
    onPressed: enabled ? onTap : null,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  );
}
