// lib/admin/books/books_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_category_model.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/book_category_repository.dart';
import '../../data/repositories/books_repository.dart';
import '../../core/di/service_locator.dart';
import '../../shared/widgets/cached_image.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../admin_l10n.dart';
import '../utils/admin_colors.dart';

class BooksManagerScreen extends StatefulWidget {
  const BooksManagerScreen({super.key});
  @override
  State<BooksManagerScreen> createState() => _BooksManagerScreenState();
}

class _BooksManagerScreenState extends State<BooksManagerScreen> {
  final _search = TextEditingController();
  String? _filterCat;
  List<BookCategory> _categories = [];

  static const _catColors = {
    'bible':         EkklisiaColors.darkMaroon,
    'prayers':       EkklisiaColors.darkMaroonMid,
    'liturgy':       EkklisiaColors.darkBronze,
    'hymns':         EkklisiaColors.tealDark,
    'saints':        EkklisiaColors.darkPlum,
    'fathers':       EkklisiaColors.forest,
    'commentaries':  EkklisiaColors.ocean,
    'studies':       EkklisiaColors.ocean,
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await sl<BookCategoryRepository>().fetchCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, state) {
        final visible = state.books.where((b) {
          final matchSearch = TextNormalizer.anyContains(
              [b.titleAr, b.titleEl, b.category], _search.text);
          final matchCat = _filterCat == null || b.category == _filterCat;
          return matchSearch && matchCat;
        }).toList();

        return Column(children: [
          // ── Toolbar ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: ac.bgDeep,
              border: Border(bottom: BorderSide(
                  color: ac.goldBorder, width: 0.5)),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: _SearchField(ctrl: _search,
                    onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                _FilterButton(
                  selected: _filterCat,
                  categories: _categories,
                  onChanged: (v) => setState(() => _filterCat = v),
                ),
                SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => context.go(Routes.adminBulkUpload),
                  icon: Icon(Icons.cloud_upload_outlined, size: 15,
                      color: ac.gold),
                  label: Text(context.adminL10n.bulk,
                      style: TextStyle(
                          fontFamily: context.adminL10n.fontFam,
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: ac.gold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: ac.gold, width: 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context.go(Routes.adminUpload),
                  icon: Icon(Icons.add, size: 16,
                      color: ac.bgDeep),
                  label: Text(context.adminL10n.upload,
                      style: TextStyle(
                          fontFamily: context.adminL10n.fontFam,
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: ac.bgDeep)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.gold,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ]),
          ),

          // ── File count strip ──────────────────────────────────────
          _FileCountStrip(books: state.books),

          // ── List ──────────────────────────────────────────────────
          Expanded(child: state.isLoading
              ? Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(ac.gold)))
              : visible.isEmpty
              ? _EmptyState(onUpload: () => context.go(Routes.adminUpload))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            separatorBuilder: (_, __) => SizedBox(height: 10),
            itemBuilder: (_, i) => _BookRow(
              book: visible[i],
              catColor: _catColors[visible[i].category] ??
                  ac.bgElevated,
              onToggle: () => _togglePublish(
                  context, visible[i]),
              onDelete: () => _confirmDelete(context, visible[i].id),
              onView: () => context.go(
                  '/home/book/${visible[i].id}',
                  extra: visible[i]),
              onEdit: () => context.go(
                  Routes.adminEditBook,
                  extra: visible[i]),
            ),
          )),

        ]);
      },
    );
  }

  Future<void> _togglePublish(BuildContext context, BookModel book) async {
    await sl<BooksRepository>().togglePublish(
        book.id, published: !book.isPublished);
    if (mounted) _snack(context,
        book.isPublished ? 'Unpublished' : 'Published');
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _DeleteDialog(),
    );
    if (confirmed == true && mounted) {
      try {
        await sl<BooksRepository>().deleteBook(id);
        if (mounted) _snack(context, 'Book deleted');
      } catch (e) {
        if (mounted) _snack(context, 'Delete failed: $e');
      }
    }
  }

  void _snack(BuildContext context, String msg) {
    final ac = AdminC(Theme.of(context).brightness);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ac.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: ac.goldBorder, width: 0.5)),
    ));
  }
}

// ── Book Row ──────────────────────────────────────────────────────────────────

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.catColor,
    required this.onToggle,
    required this.onDelete,
    required this.onView,
    required this.onEdit,
  });
  final BookModel    book;
  final Color        catColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Row(children: [
        // Colour strip
        Container(
          width: 4,
          height: 80,
          decoration: BoxDecoration(
            color: catColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              bottomLeft: Radius.circular(11),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Cover thumb
        Container(
          width: 36, height: 52,
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: ac.goldBorder, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: book.coverUrl.isNotEmpty
                ? CachedImage(
                    url: book.coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: _CoverFallback(
                        mediaType: book.mediaType, color: catColor),
                  )
                : _CoverFallback(
                    mediaType: book.mediaType, color: catColor),
          ),
        ),
        const SizedBox(width: 12),

        // Meta
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.titleAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Row(children: [
              _Tag(label: book.category, color: catColor),
              SizedBox(width: 6),
              Text(book.formattedSize, style: TextStyle(
                  color: ac.textSecondary, fontSize: 10)),
              if (book.pageCount > 0) ...[
                SizedBox(width: 6),
                Text('${book.pageCount}pp', style: TextStyle(
                    color: ac.textSecondary, fontSize: 10)),
              ],
            ]),
            SizedBox(height: 4),
            Text(
              book.createdAt.toIso8601String().substring(0, 10),
              style: TextStyle(
                  color: ac.textSecondary, fontSize: 10),
            ),
          ],
        )),

        // Status + actions
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: book.isPublished
                        ? ac.tealMid.withOpacity(0.15)
                        : ac.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: book.isPublished
                          ? ac.tealMid
                          : ac.goldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    book.isPublished ? 'LIVE' : 'DRAFT',
                    style: TextStyle(
                      color: book.isPublished
                          ? ac.tealMid
                          : ac.textSecondary,
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(
                  icon: Icons.visibility_outlined,
                  color: ac.gold,
                  onTap: onView,
                ),
                SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.edit_outlined,
                  color: ac.bronze,
                  onTap: onEdit,
                ),
                SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.delete_outline,
                  color: ac.maroonMid,
                  onTap: onDelete,
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── File count strip ──────────────────────────────────────────────────────────

class _FileCountStrip extends StatelessWidget {
  const _FileCountStrip({required this.books});
  final List<BookModel> books;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    if (books.isEmpty) return const SizedBox.shrink();
    final pdfs   = books.where((b) => b.mediaType == BookMediaType.pdf).length;
    final videos = books.where((b) => b.mediaType == BookMediaType.video).length;
    final audios = books.where((b) => b.mediaType == BookMediaType.audio).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ac.bgMid,
        border: Border(bottom: BorderSide(
            color: ac.goldBorder, width: 0.5)),
      ),
      child: Row(children: [
        _CountChip(icon: Icons.picture_as_pdf_outlined,
            label: 'PDFs', value: pdfs,
            color: ac.maroon),
        const SizedBox(width: 10),
        _CountChip(icon: Icons.videocam_outlined,
            label: 'Videos', value: videos,
            color: EkklisiaColors.ocean),
        SizedBox(width: 10),
        _CountChip(icon: Icons.headphones_outlined,
            label: 'Audios', value: audios,
            color: ac.tealMid),
        Spacer(),
        Text('${books.length} total',
            style: TextStyle(
                color: ac.textSecondary,
                fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final int      value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text('$value $label', style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ],
  );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

/// Icon-based cover fallback — shown when a book has no cover image.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.mediaType, required this.color});
  final BookMediaType mediaType;
  final Color         color;

  static IconData _icon(BookMediaType t) {
    switch (t) {
      case BookMediaType.video: return Icons.videocam_outlined;
      case BookMediaType.audio: return Icons.headphones_outlined;
      default:                  return Icons.picture_as_pdf_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Center(
    child: Icon(_icon(mediaType), size: 18,
        color: color.withOpacity(0.7)),
  );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color  color;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(label, style: TextStyle(
        color: ac.textSecondary, fontSize: 9)),
  );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.ctrl, required this.onChanged});
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return TextField(
    controller: ctrl,
    onChanged: onChanged,
    style: TextStyle(color: ac.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: '${context.adminL10n.search} ${context.adminL10n.totalBooks}…',
      hintStyle: TextStyle(
          color: ac.textSecondary, fontSize: 12),
      prefixIcon: Icon(Icons.search,
          size: 18, color: ac.goldDim),
      filled: true, fillColor: ac.bgElevated,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: ac.goldBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: ac.gold, width: 1.0),
      ),
    ),
  );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.selected,
    required this.categories,
    required this.onChanged,
  });
  final String?            selected;
  final List<BookCategory> categories;
  final ValueChanged<String?> onChanged;

  String get _selectedLabel {
    if (selected == null) return '';
    final match = categories.where((c) => c.id == selected).firstOrNull;
    return match?.nameAr.isNotEmpty == true ? match!.nameAr : selected!;
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return PopupMenuButton<String?>(
    color: ac.bgElevated,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ac.goldBorder, width: 0.5)),
    onSelected: onChanged,
    itemBuilder: (_) => [
      PopupMenuItem(
        value: null,
        child: Text('All', style: TextStyle(
            color: selected == null
                ? ac.gold
                : ac.textPrimary,
            fontSize: 13)),
      ),
      ...categories.map((cat) => PopupMenuItem(
        value: cat.id,
        child: Text(
          cat.nameAr,
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: selected == cat.id
                ? ac.gold
                : ac.textPrimary,
            fontSize: 14,
          ),
        ),
      )),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected != null
              ? ac.gold
              : ac.goldBorder,
          width: 0.5,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.filter_list,
            size: 16,
            color: selected != null
                ? ac.gold
                : ac.goldDim),
        if (selected != null) ...[
          SizedBox(width: 4),
          Text(_selectedLabel, style: TextStyle(
              fontFamily: 'Scheherazade',
              color: ac.gold, fontSize: 11)),
        ],
      ]),
    ),
  );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.library_books_outlined,
          size: 52, color: ac.goldDim),
      SizedBox(height: 16),
      Text(context.adminL10n.noFilesSelected, textDirection: context.adminL10n.dir,
          style: TextStyle(fontFamily: context.adminL10n.fontFam,
              color: ac.textSecondary, fontSize: 16)),
      SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onUpload,
        icon: Icon(Icons.upload_file, size: 18,
            color: ac.bgDeep),
        label: Text(context.adminL10n.uploadBook, textDirection: context.adminL10n.dir,
            style: TextStyle(fontFamily: context.adminL10n.fontFam,
                fontWeight: FontWeight.w700, color: ac.bgDeep)),
        style: ElevatedButton.styleFrom(
          backgroundColor: ac.gold,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ],
  ));
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog();

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.maroon, width: 0.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_amber_rounded,
            color: ac.maroonMid, size: 40),
        SizedBox(height: 12),
        Text(context.adminL10n.delete, textDirection: context.adminL10n.dir,
            style: TextStyle(fontFamily: context.adminL10n.fontFam,
            color: ac.textPrimary,
            fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'This permanently removes the item from Firestore.\n'
          'The Cloudinary asset will remain unless deleted manually.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: ac.textSecondary, fontSize: 12,
              height: 1.5),
        ),
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: ac.textSecondary,
                  side: BorderSide(
                      color: ac.goldBorder, width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(context.adminL10n.cancel,
                    style: TextStyle(fontFamily: context.adminL10n.fontFam)),
              )),
              SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.maroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(context.adminL10n.delete,
                    style: TextStyle(fontFamily: context.adminL10n.fontFam,
                        fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
        ),
      );
  }
}
