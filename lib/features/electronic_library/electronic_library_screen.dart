// lib/features/electronic_library/electronic_library_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// المكتبة الالكترونية — Electronic Library (user-facing).
// Shows published elib sections; tapping a section expands its items.
// Each item card has a play button that opens the video/audio via url_launcher.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/elib_item_model.dart';
import '../../data/models/elib_section_model.dart';
import '../../data/repositories/elib_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import 'video_player_screen.dart';

const _kNavy    = Color(0xFF1B2A4A);
const _kGold    = Color(0xFFC9A84C);
const _kCrimson = Color(0xFF6B1A1A);

class ElectronicLibraryScreen extends StatefulWidget {
  const ElectronicLibraryScreen({super.key});

  @override
  State<ElectronicLibraryScreen> createState() =>
      _ElectronicLibraryScreenState();
}

class _ElectronicLibraryScreenState extends State<ElectronicLibraryScreen> {
  final _repo = sl<ElibRepository>();
  List<ElibSectionModel> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.watchSections().listen(
      (sections) => setState(() { _sections = sections; _loading = false; }),
      onError: (_) => setState(() => _loading = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.l10n;
    final isGreek = !l.isAr;

    return Scaffold(
      backgroundColor: BrightnessColors.bgDeep(brightness),
      body: SafeArea(
        child: Column(
          children: [
            _Header(isGreek: isGreek),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                      color: BrightnessColors.gold(brightness), strokeWidth: 2))
                  : _sections.isEmpty
                      ? _EmptyState(isGreek: isGreek)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _sections.length,
                          itemBuilder: (ctx, i) => _SectionExpansion(
                            section: _sections[i],
                            repo: _repo,
                            isGreek: isGreek,
                            brightness: brightness,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              context.l10n.elib,
              textDirection: context.l10n.dir,
              style: TextStyle(
                fontFamily: context.l10n.bodyFont,
                color: _kGold,
                fontSize: isGreek ? 16 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section expansion tile ────────────────────────────────────────────────────

class _SectionExpansion extends StatelessWidget {
  const _SectionExpansion({
    required this.section,
    required this.repo,
    required this.isGreek,
    required this.brightness,
  });

  final ElibSectionModel section;
  final ElibRepository repo;
  final bool isGreek;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final title = (isGreek && section.titleEl.isNotEmpty)
        ? section.titleEl
        : section.titleAr;
    final bgCard = brightness == Brightness.light
        ? Colors.white
        : BrightnessColors.bgMid(brightness);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.25), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGold.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.video_library_outlined,
                color: _kGold, size: 18),
          ),
          title: Text(
            title,
            textDirection:
                isGreek ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              color: brightness == Brightness.light
                  ? const Color(0xFF1B2A4A)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: isGreek ? 14 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconColor: _kGold,
          collapsedIconColor: _kGold.withValues(alpha: 0.5),
          children: [
            StreamBuilder<List<ElibItemModel>>(
              stream: repo.watchPublishedBySection(section.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: _kGold, strokeWidth: 2),
                    ),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      context.l10n.noContent,
                      style: TextStyle(
                        fontFamily: context.l10n.bodyFont,
                        color: Colors.white38,
                        fontSize: isGreek ? 12 : 14,
                      ),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((item) => _ItemTile(
                            item: item,
                            isGreek: isGreek,
                            brightness: brightness,
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.isGreek,
    required this.brightness,
  });

  final ElibItemModel item;
  final bool isGreek;
  final Brightness brightness;

  bool get _isYouTube =>
      item.mediaUrl.contains('youtube.com') ||
      item.mediaUrl.contains('youtu.be');

  bool get _isVideo => item.mediaType == ElibMediaType.video;
  bool get _isAudio => item.mediaType == ElibMediaType.audio;

  static String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }

  /// Thumbnail URL: YouTube → standard thumbnail API; Cloudinary video → video thumbnail.
  String? get _thumbnailUrl {
    if (_isYouTube) {
      final id = _youtubeId(item.mediaUrl);
      if (id != null) return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    } else if (_isVideo && item.cloudinaryId.isNotEmpty) {
      final cloudName = AppConstants.cloudinaryCloudName;
      final publicId = item.cloudinaryId;
      return 'https://res.cloudinary.com/$cloudName/video/upload/'
          'so_0,w_300,h_200,c_fill,f_jpg/$publicId.jpg';
    }
    return null;
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(item: item, isGreek: isGreek),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (isGreek && item.titleEl.isNotEmpty) ? item.titleEl : item.titleAr;
    final thumbUrl = _thumbnailUrl;

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: _kNavy.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kGold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(9),
              ),
              child: SizedBox(
                width: 80,
                height: 58,
                child: thumbUrl != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            thumbUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _DefaultThumb(isAudio: _isAudio, isYouTube: _isYouTube),
                          ),
                          // Play overlay
                          Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      )
                    : _DefaultThumb(isAudio: _isAudio, isYouTube: _isYouTube),
              ),
            ),
            // ── Title ─────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  title.isNotEmpty ? title : item.mediaUrl,
                  textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: isGreek ? 13 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // ── Play icon ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                _isAudio ? Icons.play_circle_outline : Icons.play_circle_fill,
                color: _kGold.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Default thumbnail (when no image available) ───────────────────────────────

class _DefaultThumb extends StatelessWidget {
  const _DefaultThumb({required this.isAudio, required this.isYouTube});
  final bool isAudio;
  final bool isYouTube;

  @override
  Widget build(BuildContext context) {
    final color = isYouTube
        ? _kCrimson
        : isAudio
            ? _kGold
            : Colors.blue;
    final icon = isYouTube
        ? Icons.smart_display
        : isAudio
            ? Icons.audiotrack
            : Icons.videocam;

    return Container(
      color: _kNavy,
      child: Center(
        child: Icon(icon, color: color.withValues(alpha: 0.7), size: 28),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 56, color: _kGold.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            context.l10n.noVideos,
            style: TextStyle(
              fontFamily: context.l10n.bodyFont,
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: isGreek ? 15 : 18,
            ),
          ),
        ],
      ),
    );
  }
}
