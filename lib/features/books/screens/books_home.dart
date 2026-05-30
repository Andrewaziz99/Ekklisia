import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/brightness_colors.dart';
import '../cubit/books_cubit.dart';
import '../cubit/books_state.dart';
import '../widgets/book_card.dart';
import 'book_detail_screen.dart';

class BooksHomeScreen extends StatefulWidget {
  const BooksHomeScreen({super.key});

  @override
  State<BooksHomeScreen> createState() => _BooksHomeScreenState();
}

class _BooksHomeScreenState extends State<BooksHomeScreen> {
  final _searchCtrl = TextEditingController();
  static const String _lang = 'ar'; // TODO: connect to LanguageProvider

  @override
  void initState() {
    super.initState();
    context.read<BooksCubit>().watchBooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildSliverAppBar()],
        body: Column(
          children: [
            // ── Search ──────────────────────────────────────────────────
            _SearchBar(
              controller: _searchCtrl,
              onChanged: context.read<BooksCubit>().search,
              onClear: () {
                _searchCtrl.clear();
                context.read<BooksCubit>().clearSearch();
              },
            ),

            // ── Category Chips ───────────────────────────────────────────
            const _CategoryFilter(),

            Divider(height: 1, color: goldBorder),

            // ── Book Grid ────────────────────────────────────────────────
            Expanded(child: _BookGrid(lang: _lang)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 140,
      backgroundColor: bgDeep,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background texture
            Image.asset(
              'assets/images/Ekklisia_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.15),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: BrightnessColors.headerGradient(Theme.of(context).brightness),
              ),
            ),
            // Ornamental cross motif at top
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '✦',
                  style: TextStyle(
                    color: goldDim,
                    fontSize: 18,
                    height: 1,
                  ),
                ),
              ),
            ),
            // Title
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المكتبة',
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color: goldLight,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LIBRARY',
                      style: TextStyle(
                        color: goldDim,
                        fontSize: 10,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.5, color: goldBorder),
      ),
    );
  }
}

// ── Search Bar ──────────────────────────────────────────────────────────────

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Scheherazade',
          color: textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن كتاب…',
          hintStyle: TextStyle(
            fontFamily: 'Scheherazade',
            color: textSecondary,
          ),
          prefixIcon: Icon(Icons.search, color: goldDim),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: textSecondary,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: bgElevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: goldBorder,
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: gold,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category Filter ──────────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter();

  static const _labels = <String, String>{
    'bible': 'الإنجيل',
    'prayers': 'الصلوات',
    'liturgy': 'القداس',
    'hymns': 'التسابيح',
    'saints': 'القديسون',
    'fathers': 'الآباء',
    'commentaries': 'الشروحات',
    'studies': 'الدراسات',
    'other': 'أخرى',
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BooksCubit, BooksState>(
      buildWhen: (prev, curr) => prev.selectedCategory != curr.selectedCategory,
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
                label: 'الكل',
                isSelected: state.selectedCategory == null,
                onTap: () => context.read<BooksCubit>().filterByCategory(null),
              ),
              ...AppConstants.bookCategories.map(
                (cat) => _chip(
                  context,
                  label: _labels[cat] ?? cat,
                  isSelected: state.selectedCategory == cat,
                  onTap: () => context.read<BooksCubit>().filterByCategory(cat),
                ),
              ),
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
          color: isSelected
              ? goldSubtle
              : bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? gold
                : goldBorder,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: isSelected
                ? goldLight
                : textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Book Grid ────────────────────────────────────────────────────────────────

class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, state) {
        if (state.isLoading) return _LoadingGrid();

        if (state.hasError) {
          return _ErrorView(message: state.errorMessage ?? 'حدث خطأ');
        }

        if (state.isEmpty) return const _EmptyView();

        return RefreshIndicator(
          color: Theme.of(context).primaryColor,
          backgroundColor: BrightnessColors.bgMid(Theme.of(context).brightness),
          onRefresh: () async => context.read<BooksCubit>().watchBooks(
            category: state.selectedCategory,
          ),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            itemCount: state.filteredBooks.length,
            itemBuilder: (context, i) {
              final book = state.filteredBooks[i];
              return BookCard(
                book: book,
                currentLang: lang,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(book: book),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LoadingGrid extends StatelessWidget {
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
      itemCount: 6,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: _shimmerBox(bgElevated),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [_shimmerLine(bgElevated, 1.0), _shimmerLine(bgElevated, 0.6)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(Color fill) => Container(color: fill);

  Widget _shimmerLine(Color fill, double fraction) => FractionallySizedBox(
    widthFactor: fraction,
    child: Container(
      height: 10,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
            Icon(
              Icons.library_books_outlined,
              size: 56,
              color: goldDim,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد كتب بعد',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: textSecondary,
                fontSize: 18,
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
    final textSecondary = BrightnessColors.textSecondary(Theme.of(context).brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
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
