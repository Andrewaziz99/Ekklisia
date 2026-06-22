// lib/features/agbeya/screens/agbeya_hour_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Full reader for a single Agbeya hour.
//
// Layout:
//   • SliverAppBar (collapsing cover / hour title)
//   • Language tabs  (Arabic | Coptic | Greek)
//   • Prayer sections — expandable cards
//   • Persistent bottom audio strip (shows when audio is available)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../data/models/agbeya_model.dart';
import '../../../features/settings/cubit/settings_cubit.dart';
import '../../../services/settings_service.dart';
import '../cubit/audio_player_cubit.dart';
import '../cubit/audio_player_state.dart';
import '../widgets/full_audio_player_sheet.dart';
import '../widgets/track_picker_sheet.dart';
import 'agbeya_pdf_reader_screen.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/video_player_widget.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold    = Color(0xFFC9A84C);

class AgbeyaHourScreen extends StatefulWidget {
  const AgbeyaHourScreen({super.key, required this.hour});
  final AgbeyaHour hour;

  @override
  State<AgbeyaHourScreen> createState() => _AgbeyaHourScreenState();
}

class _AgbeyaHourScreenState extends State<AgbeyaHourScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Expanded state for each section
  late List<bool> _expanded;

  static const _tabs = ['ar', 'cop', 'el'];
  static const _tabLabelsAr = ['العربية', 'القبطية', 'اليونانية'];
  static const _tabLabelsEl = ['Αραβικά', 'Κοπτικά', 'Ελληνικά'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _expanded = List.filled(widget.hour.sections.length, true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? BrightnessColors.bgDeep(brightness) : const Color(0xFFF5F0E8);

    final l = context.l10n;
    final isGreek = !l.isAr;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Main scroll ───────────────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, isDark, isGreek),
              _buildSections(isDark, isGreek),
              // Bottom padding so content clears the audio strip
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),

          // ── Persistent audio strip at bottom ──────────────────────────────
          if (widget.hour.hasAudio)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _InlineAudioStrip(hour: widget.hour, isGreek: isGreek),
            ),
        ],
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool isDark, bool isGreek) {
    final l = context.l10n;
    // Putting TabBar directly in SliverAppBar.bottom is the Flutter-recommended
    // pattern. It avoids the standalone SliverPersistentHeader whose
    // render object can have geometry == null during paint when the enclosing
    // CustomScrollView is composited.
    return SliverAppBar(
      pinned: true,
      expandedHeight: widget.hour.coverUrl.isNotEmpty ? 200 : 120,
      backgroundColor: _kNavy,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      // Actions: video + PDF reader + audio play
      actions: [
        if (widget.hour.hasVideo)
          IconButton(
            icon: const Icon(Icons.videocam_outlined,
                color: _kGold, size: 24),
            tooltip: l.video,
            onPressed: () => showVideoSheet(
              context,
              widget.hour.videoUrl,
              titleAr: widget.hour.titleAr,
            ),
          ),
        if (widget.hour.hasPdf)
          IconButton(
            icon: const Icon(Icons.menu_book_outlined,
                color: _kGold, size: 24),
            tooltip: l.readPdf,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgbeyaPdfReaderScreen(hour: widget.hour),
              ),
            ),
          ),
        if (widget.hour.hasAudio)
          BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
            builder: (context, state) {
              final isCurrent =
                  state.currentItem?.extras?['hourId'] == widget.hour.id;
              final isPlaying = isCurrent && state.isPlaying;
              return IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: _kGold,
                  size: 28,
                ),
                onPressed: () => _handlePlayTap(context, state),
              );
            },
          ),
        const SizedBox(width: 4),
      ],
      // Tab bar lives here — it stays pinned when the cover collapses, exactly
      // like a regular AppBar.bottom, with no extra SliverPersistentHeader needed.
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _kGold,
        labelColor: _kGold,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
        dividerColor: _kGold.withValues(alpha: 0.3),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        tabs: const [
          Tab(text: 'العربية'),
          Tab(text: 'القبطية'),
          Tab(text: 'Ελληνικά'),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        // bottom: 58 still puts the title in the toolbar strip when collapsed
        // (toolbar 56 + tabBar ~46 = 102 total; 102 - 58 = 44 from top).
        titlePadding: const EdgeInsets.only(left: 56, bottom: 58, right: 16),
        title: Text(
          isGreek ? widget.hour.titleFor('el') : widget.hour.titleAr,
          style: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: Colors.white,
            fontSize: isGreek ? 15 : 18,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 8),
            ],
          ),
        ),
        background: widget.hour.coverUrl.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedImage(
                    url: widget.hour.coverUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: Container(color: _kNavy),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _kNavy.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E1A2E), _kNavy],
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.15,
                    child: Text(
                      '✦',
                      style: TextStyle(color: _kGold, fontSize: 80),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────────────────────

  Widget _buildSections(bool isDark, bool isGreek) {
    if (widget.hour.sections.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              isGreek
                  ? 'Δεν υπάρχει κείμενο ακόμα.\nΤο περιεχόμενο θα ανέβει σύντομα.'
                  : 'لا يوجد نص بعد.\nسيتم إضافة المحتوى قريباً.',
              textAlign: TextAlign.center,
              textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey.shade600,
                fontSize: isGreek ? 13 : 16,
                height: 1.7,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              final langCode = _tabs[_tabController.index];
              return _SectionCard(
                section: widget.hour.sections[i],
                index: i,
                langCode: langCode,
                isExpanded: _expanded[i],
                isDark: isDark,
                onToggle: () =>
                    setState(() => _expanded[i] = !_expanded[i]),
              );
            },
          ),
          childCount: widget.hour.sections.length,
        ),
      ),
    );
  }

  // ── Audio tap handler ────────────────────────────────────────────────────────

  Future<void> _handlePlayTap(
      BuildContext context, AudioPlayerState state) async {
    final cubit     = context.read<AudioPlayerCubit>();
    final isCurrent = state.currentItem?.extras?['hourId'] == widget.hour.id;

    if (isCurrent) {
      await cubit.togglePlayPause();
      return;
    }
    await playOrPickTrack(context, widget.hour, cubit);
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.index,
    required this.langCode,
    required this.isExpanded,
    required this.isDark,
    required this.onToggle,
  });

  final AgbeyaSection section;
  final int index;
  final String langCode;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isRtl = langCode != 'el';
    final title = section.titleFor(langCode);
    final text = section.textFor(langCode);
    final fontFamily = langCode == 'ar'
        ? 'Scheherazade'
        : langCode == 'cop'
            ? 'CopticFont'
            : null; // Greek uses system font
    final cardBg = isDark ? BrightnessColors.bgMid(Brightness.dark) : Colors.white;
    final textColor = isDark
        ? BrightnessColors.textPrimary(Brightness.dark)
        : const Color(0xFF2C1A0E);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kGold.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _kNavy,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _kGold.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : (langCode == 'el' ? 'Ενότητα' : 'قسم'),
                      textDirection:
                          isRtl ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor,
                        fontSize: langCode == 'ar' ? 16 : 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _kGold,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Body text ───────────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  Divider(
                    color: _kGold.withValues(alpha: 0.25),
                    height: 16,
                    thickness: 0.5,
                  ),
                  SelectableText(
                    text.isNotEmpty
                        ? text
                        : (langCode == 'el'
                            ? 'Το κείμενο δεν είναι διαθέσιμο ακόμα.'
                            : 'النص غير متوفر بعد.'),
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: textColor,
                      fontSize: langCode == 'ar'
                          ? 17
                          : langCode == 'cop'
                              ? 15
                              : 13,
                      height: 2.0,
                      letterSpacing: langCode == 'cop' ? 0.3 : 0,
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Inline audio strip (bottom of the hour screen) ───────────────────────────

class _InlineAudioStrip extends StatelessWidget {
  const _InlineAudioStrip({required this.hour, required this.isGreek});
  final AgbeyaHour hour;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, state) {
        final isCurrent = state.currentItem?.extras?['hourId'] == hour.id;
        final isPlaying = isCurrent && state.isPlaying;
        final cubit = context.read<AudioPlayerCubit>();

        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: FullAudioPlayerSheet(hour: hour),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? BrightnessColors.bgMid(brightness) : _kNavy,
              border: Border(
                top: BorderSide(
                    color: _kGold.withValues(alpha: 0.4), width: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Progress bar ──────────────────────────────────────
                    if (isCurrent && state.duration > Duration.zero)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.15),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_kGold),
                          minHeight: 2,
                        ),
                      ),
                    if (isCurrent && state.duration > Duration.zero)
                      const SizedBox(height: 8),

                    // ── Controls row ──────────────────────────────────────
                    Row(
                      children: [
                        // Track info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: isGreek
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              Text(
                                isGreek ? hour.titleFor('el') : hour.titleAr,
                                textDirection: isGreek
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: isGreek ? null : 'Scheherazade',
                                  color: Colors.white,
                                  fontSize: isGreek ? 13 : 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (isCurrent && state.duration > Duration.zero)
                                Text(
                                  '${state.positionLabel} / ${state.durationLabel}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Rewind 10s
                        IconButton(
                          icon: const Icon(Icons.replay_10, color: _kGold),
                          iconSize: 26,
                          onPressed: isCurrent ? cubit.skipBackward : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),

                        // Play / pause
                        GestureDetector(
                          onTap: () async {
                            if (!isCurrent) {
                              await playOrPickTrack(context, hour, cubit);
                            } else {
                              await cubit.togglePlayPause();
                            }
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _kCrimson,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _kGold.withValues(alpha: 0.6),
                                  width: 1),
                            ),
                            child: Center(
                              child: state.isBuffering && isCurrent
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: _kGold,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: _kGold,
                                      size: 26,
                                    ),
                            ),
                          ),
                        ),

                        // Forward 30s
                        IconButton(
                          icon: const Icon(Icons.forward_30, color: _kGold),
                          iconSize: 26,
                          onPressed: isCurrent ? cubit.skipForward : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),

                        // Expand icon
                        const Icon(Icons.expand_less, color: _kGold, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

