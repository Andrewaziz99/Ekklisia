// lib/features/agbeya/screens/agbeya_home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Agbeya (Coptic Book of Hours) home screen.
// Lists all seven canonical hours fetched from Firestore.
// Each card: title, hour badge, duration, play button → AgbeyaHourScreen.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../data/models/agbeya_model.dart';
import '../../../data/repositories/agbeya_repository.dart';
import '../../../features/settings/cubit/settings_cubit.dart';
import '../../../services/settings_service.dart';
import '../cubit/agbeya_cubit.dart';
import '../cubit/agbeya_state.dart';
import '../cubit/audio_player_cubit.dart';
import '../cubit/audio_player_state.dart';
import 'agbeya_hour_screen.dart';
import 'agbeya_pdf_reader_screen.dart';
import '../widgets/track_picker_sheet.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold    = Color(0xFFC9A84C);

// ── Arabic hour names (canonical Agbeya order) ────────────────────────────────
const _kHourNamesAr = {
  1: 'صلاة باكر',
  2: 'صلاة الساعة الثالثة',
  3: 'صلاة الساعة السادسة',
  4: 'صلاة الساعة التاسعة',
  5: 'صلاة الغروب',
  6: 'صلاة النوم',
  7: 'صلاة نصف الليل',
};

const _kHourNamesEl = {
  1: 'Ακολουθία του Όρθρου',
  2: 'Ακολουθία Τρίτης Ώρας',
  3: 'Ακολουθία Έκτης Ώρας',
  4: 'Ακολουθία Ενάτης Ώρας',
  5: 'Ακολουθία του Εσπερινού',
  6: 'Ακολουθία του Αποδείπνου',
  7: 'Ακολουθία Μεσονυκτικού',
};

class AgbeyaHomeScreen extends StatelessWidget {
  const AgbeyaHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AgbeyaCubit(sl<AgbeyaRepository>())..watchHours(),
      child: const _AgbeyaHomeView(),
    );
  }
}

class _AgbeyaHomeView extends StatelessWidget {
  const _AgbeyaHomeView();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.light
        ? const Color(0xFFF5F0E8)
        : BrightnessColors.bgDeep(brightness);

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: _kNavy,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isGreek ? 'Αγπέγια' : 'الأجبية',
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: _kGold,
                fontSize: isGreek ? 20 : 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _kGold.withValues(alpha: 0.4)),
            ),
          ),

          // ── Intro banner ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _kCrimson.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kGold.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kGold, width: 1),
                    ),
                    child: const Icon(Icons.auto_stories,
                        color: _kGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isGreek
                          ? 'Επτά Ώρες Προσευχής — διαβάστε και ακούστε'
                          : 'سبع ساعات من الصلاة — اقرأ واستمع',
                      textDirection:
                          isGreek ? TextDirection.ltr : TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: brightness == Brightness.light
                            ? const Color(0xFF2C1A0E)
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: isGreek ? 12 : 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Hours list ───────────────────────────────────────────────────
          BlocBuilder<AgbeyaCubit, AgbeyaState>(
            builder: (context, state) {
              if (state.isLoading) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const _HourCardShimmer(),
                    childCount: 7,
                  ),
                );
              }

              if (state.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      isGreek
                          ? 'Σφάλμα φόρτωσης'
                          : 'حدث خطأ أثناء التحميل',
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: _kCrimson,
                      ),
                    ),
                  ),
                );
              }

              if (state.hours.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      isGreek ? 'Δεν βρέθηκαν ώρες' : 'لا توجد ساعات بعد',
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _HourCard(
                      hour: state.hours[i],
                      index: i,
                      isGreek: isGreek,
                      brightness: brightness,
                    ),
                    childCount: state.hours.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Hour Card ─────────────────────────────────────────────────────────────────

class _HourCard extends StatelessWidget {
  const _HourCard({
    required this.hour,
    required this.index,
    required this.isGreek,
    required this.brightness,
  });

  final AgbeyaHour hour;
  final int index;
  final bool isGreek;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final cardBg = isDark ? BrightnessColors.bgMid(brightness) : Colors.white;
    final textPrimary = isDark
        ? BrightnessColors.textPrimary(brightness)
        : const Color(0xFF2C1A0E);
    final textSub = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.grey.shade600;

    final title = isGreek
        ? (_kHourNamesEl[hour.hourNumber] ?? hour.titleFor('el'))
        : (_kHourNamesAr[hour.hourNumber] ?? hour.titleAr);

    return BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
      builder: (context, audioState) {
        final isCurrentTrack =
            audioState.currentItem?.extras?['hourId'] == hour.id;
        final isPlaying = isCurrentTrack && audioState.isPlaying;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AgbeyaHourScreen(hour: hour),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentTrack
                    ? _kGold
                    : _kGold.withValues(alpha: 0.3),
                width: isCurrentTrack ? 1.5 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ── Hour number badge ───────────────────────────────────
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${hour.hourNumber}',
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Title + duration ────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: isGreek
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          textDirection:
                              isGreek ? TextDirection.ltr : TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: textPrimary,
                            fontSize: isGreek ? 14 : 17,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: isGreek
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.end,
                          children: [
                            if (hour.hasAudio) ...[
                              Icon(Icons.headphones,
                                  size: 12, color: _kGold.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                            ],
                            if (hour.formattedDuration.isNotEmpty)
                              Text(
                                hour.formattedDuration,
                                style: TextStyle(
                                  color: textSub,
                                  fontSize: 11,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              isGreek
                                  ? '${hour.sections.length} ενότητες'
                                  : '${hour.sections.length} أقسام',
                              style: TextStyle(
                                fontFamily: isGreek ? null : 'Scheherazade',
                                color: textSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        // Playing indicator
                        if (isCurrentTrack) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: isGreek
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.end,
                            children: [
                              Icon(
                                isPlaying
                                    ? Icons.graphic_eq
                                    : Icons.pause_circle_outline,
                                size: 14,
                                color: _kCrimson,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isGreek
                                    ? (isPlaying ? 'Παίζει τώρα' : 'Σε παύση')
                                    : (isPlaying ? 'يعزف الآن' : 'متوقف مؤقتاً'),
                                style: TextStyle(
                                  fontFamily: isGreek ? null : 'Scheherazade',
                                  color: _kCrimson,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Action buttons ──────────────────────────────────────
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    // PDF reader button
                    if (hour.hasPdf)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AgbeyaPdfReaderScreen(hour: hour),
                          ),
                        ),
                        child: Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF162030),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _kGold.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.menu_book_outlined,
                                color: _kGold, size: 18),
                          ),
                        ),
                      ),

                    // Audio play / pause button
                    if (hour.hasAudio)
                      GestureDetector(
                        onTap: () => _onPlayTap(context, audioState),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isCurrentTrack ? _kCrimson : _kNavy,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _kGold.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: audioState.isBuffering && isCurrentTrack
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: _kGold, strokeWidth: 2),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: _kGold,
                                    size: 22,
                                  ),
                          ),
                        ),
                      )
                    else if (!hour.hasPdf)
                      // Neither audio nor PDF — just a chevron
                      const Icon(Icons.arrow_forward_ios,
                          size: 16, color: _kGold),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onPlayTap(
      BuildContext context, AudioPlayerState audioState) async {
    final cubit       = context.read<AudioPlayerCubit>();
    final isCurrent   = audioState.currentItem?.extras?['hourId'] == hour.id;

    if (isCurrent) {
      await cubit.togglePlayPause();
      return;
    }
    await playOrPickTrack(context, hour, cubit);
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _HourCardShimmer extends StatelessWidget {
  const _HourCardShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      height: 76,
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
