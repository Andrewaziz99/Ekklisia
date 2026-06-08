// lib/features/bible/bible_home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bible home — Old & New Testament book grids with search.
// Uses BibleRepository (asset-loaded XML, singleton) + BrightnessColors.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/brightness_colors.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/bible_model.dart';
import '../../data/repositories/bible_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import 'bible_chapter_screen.dart';

class BibleHomeScreen extends StatefulWidget {
  const BibleHomeScreen({super.key});

  @override
  State<BibleHomeScreen> createState() => _BibleHomeScreenState();
}

class _BibleHomeScreenState extends State<BibleHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<BibleBook> _filter(List<BibleBook> books, bool isGreek) {
    if (_query.isEmpty) return books;
    return books.where((b) => TextNormalizer.anyContains(
      [b.nameAr, b.nameEl],
      _query,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;
    final langCode = isGreek ? 'el' : 'ar';

    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          _BibleSliverAppBar(
            brightness: brightness,
            isGreek: isGreek,
            tabCtrl: _tabCtrl,
            gold: gold,
            goldDim: goldDim,
            goldBorder: goldBorder,
          ),
          // Search bar pinned below AppBar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchBarDelegate(
              brightness: brightness,
              isGreek: isGreek,
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // Old Testament
            _BookGrid(
              future: BibleRepository.instance.loadOldTestament(langCode),
              isGreek: isGreek,
              brightness: brightness,
              query: _query,
              filterFn: _filter,
              isOldTestament: true,
            ),
            // New Testament
            _BookGrid(
              future: BibleRepository.instance.loadNewTestament(langCode),
              isGreek: isGreek,
              brightness: brightness,
              query: _query,
              filterFn: _filter,
              isOldTestament: false,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sliver App Bar ────────────────────────────────────────────────────────────

class _BibleSliverAppBar extends StatelessWidget {
  const _BibleSliverAppBar({
    required this.brightness,
    required this.isGreek,
    required this.tabCtrl,
    required this.gold,
    required this.goldDim,
    required this.goldBorder,
  });

  final Brightness brightness;
  final bool isGreek;
  final TabController tabCtrl;
  final Color gold;
  final Color goldDim;
  final Color goldBorder;

  @override
  Widget build(BuildContext context) {
    final goldLight = BrightnessColors.goldLight(brightness);
    final bgDeep = BrightnessColors.bgDeep(brightness);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: bgDeep,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: gold, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: BrightnessColors.headerGradient(brightness),
            border: Border(
              bottom: BorderSide(color: goldBorder, width: 0.8),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✦',
                    style: TextStyle(color: goldDim, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGreek ? 'ΑΓΙΑ ΓΡΑΦΗ' : 'الكتاب المقدس',
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: goldLight,
                      fontSize: isGreek ? 20 : 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: isGreek ? 3.0 : 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HOLY BIBLE',
                    style: TextStyle(
                      color: goldDim,
                      fontSize: 9,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          color: BrightnessColors.bgDeep(brightness),
          child: TabBar(
            controller: tabCtrl,
            labelColor: gold,
            unselectedLabelColor: goldDim,
            indicatorColor: gold,
            indicatorWeight: 2,
            labelStyle: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              fontSize: isGreek ? 12 : 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              fontSize: isGreek ? 12 : 14,
            ),
            tabs: [
              Tab(text: isGreek ? 'Παλαιά Διαθήκη' : 'العهد القديم'),
              Tab(text: isGreek ? 'Καινή Διαθήκη' : 'العهد الجديد'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search Bar Delegate ───────────────────────────────────────────────────────

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _SearchBarDelegate({
    required this.brightness,
    required this.isGreek,
    required this.controller,
    required this.onChanged,
  });

  final Brightness brightness;
  final bool isGreek;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = BrightnessColors.gold(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Container(
      color: bgDeep,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
        style: TextStyle(
          fontFamily: isGreek ? null : 'Scheherazade',
          color: textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: isGreek ? 'Αναζήτηση βιβλίου…' : 'ابحث عن سفر…',
          hintStyle: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, color: goldDim, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 16, color: textSecondary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: bgElevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: goldBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: gold, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchBarDelegate old) =>
      old.brightness != brightness ||
      old.isGreek != isGreek ||
      old.controller != controller;
}

// ── Book Grid ─────────────────────────────────────────────────────────────────

class _BookGrid extends StatelessWidget {
  const _BookGrid({
    required this.future,
    required this.isGreek,
    required this.brightness,
    required this.query,
    required this.filterFn,
    required this.isOldTestament,
  });

  final Future<List<BibleBook>> future;
  final bool isGreek;
  final Brightness brightness;
  final String query;
  final List<BibleBook> Function(List<BibleBook>, bool) filterFn;
  final bool isOldTestament;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BibleBook>>(
      future: future,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: BrightnessColors.gold(brightness),
              strokeWidth: 2,
            ),
          );
        }

        // Error
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorView(
            isGreek: isGreek,
            brightness: brightness,
            onRetry: () => (context as Element).markNeedsBuild(),
          );
        }

        final books = filterFn(snapshot.data!, isGreek);

        if (books.isEmpty) {
          return _EmptyView(isGreek: isGreek, brightness: brightness);
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemCount: books.length,
          itemBuilder: (context, i) => _BookCard(
            book: books[i],
            isGreek: isGreek,
            brightness: brightness,
            isOldTestament: isOldTestament,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BibleChapterScreen(book: books[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Book Card ─────────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.isGreek,
    required this.brightness,
    required this.isOldTestament,
    required this.onTap,
  });

  final BibleBook book;
  final bool isGreek;
  final Brightness brightness;
  final bool isOldTestament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final maroon = BrightnessColors.maroon(brightness);

    final accentColor = isOldTestament ? maroon : gold;
    final name = isGreek ? book.nameEl : book.nameAr;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: goldBorder, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.25 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Book number badge — top-left
            Positioned(
              top: 5,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${book.number}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            // Book name — centered
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 20, 6, 6),
              child: Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textPrimary,
                    fontSize: isGreek ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            // Chapter count — bottom right
            Positioned(
              bottom: 5,
              right: 6,
              child: Text(
                isGreek
                    ? '${book.chapterCount}κ'
                    : '${book.chapterCount}أص',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: goldDim,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error / Empty views ───────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.isGreek,
    required this.brightness,
    required this.onRetry,
  });

  final bool isGreek;
  final Brightness brightness;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final gold = BrightnessColors.gold(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              isGreek ? 'Σφάλμα φόρτωσης' : 'حدث خطأ أثناء التحميل',
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: textSecondary,
                fontSize: isGreek ? 14 : 16,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: gold,
                side: BorderSide(color: gold),
              ),
              child: Text(
                isGreek ? 'Επανάληψη' : 'إعادة المحاولة',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isGreek, required this.brightness});

  final bool isGreek;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 52, color: goldDim),
          const SizedBox(height: 12),
          Text(
            isGreek ? 'Δεν βρέθηκαν βιβλία' : 'لا توجد أسفار',
            style: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              color: textSecondary,
              fontSize: isGreek ? 14 : 17,
            ),
          ),
        ],
      ),
    );
  }
}
