// lib/features/bookmarks/bookmarks_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bookmarks — live list of the user's saved PDF content items/pages and
// Bible chapters/verses, grouped by section. Tapping a row reopens the
// content at the saved spot; the trailing icon removes it.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/bookmark_model.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/repositories/bible_repository.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/cached_image.dart';
import '../bible/bible_reader_screen.dart';
import '../pdf_content/generic_pdf_viewer_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  static const List<String> _categoryOrder = [
    PdfCategory.psalmody,
    PdfCategory.liturgy,
    PdfCategory.readings,
    PdfCategory.hymns,
    PdfCategory.occasions,
    PdfCategory.theses,
    PdfCategory.christianBooks,
    PdfCategory.serviceBooks,
  ];

  Future<void> _openBible(
    BuildContext context,
    BookmarkModel b, {
    required bool isGreek,
  }) async {
    final langCode = isGreek ? 'el' : 'ar';
    final books = await BibleRepository.instance.loadBooks(langCode);
    final book = books.where((bk) => bk.number == b.bookNumber).firstOrNull;
    if (book == null || !context.mounted) return;
    final chapterIndex =
        (b.chapter - 1).clamp(0, book.chapters.length - 1);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BibleReaderScreen(book: book, chapterIndex: chapterIndex),
      ),
    );
  }

  void _openContent(BuildContext context, BookmarkModel b) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenericPdfViewerScreen(
          url:         b.pdfUrl,
          titleAr:     b.titleAr,
          titleEl:     b.titleEl,
          contentId:   b.contentId,
          category:    b.category,
          coverUrl:    b.coverUrl,
          initialPage: b.page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;

    final l = context.l10n;
    final isGreek = !l.isAr;

    return Scaffold(
      backgroundColor: bgDeep,
      body: StreamBuilder<List<BookmarkModel>>(
        stream: sl<BookmarkRepository>().watchAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('[Bookmarks] watchAll error: ${snap.error}');
          }
          final bookmarks = snap.data ?? const <BookmarkModel>[];

          return CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 110,
                backgroundColor: bgDeep,
                automaticallyImplyLeading: false,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: BrightnessColors.headerGradient(brightness),
                      border: Border(
                        bottom: BorderSide(color: goldBorder, width: 0.5),
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              children: [
                                Text('✦',
                                    style: TextStyle(
                                        color: goldDim, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  l.bookmarks,
                                  style: TextStyle(
                                    fontFamily: l.bodyFont,
                                    color: goldLight,
                                    fontSize: isGreek ? 18 : 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: isGreek ? 2.0 : 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 0.5, color: goldBorder),
                ),
              ),

              if (snap.hasError)
                SliverFillRemaining(
                  child: _ErrorLoadingBookmarks(
                    isGreek: isGreek,
                    goldDim: goldDim,
                    textSecondary: textSecondary,
                    error: snap.error.toString(),
                  ),
                )
              else if (bookmarks.isEmpty)
                SliverFillRemaining(
                  child: _EmptyBookmarks(
                    l: l,
                    isGreek: isGreek,
                    bgMid: bgMid,
                    goldBorder: goldBorder,
                    goldDim: goldDim,
                    textSecondary: textSecondary,
                  ),
                )
              else
                ..._buildSections(
                  context,
                  bookmarks,
                  l: l,
                  isGreek: isGreek,
                  bgMid: bgMid,
                  bgElevated: bgElevated,
                  goldBorder: goldBorder,
                  gold: gold,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    List<BookmarkModel> bookmarks, {
    required AppL10n l,
    required bool isGreek,
    required Color bgMid,
    required Color bgElevated,
    required Color goldBorder,
    required Color gold,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final slivers = <Widget>[];

    final bibleBookmarks =
        bookmarks.where((b) => b.type == BookmarkType.bible).toList();
    if (bibleBookmarks.isNotEmpty) {
      slivers.add(_sectionHeader(l.bible, textSecondary));
      slivers.add(_sectionList(
        context,
        bibleBookmarks,
        isGreek: isGreek,
        bgMid: bgMid,
        bgElevated: bgElevated,
        goldBorder: goldBorder,
        gold: gold,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ));
    }

    for (final category in _categoryOrder) {
      final items = bookmarks
          .where((b) => b.type == BookmarkType.content && b.category == category)
          .toList();
      if (items.isEmpty) continue;
      final label = isGreek
          ? (PdfCategory.labelEl[category] ?? category)
          : (PdfCategory.labelAr[category] ?? category);
      slivers.add(_sectionHeader(label, textSecondary));
      slivers.add(_sectionList(
        context,
        items,
        isGreek: isGreek,
        bgMid: bgMid,
        bgElevated: bgElevated,
        goldBorder: goldBorder,
        gold: gold,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      ));
    }

    return slivers;
  }

  Widget _sectionHeader(String label, Color textSecondary) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _sectionList(
    BuildContext context,
    List<BookmarkModel> items, {
    required bool isGreek,
    required Color bgMid,
    required Color bgElevated,
    required Color goldBorder,
    required Color gold,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final b = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BookmarkRow(
                bookmark: b,
                isGreek: isGreek,
                bgMid: bgMid,
                bgElevated: bgElevated,
                goldBorder: goldBorder,
                gold: gold,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => b.isBible
                    ? _openBible(context, b, isGreek: isGreek)
                    : _openContent(context, b),
                onDelete: () => sl<BookmarkRepository>().remove(b.id),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks({
    required this.l,
    required this.isGreek,
    required this.bgMid,
    required this.goldBorder,
    required this.goldDim,
    required this.textSecondary,
  });

  final AppL10n l;
  final bool isGreek;
  final Color bgMid;
  final Color goldBorder;
  final Color goldDim;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgMid,
            border: Border.all(color: goldBorder, width: 0.5),
          ),
          child: Icon(
            Icons.bookmarks_outlined,
            size: 36,
            color: goldDim,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l.noBookmarks,
          style: TextStyle(
            fontFamily: l.bodyFont,
            color: textSecondary,
            fontSize: isGreek ? 15 : 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isGreek
              ? 'Προσθέστε σελιδοδείκτες κατά την ανάγνωση'
              : 'أضف إشارات مرجعية أثناء القراءة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: textSecondary.withOpacity(0.6),
            fontSize: isGreek ? 12 : 14,
          ),
        ),
      ],
    );
  }
}

// ── Error state ──────────────────────────────────────────────────────────────
// Shown instead of the empty state when the bookmarks query itself failed —
// most commonly because the Firestore rules for the `bookmarks` collection
// haven't been deployed yet (a permission-denied error), which would
// otherwise look identical to "no bookmarks" to the user.

class _ErrorLoadingBookmarks extends StatelessWidget {
  const _ErrorLoadingBookmarks({
    required this.isGreek,
    required this.goldDim,
    required this.textSecondary,
    required this.error,
  });

  final bool isGreek;
  final Color goldDim;
  final Color textSecondary;
  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 36, color: goldDim),
          const SizedBox(height: 16),
          Text(
            isGreek
                ? 'Δεν ήταν δυνατή η φόρτωση των σελιδοδεικτών'
                : 'تعذّر تحميل الإشارات المرجعية',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textSecondary.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Row ──────────────────────────────────────────────────────────────────────

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.bookmark,
    required this.isGreek,
    required this.bgMid,
    required this.bgElevated,
    required this.goldBorder,
    required this.gold,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onDelete,
  });

  final BookmarkModel bookmark;
  final bool isGreek;
  final Color bgMid;
  final Color bgElevated;
  final Color goldBorder;
  final Color gold;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _title {
    if (bookmark.isBible) {
      final bookName = isGreek ? bookmark.bookNameEl : bookmark.bookNameAr;
      return bookmark.isVerse
          ? '$bookName ${bookmark.chapter}:${bookmark.verse}'
          : '$bookName ${bookmark.chapter}';
    }
    return isGreek
        ? (bookmark.titleEl.isNotEmpty ? bookmark.titleEl : bookmark.titleAr)
        : bookmark.titleAr;
  }

  String? get _subtitle {
    if (bookmark.isContentPage) {
      return isGreek ? 'Σελίδα ${bookmark.page}' : 'صفحة ${bookmark.page}';
    }
    if (!bookmark.isBible && bookmark.titleEl.isNotEmpty && !isGreek) {
      return bookmark.titleEl;
    }
    return null;
  }

  /// The saved verse text, in the current app language — falling back to
  /// whichever language IS available if the preferred one is empty (e.g. an
  /// older bookmark saved before the other language could be resolved).
  String? get _versePreview {
    if (!bookmark.isVerse) return null;
    final preferred = isGreek ? bookmark.textEl : bookmark.textAr;
    if (preferred.isNotEmpty) return preferred;
    final fallback = isGreek ? bookmark.textAr : bookmark.textEl;
    return fallback.isNotEmpty ? fallback : null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: bookmark.isBible
                  ? Icon(Icons.menu_book_outlined, color: gold, size: 20)
                  : (bookmark.coverUrl.isNotEmpty
                      ? CachedImage(
                          url: bookmark.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: Icon(Icons.picture_as_pdf_outlined,
                              color: gold, size: 20),
                        )
                      : Icon(Icons.picture_as_pdf_outlined,
                          color: gold, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    textDirection:
                        isGreek ? TextDirection.ltr : TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                  if (_versePreview != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _versePreview!,
                      textDirection:
                          isGreek ? TextDirection.ltr : TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: textSecondary,
                        fontSize: isGreek ? 12 : 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: textSecondary),
              onPressed: onDelete,
              tooltip: isGreek ? 'Αφαίρεση' : 'حذف',
            ),
          ],
        ),
      ),
    );
  }
}
