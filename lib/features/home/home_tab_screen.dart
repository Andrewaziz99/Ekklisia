// lib/features/home/home_tab_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Main home dashboard tab — Byzantine / Orthodox liturgical aesthetic.
//
// Layout:
//   • Pinned header   — dark navy, [Ekklisia] serif + Coptic cross
//   • Daily verse     — crimson banner, cross icon left / verse info right
//   • Content Library — 3-col icon grid (see home_layout_defaults.dart)
//   • Recently Added  — horizontal book scroll
//
// Tile names/images, the header banner and all section titles can be
// overridden by an admin (config/home_layout — see HomeLayoutRepository).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:ekklisia/core/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/services/coptic_calendar_service.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/category_label_model.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/models/social_links_model.dart';
import '../../data/repositories/category_label_repository.dart';
import '../../data/repositories/social_links_repository.dart';
import '../../features/agbeya/screens/agbeya_home_screen.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/bible/bible_home_screen.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../../features/books/screens/book_detail_screen.dart';
import '../../features/churches/churches_screen.dart';
import '../../features/coptic_calendar/coptic_calendar_screen.dart';
import '../../features/daily_verse/daily_verse_cubit.dart';
import '../../features/daily_verse/daily_verse_state.dart';
import '../../features/electronic_library/electronic_library_screen.dart';
import '../../data/models/gallery_item_model.dart';
import '../../data/models/home_layout_model.dart';
import '../../data/repositories/home_layout_repository.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/games/screens/games_home_screen.dart';
import '../../features/pdf_content/pdf_content_list_screen.dart';
import '../../features/saints/saints_list.dart';
import '../../shared/widgets/cached_image.dart';
import 'home_layout_defaults.dart';

// ── Palette constants ─────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold = Color(0xFFC9A84C);
const _kParchment = Color(0xFFF5F0E8);

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key, required this.onGoToLibrary});

  final VoidCallback onGoToLibrary;

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final Stream<HomeLayoutModel> _layoutStream =
      sl<HomeLayoutRepository>().watch();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bodyBg = brightness == Brightness.light
        ? _kParchment
        : BrightnessColors.bgDeep(brightness);

    final isAdmin = context.select<AuthCubit, bool>((c) => c.state.isAdmin);
    final l = context.l10n;

    // Admin-editable names / images / titles (config/home_layout). Falls
    // back to the compiled-in defaults until loaded or when a field is blank.
    return StreamBuilder<HomeLayoutModel>(
      stream: _layoutStream,
      initialData: HomeLayoutModel.empty,
      builder: (context, snap) {
        final layout = snap.data ?? HomeLayoutModel.empty;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: bodyBg,
          endDrawer: _GamesEndDrawer(isAdmin: isAdmin, layout: layout),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _HomeAppBar(
                bannerUrl: layout.bannerUrl,
                onSearch: widget.onGoToLibrary,
                onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Daily Verse banner (flush to header) ─────────
                    _DailyVerseBanner(
                      title: layout.sectionLabel(
                        HomeSectionKeys.dailyVerse,
                        isAr: l.isAr,
                        fallback: l.dailyVerseTitleUpper,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Content Library ───────────────────────────────
                    _SectionHeader(
                      label: layout.sectionLabel(
                        HomeSectionKeys.contentLibrary,
                        isAr: l.isAr,
                        fallback: l.contentLibrary,
                      ),
                      onAction: widget.onGoToLibrary,
                      actionIsSearch: true,
                    ),
                    const SizedBox(height: 14),
                    _CategoryGrid(layout: layout),

                    const SizedBox(height: 24),

                    // ── Recently Added ────────────────────────────────
                    _SectionHeader(
                      label: layout.sectionLabel(
                        HomeSectionKeys.recentlyAdded,
                        isAr: l.isAr,
                        fallback: l.recentlyAdded,
                      ),
                      onAction: widget.onGoToLibrary,
                      actionIsSearch: false,
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
      },
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────
// Banner image fills the expanded space (matches the Ekklisia brand banner).
// Collapsed: compact navy bar retaining the menu + bell icons.

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({
    required this.bannerUrl,
    required this.onSearch,
    required this.onMenuTap,
  });
  final String bannerUrl;
  final VoidCallback onSearch;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 210,
      backgroundColor: _kNavy,
      elevation: 0,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,

      // ── Collapsed leading: hamburger (opens end drawer) ───────────────
      leading: _IconPill(
        child: const Icon(
          Icons.notifications_none_outlined,
          color: Colors.white,
          size: 22,
        ),
        onTap: () {},
      ),

      // ── Collapsed action: notification bell ───────────────────────────
      actions: [
        _IconPill(
          onTap: onMenuTap,
          child: const Icon(Icons.menu, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 8),
      ],

      // ── Expanded: full banner image (admin can replace it) ────────────
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (bannerUrl.isEmpty)
              _defaultBanner
            else
              CachedImage(
                url: bannerUrl,
                fit: BoxFit.cover,
                placeholder: _defaultBanner,
                errorWidget: _defaultBanner,
              ),
            // Thin gold gradient rule at the very bottom edge
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _kGold.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const Widget _defaultBanner = Image(
  image: AssetImage('assets/images/Banner.png'),
  fit: BoxFit.cover,
  alignment: Alignment.topCenter,
);

// ── Icon pill (semi-transparent dark circle used for menu / bell) ─────────────

class _IconPill extends StatelessWidget {
  const _IconPill({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(10),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Coptic Cross Painter ──────────────────────────────────────────────────────

class _CopticCrossPainter extends CustomPainter {
  const _CopticCrossPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final arm = size.width * 0.36;
    final r = size.width * 0.45;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r, linePaint..strokeWidth = 0.9);

    // Vertical arm
    canvas.drawLine(
      Offset(cx, cy - arm),
      Offset(cx, cy + arm),
      linePaint..strokeWidth = 1.4,
    );
    // Horizontal arm
    canvas.drawLine(
      Offset(cx - arm, cy),
      Offset(cx + arm, cy),
      linePaint..strokeWidth = 1.4,
    );

    // Terminal dots at four ends
    for (final p in [
      Offset(cx, cy - arm),
      Offset(cx, cy + arm),
      Offset(cx - arm, cy),
      Offset(cx + arm, cy),
    ]) {
      canvas.drawCircle(p, 2.0, dotPaint);
    }

    // Centre ring + dot
    canvas.drawCircle(Offset(cx, cy), 4.5, linePaint..strokeWidth = 0.9);
    canvas.drawCircle(Offset(cx, cy), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(_CopticCrossPainter old) => old.color != color;
}

// ── Daily Verse Banner ────────────────────────────────────────────────────────

class _DailyVerseBanner extends StatelessWidget {
  const _DailyVerseBanner({required this.title});

  /// Resolved (possibly admin-overridden) banner title.
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<DailyVerseCubit, DailyVerseState>(
      builder: (context, state) {
        final verse = state.verse;

        final verseText = verse == null
            ? ''
            : (!l.isAr && verse.verseEl.isNotEmpty
                  ? verse.verseEl
                  : verse.verseAr);
        final reference = verse == null
            ? ''
            : (!l.isAr && verse.referenceEl.isNotEmpty
                  ? verse.referenceEl
                  : verse.referenceAr);

        return Container(
          color: _kCrimson,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App logo thumbnail ────────────────────────────────
              // const AppLogo(size: 80),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Image.asset(
                  'assets/images/icons/001.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(width: 14),

              // ── Verse info ────────────────────────────────────────
              Expanded(
                child: state.isLoading
                    ? const _BannerShimmer()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: _kGold, width: 0.8),
                              ),
                            ),
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              title,
                              textDirection: l.dir,
                              style: TextStyle(
                                fontFamily: l.bodyFont,
                                color: _kGold,
                                fontSize: l.isAr ? 11 : 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: l.isAr ? 0.5 : 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (verse != null) ...[
                            Text(
                              verseText,
                              textDirection: l.dir,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: l.greekLanguage,
                                color: Colors.white,
                                fontSize: l.isAr ? 15 : 13,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              reference,
                              textDirection: l.dir,
                              style: TextStyle(
                                fontFamily: l.bodyFont,
                                color: const Color(0xFFE8C8A0),
                                fontSize: l.isAr ? 13 : 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            Text(
                              l.dailyVerseEmpty,
                              textDirection: l.dir,
                              style: TextStyle(
                                fontFamily: l.bodyFont,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: l.isAr ? 15 : 13,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Banner shimmer ────────────────────────────────────────────────────────────

class _BannerShimmer extends StatelessWidget {
  const _BannerShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _shimmer(100, 10),
        const SizedBox(height: 8),
        _shimmer(double.infinity, 13),
        const SizedBox(height: 5),
        _shimmer(140, 13),
        const SizedBox(height: 5),
        _shimmer(80, 11),
      ],
    );
  }

  Widget _shimmer(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.onAction,
    this.actionIsSearch = false,
  });

  final String label;
  final VoidCallback? onAction;
  final bool actionIsSearch;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final titleColor = brightness == Brightness.light
        ? const Color(0xFF2C1A0E)
        : BrightnessColors.goldLight(brightness);
    final l = context.l10n;

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
                  color: _kGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: l.bodyFont,
                  color: titleColor,
                  fontSize: l.isAr ? 18 : 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: actionIsSearch
                  ? Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.search,
                        size: 16,
                        color: _kCrimson,
                      ),
                    )
                  : Text(
                      context.l10n.seeAll,
                      style: TextStyle(
                        fontFamily: l.bodyFont,
                        color: _kGold,
                        fontSize: l.isAr ? 13 : 11,
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
  const _CategoryGrid({required this.layout});
  final HomeLayoutModel layout;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final brightness = Theme.of(context).brightness;
    final labelColor = brightness == Brightness.light
        ? const Color(0xFF2C1A0E)
        : Colors.white.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.9,
        ),
        itemCount: homeTileDefs.length,
        itemBuilder: (context, i) => _CategoryTile(
          def: homeTileDefs[i],
          custom: layout.tile(homeTileDefs[i].key),
          l: l,
          labelColor: labelColor,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.def,
    required this.custom,
    required this.l,
    required this.labelColor,
  });
  final HomeTileDef def;
  final HomeItemOverride custom;
  final AppL10n l;
  final Color labelColor;

  void _push(BuildContext context, Widget screen) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );

  void _onTap(BuildContext context) {
    final category = def.pdfCategory;
    if (category != null) {
      // The list screen shows its own bilingual header — pass the admin's
      // renamed labels when set, otherwise the original category labels.
      _push(
        context,
        PdfContentListScreen(
          category: category,
          labelAr: custom.label(
            isAr: true,
            fallback: PdfCategory.labelAr[category]!,
          ),
          labelEl: custom.label(
            isAr: false,
            fallback: PdfCategory.labelEl[category]!,
          ),
        ),
      );
      return;
    }
    switch (def.key) {
      case HomeTileKeys.agbeya:
        _push(context, const AgbeyaHomeScreen());
        break;
      case HomeTileKeys.bible:
        _push(context, const BibleHomeScreen());
        break;
      case HomeTileKeys.copticCalendar:
        _push(context, const CopticCalendarScreen());
        break;
    }
  }

  Widget _defaultArt() => def.asset.isEmpty
      ? const _GlyphTileContent(icon: Icons.category_outlined)
      : Image.asset(
          def.asset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        );

  Widget _art() {
    if (!def.allowImage) return _CalendarTileContent(bgColor: def.bgColor);
    if (custom.imageUrl.isEmpty) return _defaultArt();
    return CachedImage(
      url: custom.imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: Container(color: def.bgColor),
      errorWidget: _defaultArt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = custom.label(isAr: l.isAr, fallback: def.defaultLabel(l));

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: def.bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _kGold.withValues(alpha: 0.65),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: def.bgColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _art(),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: l.bodyFont,
              color: labelColor,
              fontSize: l.isAr ? 12 : 10,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
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
        final bgMid = brightness == Brightness.light
            ? Colors.white
            : BrightnessColors.bgMid(brightness);
        final textPrimary = brightness == Brightness.light
            ? const Color(0xFF2C1A0E)
            : BrightnessColors.textPrimary(brightness);

        final l = context.l10n;

        return SizedBox(
          height: 180,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, i) {
              final book = books[i];
              final title = !l.isAr && book.titleEl.isNotEmpty
                  ? book.titleEl
                  : book.titleAr;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(book: book),
                  ),
                ),
                child: Container(
                  width: 110,
                  margin: EdgeInsets.only(right: i < books.length - 1 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: bgMid,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: goldBorder, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                          child: CachedImage(
                            url: book.coverUrl,
                            fit: BoxFit.cover,
                            placeholder: _coverFallback(
                              book.titleAr,
                              brightness,
                            ),
                            errorWidget: _coverFallback(
                              book.titleAr,
                              brightness,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
                        child: Text(
                          title,
                          textDirection: l.dir,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: l.bodyFont,
                            color: textPrimary,
                            fontSize: l.isAr ? 12 : 10,
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

// ── Calendar Tile Content ─────────────────────────────────────────────────────

class _CalendarTileContent extends StatelessWidget {
  const _CalendarTileContent({required this.bgColor});
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final coptic = CopticCalendarService.fromGregorian(DateTime.now());
    final l = context.l10n;
    final monthName = l.isAr
        ? CopticCalendarService.monthNameAr(coptic.month)
        : CopticCalendarService.monthNameEl(coptic.month);
    final yearSuffix = context.l10n.yearSuffix;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // Faint cross ornament in background
          Center(
            child: Text(
              '☩',
              style: TextStyle(
                fontSize: 72,
                color: _kGold.withValues(alpha: 0.08),
                height: 1,
              ),
            ),
          ),
          // Date content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${coptic.day}',
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  monthName,
                  textDirection: l.dir,
                  style: TextStyle(
                    color: _kGold,
                    fontFamily: l.bodyFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${coptic.year} $yearSuffix',
                  style: TextStyle(
                    color: _kGold.withValues(alpha: 0.65),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glyph Tile Content ─────────────────────────────────────────────────────────
// Plain Material-icon tile, used for categories that don't have an
// illustrated asset yet (see HomeTileDef.asset in home_layout_defaults.dart).

class _GlyphTileContent extends StatelessWidget {
  const _GlyphTileContent({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, size: 40, color: _kGold),
    );
  }
}

// ── Games End Drawer ──────────────────────────────────────────────────────────

class _GamesEndDrawer extends StatelessWidget {
  const _GamesEndDrawer({required this.isAdmin, required this.layout});
  final bool isAdmin;
  final HomeLayoutModel layout;

  /// Current-language label for a drawer entry (admin override or default).
  String _label(String key, AppL10n l, String fallback) =>
      layout.sectionLabel(key, isAr: l.isAr, fallback: fallback);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.light
        ? const Color(0xFFF5F0E8)
        : const Color(0xFF0D1B2A);

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              color: _kNavy,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGold.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Center(child: AppLogo()),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ekklisiaApp,
                          style: TextStyle(
                            fontFamily: l.bodyFont,
                            color: _kGold,
                            fontSize: l.isAr ? 18 : 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l.appLabel,
                          style: TextStyle(
                            fontFamily: l.bodyFont,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: l.isAr ? 12 : 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Menu items (scrollable — the list has grown past what
            // fits on shorter screens, so it needs to scroll independently
            // of the fixed header above and footer below) ────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.auto_stories_outlined,
                    label: _label(HomeSectionKeys.drawerSaints, l, l.saints),
                    labelAlt: _label(
                      HomeSectionKeys.drawerSaints,
                      l.other,
                      l.other.saints,
                    ),
                    accentColor: const Color(0xFFC9A84C),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SaintsListScreen()),
                      );
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.church_outlined,
                    label: _label(HomeSectionKeys.drawerChurches, l, l.churches),
                    labelAlt: _label(
                      HomeSectionKeys.drawerChurches,
                      l.other,
                      l.other.churches,
                    ),
                    accentColor: const Color(0xFF7EB8C9),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChurchesScreen()),
                      );
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.gamepad_outlined,
                    label: _label(HomeSectionKeys.drawerGames, l, l.games),
                    labelAlt: _label(
                      HomeSectionKeys.drawerGames,
                      l.other,
                      l.other.games,
                    ),
                    accentColor: const Color(0xFFC9A84C),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GamesHomeScreen()),
                      );
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.photo_library_outlined,
                    label: _label(HomeSectionKeys.drawerGallery, l, l.gallery),
                    labelAlt: _label(
                      HomeSectionKeys.drawerGallery,
                      l.other,
                      l.other.gallery,
                    ),
                    accentColor: const Color(0xFF7EB8C9),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GalleryScreen()),
                      );
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.photo_camera_outlined,
                    label: _label(HomeSectionKeys.drawerSaintsPhotos, l, l.saintsPhotos),
                    labelAlt: _label(
                      HomeSectionKeys.drawerSaintsPhotos,
                      l.other,
                      l.other.saintsPhotos,
                    ),
                    accentColor: const Color(0xFF9C7EC9),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GalleryScreen(
                            galleryType: GalleryType.saintsLives,
                            titleAr: _label(
                              HomeSectionKeys.drawerSaintsPhotos,
                              AppL10n.ar,
                              'صور من حياة القديسين',
                            ),
                            titleEl: _label(
                              HomeSectionKeys.drawerSaintsPhotos,
                              AppL10n.el,
                              'Φωτογραφίες Βίοι Αγίων',
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.video_library_outlined,
                    label: _label(HomeSectionKeys.drawerElib, l, l.elib),
                    labelAlt: _label(
                      HomeSectionKeys.drawerElib,
                      l.other,
                      l.other.elib,
                    ),
                    accentColor: const Color(0xFFC9A84C),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ElectronicLibraryScreen(),
                        ),
                      );
                    },
                  ),

                  StreamBuilder<CategoryLabel?>(
                    stream: sl<CategoryLabelRepository>()
                        .watch(PdfCategory.artworks),
                    builder: (context, snap) {
                      final override = snap.data;
                      final artworksLabelAr =
                          (override != null && override.labelAr.isNotEmpty)
                              ? override.labelAr
                              : PdfCategory.labelAr[PdfCategory.artworks]!;
                      final artworksLabelEl =
                          (override != null && override.labelEl.isNotEmpty)
                              ? override.labelEl
                              : PdfCategory.labelEl[PdfCategory.artworks]!;
                      return _DrawerItem(
                        icon: Icons.palette_outlined,
                        label: l.isAr ? artworksLabelAr : artworksLabelEl,
                        labelAlt: l.isAr ? artworksLabelEl : artworksLabelAr,
                        accentColor: const Color(0xFF7EB8C9),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfContentListScreen(
                                category: PdfCategory.artworks,
                                labelAr:  artworksLabelAr,
                                labelEl:  artworksLabelEl,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  if (isAdmin) ...[
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: l.adminDashboard,
                      labelAlt: l.other.adminDashboard,
                      accentColor: const Color(0xFF7EB8C9),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/dashboard');
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── Footer divider ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(color: _kGold.withValues(alpha: 0.2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '✦',
                      style: TextStyle(
                        color: _kGold.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: _kGold.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),

            // ── Social links ──────────────────────────────────────────────
            const _SocialLinksRow(),

            // ── Clockfly copyright ───────────────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final uri = Uri.parse('https://www.clockfly.net');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Developed by ',
                        style: TextStyle(
                          color: brightness == Brightness.light
                              ? Colors.black.withValues(alpha: 0.40)
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                      Image.asset('assets/images/clockfly.png', height: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Clockfly Technologies',
                        style: TextStyle(
                          color: brightness == Brightness.light
                              ? Colors.black.withValues(alpha: 0.40)
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Social links row (bottom of drawer) ─────────────────────────────────────
// Reads the admin-editable config/social_links doc. Icons are hidden
// individually when their URL is empty, and the whole row collapses to
// nothing if no links are set.

class _SocialLinksRow extends StatelessWidget {
  const _SocialLinksRow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SocialLinksModel>(
      stream: sl<SocialLinksRepository>().watch(),
      builder: (context, snap) {
        final links = snap.data ?? SocialLinksModel.empty;
        final buttons = <Widget>[
          if (links.facebookUrl.isNotEmpty)
            _SocialIconButton(
              icon: Icons.facebook,
              color: const Color(0xFF1877F2),
              url: links.facebookUrl,
            ),
          if (links.youtubeUrl.isNotEmpty)
            _SocialIconButton(
              icon: Icons.smart_display_rounded,
              color: const Color(0xFFFF0000),
              url: links.youtubeUrl,
            ),
          if (links.viberUrl.isNotEmpty)
            _SocialIconButton(
              icon: Icons.chat_bubble_rounded,
              color: const Color(0xFF7360F2),
              url: links.viberUrl,
            ),
        ];

        if (buttons.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                buttons[i],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.color,
    required this.url,
  });

  final IconData icon;
  final Color color;
  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.labelAlt,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;

  /// Primary label — already resolved to the active language.
  final String label;

  /// Secondary label — the opposite language (bilingual display).
  final String labelAlt;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.l10n;
    final bg = brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF162535);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: l.bodyFont,
                        color: brightness == Brightness.light
                            ? const Color(0xFF1B2A4A)
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: l.isAr ? 18 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      labelAlt,
                      style: TextStyle(
                        fontFamily: l.other.bodyFont,
                        color: brightness == Brightness.light
                            ? const Color(0xFF6B7280)
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: l.isAr ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: accentColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
