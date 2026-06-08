// lib/admin/content/bible_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — Holy Bible manager.
//
// Capabilities:
//   • View current XML source per language (bundled asset vs remote Cloudinary)
//   • Upload a new .xml file → Cloudinary → saves URL to Firestore bible_config
//   • Remove remote override (revert to bundled asset)
//   • Browse books → chapters → verses
//   • Edit any individual verse (saved as Firestore override)
//   • View / delete all verse overrides
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:core';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/bible_model.dart';
import '../../data/repositories/bible_repository.dart';

// ── Palette aliases ────────────────────────────────────────────────────────────
const _kGold = EkklisiaColors.gold;
const _kNavy = EkklisiaColors.bgDeep;
const _kBorder = EkklisiaColors.goldBorder;

// ════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN — language tabs + XML config + books list
// ════════════════════════════════════════════════════════════════════════════

class BibleManagerScreen extends StatefulWidget {
  const BibleManagerScreen({super.key});

  @override
  State<BibleManagerScreen> createState() => _BibleManagerScreenState();
}

class _BibleManagerScreenState extends State<BibleManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _repo = BibleRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: _kNavy,
            expandedHeight: 90,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              title: Row(
                children: [
                  const Icon(Icons.book, color: _kGold, size: 18),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Holy Bible',
                        style: TextStyle(
                          color: EkklisiaColors.goldLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'الكتاب المقدس',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkklisiaColors.goldDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: _kNavy,
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: _kGold,
                  labelColor: _kGold,
                  unselectedLabelColor: EkklisiaColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Arabic — العربية'),
                    Tab(text: 'Greek — Ελληνικά'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _LangTab(langCode: 'ar', repo: _repo),
            _LangTab(langCode: 'el', repo: _repo),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PER-LANGUAGE TAB
// ════════════════════════════════════════════════════════════════════════════

class _LangTab extends StatefulWidget {
  const _LangTab({required this.langCode, required this.repo});
  final String langCode;
  final BibleRepository repo;

  @override
  State<_LangTab> createState() => _LangTabState();
}

class _LangTabState extends State<_LangTab> with AutomaticKeepAliveClientMixin {
  double? _uploadProgress;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  // ── Upload new XML ──────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    setState(() {
      _uploadProgress = 0;
      _error = null;
    });

    try {
      final cloudinary = sl<CloudinaryDataSource>();
      CloudinaryUploadResult uploaded;

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Could not read file bytes');
        uploaded = await cloudinary.uploadPdfBytes(
          bytes: bytes,
          fileName: file.name,
          folder: 'Ekklisia/bible',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );
      } else {
        uploaded = await cloudinary.uploadPdf(
          pdfFile: File(file.path!),
          folder: 'Ekklisia/bible',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );
      }

      await widget.repo.saveXmlConfig(
        langCode: widget.langCode,
        xmlUrl: uploaded.secureUrl,
        cloudinaryId: uploaded.publicId,
      );

      if (mounted) {
        setState(() => _uploadProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('XML uploaded — remote source active'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _uploadProgress = null;
          _error = e.toString();
        });
    }
  }

  Future<void> _revertToAsset() async {
    final ok = await _confirm(
      'Revert to bundled asset?',
      'The remote XML will be removed and the app will use the built-in asset XML.',
    );
    if (!ok) return;
    await widget.repo.clearXmlConfig(widget.langCode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverted to bundled asset')),
      );
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EkklisiaColors.bgElevated,
        title: Text(
          title,
          style: const TextStyle(
            color: EkklisiaColors.goldLight,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(
            color: EkklisiaColors.textSecondary,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: EkklisiaColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: _kGold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── XML Source Card ──────────────────────────────────────────
        _XmlSourceCard(
          langCode: widget.langCode,
          repo: widget.repo,
          uploadProgress: _uploadProgress,
          error: _error,
          onUpload: _pickAndUpload,
          onRevert: _revertToAsset,
        ),

        const SizedBox(height: 16),

        // ── Verse Overrides Card ─────────────────────────────────────
        _OverridesCard(langCode: widget.langCode, repo: widget.repo),

        const SizedBox(height: 16),

        // ── Books List ───────────────────────────────────────────────
        _BooksCard(langCode: widget.langCode, repo: widget.repo),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// XML SOURCE CARD
// ════════════════════════════════════════════════════════════════════════════

class _XmlSourceCard extends StatelessWidget {
  const _XmlSourceCard({
    required this.langCode,
    required this.repo,
    required this.uploadProgress,
    required this.error,
    required this.onUpload,
    required this.onRevert,
  });

  final String langCode;
  final BibleRepository repo;
  final double? uploadProgress;
  final String? error;
  final VoidCallback onUpload;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.source_outlined,
                color: EkklisiaColors.goldDim,
                size: 15,
              ),
              const SizedBox(width: 8),
              const Text(
                'XML Source',
                style: TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _OutlineBtn(
                label: 'Upload XML',
                icon: Icons.upload_file_outlined,
                onTap: onUpload,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Show Firestore config
          StreamBuilder<Map<String, dynamic>?>(
            stream: repo.watchConfig(langCode),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _MiniShimmer();
              }
              final cfg = snap.data;
              if (cfg == null) {
                return _SourceRow(
                  icon: Icons.folder_zip_outlined,
                  label: 'Bundled asset (default)',
                  sublabel:
                      'assets/bible/${langCode == 'el' ? 'greek' : 'arabic'}.xml',
                  color: const Color(0xFF4CAF50),
                  trailing: null,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceRow(
                    icon: Icons.cloud_done_outlined,
                    label: 'Remote XML active',
                    sublabel: cfg['xml_url'] as String? ?? '',
                    color: _kGold,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.restore_outlined,
                        color: EkklisiaColors.textSecondary,
                        size: 16,
                      ),
                      tooltip: 'Revert to asset',
                      onPressed: onRevert,
                    ),
                  ),
                ],
              );
            },
          ),

          // Upload progress
          if (uploadProgress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: uploadProgress,
                backgroundColor: EkklisiaColors.bgElevated,
                valueColor: const AlwaysStoppedAnimation(_kGold),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${((uploadProgress! * 100).round())}% uploading…',
              style: const TextStyle(
                color: EkklisiaColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],

          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.trailing,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: EkklisiaColors.goldDim,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VERSE OVERRIDES CARD
// ════════════════════════════════════════════════════════════════════════════

class _OverridesCard extends StatelessWidget {
  const _OverridesCard({required this.langCode, required this.repo});
  final String langCode;
  final BibleRepository repo;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_outlined,
                color: EkklisiaColors.goldDim,
                size: 15,
              ),
              const SizedBox(width: 8),
              const Text(
                'Verse Overrides',
                style: TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<BibleVerseOverride>>(
            stream: repo.watchOverrides(langCode),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _MiniShimmer();
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const Text(
                  'No overrides — all verses use the XML source.',
                  style: TextStyle(
                    color: EkklisiaColors.textSecondary,
                    fontSize: 11,
                  ),
                );
              }
              return Column(
                children: items
                    .map((ov) => _OverrideTile(override: ov, repo: repo))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverrideTile extends StatelessWidget {
  const _OverrideTile({required this.override, required this.repo});
  final BibleVerseOverride override;
  final BibleRepository repo;

  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  override.reference,
                  style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color: _kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  override.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkklisiaColors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: EkklisiaColors.textSecondary,
              size: 16,
            ),
            tooltip: 'Delete override',
            onPressed: () async {
              await repo.deleteVerseOverride(
                langCode: override.lang,
                bookNum: override.bookNum,
                chapterNum: override.chapterNum,
                verseNum: override.verseNum,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOOKS CARD  — list that navigates to chapters / verses
// ════════════════════════════════════════════════════════════════════════════

class _BooksCard extends StatefulWidget {
  const _BooksCard({required this.langCode, required this.repo});
  final String langCode;
  final BibleRepository repo;

  @override
  State<_BooksCard> createState() => _BooksCardState();
}

class _BooksCardState extends State<_BooksCard> {
  late Future<List<BibleBook>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.loadBooks(widget.langCode);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_bulleted_outlined,
                color: EkklisiaColors.goldDim,
                size: 15,
              ),
              const SizedBox(width: 8),
              const Text(
                'Books',
                style: TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<BibleBook>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(EkklisiaColors.gold),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Text(
                  'Error: ${snap.error}',
                  style: const TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 11,
                  ),
                );
              }
              final books = snap.data ?? [];
              return Column(
                children: [
                  _TestamentGroup(
                    label: 'العهد القديم — Old Testament',
                    books: books.where((b) => b.testament == 'Old').toList(),
                    langCode: widget.langCode,
                    repo: widget.repo,
                  ),
                  const SizedBox(height: 12),
                  _TestamentGroup(
                    label: 'العهد الجديد — New Testament',
                    books: books.where((b) => b.testament == 'New').toList(),
                    langCode: widget.langCode,
                    repo: widget.repo,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TestamentGroup extends StatelessWidget {
  const _TestamentGroup({
    required this.label,
    required this.books,
    required this.langCode,
    required this.repo,
  });
  final String label;
  final List<BibleBook> books;
  final String langCode;
  final BibleRepository repo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.goldDim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.35,
          ),
          itemCount: books.length,
          itemBuilder: (_, i) {
            final book = books[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _BibleAdminChaptersScreen(
                    book: book,
                    langCode: langCode,
                    repo: repo,
                  ),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: EkklisiaColors.bgPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder, width: 0.5),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.number.toString(),
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      langCode == 'el' ? book.nameEl : book.nameAr,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: langCode == 'el' ? null : 'Scheherazade',
                        color: EkklisiaColors.textSecondary,
                        fontSize: langCode == 'el' ? 8 : 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CHAPTERS SCREEN  (pushed)
// ════════════════════════════════════════════════════════════════════════════

class _BibleAdminChaptersScreen extends StatelessWidget {
  const _BibleAdminChaptersScreen({
    required this.book,
    required this.langCode,
    required this.repo,
  });
  final BibleBook book;
  final String langCode;
  final BibleRepository repo;

  @override
  Widget build(BuildContext context) {
    final bookName = langCode == 'el' ? book.nameEl : book.nameAr;
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: _kNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bookName,
              style: TextStyle(
                fontFamily: langCode == 'el' ? null : 'Scheherazade',
                color: EkklisiaColors.goldLight,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${book.chapterCount} chapters',
              style: const TextStyle(
                color: EkklisiaColors.goldDim,
                fontSize: 10,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _kBorder),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
        ),
        itemCount: book.chapters.length,
        itemBuilder: (_, i) {
          final chapter = book.chapters[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _BibleAdminVersesScreen(
                  book: book,
                  chapter: chapter,
                  langCode: langCode,
                  repo: repo,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: EkklisiaColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder, width: 0.5),
              ),
              child: Center(
                child: Text(
                  '${chapter.number}',
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VERSES SCREEN  (pushed) — verse list + inline edit
// ════════════════════════════════════════════════════════════════════════════

class _BibleAdminVersesScreen extends StatefulWidget {
  const _BibleAdminVersesScreen({
    required this.book,
    required this.chapter,
    required this.langCode,
    required this.repo,
  });
  final BibleBook book;
  final BibleChapter chapter;
  final String langCode;
  final BibleRepository repo;

  @override
  State<_BibleAdminVersesScreen> createState() =>
      _BibleAdminVersesScreenState();
}

class _BibleAdminVersesScreenState extends State<_BibleAdminVersesScreen> {
  // Local override map so edits reflect immediately without re-parsing XML
  final Map<int, String> _localOverrides = {};

  String _verseText(BibleVerse v) => _localOverrides[v.number] ?? v.text;

  Future<void> _editVerse(BibleVerse verse) async {
    final controller = TextEditingController(text: _verseText(verse));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditVerseDialog(
        controller: controller,
        reference:
            '${langCode == 'el' ? widget.book.nameEl : widget.book.nameAr} '
            '${widget.chapter.number}:${verse.number}',
        langCode: widget.langCode,
      ),
    );
    if (result == null) return; // cancelled

    setState(() => _localOverrides[verse.number] = result);

    await widget.repo.saveVerseOverride(
      langCode: widget.langCode,
      bookNum: widget.book.number,
      chapterNum: widget.chapter.number,
      verseNum: verse.number,
      text: result,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.book.nameAr} ${widget.chapter.number}:${verse.number} saved',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String get langCode => widget.langCode;

  @override
  Widget build(BuildContext context) {
    final bookName = langCode == 'el' ? widget.book.nameEl : widget.book.nameAr;
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: _kNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$bookName ${widget.chapter.number}',
              style: TextStyle(
                fontFamily: langCode == 'el' ? null : 'Scheherazade',
                color: EkklisiaColors.goldLight,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${widget.chapter.verses.length} verses  •  tap ✏ to edit',
              style: const TextStyle(
                color: EkklisiaColors.goldDim,
                fontSize: 10,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _kBorder),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.chapter.verses.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 0.5, color: _kBorder),
        itemBuilder: (_, i) {
          final verse = widget.chapter.verses[i];
          final isOverridden = _localOverrides.containsKey(verse.number);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOverridden
                    ? _kGold.withValues(alpha: 0.15)
                    : EkklisiaColors.bgElevated,
                border: Border.all(
                  color: isOverridden ? _kGold : _kBorder,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  verse.number.toString(),
                  style: TextStyle(
                    color: isOverridden ? _kGold : EkklisiaColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            title: Text(
              _verseText(verse),
              style: TextStyle(
                fontFamily: langCode == 'el' ? null : 'Scheherazade',
                color: EkklisiaColors.textPrimary,
                fontSize: langCode == 'el' ? 13 : 16,
                height: 1.6,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 16,
                color: isOverridden ? _kGold : EkklisiaColors.textSecondary,
              ),
              onPressed: () => _editVerse(verse),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EDIT VERSE DIALOG
// ════════════════════════════════════════════════════════════════════════════

class _EditVerseDialog extends StatelessWidget {
  const _EditVerseDialog({
    required this.controller,
    required this.reference,
    required this.langCode,
  });
  final TextEditingController controller;
  final String reference;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    final isArabic = langCode == 'ar';
    return AlertDialog(
      backgroundColor: EkklisiaColors.bgElevated,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Verse',
            style: TextStyle(
              color: EkklisiaColors.goldLight,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            reference,
            style: TextStyle(
              fontFamily: isArabic ? 'Scheherazade' : null,
              color: _kGold,
              fontSize: isArabic ? 14 : 11,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          maxLines: null,
          minLines: 4,
          style: TextStyle(
            fontFamily: isArabic ? 'Scheherazade' : null,
            color: EkklisiaColors.textPrimary,
            fontSize: isArabic ? 18 : 14,
            height: 1.6,
          ),
          decoration: InputDecoration(
            fillColor: EkklisiaColors.bgPrimary,
            filled: true,
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kGold, width: 1),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: EkklisiaColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text(
            'Save',
            style: TextStyle(color: _kGold, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      child: child,
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF5350) : _kGold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniShimmer extends StatelessWidget {
  const _MiniShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      width: 160,
      decoration: BoxDecoration(
        color: EkklisiaColors.bgPrimary,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
