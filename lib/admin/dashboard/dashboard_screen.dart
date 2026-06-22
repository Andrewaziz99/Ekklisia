// lib/admin/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/brightness_colors.dart';
import '../../core/theme/colors.dart';
import '../../core/router/app_router.dart';
import '../../core/di/service_locator.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/auth/auth_state.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../features/settings/cubit/settings_state.dart';
import '../../services/settings_service.dart';
import '../../data/models/book_model.dart';
import '../../data/models/gallery_item_model.dart';
import '../../data/models/elib_item_model.dart';
import '../../data/repositories/gallery_repository.dart';
import '../../data/repositories/elib_repository.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../admin_l10n.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.adminL10n;

    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, booksState) {
        final books     = booksState.books;
        final published = books.where((b) => b.isPublished).length;
        final drafts    = books.length - published;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeBanner(),
              const SizedBox(height: 20),

              _sectionLabel(context, l.overview),
              const SizedBox(height: 12),
              _StatsGrid(
                books: books.length,
                published: published,
                drafts: drafts,
                categories: books.map((b) => b.category).toSet().length,
                l: l,
              ),
              const SizedBox(height: 24),

              _sectionLabel(context, l.quickActionsSection),
              const SizedBox(height: 12),
              _QuickActions(),
              const SizedBox(height: 24),

              _sectionLabel(context, l.library),
              const SizedBox(height: 12),
              _AllMediaSection(books: books),
              const SizedBox(height: 24),

              _sectionLabel(context, l.contentManagement),
              const SizedBox(height: 12),
              _CmsShortcuts(),
              const SizedBox(height: 24),

              if (books.isNotEmpty) ...[
                _sectionLabel(context, l.recentBooks),
                const SizedBox(height: 12),
                _RecentBooks(books: books.take(5).toList()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final b = Theme.of(context).brightness;
    final l = context.adminL10n;
    return Text(label,
      textDirection: l.dir,
      style: TextStyle(
        color:        BrightnessColors.textSecondary(b),
        fontSize:     11,
        fontWeight:   FontWeight.w600,
        letterSpacing: 1.2,
        fontFamily:   l.fontFam,
      ),
    );
  }
}

// ── Stat Cards Grid ───────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.books, required this.published,
    required this.drafts, required this.categories, required this.l,
  });
  final int books, published, drafts, categories;
  final AdminL10n l;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _StatCard(label: l.totalBooks,  value: books.toString(),
            icon: Icons.library_books,          color: EkklisiaColors.darkGold,      l: l),
        _StatCard(label: l.published,   value: published.toString(),
            icon: Icons.check_circle_outline,   color: EkklisiaColors.darkTealMid,   l: l),
        _StatCard(label: l.drafts,      value: drafts.toString(),
            icon: Icons.edit_note_outlined,     color: EkklisiaColors.darkTextSecondary, l: l),
        _StatCard(label: l.categories,  value: categories.toString(),
            icon: Icons.category_outlined,      color: EkklisiaColors.darkGoldLight, l: l),
      ],
    );
  }
}

// ── All Media Section ─────────────────────────────────────────────────────────

class _AllMediaSection extends StatelessWidget {
  const _AllMediaSection({required this.books});
  final List<BookModel> books;

  @override
  Widget build(BuildContext context) {
    final l         = context.adminL10n;
    final pdfs      = books.where((b) => b.mediaType == BookMediaType.pdf).length;
    final videos    = books.where((b) => b.mediaType == BookMediaType.video).length;
    final audios    = books.where((b) => b.mediaType == BookMediaType.audio).length;
    final published = books.where((b) => b.isPublished).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Row 1: books breakdown
      Row(children: [
        Expanded(child: _MiniStat(label: l.pdfs,   value: pdfs,
            icon: Icons.picture_as_pdf_outlined, color: EkklisiaColors.darkMaroon, l: l)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: l.videos, value: videos,
            icon: Icons.videocam_outlined, color: EkklisiaColors.darkOcean, l: l)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: l.audio,  value: audios,
            icon: Icons.headphones_outlined, color: EkklisiaColors.darkTealMid, l: l)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: l.live,   value: published,
            icon: Icons.check_circle_outline, color: EkklisiaColors.darkTealDark, l: l)),
      ]),
      const SizedBox(height: 8),

      // Row 2: gallery + elib counts (live data)
      StreamBuilder<List<GalleryItemModel>>(
        stream: sl<GalleryRepository>().watchAll(),
        builder: (context, galSnap) {
          final galCount = galSnap.data?.length ?? 0;
          return StreamBuilder<List<ElibItemModel>>(
            stream: sl<ElibRepository>().watchAllItems(),
            builder: (context, elibSnap) {
              final elibItems  = elibSnap.data ?? [];
              final elibVideos = elibItems.where((e) => e.mediaType == ElibMediaType.video).length;
              final elibAudios = elibItems.where((e) => e.mediaType == ElibMediaType.audio).length;
              final totalAll   = pdfs + videos + audios + galCount + elibVideos + elibAudios;

              return Row(children: [
                Expanded(child: _MiniStat(
                    label: l.gallery, value: galCount,
                    icon: Icons.photo_library_outlined,
                    color: EkklisiaColors.darkBronze, l: l)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(
                    label: l.elibManager, value: elibVideos + elibAudios,
                    icon: Icons.video_library_outlined,
                    color: EkklisiaColors.darkPlum, l: l)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(
                    label: l.elibVideos, value: elibVideos,
                    icon: Icons.videocam_outlined,
                    color: EkklisiaColors.darkForest, l: l)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(
                    label: 'Total', value: totalAll,
                    icon: Icons.perm_media_outlined,
                    color: EkklisiaColors.darkGoldLight, l: l)),
              ]);
            },
          );
        },
      ),
      const SizedBox(height: 12),

      // Action buttons
      Row(children: [
        Expanded(child: _LibraryActionBtn(
          label: l.manageLibrary, icon: Icons.library_books_outlined,
          color: EkklisiaColors.darkGold, l: l,
          onTap: () => context.go(Routes.adminBooks),
        )),
        const SizedBox(width: 8),
        Expanded(child: _LibraryActionBtn(
          label: l.uploadBook, icon: Icons.upload_file_outlined,
          color: EkklisiaColors.darkBronze, l: l,
          onTap: () => context.go(Routes.adminUpload),
        )),
        const SizedBox(width: 8),
        Expanded(child: _LibraryActionBtn(
          label: l.bulkUpload, icon: Icons.cloud_upload_outlined,
          color: EkklisiaColors.darkTealMid, l: l,
          onTap: () => context.go(Routes.adminBulkUpload),
        )),
      ]),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label, required this.value,
    required this.icon,  required this.color, required this.l,
  });
  final String   label;
  final int      value;
  final IconData icon;
  final Color    color;
  final AdminL10n l;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: BrightnessColors.bgMid(b),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 6),
        Text(value.toString(), style: TextStyle(
            color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, textDirection: l.dir,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: l.fontFam,
                color: BrightnessColors.textSecondary(b), fontSize: 9,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _LibraryActionBtn extends StatelessWidget {
  const _LibraryActionBtn({
    required this.label, required this.icon,
    required this.color, required this.l, required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final AdminL10n    l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(label, overflow: TextOverflow.ellipsis,
                  textDirection: l.dir,
                  style: TextStyle(
                      fontFamily: l.fontFam,
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Welcome Banner ────────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final l = context.adminL10n;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final name = state.user?.displayName.isNotEmpty == true
            ? state.user!.displayName
            : state.user?.email.split('@').first ?? 'Admin';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [BrightnessColors.bgMid(b), BrightnessColors.bgElevated(b)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.welcomeUser(name),
                    textDirection: l.dir,
                    style: TextStyle(
                      fontFamily: l.fontFam,
                      color: BrightnessColors.goldLight(b),
                      fontSize: 20, fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(l.adminPanel,
                    textDirection: l.dir,
                    style: TextStyle(
                      fontFamily: l.fontFam,
                      color: BrightnessColors.textSecondary(b), fontSize: 13,
                    )),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrightnessColors.goldSubtle(b),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 12, color: BrightnessColors.gold(b)),
                      const SizedBox(width: 5),
                      Text('Admin', style: TextStyle(
                        color: BrightnessColors.gold(b), fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5,
                      )),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.go(Routes.home),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrightnessColors.tealDark(b).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: BrightnessColors.tealMid(b).withOpacity(0.4), width: 0.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.home_outlined,
                            size: 12, color: BrightnessColors.tealMid(b)),
                        const SizedBox(width: 5),
                        Text(l.viewApp, style: TextStyle(
                          fontFamily: l.fontFam,
                          color: BrightnessColors.tealMid(b), fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 0.3,
                        )),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ThemeToggle(),
                ]),
              ],
            )),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                    colors: [EkklisiaColors.darkBronze, EkklisiaColors.darkMaroon]),
                border: Border.all(color: BrightnessColors.goldBorder(b), width: 1.5),
              ),
              child: const Center(child: Text('✦', style: TextStyle(
                  color: EkklisiaColors.darkGoldLight, fontSize: 24))),
            ),
          ]),
        );
      },
    );
  }
}

// ── Theme Toggle ──────────────────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final isDark = state.themeMode == AppThemeMode.dark;
        return GestureDetector(
          onTap: () => context.read<SettingsCubit>().setThemeMode(
              isDark ? AppThemeMode.light : AppThemeMode.dark),
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: BrightnessColors.bgElevated(b),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 12,
                color: BrightnessColors.gold(b),
              ),
              const SizedBox(width: 5),
              Text(
                isDark ? 'DARK' : 'LIGHT',
                style: TextStyle(
                  color: BrightnessColors.gold(b), fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label, required this.value,
    required this.icon,  required this.color, required this.l,
  });
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final AdminL10n l;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrightnessColors.bgMid(b),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label,
              overflow: TextOverflow.ellipsis,
              textDirection: l.dir,
              style: TextStyle(
                fontFamily: l.fontFam,
                color: BrightnessColors.textSecondary(b),
                fontSize: 11, fontWeight: FontWeight.w500,
              ))),
          Icon(icon, size: 16, color: color),
        ]),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
              color: color, fontSize: 26, fontWeight: FontWeight.w700,
              letterSpacing: -0.5)),
        ),
      ]),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final l = context.adminL10n;
    return Column(children: [
      Row(children: [
        Expanded(child: _ActionButton(
          label: l.uploadBook, icon: Icons.upload_file,
          color: EkklisiaColors.darkGold, l: l,
          onTap: () => context.go(Routes.adminUpload),
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionButton(
          label: l.sendNotification, icon: Icons.notifications_active_outlined,
          color: EkklisiaColors.darkMaroonMid, l: l,
          onTap: () => context.go(Routes.adminNotify),
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionButton(
          label: l.users, icon: Icons.people_outline,
          color: EkklisiaColors.darkTealMid, l: l,
          onTap: () => context.go(Routes.adminUsers),
        )),
      ]),
      const SizedBox(height: 10),
      Material(
        color: BrightnessColors.tealDark(b).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(Routes.home),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: BrightnessColors.tealMid(b).withOpacity(0.35), width: 0.8),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: BrightnessColors.tealDark(b).withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: BrightnessColors.tealMid(b).withOpacity(0.4), width: 0.8),
                ),
                child: Icon(Icons.home_outlined,
                    color: BrightnessColors.tealMid(b), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l.viewApp,
                  textDirection: l.dir,
                  style: TextStyle(
                    fontFamily: l.fontFam,
                    color: BrightnessColors.tealMid(b),
                    fontSize: 13, fontWeight: FontWeight.w700,
                  ))),
              Icon(Icons.arrow_forward_ios,
                  color: BrightnessColors.tealMid(b), size: 14),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── CMS Shortcuts ─────────────────────────────────────────────────────────────

class _CmsShortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.adminL10n;

    final items = [
      (label: l.cmsBible,      icon: Icons.book_outlined,       color: EkklisiaColors.darkGold,       path: Routes.adminCmsBibles),
      (label: l.cmsHymns,      icon: Icons.music_note_outlined, color: EkklisiaColors.darkTealDark,   path: Routes.adminCmsHymns),
      (label: l.cmsPrayers,    icon: Icons.favorite_outline,    color: EkklisiaColors.darkMaroonMid,  path: Routes.adminCmsPrayers),
      (label: l.cmsLiturgies,  icon: Icons.church_outlined,     color: EkklisiaColors.darkBronze,     path: Routes.adminCmsLiturgies),
      (label: l.cmsSaints,     icon: Icons.person_outline,      color: EkklisiaColors.darkPlum,       path: Routes.adminCmsSaints),
      (label: l.cmsDailyVerse, icon: Icons.menu_book_outlined,  color: EkklisiaColors.darkTealMid,    path: Routes.adminCmsDailyVerse),
      (label: l.cmsAgbeya,     icon: Icons.access_time_outlined,color: EkklisiaColors.darkMaroon,     path: Routes.adminCmsAgbeya),
      (label: l.cmsChurches,   icon: Icons.church_outlined,     color: EkklisiaColors.darkTealDark,   path: Routes.adminCmsChurches),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w    = constraints.maxWidth;
        // Columns: 2 on narrow phones, 3 on normal phones/tablets, 4 on wide
        final cols = w < 380 ? 2 : w < 600 ? 3 : 4;
        // Cell width after gaps
        final cellW    = (w - (cols - 1) * 10) / cols;
        final iconSize = (cellW * 0.20).clamp(16.0, 26.0);
        // Base font size proportional to cell; clamped to readable range
        final fontSize = (cellW * 0.095).clamp(9.0, 13.0);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: (cellW / (cellW * 0.92)).clamp(0.95, 1.15),
          children: items.map((item) {
            return Material(
              color: item.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.go(item.path),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: item.color.withOpacity(0.25), width: 0.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: item.color, size: iconSize),
                      SizedBox(height: cellW * 0.04),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        // FittedBox scales the text down further if it still
                        // doesn't fit after the computed fontSize
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            textAlign: TextAlign.center,
                            textDirection: l.dir,
                            maxLines: 2,
                            style: TextStyle(
                              fontFamily: l.fontFam,
                              color: item.color,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label, required this.icon,
    required this.color, required this.l, required this.onTap,
  });
  final String   label;
  final IconData icon;
  final Color    color;
  final AdminL10n l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(label, overflow: TextOverflow.ellipsis,
                  textDirection: l.dir,
                  style: TextStyle(
                    fontFamily: l.fontFam,
                    color: color, fontSize: 12, fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent Books ──────────────────────────────────────────────────────────────

class _RecentBooks extends StatelessWidget {
  const _RecentBooks({required this.books});
  final List<BookModel> books;

  static const _catColors = {
    'bible': EkklisiaColors.darkMaroon,    'prayers':  EkklisiaColors.darkMaroonMid,
    'liturgy': EkklisiaColors.darkBronze,  'hymns':    EkklisiaColors.darkTealDark,
    'saints': EkklisiaColors.darkPlum,     'fathers':  EkklisiaColors.darkForest,
    'commentaries': EkklisiaColors.darkOcean, 'studies': EkklisiaColors.darkOcean,
  };

  static IconData _mediaIcon(BookMediaType t) {
    switch (t) {
      case BookMediaType.video: return Icons.videocam_outlined;
      case BookMediaType.audio: return Icons.headphones_outlined;
      default:                  return Icons.picture_as_pdf_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final l = context.adminL10n;
    return Container(
      decoration: BoxDecoration(
        color: BrightnessColors.bgMid(b),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(child: Text(l.recentlyAdded,
                textDirection: l.dir,
                style: TextStyle(
                  fontFamily: l.fontFam,
                  color: BrightnessColors.textSecondary(b),
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8,
                ))),
            GestureDetector(
              onTap: () => context.go(Routes.adminBooks),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(l.viewAll, style: TextStyle(
                    color: BrightnessColors.gold(b), fontSize: 11,
                    fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios,
                    size: 10, color: BrightnessColors.gold(b)),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: BrightnessColors.goldBorder(b)),

        for (int i = 0; i < books.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Container(
                width: 36, height: 50,
                decoration: BoxDecoration(
                  color: (_catColors[books[i].category] ??
                      BrightnessColors.bgElevated(b)).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
                ),
                child: Center(child: Icon(_mediaIcon(books[i].mediaType),
                    size: 16, color: EkklisiaColors.darkTextCream)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(books[i].titleAr,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color: BrightnessColors.textPrimary(b),
                        fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_catColors[books[i].category] ??
                            BrightnessColors.bgElevated(b)).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(books[i].category, style: TextStyle(
                          color: BrightnessColors.textSecondary(b), fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Text(books[i].formattedSize, style: TextStyle(
                        color: BrightnessColors.textSecondary(b), fontSize: 10)),
                  ]),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: books[i].isPublished
                      ? BrightnessColors.tealMid(b).withOpacity(0.15)
                      : BrightnessColors.bgElevated(b),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: books[i].isPublished
                        ? BrightnessColors.tealMid(b).withOpacity(0.4)
                        : BrightnessColors.goldBorder(b),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  books[i].isPublished ? l.statusLive : l.statusDraft,
                  style: TextStyle(
                    fontFamily: l.fontFam,
                    color: books[i].isPublished
                        ? BrightnessColors.tealMid(b)
                        : BrightnessColors.textSecondary(b),
                    fontSize: 9, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          ),
          if (i < books.length - 1)
            Divider(height: 1, color: BrightnessColors.goldBorder(b),
                indent: 14, endIndent: 14),
        ],
      ]),
    );
  }
}
