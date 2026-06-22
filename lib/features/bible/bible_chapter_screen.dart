// lib/features/bible/bible_chapter_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Chapter picker — grid of numbered chapter tiles for a given BibleBook.
// Tapping a tile → BibleReaderScreen.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/bible_model.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import 'bible_reader_screen.dart';

class BibleChapterScreen extends StatefulWidget {
  const BibleChapterScreen({super.key, required this.book});

  final BibleBook book;

  @override
  State<BibleChapterScreen> createState() => _BibleChapterScreenState();
}

class _BibleChapterScreenState extends State<BibleChapterScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.l10n;
    final isGreek = !l.isAr;

    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    final bookName = isGreek ? widget.book.nameEl : widget.book.nameAr;

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bookName,
                          textDirection:
                              isGreek ? TextDirection.ltr : TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: BrightnessColors.goldLight(brightness),
                            fontSize: isGreek ? 18 : 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isGreek
                              ? '${widget.book.chapterCount} κεφάλαια'
                              : '${widget.book.chapterCount} أصحاح',
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: BrightnessColors.goldDim(brightness),
                            fontSize: 11,
                            letterSpacing: isGreek ? 1.0 : 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Section label ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l.selectChapter,
                textDirection: l.dir,
                style: TextStyle(
                  fontFamily: l.bodyFont,
                  color: BrightnessColors.textSecondary(brightness),
                  fontSize: isGreek ? 12 : 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ── Chapter Grid ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = widget.book.chapters[index];
                  final isSelected = _selectedIndex == index;

                  return _ChapterTile(
                    chapterNumber: chapter.number,
                    isSelected: isSelected,
                    isGreek: isGreek,
                    brightness: brightness,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BibleReaderScreen(
                            book: widget.book,
                            chapterIndex: index,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) setState(() => _selectedIndex = null);
                      });
                    },
                  );
                },
                childCount: widget.book.chapters.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chapter Tile ──────────────────────────────────────────────────────────────

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapterNumber,
    required this.isSelected,
    required this.isGreek,
    required this.brightness,
    required this.onTap,
  });

  final int chapterNumber;
  final bool isSelected;
  final bool isGreek;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldSubtle = BrightnessColors.goldSubtle(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? goldSubtle : bgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? gold : goldBorder,
            width: isSelected ? 1.5 : 0.7,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            '$chapterNumber',
            style: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              color: isSelected ? goldLight : textSecondary,
              fontSize: isGreek ? 14 : 15,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
