// lib/features/home/home_tab_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Main home dashboard tab — Byzantine / Orthodox liturgical aesthetic.
//
// Layout:
//   • Pinned header   — dark navy, [Ekklisia] serif + Coptic cross
//   • Daily verse     — crimson banner, cross icon left / verse info right
//   • Content Library — 3-col icon grid (10 categories)
//   • Recently Added  — horizontal book scroll
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/coptic_calendar_service.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/pdf_content_model.dart';
import '../../features/agbeya/screens/agbeya_home_screen.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/bible/bible_home_screen.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../../features/books/screens/book_detail_screen.dart';
import '../../features/coptic_calendar/coptic_calendar_screen.dart';
import '../../features/daily_verse/daily_verse_cubit.dart';
import '../../features/daily_verse/daily_verse_state.dart';
import '../../features/electronic_library/electronic_library_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/games/screens/games_home_screen.dart';
import '../../features/pdf_content/pdf_content_list_screen.dart';
import '../../features/saints/saints_list.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/cached_image.dart';

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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bodyBg = brightness == Brightness.light
        ? _kParchment
        : BrightnessColors.bgDeep(brightness);

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;
    final isAdmin = context.select<AuthCubit, bool>((c) => c.state.isAdmin);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bodyBg,
      endDrawer: _GamesEndDrawer(isGreek: isGreek, isAdmin: isAdmin),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HomeAppBar(
            onSearch: widget.onGoToLibrary,
            onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Daily Verse banner (flush to header) ─────────────
                const _DailyVerseBanner(),

                const SizedBox(height: 20),

                // ── Content Library ───────────────────────────────────
                _SectionHeader(
                  arLabel: 'مكتبة المحتوى',
                  enLabel: 'Βιβλιοθήκη Περιεχομένου',
                  onAction: widget.onGoToLibrary,
                  actionIsSearch: true,
                ),
                const SizedBox(height: 14),
                const _CategoryGrid(),

                const SizedBox(height: 24),

                // ── Recently Added ────────────────────────────────────
                _SectionHeader(
                  arLabel: 'أحدث الإضافات',
                  enLabel: 'Πρόσφατα προστέθηκε',
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
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────
// Banner image fills the expanded space (matches the Ekklisia brand banner).
// Collapsed: compact navy bar retaining the menu + bell icons.

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.onSearch, required this.onMenuTap});
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

      // ── Expanded: full banner image ───────────────────────────────────
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/ekklisia_banner.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
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
  const _DailyVerseBanner();

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return BlocBuilder<DailyVerseCubit, DailyVerseState>(
      builder: (context, state) {
        final verse = state.verse;

        final verseText = verse == null
            ? ''
            : (isGreek && verse.verseEl.isNotEmpty
                  ? verse.verseEl
                  : verse.verseAr);
        final reference = verse == null
            ? ''
            : (isGreek && verse.referenceEl.isNotEmpty
                  ? verse.referenceEl
                  : verse.referenceAr);

        return Container(
          color: _kCrimson,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Cross icon thumbnail ──────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.transparent, width: 0.8),
                ),
                child: Image.asset('assets/images/icons/001.png'),
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
                              isGreek ? 'Ο ΣΤΙΧΟΣ ΤΗΣ ΗΜΕΡΑΣ' : 'آية اليوم',
                              textDirection: isGreek
                                  ? TextDirection.ltr
                                  : TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: isGreek ? null : 'Scheherazade',
                                color: _kGold,
                                fontSize: isGreek ? 9 : 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: isGreek ? 1.5 : 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (verse != null) ...[
                            Text(
                              verseText,
                              textDirection: isGreek
                                  ? TextDirection.ltr
                                  : TextDirection.rtl,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: isGreek ? null : 'Scheherazade',
                                color: Colors.white,
                                fontSize: isGreek ? 13 : 15,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              reference,
                              textDirection: isGreek
                                  ? TextDirection.ltr
                                  : TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: isGreek ? null : 'Scheherazade',
                                color: const Color(0xFFE8C8A0),
                                fontSize: isGreek ? 11 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            Text(
                              isGreek
                                  ? 'Καθημερινός Στίχος'
                                  : 'القراءة اليومية',
                              textDirection: isGreek
                                  ? TextDirection.ltr
                                  : TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: isGreek ? null : 'Scheherazade',
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: isGreek ? 13 : 15,
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
    required this.arLabel,
    required this.enLabel,
    this.onAction,
    this.actionIsSearch = false,
  });

  final String arLabel;
  final String enLabel;
  final VoidCallback? onAction;
  final bool actionIsSearch;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final titleColor = brightness == Brightness.light
        ? const Color(0xFF2C1A0E)
        : BrightnessColors.goldLight(brightness);

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
                  color: _kGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isGreek ? enLabel : arLabel,
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: titleColor,
                  fontSize: isGreek ? 14 : 18,
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
                      isGreek ? 'Δείτε Όλα' : 'عرض الكل',
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: _kGold,
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
      arLabel: 'الأجبية',
      enLabel: 'Αγπέγια',
      icon: 'assets/images/icons/agbeya.jpg',
      bgColor: Color(0xFF1B2A4A),
    ),
    _CategoryItem(
      arLabel: 'الترانيم',
      enLabel: 'Ψαλμωδία',
      icon: 'assets/images/icons/psalmody.jpg',
      bgColor: Color(0xFF2A1A38),
    ),
    _CategoryItem(
      arLabel: 'الكتاب المقدس',
      enLabel: 'άγια γραφή',
      icon: 'assets/images/icons/bible.jpg',
      bgColor: Color(0xFF1A2C1A),
    ),
    _CategoryItem(
      arLabel: 'القداسات',
      enLabel: 'Λειτουργία',
      icon: 'assets/images/icons/liturgies.jpg',
      bgColor: Color(0xFF2C1A0E),
    ),
    _CategoryItem(
      arLabel: 'القراءات',
      enLabel: 'Αναγνώσεις',
      icon: 'assets/images/icons/readings.jpg',
      bgColor: Color(0xFF1B2A4A),
    ),
    _CategoryItem(
      arLabel: 'الألحان',
      enLabel: 'ύμνοι',
      icon: 'assets/images/icons/hymns.jpg',
      bgColor: Color(0xFF2A1A38),
    ),
    _CategoryItem(
      arLabel: 'مناسبات',
      enLabel: 'περιστάσεις',
      icon: 'assets/images/icons/special.jpg',
      bgColor: Color(0xFF6B1A1A),
    ),
    _CategoryItem(
      arLabel: 'التقويم القبطي',
      enLabel: 'Κοπτικό Ημερολόγιο',
      icon: '',
      bgColor: Color(0xFF1A3A2A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;
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
        itemCount: _categories.length,
        itemBuilder: (context, i) => _CategoryTile(
          item: _categories[i],
          index: i,
          isGreek: isGreek,
          labelColor: labelColor,
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
    required this.bgColor,
  });
  final String arLabel;
  final String enLabel;
  final String icon;
  final Color bgColor;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.item,
    required this.index,
    required this.isGreek,
    required this.labelColor,
  });
  final _CategoryItem item;
  final int index;
  final bool isGreek;
  final Color labelColor;

  void _onTap(BuildContext context) {
    switch (index) {
      case 0: // الأجبية
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgbeyaHomeScreen()),
        );
        break;
      case 1: // الترانيم
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfContentListScreen(
              category: PdfCategory.psalmody,
              labelAr: PdfCategory.labelAr[PdfCategory.psalmody]!,
              labelEl: PdfCategory.labelEl[PdfCategory.psalmody]!,
            ),
          ),
        );
        break;
      case 2: // الكتاب المقدس
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
        );
        break;
      case 3: // القداسات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfContentListScreen(
              category: PdfCategory.liturgy,
              labelAr: PdfCategory.labelAr[PdfCategory.liturgy]!,
              labelEl: PdfCategory.labelEl[PdfCategory.liturgy]!,
            ),
          ),
        );
        break;
      case 4: // القراءات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfContentListScreen(
              category: PdfCategory.readings,
              labelAr: PdfCategory.labelAr[PdfCategory.readings]!,
              labelEl: PdfCategory.labelEl[PdfCategory.readings]!,
            ),
          ),
        );
        break;
      case 5: // الألحان
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfContentListScreen(
              category: PdfCategory.hymns,
              labelAr: PdfCategory.labelAr[PdfCategory.hymns]!,
              labelEl: PdfCategory.labelEl[PdfCategory.hymns]!,
            ),
          ),
        );
        break;
      case 6: // مناسبات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfContentListScreen(
              category: PdfCategory.occasions,
              labelAr: PdfCategory.labelAr[PdfCategory.occasions]!,
              labelEl: PdfCategory.labelEl[PdfCategory.occasions]!,
            ),
          ),
        );
        break;
      case 7: // التقويم القبطي
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CopticCalendarScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _kGold.withValues(alpha: 0.65),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.bgColor.withValues(alpha: 0.35),
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
                child: index == 7
                    ? _CalendarTileContent(bgColor: item.bgColor)
                    : Image.asset(
                        item.icon,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isGreek ? item.enLabel : item.arLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              color: labelColor,
              fontSize: isGreek ? 10 : 12,
              fontWeight: FontWeight.w600,
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
                          textDirection: isGreek
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
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

// ── Calendar Tile Content ─────────────────────────────────────────────────────

class _CalendarTileContent extends StatelessWidget {
  const _CalendarTileContent({required this.bgColor});
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final coptic = CopticCalendarService.fromGregorian(DateTime.now());
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );
    final monthName = isGreek
        ? CopticCalendarService.monthNameEl(coptic.month)
        : CopticCalendarService.monthNameAr(coptic.month);
    final yearSuffix = isGreek ? 'Α.D.' : 'م';

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
                  textDirection: isGreek
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  style: TextStyle(
                    color: _kGold,
                    fontFamily: isGreek ? null : 'Scheherazade',
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

// ── Games End Drawer ──────────────────────────────────────────────────────────

class _GamesEndDrawer extends StatelessWidget {
  const _GamesEndDrawer({required this.isGreek, required this.isAdmin});
  final bool isGreek;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
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
                    child: const Center(
                      child: Text(
                        '✦',
                        style: TextStyle(color: _kGold, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGreek ? 'Εκκλησία' : 'إكليسيا',
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: _kGold,
                            fontSize: isGreek ? 15 : 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isGreek ? 'Εφαρμογή' : 'التطبيق',
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: isGreek ? 10 : 12,
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

            // ── Menu items ───────────────────────────────────────────────
            _DrawerItem(
              icon: Icons.auto_stories_outlined,
              labelAr: 'القديسون',
              labelEl: 'Άγιοι',
              isGreek: isGreek,
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
              icon: Icons.gamepad_outlined,
              labelAr: 'الألعاب',
              labelEl: 'Παιχνίδια',
              isGreek: isGreek,
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
              labelAr: 'معرض الصور',
              labelEl: 'στοά',
              isGreek: isGreek,
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
              icon: Icons.video_library_outlined,
              labelAr: 'المكتبة الالكترونية',
              labelEl: 'Ηλεκτρονική Βιβλιοθήκη',
              isGreek: isGreek,
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

            if (isAdmin) ...[
              _DrawerItem(
                icon: Icons.admin_panel_settings_outlined,
                labelAr: 'لوحة التحكم',
                labelEl: 'Πίνακας Διαχείρισης',
                isGreek: isGreek,
                accentColor: const Color(0xFF7EB8C9),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/dashboard');
                },
              ),
            ],

            const Spacer(),

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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.labelAr,
    required this.labelEl,
    required this.isGreek,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String labelAr;
  final String labelEl;
  final bool isGreek;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
                      isGreek ? labelEl : labelAr,
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: brightness == Brightness.light
                            ? const Color(0xFF1B2A4A)
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: isGreek ? 15 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isGreek ? labelAr : labelEl,
                      style: TextStyle(
                        fontFamily: isGreek ? 'Scheherazade' : null,
                        color: brightness == Brightness.light
                            ? const Color(0xFF6B7280)
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: isGreek ? 13 : 11,
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
