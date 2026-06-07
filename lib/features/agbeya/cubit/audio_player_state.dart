// lib/features/agbeya/cubit/audio_player_state.dart
import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

class AudioPlayerState extends Equatable {
  final MediaItem? currentItem;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final double speed;

  const AudioPlayerState({
    this.currentItem,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
  });

  /// True when a track is loaded (even if paused).
  bool get hasTrack => currentItem != null;

  /// 0.0 → 1.0 scrub progress.
  double get progress {
    if (duration == Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// e.g. "23:47"
  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get positionLabel => _fmt(position);
  String get durationLabel => _fmt(duration);

  AudioPlayerState copyWith({
    MediaItem? currentItem,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    double? speed,
  }) =>
      AudioPlayerState(
        currentItem: currentItem ?? this.currentItem,
        isPlaying: isPlaying ?? this.isPlaying,
        isBuffering: isBuffering ?? this.isBuffering,
        isCompleted: isCompleted ?? this.isCompleted,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
      );

  @override
  List<Object?> get props => [
        currentItem?.id,
        isPlaying,
        isBuffering,
        isCompleted,
        position,
        duration,
        speed,
      ];
}
