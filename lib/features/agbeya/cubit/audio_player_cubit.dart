// lib/features/agbeya/cubit/audio_player_cubit.dart
// ─────────────────────────────────────────────────────────────────────────────
// Global singleton Cubit that bridges AgbeyaAudioHandler (background service)
// to the Flutter UI layer.
//
// Provided at the root in app.dart so any widget tree can access it:
//   context.read<AudioPlayerCubit>().play(item)
//   BlocBuilder<AudioPlayerCubit, AudioPlayerState>(...)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../services/audio_service.dart';
import 'audio_player_state.dart';

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  AudioPlayerCubit(this._handler) : super(const AudioPlayerState()) {
    _subscribeToHandler();
  }

  final AgbeyaAudioHandler _handler;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _processSub;

  // ── Handler stream subscriptions ────────────────────────────────────────────

  void _subscribeToHandler() {
    _playingSub = _handler.playingStream.listen(
      (playing) => emit(state.copyWith(isPlaying: playing)),
    );

    _posSub = _handler.positionStream.listen(
      (pos) => emit(state.copyWith(position: pos)),
    );

    _durSub = _handler.durationStream.listen(
      (dur) => emit(state.copyWith(duration: dur ?? Duration.zero)),
    );

    _processSub = _handler.processingStateStream.listen((ps) {
      emit(state.copyWith(
        isBuffering:
            ps == ProcessingState.buffering || ps == ProcessingState.loading,
        isCompleted: ps == ProcessingState.completed,
      ));
    });
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Load and play an audio track. Creates a [MediaItem] from the Agbeya hour.
  Future<void> play(MediaItem item) async {
    // Optimistically update UI before buffering starts
    emit(state.copyWith(
      currentItem: item,
      isPlaying: false,
      isBuffering: true,
      isCompleted: false,
      position: Duration.zero,
      duration: Duration.zero,
    ));
    await _handler.playFromUrl(item);
  }

  Future<void> resume() => _handler.play();
  Future<void> pause() => _handler.pause();

  Future<void> togglePlayPause() async {
    if (_handler.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> seekTo(Duration position) => _handler.seek(position);

  /// Jump forward 30 seconds.
  Future<void> skipForward() => _handler.fastForward();

  /// Jump back 10 seconds.
  Future<void> skipBackward() => _handler.rewind();

  Future<void> setSpeed(double speed) async {
    await _handler.setSpeed(speed);
    emit(state.copyWith(speed: speed));
  }

  Future<void> stop() async {
    await _handler.stop();
    emit(const AudioPlayerState()); // reset to initial
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _processSub?.cancel();
    return super.close();
  }
}
