// lib/features/saints/saint_detail.dart
// ─────────────────────────────────────────────────────────────────────────────
// User-facing Saint detail screen.
// Shows cover image, biography (AR / EN tabs), and media buttons:
//   • PDF   → CachedPdfViewer push
//   • Audio → AudioPlayerCubit.play()
//   • Video → showVideoSheet()
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../core/theme/colors.dart';
import '../../data/models/saint_model.dart';
import '../../features/agbeya/cubit/audio_player_cubit.dart';
import '../../shared/widgets/cached_image.dart';
import '../../shared/widgets/cached_pdf_viewer.dart';
import '../../shared/widgets/video_player_widget.dart';

class SaintDetailScreen extends StatefulWidget {
  const SaintDetailScreen({super.key, required this.saint});
  final SaintModel saint;

  @override
  State<SaintDetailScreen> createState() => _SaintDetailScreenState();
}

class _SaintDetailScreenState extends State<SaintDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final hasBothBios =
        (widget.saint.biographyEn?.isNotEmpty ?? false) &&
        (widget.saint.biographyAr?.isNotEmpty ?? false);
    _tabs = TabController(length: hasBothBios ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _playAudio() {
    final s = widget.saint;
    context.read<AudioPlayerCubit>().play(
      MediaItem(
        id: s.audioUrl,
        title: s.nameAr,
        album: s.nameEn,
        artUri: s.hasImage ? Uri.parse(s.imageUrl) : null,
        extras: {'saintId': s.id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.l10n;
    final s = widget.saint;
    final hasBothBios =
        (s.biographyEn?.isNotEmpty ?? false) &&
        (s.biographyAr?.isNotEmpty ?? false);

    final bgDeep     = BrightnessColors.bgDeep(brightness);
    final bgMid      = BrightnessColors.bgMid(brightness);
    final gold       = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final teal       = BrightnessColors.tealMid(brightness);
    final plum       = BrightnessColors.plum(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar with cover ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: bgDeep,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: gold, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (s.hasVideo)
                IconButton(
                  tooltip: 'مشاهدة الفيديو',
                  icon: Icon(Icons.videocam_outlined, color: gold, size: 22),
                  onPressed: () =>
                      showVideoSheet(context, s.videoUrl, titleAr: s.nameAr),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  s.hasImage
                      ? CachedImage(url: s.imageUrl, fit: BoxFit.cover)
                      : Container(color: bgMid),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1.0],
                        colors: [
                          Colors.transparent,
                          bgDeep.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                  // Name overlay at bottom
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.nameAr,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Scheherazade',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.nameEn,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Feast date + patron row ─────────────────────────
                  if (s.feastDate != null || s.patronOfEn != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (s.feastDate != null)
                            _InfoChip(
                              icon: Icons.calendar_today_outlined,
                              label: '${l.feastPrefix}${s.feastDate!}',
                              color: gold,
                            ),
                          if (s.patronOfEn != null)
                            _InfoChip(
                              icon: Icons.shield_outlined,
                              label: '${l.patronPrefix}${s.patronOfEn}',
                              color: teal,
                            ),
                          if (s.patronOfAr != null)
                            _InfoChip(
                              icon: Icons.shield_outlined,
                              label: s.patronOfAr!,
                              color: teal,
                              arabic: true,
                            ),
                        ],
                      ),
                    ),

                  // ── Media action buttons ─────────────────────────────
                  if (s.hasPdf || s.hasAudio || s.hasVideo) ...[
                    _SectionDivider(label: l.mediaSection, gold: gold),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (s.hasPdf)
                          _MediaButton(
                            icon: Icons.picture_as_pdf_outlined,
                            label: l.readPdf,
                            color: EkklisiaColors.bronze,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _PdfScreen(saint: s),
                              ),
                            ),
                          ),
                        if (s.hasAudio)
                          _MediaButton(
                            icon: Icons.headphones_outlined,
                            label: l.playAudio,
                            color: teal,
                            onTap: _playAudio,
                          ),
                        if (s.hasVideo)
                          _MediaButton(
                            icon: Icons.play_circle_outline,
                            label: l.watchVideo,
                            color: plum,
                            onTap: () => showVideoSheet(
                              context,
                              s.videoUrl,
                              titleAr: s.nameAr,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Biography ────────────────────────────────────────
                  if (s.biographyEn != null || s.biographyAr != null) ...[
                    _SectionDivider(
                      label: l.biography,
                      gold: gold,
                    ),
                    const SizedBox(height: 10),
                    if (hasBothBios) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: bgMid,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: goldBorder, width: 0.5),
                        ),
                        child: TabBar(
                          controller: _tabs,
                          labelColor: gold,
                          unselectedLabelColor: textSecondary,
                          indicatorColor: gold,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: [
                            Tab(text: l.english),
                            const Tab(text: 'عربي'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 300,
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _BiographyText(text: s.biographyEn!, arabic: false),
                            _BiographyText(text: s.biographyAr!, arabic: true),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (s.biographyEn != null)
                        _BiographyText(text: s.biographyEn!, arabic: false),
                      if (s.biographyAr != null)
                        _BiographyText(text: s.biographyAr!, arabic: true),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PDF viewer pushed inline ──────────────────────────────────────────────────

class _PdfScreen extends StatelessWidget {
  const _PdfScreen({required this.saint});
  final SaintModel saint;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold   = BrightnessColors.gold(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        foregroundColor: gold,
        title: Text(
          saint.nameAr,
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: gold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (saint.hasVideo)
            IconButton(
              icon: Icon(Icons.videocam_outlined, color: gold),
              onPressed: () => showVideoSheet(
                context,
                saint.videoUrl,
                titleAr: saint.nameAr,
              ),
            ),
        ],
      ),
      body: CachedPdfViewer(url: saint.pdfUrl),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label, required this.gold});
  final String label;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final goldBorder = BrightnessColors.goldBorder(Theme.of(context).brightness);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: goldBorder, height: 1)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.arabic = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontFamily: arabic ? 'Scheherazade' : null,
          ),
        ),
      ],
    ),
  );
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BiographyText extends StatelessWidget {
  const _BiographyText({required this.text, required this.arabic});
  final String text;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgElevated  = BrightnessColors.bgElevated(brightness);
    final goldBorder  = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: goldBorder, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            color: textPrimary,
            fontFamily: arabic ? 'Scheherazade' : null,
            fontSize: arabic ? 16 : 14,
            height: 1.65,
          ),
        ),
      ),
    );
  }
}
