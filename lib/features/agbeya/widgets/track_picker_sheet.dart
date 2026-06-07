// lib/features/agbeya/widgets/track_picker_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet shown when an Agbeya hour has multiple audio tracks.
// The user picks one track; the sheet closes and playback begins immediately.
//
// Usage:
//   showModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.transparent,
//     builder: (_) => BlocProvider.value(
//       value: cubit,
//       child: TrackPickerSheet(hour: hour),
//     ),
//   );
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/agbeya_model.dart';
import '../cubit/audio_player_cubit.dart';

const _kNavy    = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold    = Color(0xFFC9A84C);

class TrackPickerSheet extends StatelessWidget {
  const TrackPickerSheet({super.key, required this.hour});
  final AgbeyaHour hour;

  @override
  Widget build(BuildContext context) {
    final tracks = hour.effectiveTracks;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final sheetBg =
        isDark ? const Color(0xFF0D1825) : const Color(0xFF152236);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _kGold.withValues(alpha: 0.2), width: 0.8),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ───────────────────────────────────────────────
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // ── Header ────────────────────────────────────────────────────
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
                  const Text(
                    'Choose Recording',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    hour.titleAr,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 16),

              Divider(color: _kGold.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 14),

              // ── Track cards ───────────────────────────────────────────────
              ...tracks.asMap().entries.map((e) {
                final idx   = e.key;
                final track = e.value;
                return _TrackCard(
                  track: track,
                  index: idx,
                  hour: hour,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<AudioPlayerCubit>().play(
                          _mediaItemFor(track),
                        );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  MediaItem _mediaItemFor(AgbeyaAudioTrack track) => MediaItem(
        id: track.url,
        title: track.labelAr.isNotEmpty ? track.labelAr : hour.titleAr,
        album: hour.titleAr,
        artUri: hour.coverUrl.isNotEmpty ? Uri.parse(hour.coverUrl) : null,
        duration: track.durationSeconds > 0
            ? Duration(seconds: track.durationSeconds)
            : null,
        extras: {'hourId': hour.id, 'trackIndex': track.url},
      );
}

// ── Track card ────────────────────────────────────────────────────────────────

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.index,
    required this.hour,
    required this.onTap,
  });

  final AgbeyaAudioTrack track;
  final int              index;
  final AgbeyaHour       hour;
  final VoidCallback     onTap;

  // Accent colours cycling for each track index
  static const _accents = [_kGold, Color(0xFF7EB8C9)];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
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
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
              ),
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
                      : 'تسجيل ${index + 1}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (track.formattedDuration.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.timer_outlined,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 12),
                      const SizedBox(width: 4),
                      Text(
                        track.formattedDuration,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
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
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow, color: accent, size: 22),
          ),
        ]),
      ),
    );
  }
}

// ── Helper: build MediaItem + show picker or play directly ────────────────────
// Call this from any screen instead of calling cubit.play() directly.

Future<void> playOrPickTrack(
  BuildContext context,
  AgbeyaHour hour,
  AudioPlayerCubit cubit,
) async {
  final tracks = hour.effectiveTracks;
  if (tracks.isEmpty) return;

  if (tracks.length == 1) {
    // Single track — play immediately, no picker needed
    await cubit.play(_singleMediaItem(tracks.first, hour));
    return;
  }

  // Multiple tracks — show picker
  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: TrackPickerSheet(hour: hour),
    ),
  );
}

MediaItem _singleMediaItem(AgbeyaAudioTrack track, AgbeyaHour hour) =>
    MediaItem(
      id: track.url,
      title: track.labelAr.isNotEmpty ? track.labelAr : hour.titleAr,
      album: hour.titleAr,
      artUri: hour.coverUrl.isNotEmpty ? Uri.parse(hour.coverUrl) : null,
      duration: track.durationSeconds > 0
          ? Duration(seconds: track.durationSeconds)
          : null,
      extras: {'hourId': hour.id},
    );
