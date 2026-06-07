// lib/features/agbeya/widgets/full_audio_player_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Full-screen audio player modal sheet.
// Opened by tapping the mini player bar or the inline audio strip.
//
// Contains:
//   • Cover image / cross art
//   • Track title + hour name
//   • Seek slider with position labels
//   • Rewind 10s | Play/Pause | Forward 30s
//   • Playback speed selector (0.75 / 1.0 / 1.25 / 1.5×)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/agbeya_model.dart';
import '../cubit/audio_player_cubit.dart';
import '../cubit/audio_player_state.dart';

const _kNavy = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold = Color(0xFFC9A84C);

class FullAudioPlayerSheet extends StatelessWidget {
  const FullAudioPlayerSheet({super.key, required this.hour});
  final AgbeyaHour hour;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0E1A2E) : const Color(0xFF1B2A4A);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _kGold.withValues(alpha: 0.25), width: 0.8),
        ),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          child: BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
            builder: (context, state) {
              final cubit = context.read<AudioPlayerCubit>();
              final isCurrent = state.currentItem?.extras?['hourId'] == hour.id;

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    // ── Drag handle ─────────────────────────────────────
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Cover image ──────────────────────────────────────
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: hour.coverUrl.isNotEmpty
                            ? Image.network(
                                hour.coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _crossArt(),
                              )
                            : _crossArt(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Title ────────────────────────────────────────────
                    Text(
                      'الأجبية',
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color: _kGold.withValues(alpha: 0.7),
                        fontSize: 13,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hour.titleAr,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Seek slider ──────────────────────────────────────
                    _SeekSlider(
                      state: state,
                      isCurrent: isCurrent,
                      cubit: cubit,
                    ),
                    const SizedBox(height: 28),

                    // ── Main controls ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Rewind 10s
                        _ControlBtn(
                          icon: Icons.replay_10,
                          size: 36,
                          onTap: isCurrent ? cubit.skipBackward : null,
                          color: isCurrent
                              ? _kGold
                              : _kGold.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 24),

                        // Play / Pause
                        GestureDetector(
                          onTap: () async {
                            if (!isCurrent) {
                              await _playHour(cubit);
                            } else {
                              await cubit.togglePlayPause();
                            }
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _kCrimson,
                              shape: BoxShape.circle,
                              border: Border.all(color: _kGold, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _kCrimson.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: state.isBuffering && isCurrent
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        color: _kGold,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Icon(
                                      isCurrent && state.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: _kGold,
                                      size: 38,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Forward 30s
                        _ControlBtn(
                          icon: Icons.forward_30,
                          size: 36,
                          onTap: isCurrent ? cubit.skipForward : null,
                          color: isCurrent
                              ? _kGold
                              : _kGold.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Speed selector ───────────────────────────────────
                    _SpeedSelector(
                      currentSpeed: state.speed,
                      onSpeedChanged: cubit.setSpeed,
                    ),
                    const SizedBox(height: 20),

                    // ── Stop button ──────────────────────────────────────
                    TextButton.icon(
                      onPressed: () {
                        cubit.stop();
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      label: const Text(
                        'إيقاف',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _playHour(AudioPlayerCubit cubit) async {
    await cubit.play(
      MediaItem(
        id: hour.audioUrl,
        title: hour.titleAr,
        album: 'الأجبية',
        artUri: hour.coverUrl.isNotEmpty ? Uri.parse(hour.coverUrl) : null,
        duration: hour.durationSeconds > 0
            ? Duration(seconds: hour.durationSeconds)
            : null,
        extras: {'hourId': hour.id},
      ),
    );
  }

  Widget _crossArt() => Container(
    color: _kNavy,
    child: Center(
      child: Text(
        '✦',
        style: TextStyle(color: _kGold.withValues(alpha: 0.6), fontSize: 80),
      ),
    ),
  );
}

// ── Seek slider ───────────────────────────────────────────────────────────────

class _SeekSlider extends StatelessWidget {
  const _SeekSlider({
    required this.state,
    required this.isCurrent,
    required this.cubit,
  });

  final AudioPlayerState state;
  final bool isCurrent;
  final AudioPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final pos = isCurrent ? state.position : Duration.zero;
    final dur = isCurrent ? state.duration : Duration.zero;
    final progress = isCurrent ? state.progress : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _kGold,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: _kGold,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayColor: _kGold.withValues(alpha: 0.15),
            trackHeight: 3,
          ),
          child: Slider(
            value: progress,
            onChanged: dur > Duration.zero
                ? (v) => cubit.seekTo(
                    Duration(milliseconds: (v * dur.inMilliseconds).round()),
                  )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.positionLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              Text(
                state.durationLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Speed selector ────────────────────────────────────────────────────────────

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  final double currentSpeed;
  final Future<void> Function(double) onSpeedChanged;

  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _speeds.map((speed) {
        final isSelected = (currentSpeed - speed).abs() < 0.01;
        return GestureDetector(
          onTap: () => onSpeedChanged(speed),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kGold.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _kGold : _kGold.withValues(alpha: 0.25),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Text(
              '${speed}x',
              style: TextStyle(
                color: isSelected
                    ? _kGold
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Control button ────────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: color, size: size),
  );
}
