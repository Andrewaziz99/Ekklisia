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
  });

  final BookModel book;
  final VoidCallback onTap;
  final String currentLang;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EkkleiciaColors.bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: EkkleiciaColors.bgDeep.withValues(alpha: 0.6),
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
                        child: _CategoryBadge(category: book.category),
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
                        color: EkkleiciaColors.textPrimary,
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
                              color: EkkleiciaColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        Text(
                          textDirection: TextDirection.ltr,
                          book.formattedSize,
                          style: const TextStyle(
                            color: EkkleiciaColors.gold,
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
        color: EkkleiciaColors.bgElevated,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: EkkleiciaColors.goldDim,
            ),
            const SizedBox(height: 8),
            Text(
              book.category,
              style: const TextStyle(
                color: EkkleiciaColors.textSecondary,
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
        baseColor: EkkleiciaColors.bgElevated,
        highlightColor: EkkleiciaColors.bgMid,
        child: Container(color: EkkleiciaColors.bgElevated),
      ),
      errorWidget: (_, __, ___) => Container(
        color: EkkleiciaColors.bgElevated,
        child: const Icon(
          Icons.broken_image_outlined,
          color: EkkleiciaColors.goldDim,
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
        gradient: EkkleiciaColors.cardOverlayGradient,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final String category;

  Color get _color {
    const map = {
      'bible': EkkleiciaColors.maroon,
      'prayers': EkkleiciaColors.maroon,
      'liturgy': EkkleiciaColors.bronze,
      'hymns': EkkleiciaColors.tealDark,
      'saints': EkkleiciaColors.plum,
      'fathers': EkkleiciaColors.forest,
      'commentaries': EkkleiciaColors.ocean,
      'studies': EkkleiciaColors.ocean,
    };
    return map[category] ?? EkkleiciaColors.bgElevated;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: EkkleiciaColors.textCream,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
