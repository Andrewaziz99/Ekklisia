// lib/admin/books/bulk_upload_screen.dart
//
// Bulk-upload screen: select multiple files (PDF / video / audio),
// assign each a title + category, then upload all sequentially.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../data/models/book_category_model.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/book_category_repository.dart';
import '../../data/repositories/books_repository.dart';
import '../../features/auth/auth_cubit.dart';
import '../admin_l10n.dart';
import '../utils/admin_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-row state
// ─────────────────────────────────────────────────────────────────────────────

enum _RowStatus { pending, uploading, done, error }

class _FileRow {
  _FileRow({
    required this.item,
    required this.titleCtrl,
  });

  final BulkUploadItem item;
  final TextEditingController titleCtrl;

  _RowStatus status  = _RowStatus.pending;
  double     progress = 0;
  String     stepLabel = '';
  String?    errorMsg;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  // ── File list ────────────────────────────────────────────────────────────
  final List<_FileRow> _rows = [];

  // ── Shared category (applied to newly added files; each row overrides) ──
  String _sharedCategory = '';

  /// Resolves the human-readable name for a category [id] from [_categories].
  String? _catName(String id) =>
      _categories.where((c) => c.id == id).firstOrNull?.nameAr;

  // ── Categories from Firestore ────────────────────────────────────────────
  List<BookCategory> _categories = [];
  bool _categoriesLoading = true;

  // ── Upload state ─────────────────────────────────────────────────────────
  bool _uploading = false;
  bool _done      = false;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final r in _rows) r.titleCtrl.dispose();
    super.dispose();
  }

  // ── Load categories ───────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    try {
      final cats = await sl<BookCategoryRepository>()
          .fetchCategories(visibleOnly: true);
      if (mounted) {
        setState(() {
          _categories = cats;
          _categoriesLoading = false;
          if (_sharedCategory.isEmpty && cats.isNotEmpty) {
            _sharedCategory = cats.first.id;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _categories = AppConstants.bookCategories
              .asMap()
              .entries
              .map((e) => BookCategory(
                    id: e.value, nameAr: e.value,
                    sortOrder: e.key, createdAt: DateTime.now()))
              .toList();
          _categoriesLoading = false;
          if (_sharedCategory.isEmpty && _categories.isNotEmpty) {
            _sharedCategory = _categories.first.id;
          }
        });
      }
    }
  }

  // ── Detect media type from extension ─────────────────────────────────────

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot).toLowerCase();
  }

  static String _basenameWithoutExtension(String fileName) {
    final slash = fileName.lastIndexOf(RegExp(r'[/\\]'));
    final base  = slash < 0 ? fileName : fileName.substring(slash + 1);
    final dot   = base.lastIndexOf('.');
    return dot < 0 ? base : base.substring(0, dot);
  }

  static BookMediaType _detectType(String fileName) {
    final ext = _extension(fileName);
    const videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'};
    const audioExts = {'.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac', '.opus'};
    if (videoExts.contains(ext)) return BookMediaType.video;
    if (audioExts.contains(ext)) return BookMediaType.audio;
    return BookMediaType.pdf;
  }

  static String _titleFromFileName(String fileName) {
    final base = _basenameWithoutExtension(fileName);
    return base.replaceAll(RegExp(r'[-_]'), ' ').trim();
  }

  // ── Pick files ────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v',
        'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'opus',
      ],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    final oversized = <String>[];

    setState(() {
      for (final f in result.files) {
        final mediaType = _detectType(f.name);
        final sizeMb    = f.size / (1024 * 1024);

        // ── Size guard ────────────────────────────────────────────────────
        final limit = switch (mediaType) {
          BookMediaType.pdf   => AppConstants.maxPdfSizeMb,
          BookMediaType.video => AppConstants.maxVideoSizeMb,
          BookMediaType.audio => AppConstants.maxAudioSizeMb,
          _                   => AppConstants.maxPdfSizeMb,
        };
        if (sizeMb > limit) {
          oversized.add('${f.name} (${sizeMb.toStringAsFixed(1)} MB > ${limit.toInt()} MB)');
          return; // skip this file
        }

        final titleCtrl = TextEditingController(
          text: _titleFromFileName(f.name),
        );
        _rows.add(_FileRow(
          item: BulkUploadItem(
            fileName:       f.name,
            titleAr:        titleCtrl.text,
            category:       _sharedCategory,
            categoryFolder: _catName(_sharedCategory),
            mediaType:      mediaType,
            file:           kIsWeb ? null : File(f.path!),
            fileBytes:      kIsWeb ? f.bytes : null,
            fileSizeMb:     sizeMb,
          ),
          titleCtrl: titleCtrl,
        ));
      }
    });

    if (oversized.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.redAccent,
        content: Text(
          'Skipped ${oversized.length} oversized file(s):\n${oversized.join('\n')}',
        ),
      ));
    }
  }

  // ── Remove a row ──────────────────────────────────────────────────────────

  void _removeRow(int index) {
    _rows[index].titleCtrl.dispose();
    setState(() => _rows.removeAt(index));
  }

  // ── Upload all ────────────────────────────────────────────────────────────

  Future<void> _uploadAll() async {
    if (_rows.isEmpty) return;

    // Sync titles back from controllers
    for (final r in _rows) {
      r.item.titleAr = r.titleCtrl.text.trim().isEmpty
          ? r.item.fileName
          : r.titleCtrl.text.trim();
    }

    setState(() {
      _uploading = true;
      _done      = false;
    });

    final authState  = context.read<AuthCubit>().state;
    final repo       = sl<BooksRepository>();
    final addedByUid = authState.user?.uid ?? '';

    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.status == _RowStatus.done) continue;

      setState(() {
        row.status    = _RowStatus.uploading;
        row.progress  = 0;
        row.stepLabel = 'Starting…';
      });

      try {
        if (row.item.mediaType == BookMediaType.pdf) {
          await repo.addBook(
            pdfFile:        row.item.file,
            pdfBytes:       row.item.fileBytes,
            pdfName:        row.item.fileName,
            titleAr:        row.item.titleAr,
            category:       row.item.category,
            categoryFolder: row.item.categoryFolder,
            addedByUid:     addedByUid,
            tags:           row.item.tags,
            onProgress: (step, pct) => setState(() {
              row.stepLabel = step;
              row.progress  = pct;
            }),
          );
        } else {
          await repo.addMediaFile(
            file:           row.item.file,
            fileBytes:      row.item.fileBytes,
            fileName:       row.item.fileName,
            mediaType:      row.item.mediaType,
            titleAr:        row.item.titleAr,
            category:       row.item.category,
            categoryFolder: row.item.categoryFolder,
            addedByUid:     addedByUid,
            tags:           row.item.tags,
            onProgress: (step, pct) => setState(() {
              row.stepLabel = step;
              row.progress  = pct;
            }),
          );
        }
        setState(() {
          row.status   = _RowStatus.done;
          row.progress = 1.0;
          row.stepLabel = 'Done ✓';
        });
      } catch (e) {
        setState(() {
          row.status   = _RowStatus.error;
          row.errorMsg = e.toString();
        });
        // Continue uploading remaining files
      }
    }

    setState(() {
      _uploading = false;
      _done      = _rows.every((r) => r.status == _RowStatus.done);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        Expanded(
          child: _rows.isEmpty ? _buildEmpty() : _buildFileList(),
        ),
        _buildBottomBar(),
      ],
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    final ac = AdminC(Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        border: Border(
            bottom: BorderSide(color: ac.goldBorder, width: 0.5)),
      ),
      child: Row(children: [
        // Category picker for new files
        Expanded(
          child: _categoriesLoading
              ? SizedBox(
                  height: 36,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ac.gold)))
              : _CategoryDropdown(
                  value: _sharedCategory,
                  categories: _categories,
                  label: context.adminL10n.defaultCat,
                  onChanged: (v) => setState(() => _sharedCategory = v),
                ),
        ),
        SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _pickFiles,
          icon: Icon(Icons.add, size: 16, color: ac.bgDeep),
          label: Text(context.adminL10n.addFiles,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ac.bgDeep)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ac.gold,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final ac = AdminC(Theme.of(context).brightness);

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_upload_outlined,
            size: 64, color: ac.goldDim.withOpacity(0.5)),
        SizedBox(height: 16),
        Text(context.adminL10n.noFilesSelected,
            textDirection: context.adminL10n.dir,
            style: TextStyle(
                fontFamily: context.adminL10n.fontFam,
                color: ac.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          context.adminL10n.filenameHint,
          textAlign: TextAlign.center,
          textDirection: context.adminL10n.dir,
          style: TextStyle(
              fontFamily: context.adminL10n.fontFam,
              color: ac.textSecondary, fontSize: 12, height: 1.6),
        ),
        SizedBox(height: 6),
        Text(
          'PDF · MP4 · MOV · MP3 · WAV · AAC · M4A · OGG',
          textAlign: TextAlign.center,
          style: TextStyle(color: ac.goldDim, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          'Max: PDF ${AppConstants.maxPdfSizeMb.toInt()} MB  ·  '
          'Video ${AppConstants.maxVideoSizeMb.toInt()} MB  ·  '
          'Audio ${AppConstants.maxAudioSizeMb.toInt()} MB',
          textAlign: TextAlign.center,
          style: TextStyle(color: ac.textSecondary, fontSize: 10),
        ),
      ]),
    );
  }

  // ── File list ─────────────────────────────────────────────────────────────

  Widget _buildFileList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _FileRowCard(
        row: _rows[i],
        index: i,
        categories: _categories,
        uploading: _uploading,
        onRemove: () => _removeRow(i),
        onCategoryChanged: (v) => setState(() {
          _rows[i].item.category       = v;
          _rows[i].item.categoryFolder = _catName(v);
        }),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final ac = AdminC(Theme.of(context).brightness);

    final pending  = _rows.where((r) => r.status == _RowStatus.pending).length;
    final doneCount= _rows.where((r) => r.status == _RowStatus.done).length;
    final errors   = _rows.where((r) => r.status == _RowStatus.error).length;
    final total    = _rows.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        border: Border(
            top: BorderSide(color: ac.goldBorder, width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusPill(context.adminL10n.pendingCount(total),
                    ac.textSecondary),
                if (doneCount > 0) ...[
                  SizedBox(width: 8),
                  _StatusPill(context.adminL10n.doneCount(doneCount),
                      ac.tealMid),
                ],
                if (errors > 0) ...[
                  const SizedBox(width: 8),
                  _StatusPill(context.adminL10n.failedCount(errors),
                      Colors.redAccent),
                ],
              ],
            ),
          ),
        if (_done)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go(Routes.adminBooks),
              icon: Icon(Icons.library_books_outlined,
                  size: 16, color: ac.bgDeep),
              label: Text(context.adminL10n.manageLibrary,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ac.bgDeep)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.tealMid,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_rows.isNotEmpty && !_uploading) ? _uploadAll : null,
              icon: _uploading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ac.bgDeep))
                  : Icon(Icons.upload_rounded,
                      size: 18, color: ac.bgDeep),
              label: Text(
                _uploading
                    ? context.adminL10n.uploadAll
                    : context.adminL10n.uploadAllN(pending),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ac.bgDeep),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _rows.isNotEmpty && !_uploading
                    ? ac.gold
                    : ac.goldDim.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FileRowCard  — one row per file
// ─────────────────────────────────────────────────────────────────────────────

class _FileRowCard extends StatelessWidget {
  const _FileRowCard({
    required this.row,
    required this.index,
    required this.categories,
    required this.uploading,
    required this.onRemove,
    required this.onCategoryChanged,
  });

  final _FileRow           row;
  final int                index;
  final List<BookCategory> categories;
  final bool               uploading;
  final VoidCallback       onRemove;
  final ValueChanged<String> onCategoryChanged;

  static IconData _iconFor(BookMediaType t) {
    switch (t) {
      case BookMediaType.video: return Icons.videocam_outlined;
      case BookMediaType.audio: return Icons.headphones_outlined;
      default:                  return Icons.picture_as_pdf_outlined;
    }
  }

  static Color _colorFor(BookMediaType t) {
    switch (t) {
      case BookMediaType.video: return EkklisiaColors.ocean;
      case BookMediaType.audio: return EkklisiaColors.darkTealMid;
      default:                  return EkklisiaColors.darkMaroon;
    }
  }

  static String _labelFor(BookMediaType t) {
    switch (t) {
      case BookMediaType.video: return 'Video';
      case BookMediaType.audio: return 'Audio';
      default:                  return 'PDF';
    }
  }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final isUploading = row.status == _RowStatus.uploading;
    final isDone      = row.status == _RowStatus.done;
    final isError     = row.status == _RowStatus.error;

    final borderColor = isDone
        ? ac.tealMid
        : isError
            ? Colors.redAccent
            : isUploading
                ? ac.gold
                : ac.goldBorder;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row header ────────────────────────────────────────────────────
          Row(children: [
            // Type badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _colorFor(row.item.mediaType).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _colorFor(row.item.mediaType).withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_iconFor(row.item.mediaType),
                    size: 12, color: _colorFor(row.item.mediaType)),
                const SizedBox(width: 4),
                Text(_labelFor(row.item.mediaType),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _colorFor(row.item.mediaType))),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.item.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: ac.textSecondary, fontSize: 11),
              ),
            ),
            if (row.item.fileSizeMb > 0)
              Text(
                '${row.item.fileSizeMb.toStringAsFixed(1)} MB',
                style: TextStyle(
                    color: ac.textSecondary, fontSize: 10),
              ),
            if (!uploading && !isDone)
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close,
                      size: 16, color: ac.textSecondary),
                ),
              ),
            if (isDone)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_outline,
                    size: 16, color: ac.tealMid),
              ),
          ]),
          const SizedBox(height: 10),

          // ── Title field + category ────────────────────────────────────────
          if (!isDone && !isUploading) ...[
            _TitleField(ctrl: row.titleCtrl, enabled: !uploading),
            const SizedBox(height: 8),
            _CategoryDropdown(
              value: row.item.category,
              categories: categories,
              onChanged: uploading ? (_) {} : onCategoryChanged,
            ),
          ],

          // ── Upload progress ───────────────────────────────────────────────
          if (isUploading) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: row.progress,
                minHeight: 5,
                backgroundColor: ac.bgElevated,
                valueColor: AlwaysStoppedAnimation(ac.gold),
              ),
            ),
            SizedBox(height: 4),
            Text(row.stepLabel,
                style: TextStyle(
                    color: ac.textSecondary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic)),
          ],

          // ── Error message ─────────────────────────────────────────────────
          if (isError && row.errorMsg != null) ...[
            const SizedBox(height: 6),
            Text('Error: ${row.errorMsg}',
                style: TextStyle(
                    color: Colors.redAccent, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TitleField extends StatelessWidget {
  const _TitleField({required this.ctrl, required this.enabled});
  final TextEditingController ctrl;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return TextField(
      controller: ctrl,
      enabled: enabled,
      textDirection: TextDirection.rtl,
      style: TextStyle(
          fontFamily: 'Scheherazade',
          color: ac.textPrimary,
          fontSize: 14),
      decoration: InputDecoration(
        hintText: 'عنوان الكتاب',
        hintStyle: TextStyle(
            fontFamily: 'Scheherazade',
            color: ac.textSecondary,
            fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: ac.bgElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
              color: ac.goldBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              BorderSide(color: ac.gold, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
              color: ac.goldBorder, width: 0.3),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
    this.label,
  });

  final String             value;
  final List<BookCategory> categories;
  final ValueChanged<String> onChanged;
  final String?            label;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final effectiveValue = categories.any((c) => c.id == value)
        ? value
        : (categories.isNotEmpty ? categories.first.id : null);

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      dropdownColor: ac.bgElevated,
      isDense: true,
      style: TextStyle(
          color: ac.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: ac.textSecondary, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: ac.bgElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
              color: ac.goldBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              BorderSide(color: ac.gold, width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
      ),
      items: categories
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(
                  c.nameAr,
                  style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: ac.textPrimary),
                ),
              ))
          .toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, this.color);
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
