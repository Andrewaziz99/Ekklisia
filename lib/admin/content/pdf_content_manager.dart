// lib/admin/content/pdf_content_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — generic manager for PDF-based liturgical content.
//
// Parameterized by category slug + display labels.
// Supports: psalmody | liturgy | readings | hymns | occasions
//
// List view:
//   • StreamBuilder on PdfContentRepository.watchAll(category)
//   • Drag-to-reorder (pending-reorder banner with save/cancel)
//   • Visibility toggle, edit pencil, delete trash per row
//   • FAB / "Add Item" button
//
// Form view (add / edit):
//   • titleAr (Arabic, RTL, Scheherazade, required)
//   • titleEl (Greek, optional)
//   • PDF upload via file_picker → Cloudinary (with progress)
//   • isVisible switch
//   • Save → repo.add() / repo.update()
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/repositories/pdf_content_repository.dart';

// ── Audio track entry (mutable form state per track) ──────────────────────────

class _AudioTrackEntry {
  _AudioTrackEntry({
    String labelAr = '',
    String labelEl = '',
    this.url               = '',
    this.cloudinaryAudioId = '',
    this.durationSeconds   = 0,
  }) : labelArCtrl = TextEditingController(text: labelAr),
       labelElCtrl = TextEditingController(text: labelEl);

  final TextEditingController labelArCtrl;
  final TextEditingController labelElCtrl;
  String     url;
  String     cloudinaryAudioId;
  int        durationSeconds;
  File?      audioFile;
  Uint8List? audioBytes;
  String?    audioFileName;
  double?    uploadProgress;

  bool get hasPendingFile => audioFile != null || audioBytes != null;
  bool get hasAudio       => url.isNotEmpty || hasPendingFile;

  ContentAudioTrack toModel() => ContentAudioTrack(
    labelAr:           labelArCtrl.text.trim(),
    labelEl:           labelElCtrl.text.trim(),
    url:               url,
    cloudinaryAudioId: cloudinaryAudioId,
    durationSeconds:   durationSeconds,
  );

  void dispose() {
    labelArCtrl.dispose();
    labelElCtrl.dispose();
  }
}

// ── Palette aliases ────────────────────────────────────────────────────────────
const _kNavy   = EkklisiaColors.bgDeep;
const _kGold   = EkklisiaColors.gold;
const _kBorder = EkklisiaColors.goldBorder;

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════

class PdfContentManagerScreen extends StatefulWidget {
  const PdfContentManagerScreen({
    super.key,
    required this.category,
    required this.labelAr,
    required this.labelEn,
  });

  /// PdfCategory.psalmody | .liturgy | .readings | .hymns | .occasions
  final String category;

  /// e.g. 'الترانيم'
  final String labelAr;

  /// e.g. 'Psalmody'
  final String labelEn;

  @override
  State<PdfContentManagerScreen> createState() =>
      _PdfContentManagerScreenState();
}

enum _Mode { list, form }

class _PdfContentManagerScreenState extends State<PdfContentManagerScreen> {
  final _repo     = sl<PdfContentRepository>();
  final _cloudinary = sl<CloudinaryDataSource>();

  _Mode _mode = _Mode.list;
  PdfContent? _editing; // null → adding new

  // ── Form state ─────────────────────────────────────────────────────────────
  final _formKey    = GlobalKey<FormState>();
  final _titleArCtrl = TextEditingController();
  final _titleElCtrl = TextEditingController();
  bool  _isVisible  = true;
  bool  _saving     = false;

  // ── PDF upload state ────────────────────────────────────────────────────────
  /// Native file (mobile / desktop).
  File?      _pdfFile;
  /// Raw bytes (web).
  Uint8List? _pdfBytes;
  String?    _pdfName;
  double?    _pdfSizeMb;
  double?    _uploadProgress; // null → not uploading

  /// URL of the already-uploaded or pre-existing PDF.
  String _pdfUrl          = '';
  String _cloudinaryPdfId = '';

  // ── Audio tracks state ──────────────────────────────────────────────────────
  List<_AudioTrackEntry> _audioTracks = [];

  // ── Video state ─────────────────────────────────────────────────────────────
  String     _videoUrl          = '';
  String     _cloudinaryVideoId = '';
  File?      _videoFile;
  Uint8List? _videoBytes;
  String?    _videoName;
  double?    _videoUploadProgress;

  // ── Reorder buffer ──────────────────────────────────────────────────────────
  List<PdfContent>? _reorderBuffer;
  bool _reordering = false;

  @override
  void dispose() {
    _titleArCtrl.dispose();
    _titleElCtrl.dispose();
    for (final e in _audioTracks) e.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _openAdd() {
    _editing = null;
    _titleArCtrl.clear();
    _titleElCtrl.clear();
    _isVisible        = true;
    _pdfFile          = null;
    _pdfBytes         = null;
    _pdfName          = null;
    _pdfSizeMb        = null;
    _uploadProgress   = null;
    _pdfUrl           = '';
    _cloudinaryPdfId  = '';
    for (final e in _audioTracks) e.dispose();
    _audioTracks             = [];
    _videoUrl                = '';
    _cloudinaryVideoId       = '';
    _videoFile               = null;
    _videoBytes              = null;
    _videoName               = null;
    _videoUploadProgress     = null;
    setState(() => _mode = _Mode.form);
  }

  void _openEdit(PdfContent item) {
    _editing          = item;
    _titleArCtrl.text = item.titleAr;
    _titleElCtrl.text = item.titleEl;
    _isVisible        = item.isVisible;
    _pdfFile          = null;
    _pdfBytes         = null;
    _pdfName          = item.pdfUrl.isNotEmpty ? _fileNameFromUrl(item.pdfUrl) : null;
    _pdfSizeMb        = null;
    _uploadProgress   = null;
    _pdfUrl           = item.pdfUrl;
    _cloudinaryPdfId  = item.cloudinaryPdfId;
    for (final e in _audioTracks) e.dispose();
    _audioTracks = item.audioTracks.map((t) => _AudioTrackEntry(
      labelAr:           t.labelAr,
      labelEl:           t.labelEl,
      url:               t.url,
      cloudinaryAudioId: t.cloudinaryAudioId,
      durationSeconds:   t.durationSeconds,
    )).toList();
    _videoUrl              = item.videoUrl;
    _cloudinaryVideoId     = item.cloudinaryVideoId;
    _videoFile             = null;
    _videoBytes            = null;
    _videoName             = item.videoUrl.isNotEmpty ? _fileNameFromUrl(item.videoUrl) : null;
    _videoUploadProgress   = null;
    setState(() => _mode = _Mode.form);
  }

  void _backToList() => setState(() {
    _mode    = _Mode.list;
    _editing = null;
  });

  // ── Pick PDF ────────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _pdfName   = f.name;
      _pdfSizeMb = f.size / (1024 * 1024);
      if (kIsWeb) {
        _pdfBytes = f.bytes;
        _pdfFile  = null;
      } else {
        _pdfFile  = File(f.path!);
        _pdfBytes = null;
      }
      // Reset previously uploaded result — user chose a new file.
      _pdfUrl          = '';
      _cloudinaryPdfId = '';
      _uploadProgress  = null;
    });
  }

  // ── Upload PDF to Cloudinary ────────────────────────────────────────────────

  Future<bool> _uploadPdfIfNeeded() async {
    // Nothing to upload — existing URL is still valid.
    if (_pdfFile == null && _pdfBytes == null) return true;

    setState(() => _uploadProgress = 0);

    try {
      final folder = 'Ekklisia/${widget.category}';

      CloudinaryUploadResult result;
      if (kIsWeb && _pdfBytes != null) {
        result = await _cloudinary.uploadPdfBytes(
          bytes:    _pdfBytes!,
          fileName: _pdfName ?? 'document.pdf',
          folder:   folder,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      } else {
        result = await _cloudinary.uploadPdf(
          pdfFile:    _pdfFile!,
          folder:     folder,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      _pdfUrl          = result.secureUrl;
      _cloudinaryPdfId = result.publicId;
      setState(() => _uploadProgress = 1.0);
      return true;
    } catch (e) {
      setState(() => _uploadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF upload failed: $e'),
          backgroundColor: Colors.red.shade800,
        ));
      }
      return false;
    }
  }

  // ── Pick audio for a track ──────────────────────────────────────────────────

  Future<void> _pickAudio(int trackIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      final entry         = _audioTracks[trackIndex];
      entry.audioFileName = f.name;
      entry.url           = '';          // reset — new file needs upload
      entry.uploadProgress = null;
      if (kIsWeb) {
        entry.audioBytes = f.bytes;
        entry.audioFile  = null;
      } else {
        entry.audioFile  = File(f.path!);
        entry.audioBytes = null;
      }
    });
  }

  // ── Upload all pending audio tracks ─────────────────────────────────────────

  Future<bool> _uploadAudioTracksIfNeeded() async {
    for (int i = 0; i < _audioTracks.length; i++) {
      final entry = _audioTracks[i];
      if (!entry.hasPendingFile) continue;

      setState(() => entry.uploadProgress = 0);
      try {
        final folder = 'Ekklisia/${widget.category}/audio';
        CloudinaryUploadResult result;
        if (kIsWeb && entry.audioBytes != null) {
          result = await _cloudinary.uploadAudioBytes(
            bytes:    entry.audioBytes!,
            fileName: entry.audioFileName ?? 'audio.mp3',
            folder:   folder,
            onProgress: (p) => setState(() => entry.uploadProgress = p),
          );
        } else {
          result = await _cloudinary.uploadAudio(
            audioFile:  entry.audioFile!,
            folder:     folder,
            onProgress: (p) => setState(() => entry.uploadProgress = p),
          );
        }
        entry.url               = result.secureUrl;
        entry.cloudinaryAudioId = result.publicId;
        setState(() => entry.uploadProgress = 1.0);
      } catch (e) {
        setState(() => entry.uploadProgress = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Audio upload failed (track ${i + 1}): $e'),
            backgroundColor: Colors.red.shade800,
          ));
        }
        return false;
      }
    }
    return true;
  }

  // ── Pick + upload video ─────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _videoName           = f.name;
      _videoUrl            = '';
      _cloudinaryVideoId   = '';
      _videoUploadProgress = null;
      if (kIsWeb) {
        _videoBytes = f.bytes;
        _videoFile  = null;
      } else {
        _videoFile  = File(f.path!);
        _videoBytes = null;
      }
    });
  }

  Future<bool> _uploadVideoIfNeeded() async {
    final hasNewFile = (_videoFile != null) || (_videoBytes != null);
    if (!hasNewFile) return true; // already has URL or no video — skip

    final folder = 'Ekklisia/${widget.category}/videos';
    setState(() => _videoUploadProgress = 0);
    try {
      CloudinaryUploadResult result;
      if (kIsWeb && _videoBytes != null) {
        result = await _cloudinary.uploadVideoBytes(
          bytes:    _videoBytes!,
          fileName: _videoName ?? 'video.mp4',
          folder:   folder,
          onProgress: (p) => setState(() => _videoUploadProgress = p),
        );
      } else {
        result = await _cloudinary.uploadVideo(
          videoFile:  _videoFile!,
          folder:     folder,
          onProgress: (p) => setState(() => _videoUploadProgress = p),
        );
      }
      _videoUrl          = result.secureUrl;
      _cloudinaryVideoId = result.publicId;
      setState(() => _videoUploadProgress = 1.0);
      return true;
    } catch (e) {
      setState(() => _videoUploadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Video upload failed: $e'),
          backgroundColor: Colors.red.shade800,
        ));
      }
      return false;
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      // 1. Upload PDF if needed.
      final pdfUploaded = await _uploadPdfIfNeeded();
      if (!pdfUploaded) return;

      // 2. Upload any pending audio tracks.
      final audioUploaded = await _uploadAudioTracksIfNeeded();
      if (!audioUploaded) return;

      // 3. Upload video if a new file was picked.
      final videoUploaded = await _uploadVideoIfNeeded();
      if (!videoUploaded) return;

      // 4. Build audio track list (skip any with no URL).
      final tracks = _audioTracks
          .where((e) => e.url.isNotEmpty)
          .map((e) => e.toModel())
          .toList();

      final titleAr = _titleArCtrl.text.trim();
      final titleEl = _titleElCtrl.text.trim();

      if (_editing == null) {
        await _repo.add(PdfContent(
          id:                   '',
          titleAr:              titleAr,
          titleEl:              titleEl,
          category:             widget.category,
          pdfUrl:               _pdfUrl,
          cloudinaryPdfId:      _cloudinaryPdfId,
          coverUrl:             '',
          sortOrder:            0,
          isVisible:            _isVisible,
          createdAt:            DateTime.now(),
          audioTracks:          tracks,
          videoUrl:             _videoUrl,
          cloudinaryVideoId:    _cloudinaryVideoId,
        ));
      } else {
        await _repo.update(_editing!.copyWith(
          titleAr:              titleAr,
          titleEl:              titleEl,
          pdfUrl:               _pdfUrl,
          cloudinaryPdfId:      _cloudinaryPdfId,
          isVisible:            _isVisible,
          audioTracks:          tracks,
          videoUrl:             _videoUrl,
          cloudinaryVideoId:    _cloudinaryVideoId,
        ));
      }

      if (mounted) _backToList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade800,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _delete(PdfContent item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(item: item),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.delete(item.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red.shade800,
        ));
      }
    }
  }

  // ── Reorder ─────────────────────────────────────────────────────────────────

  void _onReorderStart(List<PdfContent> current) =>
      _reorderBuffer = List.of(current);

  void _onReorder(int oldIndex, int newIndex) {
    final list = _reorderBuffer!;
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() {});
  }

  Future<void> _commitReorder() async {
    if (_reorderBuffer == null) return;
    setState(() => _reordering = true);
    try {
      await _repo.reorder(_reorderBuffer!);
      _reorderBuffer = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reorder failed: $e'),
          backgroundColor: Colors.red.shade800,
        ));
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  // ── Utilities ────────────────────────────────────────────────────────────────

  String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.pathSegments.last;
    } catch (_) {
      return 'document.pdf';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      body: _mode == _Mode.list ? _buildList() : _buildForm(),
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    return StreamBuilder<List<PdfContent>>(
      stream: _repo.watchAll(widget.category),
      builder: (context, snap) {
        final items = _reorderBuffer ??
            (snap.hasData ? snap.data! : const <PdfContent>[]);
        final loading = snap.connectionState == ConnectionState.waiting &&
            items.isEmpty;

        return Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            _Header(
              title:   widget.labelEn,
              titleAr: widget.labelAr,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: EkklisiaColors.textSecondary, size: 18),
                onPressed: () => context.go('/admin/dashboard'),
              ),
              trailing: _SmallBtn(
                icon:    Icons.add,
                label:   'Add Item',
                onTap:   _openAdd,
                primary: true,
              ),
            ),

            // ── Pending reorder banner ────────────────────────────────────
            if (_reorderBuffer != null)
              _ReorderBanner(
                saving:   _reordering,
                onSave:   _commitReorder,
                onCancel: () => setState(() => _reorderBuffer = null),
              ),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: EkklisiaColors.gold))
                  : items.isEmpty
                      ? _EmptyState(onAdd: _openAdd)
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          onReorderStart: (_) =>
                              _onReorderStart(snap.data ?? items),
                          onReorder: _onReorder,
                          onReorderEnd: (_) {},
                          itemCount: items.length,
                          itemBuilder: (_, i) => _ContentRow(
                            key:      ValueKey(items[i].id),
                            item:     items[i],
                            index:    i,
                            onEdit:   () => _openEdit(items[i]),
                            onDelete: () => _delete(items[i]),
                            onToggle: () => _repo.toggleVisibility(items[i]),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  // ── Form view (add / edit) ─────────────────────────────────────────────────

  Widget _buildForm() {
    final isAdd = _editing == null;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        _Header(
          title:   isAdd
              ? 'Add — ${widget.labelEn}'
              : 'Edit — ${widget.labelEn}',
          titleAr: isAdd ? 'إضافة عنصر' : 'تعديل العنصر',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: EkklisiaColors.textSecondary, size: 18),
            onPressed: _backToList,
          ),
          trailing: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: EkklisiaColors.gold))
              : TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check,
                      color: EkklisiaColors.gold, size: 18),
                  label: const Text('Save',
                      style: TextStyle(color: EkklisiaColors.gold)),
                ),
        ),

        // ── Form body ────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Titles ─────────────────────────────────────────────
                  _FormCard(
                    title:   'Titles',
                    titleAr: 'العناوين',
                    child: Column(
                      children: [
                        _Field(
                          controller:    _titleArCtrl,
                          label:         'Arabic Title *',
                          hint:          'أدخل العنوان بالعربية',
                          textDirection: TextDirection.rtl,
                          fontFamily:    'Scheherazade',
                          validator:     (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _titleElCtrl,
                          label:      'Greek Title (optional)',
                          hint:       'e.g. Ψαλμωδία',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── PDF Upload ─────────────────────────────────────────
                  _FormCard(
                    title:   'PDF File (Optional)',
                    titleAr: 'ملف PDF',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info line
                        Text(
                          'Upload a PDF to Cloudinary folder '
                          '"Ekklisia/${widget.category}".',
                          style: TextStyle(
                            color: EkklisiaColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Pick button / status
                        _PdfPickerTile(
                          pdfName:  _pdfName,
                          sizeMb:   _pdfSizeMb,
                          existingUrl: _pdfUrl,
                          onPick:   _saving ? null : _pickPdf,
                        ),

                        // Upload progress
                        if (_uploadProgress != null) ...[
                          const SizedBox(height: 10),
                          _UploadProgressBar(progress: _uploadProgress!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Audio Tracks ───────────────────────────────────────
                  _FormCard(
                    title:   'Audio Tracks',
                    titleAr: 'التسجيلات الصوتية',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Optional. Add one or more audio tracks (MP3, AAC…).',
                          style: TextStyle(
                            color: EkklisiaColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Per-track entries
                        ..._audioTracks.asMap().entries.map((e) {
                          final idx   = e.key;
                          final entry = e.value;
                          return _AudioTrackTile(
                            key:      ValueKey(idx),
                            entry:    entry,
                            index:    idx,
                            saving:   _saving,
                            onPick:   () => _pickAudio(idx),
                            onRemove: () => setState(() {
                              _audioTracks.removeAt(idx);
                            }),
                          );
                        }),

                        const SizedBox(height: 8),

                        // Add track button
                        GestureDetector(
                          onTap: _saving
                              ? null
                              : () => setState(
                                    () => _audioTracks.add(_AudioTrackEntry()),
                                  ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color:        EkklisiaColors.bgMid,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: EkklisiaColors.goldBorder,
                                  width: 0.8),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add,
                                    size: 16,
                                    color: _saving
                                        ? EkklisiaColors.textSecondary
                                        : EkklisiaColors.gold),
                                const SizedBox(width: 6),
                                Text(
                                  'Add Audio Track',
                                  style: TextStyle(
                                    color: _saving
                                        ? EkklisiaColors.textSecondary
                                        : EkklisiaColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Video ──────────────────────────────────────────────
                  _FormCard(
                    title:   'Video',
                    titleAr: 'الفيديو',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Optional. Upload a video file or paste a YouTube / Cloudinary URL.',
                          style: TextStyle(
                            color: EkklisiaColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // URL text field
                        TextFormField(
                          initialValue: _videoUrl,
                          style: const TextStyle(
                              color: EkklisiaColors.textPrimary,
                              fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Video URL (YouTube or direct link)',
                            labelStyle: TextStyle(
                                color: EkklisiaColors.textSecondary,
                                fontSize: 12),
                            hintText: 'https://youtube.com/... or https://res.cloudinary.com/...',
                            hintStyle: TextStyle(
                                color: EkklisiaColors.textSecondary,
                                fontSize: 11),
                            filled: true,
                            fillColor: EkklisiaColors.bgDeep,
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: EkklisiaColors.goldBorder),
                            ),
                          ),
                          onChanged: (v) => setState(() {
                            _videoUrl          = v.trim();
                            _cloudinaryVideoId = '';
                            _videoFile         = null;
                            _videoBytes        = null;
                            _videoName         = null;
                          }),
                        ),
                        const SizedBox(height: 8),

                        // OR — file upload
                        Row(children: [
                          const Expanded(child: Divider(color: EkklisiaColors.goldBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('OR',
                                style: TextStyle(
                                    color: EkklisiaColors.textSecondary
                                        .withValues(alpha: 0.6),
                                    fontSize: 11)),
                          ),
                          const Expanded(child: Divider(color: EkklisiaColors.goldBorder)),
                        ]),
                        const SizedBox(height: 8),

                        // File picker button + upload progress
                        if (_videoUploadProgress != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(
                                value: _videoUploadProgress,
                                backgroundColor: EkklisiaColors.bgMid,
                                valueColor: const AlwaysStoppedAnimation(
                                    EkklisiaColors.gold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Uploading… ${((_videoUploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: EkklisiaColors.textSecondary,
                                    fontSize: 11),
                              ),
                            ],
                          )
                        else ...[
                          // Show selected file name or current URL
                          if (_videoName != null || _videoUrl.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: EkklisiaColors.bgDeep,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: EkklisiaColors.goldBorder,
                                    width: 0.5),
                              ),
                              child: Row(children: [
                                const Icon(Icons.videocam_outlined,
                                    color: EkklisiaColors.gold, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _videoName ?? _videoUrl,
                                    style: const TextStyle(
                                        color: EkklisiaColors.textPrimary,
                                        fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _videoUrl          = '';
                                    _cloudinaryVideoId = '';
                                    _videoFile         = null;
                                    _videoBytes        = null;
                                    _videoName         = null;
                                  }),
                                  child: const Icon(Icons.close,
                                      color: EkklisiaColors.textSecondary,
                                      size: 16),
                                ),
                              ]),
                            ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _saving ? null : _pickVideo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: EkklisiaColors.bgMid,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: EkklisiaColors.goldBorder,
                                    width: 0.8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_file,
                                      size: 16,
                                      color: _saving
                                          ? EkklisiaColors.textSecondary
                                          : EkklisiaColors.gold),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Upload Video File',
                                    style: TextStyle(
                                      color: _saving
                                          ? EkklisiaColors.textSecondary
                                          : EkklisiaColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Visibility ─────────────────────────────────────────
                  _FormCard(
                    title:   'Visibility',
                    titleAr: 'الظهور',
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Visible to users',
                                  style: TextStyle(
                                      color: EkklisiaColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                'Hidden items exist but won\'t appear in the app.',
                                style: TextStyle(
                                    color: EkklisiaColors.textSecondary
                                        .withValues(alpha: 0.8),
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value:     _isVisible,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _isVisible = v),
                          activeColor: EkklisiaColors.gold,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save button ────────────────────────────────────────
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EkklisiaColors.maroon,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: EkklisiaColors.gold))
                          : Text(
                              isAdd ? 'Add Item' : 'Save Changes',
                              style: const TextStyle(
                                  color: EkklisiaColors.goldLight,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIST ROW
// ════════════════════════════════════════════════════════════════════════════

class _ContentRow extends StatelessWidget {
  const _ContentRow({
    super.key,
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final PdfContent item;
  final int        index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        EkklisiaColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.drag_handle,
                color: EkklisiaColors.textSecondary, size: 20),
          ),

          // ── Order badge ─────────────────────────────────────────────────
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color:  _kNavy,
              shape:  BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color:      _kGold,
                    fontSize:   10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── PDF icon badge ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color:        _kNavy,
              borderRadius: BorderRadius.circular(4),
              border:       Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined,
                color: _kGold, size: 14),
          ),
          const SizedBox(width: 4),

          // ── Audio badge (shown when item has tracks) ─────────────────────
          if (item.hasAudio)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color:        _kNavy,
                borderRadius: BorderRadius.circular(4),
                border:       Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.music_note,
                  color: _kGold, size: 14),
            ),
          const SizedBox(width: 6),

          // ── Titles ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titleAr.isNotEmpty ? item.titleAr : '—',
                  style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color:      EkklisiaColors.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.titleEl.isNotEmpty)
                  Text(
                    item.titleEl,
                    style: const TextStyle(
                        color:    EkklisiaColors.textSecondary,
                        fontSize: 11),
                  ),
              ],
            ),
          ),

          // ── Visibility toggle ────────────────────────────────────────────
          Tooltip(
            message: item.isVisible ? 'Visible' : 'Hidden',
            child: IconButton(
              icon: Icon(
                item.isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size:  18,
                color: item.isVisible
                    ? EkklisiaColors.gold
                    : EkklisiaColors.textSecondary,
              ),
              onPressed: onToggle,
            ),
          ),

          // ── Edit ─────────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: EkklisiaColors.textSecondary),
            onPressed: onEdit,
          ),

          // ── Delete ───────────────────────────────────────────────────────
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: Colors.red.shade400),
            onPressed: onDelete,
          ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PDF PICKER TILE
// ════════════════════════════════════════════════════════════════════════════

class _PdfPickerTile extends StatelessWidget {
  const _PdfPickerTile({
    required this.pdfName,
    required this.sizeMb,
    required this.existingUrl,
    required this.onPick,
  });

  final String?      pdfName;
  final double?      sizeMb;
  final String       existingUrl;
  final VoidCallback? onPick;

  bool get _hasPdf => pdfName != null || existingUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EkklisiaColors.bgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hasPdf
                ? EkklisiaColors.tealMid
                : _kBorder,
            width: _hasPdf ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _hasPdf
                  ? Icons.check_circle_outline
                  : Icons.picture_as_pdf_outlined,
              size:  26,
              color: _hasPdf
                  ? EkklisiaColors.tealMid
                  : EkklisiaColors.goldDim,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasPdf
                        ? (pdfName ?? _shortUrl(existingUrl))
                        : 'Select PDF File',
                    style: TextStyle(
                      color: _hasPdf
                          ? EkklisiaColors.textPrimary
                          : EkklisiaColors.textSecondary,
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasPdf
                        ? (sizeMb != null
                            ? '${sizeMb!.toStringAsFixed(2)} MB — Tap to replace'
                            : 'Tap to replace')
                        : 'PDF only — Max 100 MB',
                    style: const TextStyle(
                        color:    EkklisiaColors.textSecondary,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: EkklisiaColors.goldDim, size: 18),
          ],
        ),
      ),
    );
  }

  String _shortUrl(String url) {
    try {
      return Uri.parse(url).pathSegments.last;
    } catch (_) {
      return 'document.pdf';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// UPLOAD PROGRESS BAR
// ════════════════════════════════════════════════════════════════════════════

class _UploadProgressBar extends StatelessWidget {
  const _UploadProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              done ? 'Upload complete' : 'Uploading to Cloudinary…',
              style: const TextStyle(
                  color:    EkklisiaColors.textSecondary,
                  fontSize: 11),
            ),
            Text(
              done ? 'Done ✓' : '${(progress * 100).round()}%',
              style: TextStyle(
                color: done
                    ? EkklisiaColors.tealMid
                    : EkklisiaColors.gold,
                fontSize:   11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           progress,
            minHeight:       6,
            backgroundColor: EkklisiaColors.bgElevated,
            valueColor: AlwaysStoppedAnimation(
                done ? EkklisiaColors.tealMid : EkklisiaColors.gold),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS / SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.titleAr,
    this.leading,
    this.trailing,
  });
  final String  title;
  final String  titleAr;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        left:   16,
        right:  16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color:  _kNavy,
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          if (leading == null) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color:      EkklisiaColors.goldLight,
                        fontSize:   16,
                        fontWeight: FontWeight.w700)),
                Text(titleAr,
                    style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        color:      EkklisiaColors.textSecondary,
                        fontSize:   12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final bool         primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary
              ? EkklisiaColors.maroon
              : EkklisiaColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _kGold),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color:      _kGold,
                    fontSize:   11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ReorderBanner extends StatelessWidget {
  const _ReorderBanner({
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });
  final bool         saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color:   EkklisiaColors.maroon.withValues(alpha: 0.9),
      child: Row(
        children: [
          const Icon(Icons.swap_vert,
              color: EkklisiaColors.goldLight, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Drag to reorder — save to apply.',
                style: TextStyle(
                    color:    EkklisiaColors.goldLight,
                    fontSize: 12)),
          ),
          TextButton(
            onPressed: saving ? null : onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: EkklisiaColors.textSecondary)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: EkklisiaColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize:    Size.zero,
              tapTargetSize:  MaterialTapTargetSize.shrinkWrap,
            ),
            child: saving
                ? const SizedBox(
                    width:  14,
                    height: 14,
                    child:  CircularProgressIndicator(
                        strokeWidth: 2,
                        color:       EkklisiaColors.bgDeep))
                : const Text('Save Order',
                    style: TextStyle(
                        color:      EkklisiaColors.bgDeep,
                        fontSize:   11,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✦',
              style: TextStyle(
                  color:    EkklisiaColors.goldDim,
                  fontSize: 40)),
          const SizedBox(height: 12),
          const Text('No items yet',
              style: TextStyle(
                  color:      EkklisiaColors.goldLight,
                  fontSize:   14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Add the first PDF item for this category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:    EkklisiaColors.textSecondary,
                  fontSize: 12)),
          const SizedBox(height: 20),
          _SmallBtn(
            icon:    Icons.add,
            label:   'Add First Item',
            primary: true,
            onTap:   onAdd,
          ),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.item});
  final PdfContent item;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: EkklisiaColors.bgElevated,
      title: const Text('Delete Item',
          style: TextStyle(
              color:    EkklisiaColors.goldLight,
              fontSize: 15)),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(
              color:     EkklisiaColors.textSecondary,
              fontSize:  13,
              height:    1.5),
          children: [
            const TextSpan(text: 'Delete '),
            TextSpan(
              text: '"${item.titleAr.isNotEmpty ? item.titleAr : item.titleEl}"',
              style: const TextStyle(
                  color:      EkklisiaColors.goldLight,
                  fontWeight: FontWeight.w700),
            ),
            const TextSpan(
                text: '?\n\nThe PDF record will be removed from Firestore. '
                    'The Cloudinary asset is not deleted automatically. '
                    'This cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: EkklisiaColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete',
              style: TextStyle(
                  color:      Colors.red.shade400,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        EkklisiaColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
                style: const TextStyle(
                    color:         EkklisiaColors.goldLight,
                    fontSize:      12,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(width: 6),
            Text(titleAr,
                style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color:      EkklisiaColors.textSecondary,
                    fontSize:   12)),
          ]),
          const Divider(height: 14, color: EkklisiaColors.goldBorder),
          child,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AUDIO TRACK TILE
// ════════════════════════════════════════════════════════════════════════════

class _AudioTrackTile extends StatefulWidget {
  const _AudioTrackTile({
    super.key,
    required this.entry,
    required this.index,
    required this.saving,
    required this.onPick,
    required this.onRemove,
  });

  final _AudioTrackEntry entry;
  final int              index;
  final bool             saving;
  final VoidCallback     onPick;
  final VoidCallback     onRemove;

  @override
  State<_AudioTrackTile> createState() => _AudioTrackTileState();
}

class _AudioTrackTileState extends State<_AudioTrackTile> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasFile = entry.hasAudio;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        EkklisiaColors.bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: EkklisiaColors.goldBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: track # + remove button
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        EkklisiaColors.bgDeep,
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: EkklisiaColors.goldBorder),
              ),
              child: Text('Track ${widget.index + 1}',
                  style: const TextStyle(
                    color:      EkklisiaColors.gold,
                    fontSize:   10,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close,
                  size: 18, color: Colors.red.shade400),
              onPressed: widget.saving ? null : widget.onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Remove track',
            ),
          ]),
          const SizedBox(height: 10),

          // Arabic label
          _Field(
            controller: entry.labelArCtrl,
            label:      'Label (Arabic, optional)',
            hint:       'e.g. اللحن القبطي',
            textDirection: TextDirection.rtl,
            fontFamily: 'Scheherazade',
          ),
          const SizedBox(height: 8),

          // English/Greek label
          _Field(
            controller: entry.labelElCtrl,
            label:      'Label (English/Greek, optional)',
            hint:       'e.g. Coptic Melody',
          ),
          const SizedBox(height: 10),

          // Audio file picker
          GestureDetector(
            onTap: widget.saving ? null : widget.onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        EkklisiaColors.bgMid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFile
                      ? EkklisiaColors.tealMid
                      : EkklisiaColors.goldBorder,
                  width: hasFile ? 1.0 : 0.5,
                ),
              ),
              child: Row(children: [
                Icon(
                  hasFile
                      ? Icons.check_circle_outline
                      : Icons.audio_file_outlined,
                  size:  22,
                  color: hasFile
                      ? EkklisiaColors.tealMid
                      : EkklisiaColors.goldDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFile
                            ? (entry.audioFileName ??
                                _shortUrl(entry.url))
                            : 'Select Audio File',
                        style: TextStyle(
                          color: hasFile
                              ? EkklisiaColors.textPrimary
                              : EkklisiaColors.textSecondary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hasFile
                            ? 'Tap to replace'
                            : 'MP3, M4A, AAC…',
                        style: const TextStyle(
                          color:    EkklisiaColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: EkklisiaColors.goldDim, size: 16),
              ]),
            ),
          ),

          // Upload progress (shown while uploading)
          if (entry.uploadProgress != null) ...[
            const SizedBox(height: 8),
            _UploadProgressBar(progress: entry.uploadProgress!),
          ],
        ],
      ),
    );
  }

  String _shortUrl(String url) {
    try {
      return Uri.parse(url).pathSegments.last;
    } catch (_) {
      return 'audio';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TEXT FIELD
// ════════════════════════════════════════════════════════════════════════════

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.fontFamily,
    this.textDirection,
    this.validator,
  });

  final TextEditingController       controller;
  final String                      label;
  final String                      hint;
  final String?                     fontFamily;
  final TextDirection?              textDirection;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color:      EkklisiaColors.textSecondary,
                fontSize:   11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextFormField(
          controller:    controller,
          textDirection: textDirection,
          validator:     validator,
          style: TextStyle(
            color:      EkklisiaColors.textPrimary,
            fontSize:   14,
            fontFamily: fontFamily,
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(
                color:    EkklisiaColors.textSecondary.withValues(alpha: 0.4),
                fontSize: 13),
            filled:    true,
            fillColor: EkklisiaColors.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: EkklisiaColors.goldBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: EkklisiaColors.goldBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: EkklisiaColors.gold, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade700)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Colors.red.shade700, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
