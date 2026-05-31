// lib/features/home/home_tab_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Main home dashboard tab.
//   • App header with search + notification icons
//   • Daily Readings hero card (from DailyVerseCubit)
//   • Quick-access category grid
//   • Recently Added books horizontal scroll
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/brightness_colors.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../../features/books/screens/book_detail_screen.dart';
import '../../features/daily_verse/daily_verse_cubit.dart';
import '../../features/daily_verse/daily_verse_state.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../settings/cubit/settings_state.dart';

class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key, required this.onGoToLibrary});

  /// Called when user taps a category shortcut or "See All" → switches to Library tab.
  final VoidCallback onGoToLibrary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HomeAppBar(onSearch: onGoToLibrary),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Daily Readings hero ──────────────────────────────
                const _DailyReadingsCard(),
                const SizedBox(height: 24),

                // ── Category quick-access ────────────────────────────
                _SectionHeader(
                  arLabel: 'الأقسام',
                  enLabel: 'CATEGORIES',
                  onSeeAll: onGoToLibrary,
                ),
                const SizedBox(height: 12),
                const _CategoryGrid(),
                const SizedBox(height: 24),

                // ── Recently Added ───────────────────────────────────
                _SectionHeader(
                  arLabel: 'أحدث الإضافات',
                  enLabel: 'RECENTLY ADDED',
                  onSeeAll: onGoToLibrary,
                ),
                const SizedBox(height: 12),
                const _RecentBooksRow(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);

    // Determine language for header title
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: bgDeep,
      elevation: 0,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(height: 0.5, color: goldBorder),
      ),
      title: Row(
        children: [
          // Cross ornament
          Text('✦', style: TextStyle(color: goldDim, fontSize: 14)),
          const SizedBox(width: 10),
          Text(
            isGreek ? 'Εκκλησία' : 'إكليسيا',
            style: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              color: goldLight,
              fontSize: isGreek ? 18 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: isGreek ? 0.5 : 1.0,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: goldDim, size: 22),
          onPressed: onSearch,
          tooltip: isGreek ? 'Αναζήτηση' : 'بحث',
        ),
        IconButton(
          icon: Icon(Icons.notifications_none_outlined,
              color: goldDim, size: 22),
          onPressed: () {},
          tooltip: isGreek ? 'Ειδοποιήσεις' : 'الإشعارات',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Daily Readings hero card ──────────────────────────────────────────────────

class _DailyReadingsCard extends StatelessWidget {
  const _DailyReadingsCard();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return BlocBuilder<DailyVerseCubit, DailyVerseState>(
      builder: (context, state) {
        final verse = state.verse;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: goldBorder, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: gold.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.asset(
                    'assets/images/Ekklisia_background.png',
                    fit: BoxFit.cover,
                    opacity: AlwaysStoppedAnimation(brightness == Brightness.dark ? 0.4 : 0.2),
                  ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          (brightness == Brightness.dark
                              ? const Color(0xFF6B1A2A)
                              : const Color(0xFF8B2238))
                              .withOpacity(0.92),
                          bgMid.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: isGreek
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Header label
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 0.5),
                          ),
                          child: Text(
                            isGreek
                                ? 'ΚΑΘΗΜΕΡΙΝΑ ΑΝΑΓΝΩΣΜΑΤΑ'
                                : 'القراءات اليومية',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),

                        // Push verse + button to bottom
                        const Spacer(),

                        // Verse / title text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isGreek
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            if (verse != null) ...[
                              Text(
                                isGreek && verse.verseEl.isNotEmpty
                                    ? verse.verseEl
                                    : verse.verseAr,
                                textDirection: isGreek
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily:
                                      isGreek ? null : 'Scheherazade',
                                  color: Colors.white,
                                  fontSize: isGreek ? 13 : 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                isGreek && verse.referenceEl.isNotEmpty
                                    ? verse.referenceEl
                                    : verse.referenceAr,
                                textDirection: isGreek
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily:
                                      isGreek ? null : 'Scheherazade',
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ] else ...[
                              Text(
                                isGreek
                                    ? 'Καθημερινά Αναγνώσματα'
                                    : 'القراءات اليومية',
                                textDirection: isGreek
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily:
                                      isGreek ? null : 'Scheherazade',
                                  color: Colors.white,
                                  fontSize: isGreek ? 15 : 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),

                            // Read button
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8A84B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isGreek ? 'ΔΙΑΒΑΣΤΕ' : 'اقرأ',
                                style: const TextStyle(
                                  color: Color(0xFF0D1B2A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.arLabel,
    required this.enLabel,
    this.onSeeAll,
  });
  final String arLabel;
  final String enLabel;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isGreek ? enLabel : arLabel,
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: goldLight,
                  fontSize: isGreek ? 13 : 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: isGreek ? 1.0 : 0.5,
                ),
              ),
            ],
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                isGreek ? 'Δείτε Όλα' : 'عرض الكل',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: gold,
                  fontSize: isGreek ? 11 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Category Grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _categories = [
    _CategoryItem(
      arLabel: 'الليتورجيا',
      enLabel: 'Λειτουργίες',
      icon: Icons.church_outlined,
      colorDark: Color(0xFF6B1A2A),
      colorLight: Color(0xFF8B2238),
    ),
    _CategoryItem(
      arLabel: 'السنكسار',
      enLabel: 'Συναξάριο',
      icon: Icons.menu_book_outlined,
      colorDark: Color(0xFF1A3D5A),
      colorLight: Color(0xFF2A5D8B),
    ),
    _CategoryItem(
      arLabel: 'التسابيح',
      enLabel: 'Ψαλμωδία',
      icon: Icons.music_note_outlined,
      colorDark: Color(0xFF0F4A3C),
      colorLight: Color(0xFF156B55),
    ),
    _CategoryItem(
      arLabel: 'الكتاب المقدس',
      enLabel: 'Βίβλος',
      icon: Icons.book_outlined,
      colorDark: Color(0xFF3D2860),
      colorLight: Color(0xFF5C4080),
    ),
    _CategoryItem(
      arLabel: 'القديسون',
      enLabel: 'Άγιοι',
      icon: Icons.stars_outlined,
      colorDark: Color(0xFF5C4010),
      colorLight: Color(0xFF8B6020),
    ),
    _CategoryItem(
      arLabel: 'شباب الكنيسة',
      enLabel: 'Νεολαία',
      icon: Icons.groups_outlined,
      colorDark: Color(0xFF1A5E5E),
      colorLight: Color(0xFF2A7D7D),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, i) => _CategoryTile(
          item: _categories[i],
          isGreek: isGreek,
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.arLabel,
    required this.enLabel,
    required this.icon,
    required this.colorDark,
    required this.colorLight,
  });
  final String arLabel;
  final String enLabel;
  final IconData icon;
  final Color colorDark;
  final Color colorLight;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.item, required this.isGreek});
  final _CategoryItem item;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor =
        brightness == Brightness.dark ? item.colorDark : item.colorLight;
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: Colors.white.withOpacity(0.9), size: 26),
              const SizedBox(height: 5),
              Text(
                isGreek ? item.enLabel : item.arLabel,
                textAlign: TextAlign.center,
                textDirection:
                    isGreek ? TextDirection.ltr : TextDirection.rtl,
                maxLines: 2,
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: Colors.white,
                  fontSize: isGreek ? 10 : 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recently Added books row ──────────────────────────────────────────────────

class _RecentBooksRow extends StatelessWidget {
  const _RecentBooksRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, state) {
        final books = state.books.take(8).toList();
        if (books.isEmpty) return const SizedBox.shrink();

        final brightness = Theme.of(context).brightness;
        final goldBorder = BrightnessColors.goldBorder(brightness);
        final bgMid = BrightnessColors.bgMid(brightness);
        final textPrimary = BrightnessColors.textPrimary(brightness);
        final textSecondary = BrightnessColors.textSecondary(brightness);
        final goldDim = BrightnessColors.goldDim(brightness);

        final lang = context.select<SettingsCubit, AppLanguage>(
          (c) => c.state.language,
        );
        final isGreek = lang == AppLanguage.greek;

        return SizedBox(
          height: 180,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, i) {
              final book = books[i];
              final title = isGreek && book.titleEl.isNotEmpty
                  ? book.titleEl
                  : book.titleAr;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BookDetailScreen(book: book)),
                ),
                child: Container(
                  width: 110,
                  margin: EdgeInsets.only(
                      right: i < books.length - 1 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: bgMid,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: goldBorder, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cover
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(11)),
                          child: book.coverUrl.isNotEmpty
                              ? Image.network(
                                  book.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _coverFallback(book.titleAr,
                                          brightness),
                                )
                              : _coverFallback(
                                  book.titleAr, brightness),
                        ),
                      ),
                      // Title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
                        child: Text(
                          title,
                          textDirection: isGreek
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily:
                                isGreek ? null : 'Scheherazade',
                            color: textPrimary,
                            fontSize: isGreek ? 10 : 12,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _coverFallback(String titleAr, Brightness brightness) {
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF162535)
        : const Color(0xFFEFEBE6);
    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          titleAr.isNotEmpty
              ? titleAr.substring(0, titleAr.length > 1 ? 2 : 1)
              : '✦',
          style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: Color(0xFFC8A84B),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
