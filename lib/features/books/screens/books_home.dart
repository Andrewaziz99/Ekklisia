// lib/features/books/screens/books_home.dart
// ─────────────────────────────────────────────────────────────────────────────
// Library tab — All Books / Downloaded / Recent with grid/list toggle.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../data/models/book_category_model.dart';
import '../../../data/repositories/book_category_repository.dart';
import '../../../features/daily_verse/widgets/daily_verse_card.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../features/settings/cubit/settings_cubit.dart';
import '../../../services/settings_service.dart';
import '../cubit/books_cubit.dart';
import '../cubit/books_state.dart';
import '../widgets/book_card.dart';
import 'book_detail_screen.dart';

class BooksHomeScreen extends StatefulWidget {
  const BooksHomeScreen({super.key});

  @override
  State<BooksHomeScreen> createState() => _BooksHomeScreenState();
}

class _BooksHomeScreenState extends State<BooksHomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    context.read<BooksCubit>().watchBooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Scaffold(
      backgroundColor: bgDeep,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildSliverAppBar(brightness, isGreek),
        ],
        body: Column(
          children: [
            // ── Daily Bible Verse ──────────────────────────────────────
            const DailyVerseCard(),

            // ── Search ────────────────────────────────────────────────
            _SearchBar(
              controller: _searchCtrl,
              onChanged: context.read<BooksCubit>().search,
              onClear: () {
                _searchCtrl.clear();
                context.read<BooksCubit>().clearSearch();
              },
            ),

            // ── Category Chips ────────────────────────────────────────
            const _CategoryFilter(),

            Divider(height: 1, color: goldBorder),

            // ── Book content ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _BooksContent(isListView: _isListView, filter: _AllFilter()),
                  _BooksContent(
                      isListView: _isListView,
                      filter: _DownloadedFilter()),
                  _BooksContent(isListView: _isListView, filter: _RecentFilter()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(Brightness brightness, bool isGreek) {
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = Theme.of(context).primaryColor;


    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: bgDeep,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/Ekklisia_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.12),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: BrightnessColors.headerGradient(brightness),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✦',
                      style: TextStyle(color: goldDim, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    isGreek ? 'ΒΙΒΛΙΟΘΗΚΗ' : 'المكتبة',
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
                    isGreek ? 'LIBRARY' : 'LIBRARY',
                    style: TextStyle(
                      color: goldDim,
                      fontSize: 9,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Tab bar + view toggle
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: bgDeep,
            border: Border(
              top: BorderSide(color: goldBorder, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: gold,
                  unselectedLabelColor: goldDim,
                  indicatorColor: gold,
                  indicatorWeight: 2,
                  labelStyle: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    fontSize: isGreek ? 11 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    fontSize: isGreek ? 11 : 13,
                  ),
                  tabs: [
                    Tab(text: isGreek ? 'ΟΛΑ' : 'الكل'),
                    Tab(text: isGreek ? 'ΛΗΨΕΙΣ' : 'تم التحميل'),
                    Tab(text: isGreek ? 'ΠΡΟΣΦΑΤΑ' : 'الأحدث'),
                  ],
                ),
              ),
              // Grid / List toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IconButton(
                  icon: Icon(
                    _isListView
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                    color: goldDim,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isListView = !_isListView),
                  tooltip: _isListView ? 'Grid view' : 'List view',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter interfaces ─────────────────────────────────────────────────────────

abstract class _BookFilter {
  List apply(List books);
}

class _AllFilter extends _BookFilter {
  @override
  List apply(List books) => books;
}

class _DownloadedFilter extends _BookFilter {
  @override
  List apply(List books) =>
      books.where((b) => b.isPublished).toList(); // placeholder
}

class _RecentFilter extends _BookFilter {
  @override
  List apply(List books) {
    final sorted = List.from(books);
    // Sort by createdAt descending if available, else first 10
    return sorted.take(10).toList();
  }
}

// ── Books content (shared between tabs) ──────────────────────────────────────

class _BooksContent extends StatelessWidget {
  const _BooksContent({
    required this.isListView,
    required this.filter,
  });
  final bool isListView;
  final _BookFilter filter;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;
    final langCode = isGreek ? 'el' : 'ar';

    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, state) {
        if (state.isLoading) return _LoadingGrid();

        if (state.hasError) {
          return _ErrorView(
              message: state.errorMessage ??
                  (isGreek ? 'Σφάλμα φόρτωσης' : 'حدث خطأ'));
        }

        final books = filter.apply(state.filteredBooks);

        if (books.isEmpty) return _EmptyView(isGreek: isGreek);

        return RefreshIndicator(
          color: Theme.of(context).primaryColor,
          backgroundColor: BrightnessColors.bgMid(
              Theme.of(context).brightness),
          onRefresh: () async => context
              .read<BooksCubit>()
              .watchBooks(category: state.selectedCategory),
          child: isListView
              ? _ListView(books: books, lang: langCode)
              : _GridView(books: books, lang: langCode),
        );
      },
    );
  }
}

// ── Grid view ─────────────────────────────────────────────────────────────────

class _GridView extends StatelessWidget {
  const _GridView({required this.books, required this.lang});
  final List books;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return BookCard(
          book: book,
          currentLang: lang,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BookDetailScreen(book: book)),
          ),
        );
      },
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  const _ListView({required this.books, required this.lang});
  final List books;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;
    final isGreek = lang == 'el';

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final book = books[i];
        final title = isGreek && book.titleEl.isNotEmpty
            ? book.titleEl
            : book.titleAr;
        final description = isGreek && book.descriptionEl.isNotEmpty
            ? book.descriptionEl
            : book.descriptionAr;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BookDetailScreen(book: book)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgMid,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: goldBorder, width: 0.5),
            ),
            child: Row(
              children: [
                // Cover
                Container(
                  width: 52,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: goldBorder, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CachedImage(
                      url: book.coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: _fallbackCover(book.titleAr, bgElevated),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: isGreek
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        textDirection: isGreek
                            ? TextDirection.ltr
                            : TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: isGreek ? null : 'Scheherazade',
                          color: textPrimary,
                          fontSize: isGreek ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          textDirection: isGreek
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: isGreek
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: goldBorder, width: 0.5),
                            ),
                            child: Text(
                              book.category,
                              style: TextStyle(
                                color: gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: goldBorder, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackCover(String titleAr, Color bg) => Container(
        color: bg,
        child: Center(
          child: Text(
            titleAr.isNotEmpty
                ? titleAr.substring(0, titleAr.length > 1 ? 2 : 1)
                : '✦',
            style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: Color(0xFFC8A84B),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = Theme.of(context).primaryColor;
    final bgElevated = BrightnessColors.bgElevated(brightness);

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection:
            isGreek ? TextDirection.ltr : TextDirection.rtl,
        style: TextStyle(
          fontFamily: isGreek ? null : 'Scheherazade',
          color: textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText:
              isGreek ? 'Αναζήτηση βιβλίου…' : 'ابحث عن كتاب…',
          hintStyle: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: textSecondary,
          ),
          prefixIcon: Icon(Icons.search, color: goldDim),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: bgElevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
}

// ── Category Filter ───────────────────────────────────────────────────────────
// Streams visible categories from Firestore so any admin changes are reflected
// immediately without restarting the app.

class _CategoryFilter extends StatefulWidget {
  const _CategoryFilter();

  @override
  State<_CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<_CategoryFilter> {
  final _repo = sl<BookCategoryRepository>();
  StreamSubscription<List<BookCategory>>? _sub;
  List<BookCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchVisibleCategories().listen(
      (cats) { if (mounted) setState(() => _categories = cats); },
      onError: (_) {/* silently fall back to empty — "All" chip still works */},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return BlocBuilder<BooksCubit, BooksState>(
      buildWhen: (prev, curr) =>
          prev.selectedCategory != curr.selectedCategory,
      builder: (context, state) {
        return SizedBox(
          height: 44,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            scrollDirection: Axis.horizontal,
            children: [
              // "All" chip
              _chip(
                context,
                label: isGreek ? 'ΟΛΑ' : 'الكل',
                isSelected: state.selectedCategory == null,
                isGreek: isGreek,
                onTap: () =>
                    context.read<BooksCubit>().filterByCategory(null),
              ),
              // Dynamic chips from Firestore
              ..._categories.map((cat) {
                final label = isGreek
                    ? (cat.nameEl.isNotEmpty ? cat.nameEl : cat.nameAr)
                    : (cat.nameAr.isNotEmpty ? cat.nameAr : cat.slug);
                return _chip(
                  context,
                  label: label,
                  isSelected: state.selectedCategory == cat.slug,
                  isGreek: isGreek,
                  onTap: () =>
                      context.read<BooksCubit>().filterByCategory(cat.slug),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required bool isGreek,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final gold = Theme.of(context).primaryColor;
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldSubtle = BrightnessColors.goldSubtle(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? goldSubtle : bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gold : goldBorder,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: isSelected ? goldLight : textSecondary,
            fontSize: isGreek ? 11 : 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Loading / Empty / Error ───────────────────────────────────────────────────

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _ShimmerCard(brightness: brightness),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.brightness});
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Container(
      decoration: BoxDecoration(
        color: bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: Container(color: bgElevated),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: bgElevated,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                          color: bgElevated,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_books_outlined, size: 56, color: goldDim),
            const SizedBox(height: 16),
            Text(
              isGreek ? 'Δεν βρέθηκαν βιβλία' : 'لا توجد كتب',
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: textSecondary,
                fontSize: isGreek ? 15 : 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFA89060), fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.read<BooksCubit>().watchBooks(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
