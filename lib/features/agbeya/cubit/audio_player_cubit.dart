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
      final completed = ps == ProcessingState.completed;
      emit(state.copyWith(
        isBuffering:
            ps == ProcessingState.buffering || ps == ProcessingState.loading,
        isCompleted: completed,
      ));
      // Lives here (the app-wide singleton cubit), NOT in a screen widget —
      // so a Holy Mass's audio parts (or an Agbeya intro handing off to the
      // chosen hour track) keep auto-advancing even if the user navigates
      // to a different screen, or the device screen locks. AgbeyaAudioHandler
      // runs inside audio_service's Android foreground service / iOS
      // background-audio session, which keeps this cubit's isolate alive
      // through both of those, so this listener still fires.
      //
      // Stopping vs. advancing is one decision made right here — the
      // handler itself must NOT also stop on completion, or that stop can
      // race this advance and kill the next track right as it starts.
      if (completed && !_advanceIfQueued()) {
        _handler.stop();
      }
    });
  }

  /// Plays the next item in [AudioPlayerState.playlist] after the one that
  /// just finished, if there is one, and returns whether it did. No-op
  /// (returns false) for a standalone track (empty playlist) or if the
  /// finished item was already the last one.
  bool _advanceIfQueued() {
    final playlist = state.playlist;
    final current = state.currentItem;
    if (playlist.length < 2 || current == null) return false;
    final idx = playlist.indexWhere((m) => m.id == current.id);
    if (idx == -1 || idx + 1 >= playlist.length) return false;
    play(playlist[idx + 1], playlist: playlist);
    return true;
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Load and play an audio track.
  ///
  /// [playlist] is the full ordered list [item] belongs to (e.g. every part
  /// of a Holy Mass) — pass it so completion auto-advances to the next
  /// entry; omit it (default: none) for a standalone track, which also
  /// correctly clears out whatever playlist was previously queued.
  Future<void> play(MediaItem item, {List<MediaItem> playlist = const []}) async {
    // Optimistically update UI before buffering starts
    emit(state.copyWith(
      currentItem: item,
      playlist: playlist,
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
