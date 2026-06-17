// lib/features/electronic_library/video_player_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// In-app video/audio player for Electronic Library items.
//
// Routing:
//   YouTube URLs  → YoutubePlayerScaffold (youtube_player_iframe)
//   Direct URLs   → VideoPlayerController + ChewieController (video_player + chewie)
//   Audio items   → same Chewie path (video_player handles audio-only files too)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../data/models/elib_item_model.dart';

const _kGold   = Color(0xFFC9A84C);
const _kNavy   = Color(0xFF1B2A4A);

// ── Entry point ───────────────────────────────────────────────────────────────

class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({
    super.key,
    required this.item,
    required this.isGreek,
  });

  final ElibItemModel item;
  final bool isGreek;

  bool get _isYouTube =>
      item.mediaUrl.contains('youtube.com') ||
      item.mediaUrl.contains('youtu.be');

  String? get _youTubeId {
    final uri = Uri.tryParse(item.mediaUrl);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }

  String get _title =>
      (isGreek && item.titleEl.isNotEmpty) ? item.titleEl : item.titleAr;

  @override
  Widget build(BuildContext context) {
    if (_isYouTube && _youTubeId != null) {
      return _YoutubePlayerScreen(
        videoId: _youTubeId!,
        title: _title,
        isGreek: isGreek,
      );
    }
    return _DirectMediaScreen(
      url: item.mediaUrl,
      title: _title,
      isGreek: isGreek,
      isAudio: item.mediaType == ElibMediaType.audio,
    );
  }
}

// ── YouTube player ────────────────────────────────────────────────────────────

class _YoutubePlayerScreen extends StatefulWidget {
  const _YoutubePlayerScreen({
    required this.videoId,
    required this.title,
    required this.isGreek,
  });

  final String videoId;
  final String title;
  final bool isGreek;

  @override
  State<_YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<_YoutubePlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        showVideoAnnotations: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (ctx, player) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            widget.title,
            style: TextStyle(
              fontFamily: widget.isGreek ? null : 'Scheherazade',
              fontSize: widget.isGreek ? 16 : 20,
            ),
          ),
        ),
        body: Column(
          children: [
            // Video player — fixed 16:9 at the top
            AspectRatio(
              aspectRatio: 16 / 9,
              child: player,
            ),
            // Extra space below in case user scrolls up info later
            const Expanded(child: ColoredBox(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

// ── Direct URL player (Cloudinary video / audio) ──────────────────────────────

class _DirectMediaScreen extends StatefulWidget {
  const _DirectMediaScreen({
    required this.url,
    required this.title,
    required this.isGreek,
    required this.isAudio,
  });

  final String url;
  final String title;
  final bool isGreek;
  final bool isAudio;

  @override
  State<_DirectMediaScreen> createState() => _DirectMediaScreenState();
}

class _DirectMediaScreenState extends State<_DirectMediaScreen> {
  VideoPlayerController? _vpc;
  ChewieController? _chewieCtrl;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await vpc.initialize();
      if (!mounted) {
        vpc.dispose();
        return;
      }
      final chewieCtrl = ChewieController(
        videoPlayerController: vpc,
        autoPlay: true,
        looping: false,
        aspectRatio: widget.isAudio ? null : vpc.value.aspectRatio,
        // For audio, hide the video area and show audio-friendly UI
        showControls: true,
      );
      setState(() {
        _vpc = vpc;
        _chewieCtrl = chewieCtrl;
        _initialized = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: widget.isGreek ? null : 'Scheherazade',
            fontSize: widget.isGreek ? 15 : 19,
          ),
        ),
      ),
      body: Center(
        child: _error != null
            ? _ErrorView(message: _error!)
            : !_initialized
                ? const CircularProgressIndicator(color: _kGold)
                : widget.isAudio
                    ? _AudioView(chewieCtrl: _chewieCtrl!)
                    : Chewie(controller: _chewieCtrl!),
      ),
    );
  }
}

// ── Audio view (music note + chewie controls below) ───────────────────────────

class _AudioView extends StatelessWidget {
  const _AudioView({required this.chewieCtrl});
  final ChewieController chewieCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: _kNavy,
            borderRadius: BorderRadius.circular(70),
            border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 2),
          ),
          child: const Icon(Icons.audiotrack, color: _kGold, size: 64),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 80,
          child: Chewie(controller: chewieCtrl),
        ),
      ],
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(
            'Failed to load media',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
