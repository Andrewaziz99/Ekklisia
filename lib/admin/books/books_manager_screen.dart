// lib/admin/books/books_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/books_repository.dart';
import '../../core/di/service_locator.dart';
import '../../shared/widgets/cached_image.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';

class BooksManagerScreen extends StatefulWidget {
  const BooksManagerScreen({super.key});
  @override
  State<BooksManagerScreen> createState() => _BooksManagerScreenState();
}

class _BooksManagerScreenState extends State<BooksManagerScreen> {
  final _search = TextEditingController();
  String? _filterCat;
  String? _confirmDeleteId;

  static const _catColors = {
    'bible': EkklisiaColors.maroon, 'prayers': EkklisiaColors.maroonMid,
    'liturgy': EkklisiaColors.bronze, 'hymns': EkklisiaColors.tealDark,
    'saints': EkklisiaColors.plum, 'fathers': EkklisiaColors.forest,
    'commentaries': EkklisiaColors.ocean, 'studies': EkklisiaColors.ocean,
  };

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              color: EkklisiaColors.bgDeep,
              border: Border(bottom: BorderSide(
                  color: EkklisiaColors.goldBorder, width: 0.5)),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: _SearchField(ctrl: _search,
                    onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                _FilterButton(
                  selected: _filterCat,
                  onChanged: (v) => setState(() => _filterCat = v),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => context.go(Routes.adminUpload),
                  icon: const Icon(Icons.add, size: 16,
                      color: EkklisiaColors.bgDeep),
                  label: const Text('Upload',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: EkklisiaColors.bgDeep)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EkklisiaColors.gold,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ]),
          ),

          // ── List ──────────────────────────────────────────────────
          Expanded(child: state.isLoading
              ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(EkklisiaColors.gold)))
              : visible.isEmpty
              ? _EmptyState(onUpload: () => context.go(Routes.adminUpload))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _BookRow(
              book: visible[i],
              catColor: _catColors[visible[i].category] ??
                  EkklisiaColors.bgElevated,
              onToggle: () => _togglePublish(
                  context, visible[i]),
              onDelete: () => setState(
                      () => _confirmDeleteId = visible[i].id),
              onView: () => context.go(
                  '/home/book/${visible[i].id}',
                  extra: visible[i]),
            ),
          )),

          // ── Delete confirm ────────────────────────────────────────
          if (_confirmDeleteId != null)
            _DeleteDialog(
              onCancel: () =>
                  setState(() => _confirmDeleteId = null),
              onConfirm: () {
                _deleteBook(context, _confirmDeleteId!);
                setState(() => _confirmDeleteId = null);
              },
            ),
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

  Future<void> _deleteBook(BuildContext context, String id) async {
    await sl<BooksRepository>().deleteBook(id);
    if (mounted) _snack(context, 'Book deleted');
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: EkklisiaColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(
                color: EkklisiaColors.goldBorder, width: 0.5)),
      ));
}

// ── Book Row ──────────────────────────────────────────────────────────────────

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.catColor,
    required this.onToggle,
    required this.onDelete,
    required this.onView,
  });
  final BookModel    book;
  final Color        catColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EkklisiaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
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
                color: EkklisiaColors.goldBorder, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedImage(
              url: book.coverUrl,
              fit: BoxFit.cover,
              errorWidget: _CoverInitials(title: book.titleAr),
            ),
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
                style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkklisiaColors.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              _Tag(label: book.category, color: catColor),
              const SizedBox(width: 6),
              Text(book.formattedSize, style: const TextStyle(
                  color: EkklisiaColors.textSecondary, fontSize: 10)),
              if (book.pageCount > 0) ...[
                const SizedBox(width: 6),
                Text('${book.pageCount}pp', style: const TextStyle(
                    color: EkklisiaColors.textSecondary, fontSize: 10)),
              ],
            ]),
            const SizedBox(height: 4),
            Text(
              book.createdAt.toIso8601String().substring(0, 10),
              style: const TextStyle(
                  color: EkklisiaColors.textSecondary, fontSize: 10),
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
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: book.isPublished
                        ? EkklisiaColors.tealMid.withOpacity(0.15)
                        : EkklisiaColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: book.isPublished
                          ? EkklisiaColors.tealMid
                          : EkklisiaColors.goldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    book.isPublished ? 'LIVE' : 'DRAFT',
                    style: TextStyle(
                      color: book.isPublished
                          ? EkklisiaColors.tealMid
                          : EkklisiaColors.textSecondary,
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(
                  icon: Icons.visibility_outlined,
                  color: EkklisiaColors.gold,
                  onTap: onView,
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.delete_outline,
                  color: EkklisiaColors.maroonMid,
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

// ── Small helpers ─────────────────────────────────────────────────────────────

class _CoverInitials extends StatelessWidget {
  const _CoverInitials({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(child: Text(
      title.length > 1 ? title.substring(0, 2) : title,
      style: const TextStyle(
          fontFamily: 'Scheherazade',
          color: EkklisiaColors.textCream, fontSize: 11)));
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(label, style: const TextStyle(
        color: EkklisiaColors.textSecondary, fontSize: 9)),
  );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.ctrl, required this.onChanged});
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    onChanged: onChanged,
    style: const TextStyle(color: EkklisiaColors.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: 'Search books…',
      hintStyle: const TextStyle(
          color: EkklisiaColors.textSecondary, fontSize: 12),
      prefixIcon: const Icon(Icons.search,
          size: 18, color: EkklisiaColors.goldDim),
      filled: true, fillColor: EkklisiaColors.bgElevated,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: EkklisiaColors.goldBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: EkklisiaColors.gold, width: 1.0),
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;
  static const _cats = ['bible','prayers','liturgy','hymns',
    'saints','fathers','commentaries','studies','other'];
  @override
  Widget build(BuildContext context) => PopupMenuButton<String?>(
    color: EkklisiaColors.bgElevated,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
            color: EkklisiaColors.goldBorder, width: 0.5)),
    onSelected: onChanged,
    itemBuilder: (_) => [
      PopupMenuItem(value: null, child: Text('All',
          style: TextStyle(
              color: selected == null
                  ? EkklisiaColors.gold
                  : EkklisiaColors.textPrimary,
              fontSize: 13))),
      ..._cats.map((c) => PopupMenuItem(value: c,
          child: Text(c, style: TextStyle(
              color: selected == c
                  ? EkklisiaColors.gold
                  : EkklisiaColors.textPrimary,
              fontSize: 13)))),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected != null
              ? EkklisiaColors.gold
              : EkklisiaColors.goldBorder,
          width: 0.5,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.filter_list,
            size: 16,
            color: selected != null
                ? EkklisiaColors.gold
                : EkklisiaColors.goldDim),
        if (selected != null) ...[
          const SizedBox(width: 4),
          Text(selected!, style: const TextStyle(
              color: EkklisiaColors.gold, fontSize: 11)),
        ],
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.library_books_outlined,
          size: 52, color: EkklisiaColors.goldDim),
      const SizedBox(height: 16),
      const Text('No books yet', style: TextStyle(
          color: EkklisiaColors.textSecondary, fontSize: 16)),
      const SizedBox(height: 8),
      const Text('لا توجد كتب بعد', style: TextStyle(
          fontFamily: 'Scheherazade',
          color: EkklisiaColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onUpload,
        icon: const Icon(Icons.upload_file, size: 18,
            color: EkklisiaColors.bgDeep),
        label: const Text('Upload First Book', style: TextStyle(
            fontWeight: FontWeight.w700, color: EkklisiaColors.bgDeep)),
        style: ElevatedButton.styleFrom(
          backgroundColor: EkklisiaColors.gold,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ],
  ));
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.onCancel, required this.onConfirm});
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onCancel,
    child: Container(
      color: Colors.black54,
      child: Center(child: GestureDetector(
        onTap: () {},
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: EkklisiaColors.bgMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: EkklisiaColors.maroon, width: 0.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded,
                color: EkklisiaColors.maroonMid, size: 40),
            const SizedBox(height: 12),
            const Text('Delete Book', style: TextStyle(
                color: EkklisiaColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'This permanently removes the book from Firestore. '
                  'Delete the Cloudinary asset separately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: EkklisiaColors.textSecondary, fontSize: 12,
                  height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EkklisiaColors.textSecondary,
                  side: const BorderSide(
                      color: EkklisiaColors.goldBorder, width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EkklisiaColors.maroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
        ),
      )),
    ),
  );
}