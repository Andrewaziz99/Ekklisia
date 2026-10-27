// lib/features/bible/bible_reader_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Verse-by-verse reader for a single Bible chapter.
// Supports forward/back chapter navigation, language-aware RTL/LTR layout,
// Scheherazade for Arabic, and a floating chapter-nav strip at the bottom.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/bible_model.dart';
import '../../data/repositories/bible_repository.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({
    super.key,
    required this.book,
    required this.chapterIndex,
  });

  final BibleBook book;
  final int chapterIndex;

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  late int _chapterIndex;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.chapterIndex;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  bool get _hasPrev => _chapterIndex > 0;
  bool get _hasNext => _chapterIndex < widget.book.chapters.length - 1;

  BibleChapter get _currentChapter => widget.book.chapters[_chapterIndex];

  void _goTo(int index) {
    setState(() => _chapterIndex = index);
    // Scroll back to top when chapter changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.l10n;
    final isGreek = !l.isAr;

    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    final bookName = isGreek ? widget.book.nameEl : widget.book.nameAr;
    final chapterNum = _currentChapter.number;
    final totalChapters = widget.book.chapters.length;

    final chapterLabel = isGreek
        ? '$bookName — Κεφάλαιο $chapterNum'
        : '$bookName — الأصحاح $chapterNum';

    return Scaffold(
      backgroundColor: bgDeep,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                floating: false,
                expandedHeight: 90,
                backgroundColor: bgDeep,
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 56),
                          child: Text(
                            chapterLabel,
                            textDirection: isGreek
                                ? TextDirection.ltr
                                : TextDirection.rtl,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: isGreek ? null : 'Scheherazade',
                              color: BrightnessColors.goldLight(brightness),
                              fontSize: isGreek ? 13 : 17,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Bookmark this chapter
                  StreamBuilder<bool>(
                    stream: sl<BookmarkRepository>().watchIsBibleBookmarked(
                      bookNumber: widget.book.number,
                      chapter:    chapterNum,
                    ),
                    builder: (context, snap) {
                      final isBookmarked = snap.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: gold,
                          size: 20,
                        ),
                        tooltip: isGreek
                            ? 'Σελιδοδείκτης κεφαλαίου'
                            : 'إشارة مرجعية للأصحاح',
                        onPressed: () async {
                          try {
                            await sl<BookmarkRepository>()
                                .toggleBibleBookmark(
                              bookNumber: widget.book.number,
                              bookNameAr: widget.book.nameAr,
                              bookNameEl: widget.book.nameEl,
                              chapter:    chapterNum,
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(isGreek
                                        ? 'Αποτυχία αποθήκευσης: $e'
                                        : 'تعذّر الحفظ: $e'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                  // Previous chapter
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: _hasPrev
                          ? gold
                          : BrightnessColors.goldDim(brightness)
                              .withValues(alpha: 0.3),
                    ),
                    onPressed: _hasPrev ? () => _goTo(_chapterIndex - 1) : null,
                    tooltip: l.previous,
                  ),
                  // Next chapter
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: _hasNext
                          ? gold
                          : BrightnessColors.goldDim(brightness)
                              .withValues(alpha: 0.3),
                    ),
                    onPressed: _hasNext ? () => _goTo(_chapterIndex + 1) : null,
                    tooltip: l.next,
                  ),
                ],
              ),

              // ── Verses ────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final verse = _currentChapter.verses[i];
                      final showDivider =
                          i > 0 && (i + 1) % 5 == 0;

                      return _VerseItem(
                        verse: verse,
                        isGreek: isGreek,
                        brightness: brightness,
                        showDivider: showDivider,
                        book: widget.book,
                        chapter: chapterNum,
                      );
                    },
                    childCount: _currentChapter.verses.length,
                  ),
                ),
              ),
            ],
          ),

          // ── Floating chapter navigation strip ──────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ChapterNavStrip(
              chapterIndex: _chapterIndex,
              totalChapters: totalChapters,
              isGreek: isGreek,
              brightness: brightness,
              hasPrev: _hasPrev,
              hasNext: _hasNext,
              onPrev: _hasPrev ? () => _goTo(_chapterIndex - 1) : null,
              onNext: _hasNext ? () => _goTo(_chapterIndex + 1) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verse Item ────────────────────────────────────────────────────────────────

class _VerseItem extends StatelessWidget {
  const _VerseItem({
    required this.verse,
    required this.isGreek,
    required this.brightness,
    required this.showDivider,
    required this.book,
    required this.chapter,
  });

  final BibleVerse verse;
  final bool isGreek;
  final Brightness brightness;
  final bool showDivider;
  final BibleBook book;
  final int chapter;

  Future<void> _toggleVerseBookmark(BuildContext context) async {
    try {
      // The current language's text is already on hand; fetch the other
      // language's verse text too (bundled asset, cached after first load —
      // essentially free) so the Bookmarks screen can show a preview no
      // matter which language the app is in when the user looks at it later.
      var textAr = isGreek ? '' : verse.text;
      var textEl = isGreek ? verse.text : '';
      try {
        final otherLangCode = isGreek ? 'ar' : 'el';
        final otherBooks = await BibleRepository.instance.loadBooks(otherLangCode);
        final otherBook =
            otherBooks.firstWhere((b) => b.number == book.number);
        final otherChapter =
            otherBook.chapters.firstWhere((c) => c.number == chapter);
        final otherVerse =
            otherChapter.verses.firstWhere((v) => v.number == verse.number);
        if (isGreek) {
          textAr = otherVerse.text;
        } else {
          textEl = otherVerse.text;
        }
      } catch (_) {
        // Non-fatal — the bookmark still saves with just the current
        // language's text if the other language can't be resolved.
      }

      final added = await sl<BookmarkRepository>().toggleBibleBookmark(
        bookNumber: book.number,
        bookNameAr: book.nameAr,
        bookNameEl: book.nameEl,
        chapter:    chapter,
        verse:      verse.number,
        textAr:     textAr,
        textEl:     textEl,
      );
      if (!context.mounted) return;
      final bookName = isGreek ? book.nameEl : book.nameAr;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isGreek
            ? (added
                ? 'Αποθηκεύτηκε: $bookName $chapter:${verse.number}'
                : 'Αφαιρέθηκε ο σελιδοδείκτης')
            : (added
                ? 'تم حفظ إشارة $bookName $chapter:${verse.number}'
                : 'تم حذف الإشارة')),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isGreek ? 'Αποτυχία αποθήκευσης: $e' : 'تعذّر الحفظ: $e'),
        backgroundColor: Colors.red.shade800,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    final numberBadge = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gold.withValues(alpha: 0.15),
        border: Border.all(color: goldBorder, width: 0.8),
      ),
      child: Center(
        child: Text(
          '${verse.number}',
          style: TextStyle(
            color: gold,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final verseText = Expanded(
      child: Text(
        verse.text,
        textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
        style: TextStyle(
          fontFamily: isGreek ? null : 'Scheherazade',
          color: textPrimary,
          fontSize: isGreek ? 15 : 17,
          height: isGreek ? 1.7 : 1.9,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _toggleVerseBookmark(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
              children: [
                numberBadge,
                const SizedBox(width: 10),
                verseText,
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
            child: Divider(
              color: goldBorder.withValues(alpha: 0.3),
              height: 1,
              thickness: 0.6,
            ),
          ),
      ],
    );
  }
}

// ── Floating Chapter Nav Strip ────────────────────────────────────────────────

class _ChapterNavStrip extends StatelessWidget {
  const _ChapterNavStrip({
    required this.chapterIndex,
    required this.totalChapters,
    required this.isGreek,
    required this.brightness,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  final int chapterIndex;
  final int totalChapters;
  final bool isGreek;
  final Brightness brightness;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    final currentLabel = isGreek
        ? 'Κεφ. ${chapterIndex + 1} / $totalChapters'
        : 'الأصحاح ${chapterIndex + 1} / $totalChapters';

    return Container(
      decoration: BoxDecoration(
        color: bgMid,
        border: Border(
          top: BorderSide(color: goldBorder, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              // Previous
              _NavButton(
                icon: Icons.chevron_left,
                enabled: hasPrev,
                gold: gold,
                goldDim: goldDim,
                onTap: onPrev,
              ),
              // Chapter label
              Expanded(
                child: Center(
                  child: Text(
                    currentLabel,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: textSecondary,
                      fontSize: isGreek ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Next
              _NavButton(
                icon: Icons.chevron_right,
                enabled: hasNext,
                gold: gold,
                goldDim: goldDim,
                onTap: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.gold,
    required this.goldDim,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final Color gold;
  final Color goldDim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: double.infinity,
        child: Icon(
          icon,
          color: enabled ? gold : goldDim.withValues(alpha: 0.3),
          size: 28,
        ),
      ),
    );
  }
}
