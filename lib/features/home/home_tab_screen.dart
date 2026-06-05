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

import '../../core/theme/brightness_colors.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../../features/books/screens/book_detail_screen.dart';
import '../../features/daily_verse/daily_verse_cubit.dart';
import '../../features/daily_verse/daily_verse_state.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';

// ── Palette constants ─────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1B2A4A);
const _kCrimson = Color(0xFF6B1A1A);
const _kGold = Color(0xFFC9A84C);
const _kParchment = Color(0xFFF5F0E8);

class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key, required this.onGoToLibrary});

  final VoidCallback onGoToLibrary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bodyBg = brightness == Brightness.light
        ? _kParchment
        : BrightnessColors.bgDeep(brightness);

    return Scaffold(
      backgroundColor: bodyBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HomeAppBar(onSearch: onGoToLibrary),
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
                  enLabel: 'Content Library',
                  onAction: onGoToLibrary,
                  actionIsSearch: true,
                ),
                const SizedBox(height: 14),
                const _CategoryGrid(),

                const SizedBox(height: 24),

                // ── Recently Added ────────────────────────────────────
                _SectionHeader(
                  arLabel: 'أحدث الإضافات',
                  enLabel: 'Πρόσφατα προστέθηκε',
                  onAction: onGoToLibrary,
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

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return SliverAppBar(
      pinned: true,
      backgroundColor: _kNavy,
      elevation: 0,
      toolbarHeight: 82,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 0.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                _kGold.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(height: 1.1),
                    children: [
                      TextSpan(
                        text: isGreek ? 'Εκκλησία' : 'إكليسيا',
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isGreek
                      ? 'ΚΟΠΤΙΚΗ ΟΡΘΟΔΟΞΗ ΒΙΒΛΙΟΘΗΚΗ'
                      : 'المكتبة القبطية الأرثوذكسية',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(38, 38),
            painter: _CopticCrossPainter(color: _kGold),
          ),
          const SizedBox(width: 2),
        ],
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
      arLabel: 'التسابيح',
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
    required this.isGreek,
    required this.labelColor,
  });
  final _CategoryItem item;
  final bool isGreek;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
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
                child: Image.asset(
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
                          child: book.coverUrl.isNotEmpty
                              ? Image.network(
                                  book.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _coverFallback(book.titleAr, brightness),
                                )
                              : _coverFallback(book.titleAr, brightness),
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
