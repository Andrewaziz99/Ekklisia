import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/book_model.dart';
import 'pdf_viewer_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});
  final BookModel book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EkkleiciaColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: EkkleiciaColors.bgDeep,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: EkkleiciaColors.bgDeep.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: EkkleiciaColors.gold,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background
            if (book.coverUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: book.coverUrl,
                fit: BoxFit.cover,
                color: Colors.black54,
                colorBlendMode: BlendMode.darken,
              )
            else
              Container(color: EkkleiciaColors.bgDeep),
            // Bottom gradient
            const Align(
              alignment: Alignment.bottomCenter,
              child: _FadeGradient(),
            ),
            // Cover book portrait
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _BookCoverPortrait(book: book),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Title
          Text(
            book.titleAr,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkkleiciaColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          if (book.titleCop.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              book.titleCop,
              style: const TextStyle(
                fontFamily: 'CopticFont',
                color: EkkleiciaColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Metadata chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _MetaChip(icon: Icons.category_outlined, label: book.category),
              if (book.pageCount > 0)
                _MetaChip(
                  icon: Icons.format_list_numbered,
                  label: '${book.pageCount} صفحة',
                ),
              _MetaChip(
                icon: Icons.storage_outlined,
                label: book.formattedSize,
                direction: TextDirection.ltr,
              ),
            ],
          ),

          const SizedBox(height: 20),
          const _GoldDivider(),
          const SizedBox(height: 20),

          // Description
          if (book.descriptionAr.isNotEmpty) ...[
            Text(
              book.descriptionAr,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Scheherazade',
                color: EkkleiciaColors.textSecondary,
                fontSize: 16,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Tags
          if (book.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: book.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: EkkleiciaColors.goldSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: EkkleiciaColors.goldBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                          color: EkkleiciaColors.gold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Open PDF Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PdfViewerScreen(book: book)),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: const Text(
                'فتح الكتاب',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: EkkleiciaColors.gold,
                foregroundColor: EkkleiciaColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _FadeGradient extends StatelessWidget {
  const _FadeGradient();

  @override
  Widget build(BuildContext context) => Container(
    height: 200,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, EkkleiciaColors.bgPrimary],
      ),
    ),
  );
}

class _BookCoverPortrait extends StatelessWidget {
  const _BookCoverPortrait({required this.book});
  final BookModel book;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EkkleiciaColors.goldBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(4, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: book.coverUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: book.coverUrl, fit: BoxFit.cover)
            : Container(
                color: EkkleiciaColors.bgElevated,
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 40,
                  color: EkkleiciaColors.goldDim,
                ),
              ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.direction = TextDirection.rtl});
  final IconData icon;
  final String label;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: EkkleiciaColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: EkkleiciaColors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            textDirection: direction,
            style: const TextStyle(
              color: EkkleiciaColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 0.5, color: EkkleiciaColors.goldBorder),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '✦',
            style: TextStyle(color: EkkleiciaColors.goldDim, fontSize: 12),
          ),
        ),
        Expanded(
          child: Container(height: 0.5, color: EkkleiciaColors.goldBorder),
        ),
      ],
    );
  }
}
