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

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../data/models/agbeya_intro_model.dart';
import '../../../data/models/agbeya_model.dart';
import '../../../data/repositories/agbeya_intro_repository.dart';
import '../../../features/settings/cubit/settings_cubit.dart';
import '../../../services/settings_service.dart';
import '../cubit/audio_player_cubit.dart';

const _kNavy    = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold    = Color(0xFFC9A84C);

class TrackPickerSheet extends StatelessWidget {
  const TrackPickerSheet({super.key, required this.hour});
  final AgbeyaHour hour;

  @override
  Widget build(BuildContext context) {
    final groups = hour.effectiveGroups;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final sheetBg =
        isDark ? const Color(0xFF0D1825) : const Color(0xFF152236);
    final l = context.l10n;
    final isGreek = !l.isAr;

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
                  Text(
                    l.pickTrack,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    hour.titleFor(isGreek ? 'el' : 'ar'),
                    textDirection: l.dir,
                    style: TextStyle(
                      fontFamily: l.bodyFont,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 16),

              Divider(color: _kGold.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 14),

              // ── Track cards (grouped into named sub-sections) ───────────
              ..._buildGroupedCards(context, groups, isGreek),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders each group's tracks under an optional section header (hidden
  /// for an untitled/legacy group), numbering tracks continuously across
  /// every group so the badge reflects overall play order.
  List<Widget> _buildGroupedCards(
    BuildContext context,
    List<AgbeyaTrackGroup> groups,
    bool isGreek,
  ) {
    final widgets = <Widget>[];
    var runningIndex = 0;
    for (final group in groups) {
      final title = group.titleFor(isGreek ? 'el' : 'ar');
      if (title.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(children: [
            Icon(Icons.label_outline,
                size: 13, color: _kGold.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: _kGold.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ));
      }
      for (final track in group.tracks) {
        final idx = runningIndex;
        widgets.add(_TrackCard(
          track: track,
          index: idx,
          hour: hour,
          onTap: () async {
            // Capture everything context-dependent BEFORE the async gap and
            // the pop below, so we never touch a stale/unmounted context.
            final cubit = context.read<AudioPlayerCubit>();
            AgbeyaIntroModel intro = AgbeyaIntroModel.empty;
            try {
              intro = await sl<AgbeyaIntroRepository>().fetch();
            } catch (_) {
              // No intro configured / fetch failed — fall back to playing
              // the chosen track directly.
            }
            if (context.mounted) Navigator.pop(context);
            final chosenItem = _mediaItemFor(track);
            // The intro's language matches the TRACK's own recorded
            // language (track.lang), not the app's current UI language —
            // an hour can mix Arabic- and Greek-language recordings.
            final introUrl = intro.urlFor(track.lang);
            if (introUrl.isNotEmpty) {
              final introItem = _introMediaItem(intro, track.isGreek, hour);
              cubit.play(introItem, playlist: [introItem, chosenItem]);
            } else {
              cubit.play(chosenItem);
            }
          },
        ));
        runningIndex++;
      }
    }
    return widgets;
  }

  /// Stores BOTH languages in `extras` (not just whichever is selected right
  /// now) so every "now playing" display (mini bar, full player sheet, audio
  /// strips) can pick the right one live off [AppL10n] — including if the
  /// user switches app language mid-playback — instead of the title being
  /// frozen in whatever language was active when play() was called.
  MediaItem _mediaItemFor(AgbeyaAudioTrack track) => MediaItem(
        id: track.url,
        title: track.labelAr.isNotEmpty ? track.labelAr : hour.titleAr,
        album: hour.titleAr,
        artUri: hour.coverUrl.isNotEmpty ? Uri.parse(hour.coverUrl) : null,
        duration: track.durationSeconds > 0
            ? Duration(seconds: track.durationSeconds)
            : null,
        extras: {
          'hourId': hour.id,
          'trackIndex': track.url,
          'titleAr': track.labelFor('ar').isNotEmpty
              ? track.labelFor('ar')
              : hour.titleAr,
          'titleEl': track.labelFor('el').isNotEmpty
              ? track.labelFor('el')
              : hour.titleFor('el'),
          'albumAr': hour.titleAr,
          'albumEl': hour.titleFor('el'),
        },
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
    final l = context.l10n;
    final isGreek = !l.isAr;
    final label = track.labelFor(isGreek ? 'el' : 'ar');

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
                  label.isNotEmpty
                      ? label
                      : '${l.trackLabelFallback} ${index + 1}',
                  textDirection: l.dir,
                  style: TextStyle(
                    fontFamily: l.bodyFont,
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
    // Single track — play immediately (after the shared intro, if any is
    // configured for the TRACK's own recorded language), no picker needed.
    final track = tracks.first;
    AgbeyaIntroModel intro = AgbeyaIntroModel.empty;
    try {
      intro = await sl<AgbeyaIntroRepository>().fetch();
    } catch (_) {
      // No intro configured / fetch failed — fall back below.
    }
    final chosenItem = _singleMediaItem(track, hour);
    final introUrl = intro.urlFor(track.lang);
    if (introUrl.isNotEmpty) {
      final introItem = _introMediaItem(intro, track.isGreek, hour);
      await cubit.play(introItem, playlist: [introItem, chosenItem]);
    } else {
      await cubit.play(chosenItem);
    }
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
      extras: {
        'hourId': hour.id,
        'titleAr':
            track.labelFor('ar').isNotEmpty ? track.labelFor('ar') : hour.titleAr,
        'titleEl':
            track.labelFor('el').isNotEmpty ? track.labelFor('el') : hour.titleFor('el'),
        'albumAr': hour.titleAr,
        'albumEl': hour.titleFor('el'),
      },
    );

// ── Shared intro (plays before whichever track was chosen) ────────────────────
// One MediaItem per language pair, built fresh from whatever's saved in
// config/agbeya_intro. Its id is the intro's own URL, distinct from any
// track's URL, so AudioPlayerCubit._advanceIfQueued can find it in the
// 2-item playlist and correctly hand off to the chosen track once it ends.
MediaItem _introMediaItem(AgbeyaIntroModel intro, bool isGreek, AgbeyaHour hour) {
  final url = intro.urlFor(isGreek ? 'el' : 'ar');
  final durationSecs = intro.durationFor(isGreek ? 'el' : 'ar');
  return MediaItem(
    id: url,
    title: isGreek ? 'Εισαγωγή κάθε Ώρας' : 'مقدمة كل ساعة',
    album: hour.titleAr,
    artUri: hour.coverUrl.isNotEmpty ? Uri.parse(hour.coverUrl) : null,
    duration: durationSecs > 0 ? Duration(seconds: durationSecs) : null,
    extras: {
      'hourId': hour.id,
      'titleAr': 'مقدمة كل ساعة',
      'titleEl': 'Εισαγωγή κάθε Ώρας',
      'albumAr': hour.titleAr,
      'albumEl': hour.titleFor('el'),
    },
  );
}
