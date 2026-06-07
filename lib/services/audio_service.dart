// lib/services/audio_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// AgbeyaAudioHandler — background audio playback for the Coptic Agbeya.
//
// Uses the audio_service + just_audio stack:
//   • audio_service  → Android foreground service + iOS audio session
//                      lock-screen controls, notification media controls
//   • just_audio     → actual audio decoding + streaming from Cloudinary URLs
//
// Initialization (in main.dart, BEFORE runApp):
//   final handler = await AudioService.init<AgbeyaAudioHandler>(
//     builder: () => AgbeyaAudioHandler(),
//     config: const AudioServiceConfig(
//       androidNotificationChannelId: 'com.ekklisia.audio',
//       androidNotificationChannelName: 'Ekklisia',
//       androidNotificationOngoing: true,
//       androidStopForegroundOnPause: true,
//     ),
//   );
//   sl.registerSingleton<AgbeyaAudioHandler>(handler);
//
// REQUIRED native configuration — see bottom of this file.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AgbeyaAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  AgbeyaAudioHandler() {
    // Forward just_audio events → audio_service playback state stream.
    // listen() is used instead of pipe() so that playbackState.add() calls
    // in super.stop() don't conflict with an active addStream lock.
    _player.playbackEventStream
        .map(_transformEvent)
        .listen(playbackState.add);

    // Keep mediaItem in sync with queue index
    _player.currentIndexStream.listen((index) {
      final q = queue.value;
      if (index != null && index < q.length) {
        mediaItem.add(q[index]);
      }
    });

    // Auto-stop on completion so the notification clears
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) stop();
    });
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Load [item] from its Cloudinary URL (item.id) and begin playback.
  Future<void> playFromUrl(MediaItem item) async {
    mediaItem.add(item);
    queue.add([item]);
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(item.id)),
        preload: true,
      );
      await _player.play();
    } catch (e) {
      debugPrint('[AgbeyaAudio] Failed to load ${item.id}: $e');
      rethrow;
    }
  }

  // ── BaseAudioHandler overrides ──────────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> fastForward() =>
      seek(_player.position + const Duration(seconds: 30));

  @override
  Future<void> rewind() => seek(_player.position - const Duration(seconds: 10));

  // ── Raw accessors (used by AudioPlayerCubit) ───────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  bool get playing => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  double get speed => _player.speed;

  // ── Internal ────────────────────────────────────────────────────────────────

  PlaybackState _transformEvent(PlaybackEvent event) {
    final isPlaying = _player.playing;
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: isPlaying,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUIRED NATIVE CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────
//
// ── Android ── android/app/src/main/AndroidManifest.xml ─────────────────────
//
//  Inside <manifest>:
//    <uses-permission android:name="android.permission.WAKE_LOCK"/>
//    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
//    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
//
//  Inside <application>:
//    <service
//        android:name="com.ryanheise.audioservice.AudioService"
//        android:foregroundServiceType="mediaPlayback"
//        android:exported="true">
//      <intent-filter>
//        <action android:name="android.media.browse.MediaBrowserService" />
//      </intent-filter>
//    </service>
//    <receiver
//        android:name="com.ryanheise.audioservice.MediaButtonReceiver"
//        android:exported="true">
//      <intent-filter>
//        <action android:name="android.intent.action.MEDIA_BUTTON" />
//      </intent-filter>
//    </receiver>
//
// ── iOS ── ios/Runner/Info.plist ─────────────────────────────────────────────
//
//    <key>UIBackgroundModes</key>
//    <array>
//      <string>audio</string>
//    </array>
//
// ─────────────────────────────────────────────────────────────────────────────
