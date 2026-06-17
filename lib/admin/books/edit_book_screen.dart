// lib/admin/books/edit_book_screen.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/models/book_category_model.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/book_category_repository.dart';
import '../../data/repositories/books_repository.dart';
import '../../shared/widgets/cached_image.dart';

class EditBookScreen extends StatefulWidget {
  const EditBookScreen({super.key, required this.book});
  final BookModel book;

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  late final TextEditingController _titleAr;
  late final TextEditingController _titleCop;
  late final TextEditingController _titleEl;
  late final TextEditingController _descAr;
  late final TextEditingController _tags;
  late String _category;
  late bool _isPublished;

  Uint8List? _newCoverBytes;
  String? _newCoverName;
  bool _saving = false;
  String _status = '';

  List<BookCategory> _categories = [];
  bool _catsLoading = true;

  static const _catColors = {
    'bible':        EkklisiaColors.maroon,
    'prayers':      EkklisiaColors.maroonMid,
    'liturgy':      EkklisiaColors.bronze,
    'hymns':        EkklisiaColors.tealDark,
    'saints':       EkklisiaColors.plum,
    'fathers':      EkklisiaColors.forest,
    'commentaries': EkklisiaColors.ocean,
    'studies':      EkklisiaColors.ocean,
  };

  Color get _catColor => _catColors[_category] ?? EkklisiaColors.bgElevated;

  @override
  void initState() {
    super.initState();
    _titleAr     = TextEditingController(text: widget.book.titleAr);
    _titleCop    = TextEditingController(text: widget.book.titleCop);
    _titleEl     = TextEditingController(text: widget.book.titleEl);
    _descAr      = TextEditingController(text: widget.book.descriptionAr);
    _tags        = TextEditingController(text: widget.book.tags.join(', '));
    _category    = widget.book.category;
    _isPublished = widget.book.isPublished;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await sl<BookCategoryRepository>().fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories   = cats;
        _catsLoading  = false;
        // If the book's current category isn't in Firestore yet, keep it
        // selectable by injecting a synthetic entry.
        final ids = cats.map((c) => c.id).toSet();
        if (!ids.contains(_category)) {
          _categories = [
            BookCategory(
              id:        _category,
              nameAr:    _category,
              createdAt: DateTime.now(),
            ),
            ..._categories,
          ];
        }
      });
    } catch (_) {
      if (mounted) setState(() => _catsLoading = false);
    }
  }

  @override
  void dispose() {
    _titleAr.dispose();
    _titleCop.dispose();
    _titleEl.dispose();
    _descAr.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _newCoverBytes = result.files.first.bytes;
        _newCoverName  = result.files.first.name;
      });
    }
  }

  Future<void> _save() async {
    if (_titleAr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Arabic title is required'),
        backgroundColor: EkklisiaColors.maroon,
      ));
      return;
    }
    setState(() { _saving = true; _status = 'Saving…'; });

    try {
      final repo = sl<BooksRepository>();
      String coverUrl = widget.book.coverUrl;

      if (_newCoverBytes != null) {
        setState(() => _status = 'Uploading cover…');
        coverUrl = await repo.uploadCoverOnly(
          bytes:    _newCoverBytes!,
          fileName: _newCoverName ?? 'cover.jpg',
          category: _category,
        );
      }

      final tagList = _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await repo.updateBook(widget.book.copyWith(
        titleAr:       _titleAr.text.trim(),
        titleCop:      _titleCop.text.trim(),
        titleEl:       _titleEl.text.trim(),
        descriptionAr: _descAr.text.trim(),
        category:      _category,
        coverUrl:      coverUrl,
        isPublished:   _isPublished,
        tags:          tagList,
        updatedAt:     DateTime.now(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Book updated successfully'),
          backgroundColor: EkklisiaColors.bgElevated,
          behavior: SnackBarBehavior.floating,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EkklisiaColors.bgDeep,
      appBar: AppBar(
        backgroundColor: EkklisiaColors.bgDeep,
        foregroundColor: EkklisiaColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit Book', style: TextStyle(
            color: EkklisiaColors.gold,
            fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: EkklisiaColors.goldBorder),
        ),
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cover image ──────────────────────────────────────────────
              _CoverSection(
                existingUrl:   widget.book.coverUrl,
                newCoverBytes: _newCoverBytes,
                mediaType:     widget.book.mediaType,
                catColor:      _catColor,
                onTap:         _pickCover,
              ),
              const SizedBox(height: 14),

              // ── File info (read-only) ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: EkklisiaColors.bgMid,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: EkklisiaColors.goldBorder, width: 0.5),
                ),
                child: Row(children: [
                  Icon(_mediaIcon(widget.book.mediaType),
                      size: 16, color: EkklisiaColors.goldDim),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    widget.book.pdfUrl.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: EkklisiaColors.textSecondary, fontSize: 11),
                  )),
                  Text(widget.book.formattedSize, style: const TextStyle(
                      color: EkklisiaColors.textSecondary, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Titles ───────────────────────────────────────────────────
              _AdminCard(
                title: 'Titles', titleAr: 'العناوين',
                child: Column(children: [
                  _ArabicField(
                    controller: _titleAr,
                    label: 'ARABIC TITLE', labelAr: 'العنوان بالعربية',
                    hint: 'أدخل العنوان', required: true,
                  ),
                  const SizedBox(height: 12),
                  _AdminField(
                    controller: _titleCop,
                    label: 'COPTIC TITLE',
                    hint: 'Coptic title (optional)',
                  ),
                  const SizedBox(height: 12),
                  _AdminField(
                    controller: _titleEl,
                    label: 'GREEK TITLE',
                    hint: 'Greek title (optional)',
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Description ──────────────────────────────────────────────
              _AdminCard(
                title: 'Description', titleAr: 'الوصف',
                child: _ArabicField(
                  controller: _descAr,
                  label: 'DESCRIPTION (AR)', labelAr: 'الوصف بالعربية',
                  hint: 'أدخل وصفاً مختصراً…',
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 12),

              // ── Category & Tags ──────────────────────────────────────────
              _AdminCard(
                title: 'Category & Tags', titleAr: 'الفئة والوسوم',
                child: Column(children: [
                  _CategoryDropdown(
                    value: _category,
                    categories: _categories,
                    loading: _catsLoading,
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _AdminField(
                    controller: _tags,
                    label: 'TAGS (comma-separated)',
                    hint: 'theology, coptic, prayer',
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Visibility ───────────────────────────────────────────────
              _AdminCard(
                title: 'Visibility', titleAr: 'الظهور',
                child: _ToggleRow(
                  label: 'Published', labelAr: 'منشور',
                  value: _isPublished,
                  onChanged: (v) => setState(() => _isPublished = v),
                ),
              ),
              const SizedBox(height: 24),

              // ── Save ─────────────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined,
                    color: EkklisiaColors.bgDeep, size: 18),
                label: const Text('Save Changes', style: TextStyle(
                    color: EkklisiaColors.bgDeep,
                    fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EkklisiaColors.gold,
                  disabledBackgroundColor: EkklisiaColors.goldDim,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Saving overlay ─────────────────────────────────────────────────
        if (_saving)
          Container(
            color: Colors.black54,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: EkklisiaColors.bgMid,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: EkklisiaColors.goldBorder, width: 0.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(EkklisiaColors.gold)),
                const SizedBox(height: 14),
                Text(_status, style: const TextStyle(
                    color: EkklisiaColors.textPrimary, fontSize: 13)),
              ]),
            )),
          ),
      ]),
    );
  }
}

// ── Cover Section ─────────────────────────────────────────────────────────────

class _CoverSection extends StatelessWidget {
  const _CoverSection({
    required this.existingUrl,
    required this.newCoverBytes,
    required this.mediaType,
    required this.catColor,
    required this.onTap,
  });
  final String        existingUrl;
  final Uint8List?    newCoverBytes;
  final BookMediaType mediaType;
  final Color         catColor;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    Widget coverContent;
    if (newCoverBytes != null) {
      coverContent = Image.memory(newCoverBytes!, fit: BoxFit.cover,
          width: double.infinity);
    } else if (existingUrl.isNotEmpty) {
      coverContent = CachedImage(url: existingUrl, fit: BoxFit.cover,
          width: double.infinity);
    } else {
      coverContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_mediaIcon(mediaType), size: 36,
              color: catColor.withOpacity(0.6)),
          const SizedBox(height: 8),
          const Text('No cover image', style: TextStyle(
              color: EkklisiaColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          const Text('Tap to add', style: TextStyle(
              color: EkklisiaColors.gold, fontSize: 10)),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: newCoverBytes != null
                ? EkklisiaColors.tealMid
                : EkklisiaColors.goldBorder,
            width: newCoverBytes != null ? 1.0 : 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(fit: StackFit.expand, children: [
            coverContent,
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        size: 13, color: EkklisiaColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      newCoverBytes != null
                          ? 'Cover selected — tap to change'
                          : existingUrl.isNotEmpty
                              ? 'Tap to change cover'
                              : 'Tap to add cover image',
                      style: const TextStyle(
                          color: EkklisiaColors.gold, fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

IconData _mediaIcon(BookMediaType t) {
  switch (t) {
    case BookMediaType.video: return Icons.videocam_outlined;
    case BookMediaType.audio: return Icons.headphones_outlined;
    default:                  return Icons.picture_as_pdf_outlined;
  }
}

// ── Category Dropdown ─────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
    this.loading = false,
  });
  final String              value;
  final List<BookCategory>  categories;
  final ValueChanged<String?> onChanged;
  final bool                loading;

  static InputDecoration _decoration() => InputDecoration(
    filled: true,
    fillColor: EkklisiaColors.bgElevated,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
          color: EkklisiaColors.goldBorder, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: EkklisiaColors.gold, width: 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('CATEGORY', style: TextStyle(
            color: EkklisiaColors.textSecondary,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        SizedBox(width: 6),
        Text('الفئة', style: TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.textSecondary, fontSize: 11)),
      ]),
      const SizedBox(height: 6),

      if (loading)
        // Skeleton while Firestore loads
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: EkklisiaColors.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: EkklisiaColors.goldBorder, width: 0.5),
          ),
          child: const Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(EkklisiaColors.gold)),
            ),
          ),
        )
      else
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: EkklisiaColors.bgElevated,
          style: const TextStyle(
              color: EkklisiaColors.textPrimary, fontSize: 13),
          decoration: _decoration(),
          items: categories.map((cat) => DropdownMenuItem(
            value: cat.id,
            child: Text(
              cat.nameAr,
              style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color: EkklisiaColors.textPrimary,
                  fontSize: 14),
            ),
          )).toList(),
          onChanged: onChanged,
        ),
    ]);
  }
}

// ── Admin Card ────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.titleAr,
    required this.child,
  });
  final String title;
  final String titleAr;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
                color: EkklisiaColors.gold,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              color: EkklisiaColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(titleAr, style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

// ── Arabic Field ──────────────────────────────────────────────────────────────

class _ArabicField extends StatelessWidget {
  const _ArabicField({
    required this.controller,
    required this.label,
    required this.labelAr,
    required this.hint,
    this.maxLines = 1,
    this.required = false,
  });
  final TextEditingController controller;
  final String label;
  final String labelAr;
  final String hint;
  final int    maxLines;
  final bool   required;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(
            color: EkklisiaColors.textSecondary,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(width: 6),
        Text(labelAr, style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.textSecondary, fontSize: 11)),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(' *', style: TextStyle(
              color: EkklisiaColors.maroonMid, fontSize: 11)),
        ],
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller:    controller,
        textDirection: TextDirection.rtl,
        maxLines:      maxLines,
        style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.textSecondary, fontSize: 14),
          filled:     true,
          fillColor:  EkklisiaColors.bgElevated,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
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
      ),
    ]);
  }
}

// ── Plain Field ───────────────────────────────────────────────────────────────

class _AdminField extends StatelessWidget {
  const _AdminField({
    required this.controller,
    required this.label,
    required this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: EkklisiaColors.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        style: const TextStyle(
            color: EkklisiaColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              color: EkklisiaColors.textSecondary, fontSize: 12),
          filled:     true,
          fillColor:  EkklisiaColors.bgElevated,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
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
      ),
    ]);
  }
}

// ── Toggle Row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.labelAr,
    required this.value,
    required this.onChanged,
  });
  final String   label;
  final String   labelAr;
  final bool     value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
              color: EkklisiaColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600)),
          Text(labelAr, style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.textSecondary, fontSize: 12)),
        ],
      )),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: EkklisiaColors.gold,
      ),
    ]);
  }
}
