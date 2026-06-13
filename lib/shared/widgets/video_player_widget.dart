// lib/shared/widgets/video_player_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// EkklisiaVideoPlayer — two-path video playback with full debug logging.
//
//   YouTube URLs  → youtube_player_iframe (IFrame API, no navigator hijack)
//   All others    → in-app video_player + chewie (raw URL)
//                   with "Open in browser" fallback if initialisation fails
//
// To watch logs, run: flutter run  then filter logcat/console for "EkklisiaVideo"
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer' as dev;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theme/colors.dart';

// ── Debug logger ──────────────────────────────────────────────────────────────

void _log(String msg) => dev.log(msg, name: 'EkklisiaVideo');

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _isYouTube(String url) =>
    url.contains('youtube.com') || url.contains('youtu.be');

/// Extract the 11-character YouTube video ID from any YouTube URL.
String? _youtubeId(String url) {
  // youtu.be/ID
  final m1 = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
  if (m1 != null) return m1.group(1);

  // ?v=ID or &v=ID
  final m2 = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
  if (m2 != null) return m2.group(1);

  // /embed/ID
  final m3 = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
  if (m3 != null) return m3.group(1);

  return null;
}

// ── Public API ────────────────────────────────────────────────────────────────

void showVideoSheet(BuildContext context, String url, {String? titleAr}) {
  _log('showVideoSheet called — url="$url"');
  if (url.isEmpty) {
    _log('showVideoSheet: url is empty, aborting');
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _VideoSheet(url: url, titleAr: titleAr),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// INLINE PLAYER
// ═════════════════════════════════════════════════════════════════════════════

class EkklisiaVideoPlayer extends StatelessWidget {
  const EkklisiaVideoPlayer({super.key, required this.url, this.titleAr});
  final String  url;
  final String? titleAr;

  @override
  Widget build(BuildContext context) {
    _log('EkklisiaVideoPlayer.build — url="$url"');
    if (url.isEmpty) return const SizedBox.shrink();
    return _isYouTube(url)
        ? _YouTubeCard(url: url)
        : _DirectPlayer(url: url);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET WRAPPER
// ═════════════════════════════════════════════════════════════════════════════

class _VideoSheet extends StatelessWidget {
  const _VideoSheet({required this.url, this.titleAr});
  final String  url;
  final String? titleAr;

  @override
  Widget build(BuildContext context) {
    final width  = MediaQuery.sizeOf(context).width;
    final videoH = width * 9.0 / 16.0;

    _log('_VideoSheet.build — url="$url" isYouTube=${_isYouTube(url)}');

    return Material(
      color: Colors.transparent,
      child: Container(
        height: videoH + 56,
        decoration: const BoxDecoration(
          color: Color(0xFF08111C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: (titleAr?.isNotEmpty == true)
                          ? Text(
                              titleAr!,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Scheherazade',
                                color: EkklisiaColors.goldLight,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: EkklisiaColors.textSecondary, size: 20),
                      onPressed: () {
                        _log('_VideoSheet: close tapped');
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Player
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18)),
                child: _isYouTube(url)
                    ? _YouTubeCard(url: url)
                    : _DirectPlayer(url: url),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// YOUTUBE CARD — in-app playback via youtube_player_iframe
//
// Uses the YouTube IFrame API directly — no navigator hijacking, no go_router
// conflicts. The controller is properly closed on dispose.
// ═════════════════════════════════════════════════════════════════════════════

class _YouTubeCard extends StatefulWidget {
  const _YouTubeCard({required this.url});
  final String url;

  @override
  State<_YouTubeCard> createState() => _YouTubeCardState();
}

class _YouTubeCardState extends State<_YouTubeCard> {
  YoutubePlayerController? _controller;
  String? _id;

  @override
  void initState() {
    super.initState();
    _id = _youtubeId(widget.url);
    _log('_YouTubeCard.initState — url="${widget.url}" id="$_id"');

    if (_id != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: _id!,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          playsInline: true,
          showVideoAnnotations: false,
          strictRelatedVideos: true,
          mute: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _log('_YouTubeCard.dispose — id="$_id"');
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log('_YouTubeCard.build — id="$_id"');

    if (_id == null || _controller == null) {
      return const _ErrView(message: 'رابط YouTube غير صالح');
    }

    return YoutubePlayer(controller: _controller!);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIRECT VIDEO PLAYER  (Cloudinary / MP4 / any direct URL)
// ═════════════════════════════════════════════════════════════════════════════

class _DirectPlayer extends StatefulWidget {
  const _DirectPlayer({required this.url});
  final String url;

  @override
  State<_DirectPlayer> createState() => _DirectPlayerState();
}

class _DirectPlayerState extends State<_DirectPlayer> {
  VideoPlayerController? _vpc;
  ChewieController?      _cc;

  // State machine: loading | ready | failed
  bool   _loading = true;
  bool   _failed  = false;
  String _failMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _log('_DirectPlayer.dispose — url="${widget.url}"');
    _cc?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _log('_DirectPlayer._load START — url="${widget.url}"');

    // Tear down previous attempt
    _cc?.dispose();  _cc  = null;
    await _vpc?.dispose(); _vpc = null;

    if (mounted) {
      setState(() { _loading = true; _failed = false; _failMsg = ''; });
    }

    VideoPlayerController? vpc;
    try {
      _log('_DirectPlayer._load — creating VideoPlayerController');
      vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url));

      _log('_DirectPlayer._load — calling initialize()…');
      await vpc.initialize();
      _log('_DirectPlayer._load — initialize() complete'
          ' duration=${vpc.value.duration}'
          ' size=${vpc.value.size}'
          ' isInitialized=${vpc.value.isInitialized}');

      if (!mounted) {
        _log('_DirectPlayer._load — widget unmounted after init, disposing');
        await vpc.dispose();
        return;
      }

      _vpc = vpc;
      _cc  = ChewieController(
        videoPlayerController: vpc,
        autoPlay:        true,
        looping:         false,
        allowFullScreen: true,
        allowMuting:     true,
        showControls:    true,
        materialProgressColors: ChewieProgressColors(
          playedColor:     EkklisiaColors.gold,
          handleColor:     EkklisiaColors.goldLight,
          bufferedColor:   const Color(0x40C9A84C),
          backgroundColor: const Color(0xFF1B2A4A),
        ),
        errorBuilder: (_, msg) {
          _log('_DirectPlayer: chewie errorBuilder — $msg');
          return _ErrView(
            message: msg,
            onAction: ('فتح في المتصفح', _openExternal),
          );
        },
      );

      if (mounted) setState(() => _loading = false);
      _log('_DirectPlayer._load SUCCESS');
    } catch (e, st) {
      _log('_DirectPlayer._load FAILED — error: $e\nstacktrace: $st');
      await vpc?.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed  = true;
          _failMsg = e.toString();
        });
      }
    }
  }

  Future<void> _openExternal() async {
    _log('_DirectPlayer._openExternal — url="${widget.url}"');
    try {
      final ok = await launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      );
      _log('_DirectPlayer._openExternal — launchUrl result=$ok');
    } catch (e) {
      _log('_DirectPlayer._openExternal — ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _log('_DirectPlayer.build — loading=$_loading failed=$_failed');

    if (_loading) {
      return const ColoredBox(
        color: Color(0xFF08111C),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(EkklisiaColors.gold),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_failed || _cc == null) {
      return _ErrView(
        message: 'تعذّر تحميل الفيديو\n$_failMsg',
        onAction: ('فتح في المتصفح', _openExternal),
        onRetry:  _load,
      );
    }

    return Chewie(controller: _cc!);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _ErrView extends StatelessWidget {
  const _ErrView({
    required this.message,
    this.onAction,
    this.onRetry,
  });
  final String message;
  final (String label, VoidCallback fn)? onAction;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF08111C),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_outlined,
                    color: EkklisiaColors.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: EkklisiaColors.textSecondary, fontSize: 12),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 14),
                  _Btn(label: onAction!.$1, onTap: onAction!.$2),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  _Btn(label: 'إعادة المحاولة', onTap: onRetry!),
                ],
              ],
            ),
          ),
        ),
      );
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: EkklisiaColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: EkklisiaColors.gold.withOpacity(0.4), width: 0.5),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: EkklisiaColors.gold, fontSize: 13)),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// VIDEO WATCH BUTTON — reusable chip on content screens
// ═════════════════════════════════════════════════════════════════════════════

class VideoWatchButton extends StatelessWidget {
  const VideoWatchButton({
    super.key,
    required this.url,
    this.titleAr,
    this.isGreek = false,
  });
  final String  url;
  final String? titleAr;
  final bool    isGreek;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();
    final label = isGreek ? 'Βίντεο' : 'مشاهدة الفيديو';
    return GestureDetector(
      onTap: () => showVideoSheet(context, url, titleAr: titleAr),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1B2A4A), Color(0xFF0D1B2A)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EkklisiaColors.goldBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline,
                color: EkklisiaColors.gold, size: 18),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: isGreek ? 'GFSDidot' : 'Scheherazade',
                color: EkklisiaColors.goldLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
