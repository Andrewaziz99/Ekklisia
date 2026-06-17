import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/book_model.dart';

/// Displays a book as a tall portrait card with cover art,
/// gold framing, and multi-language title support.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.currentLang = 'ar',
    this.showCategory = true,
    this.categoryName,
  });

  final BookModel book;
  final VoidCallback onTap;
  final String currentLang;
  final bool showCategory;
  /// Human-readable category name to display. Falls back to [book.category]
  /// (the raw Firestore ID) if not supplied.
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EkklisiaColors.bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: EkklisiaColors.bgDeep.withValues(alpha: 0.6),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image ─────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCoverImage(),
                    // Gradient overlay at bottom
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: _CoverGradientOverlay(),
                    ),
                    // Category badge
                    if (showCategory)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _CategoryBadge(
                          category: book.category,
                          displayName: categoryName,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Book Info ────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: currentLang == 'ar'
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      book.titleFor(currentLang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: currentLang == 'ar'
                          ? TextAlign.right
                          : TextAlign.left,
                      style: TextStyle(
                        fontFamily: currentLang == 'ar' ? 'Scheherazade' : null,
                        color: EkklisiaColors.textPrimary,
                        fontSize: currentLang == 'ar' ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),

                    // Metadata row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (book.pageCount > 0)
                          Text(
                            '${book.pageCount} صفحة',
                            style: const TextStyle(
                              fontFamily: 'Scheherazade',
                              color: EkklisiaColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        Text(
                          textDirection: TextDirection.ltr,
                          book.formattedSize,
                          style: const TextStyle(
                            color: EkklisiaColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (book.coverUrl.isEmpty) {
      return Container(
        color: EkklisiaColors.bgElevated,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: EkklisiaColors.goldDim,
            ),
            const SizedBox(height: 8),
            Text(
              categoryName ?? book.category,
              style: const TextStyle(
                color: EkklisiaColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: book.coverUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: EkklisiaColors.bgElevated,
        highlightColor: EkklisiaColors.bgMid,
        child: Container(color: EkklisiaColors.bgElevated),
      ),
      errorWidget: (_, __, ___) => Container(
        color: EkklisiaColors.bgElevated,
        child: const Icon(
          Icons.broken_image_outlined,
          color: EkklisiaColors.goldDim,
          size: 32,
        ),
      ),
    );
  }
}

class _CoverGradientOverlay extends StatelessWidget {
  const _CoverGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: EkklisiaColors.cardOverlayGradient,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, this.displayName});
  final String category;
  final String? displayName;

  Color get _color {
    const map = {
      'bible': EkklisiaColors.maroon,
      'prayers': EkklisiaColors.maroon,
      'liturgy': EkklisiaColors.bronze,
      'hymns': EkklisiaColors.tealDark,
      'saints': EkklisiaColors.plum,
      'fathers': EkklisiaColors.forest,
      'commentaries': EkklisiaColors.ocean,
      'studies': EkklisiaColors.ocean,
    };
    return map[category] ?? EkklisiaColors.bgElevated;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
      ),
      child: Text(
        displayName ?? category,
        style: const TextStyle(
          color: EkklisiaColors.textCream,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
