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

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/artwork_section_model.dart';
import '../../data/models/category_label_model.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/repositories/artwork_section_repository.dart';
import '../../data/repositories/category_label_repository.dart';
import '../../data/repositories/pdf_content_repository.dart';
import '../../data/repositories/section_description_repository.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/cached_image.dart';
import '../utils/admin_colors.dart';
import '../utils/drive_link_field.dart';
import '../utils/drive_link_utils.dart';
import 'artwork_section_manager.dart';

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
// (was: hardcoded-dark _kNavy / _kGold aliases — replaced with ac.bgDeep /
// ac.gold at each call site so this screen follows the app theme)

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
  final _descriptionArCtrl = TextEditingController();
  final _descriptionElCtrl = TextEditingController();
  bool  _isVisible  = true;
  bool  _saving     = false;

  /// Only offered when adding brand-new content (not on edits, to avoid
  /// re-notifying users about items that already exist).
  bool  _sendNotif  = true;

  /// Only used/shown when widget.category == PdfCategory.theses — splits
  /// that one category into "Masters" vs "Doctoral" on the reader side.
  String _level = '';
  bool get _isThesesCategory => widget.category == PdfCategory.theses;

  /// Only used/shown when widget.category == PdfCategory.artworks — which
  /// admin-editable [ArtworkSection] this item belongs to.
  String _sectionId = '';

  /// Art Works items are a static visual showcase — cover + bilingual
  /// description — with no PDF/audio/video content to open, unlike every
  /// other category managed by this screen.
  bool get _isArtworksCategory => widget.category == PdfCategory.artworks;

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

  // ── Cover image upload state ────────────────────────────────────────────────
  File?      _coverFile;
  Uint8List? _coverBytes;
  String?    _coverName;
  String     _coverUrl        = '';
  double?    _coverProgress;  // null → not uploading

  // ── Google Drive URL (alternative to file upload) ──────────────────────────
  bool _useDriveUrl = false;
  final _driveUrlCtrl = TextEditingController();
  String? _driveUrlError;

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
    _descriptionArCtrl.dispose();
    _descriptionElCtrl.dispose();
    _driveUrlCtrl.dispose();
    for (final e in _audioTracks) e.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _openAdd() {
    _editing = null;
    _titleArCtrl.clear();
    _titleElCtrl.clear();
    _descriptionArCtrl.clear();
    _descriptionElCtrl.clear();
    _sectionId         = '';
    _isVisible        = true;
    _sendNotif        = true;
    _level             = _isThesesCategory ? ThesisLevel.masters : '';
    _pdfFile          = null;
    _pdfBytes         = null;
    _pdfName          = null;
    _pdfSizeMb        = null;
    _uploadProgress   = null;
    _pdfUrl           = '';
    _cloudinaryPdfId  = '';
    _useDriveUrl      = false;
    _driveUrlCtrl.clear();
    _driveUrlError    = null;
    for (final e in _audioTracks) e.dispose();
    _audioTracks             = [];
    _videoUrl                = '';
    _cloudinaryVideoId       = '';
    _videoFile               = null;
    _videoBytes              = null;
    _videoName               = null;
    _videoUploadProgress     = null;
    _coverFile               = null;
    _coverBytes              = null;
    _coverName                = null;
    _coverUrl                = '';
    _coverProgress            = null;
    setState(() => _mode = _Mode.form);
  }

  void _openEdit(PdfContent item) {
    _editing          = item;
    _titleArCtrl.text = item.titleAr;
    _titleElCtrl.text = item.titleEl;
    _descriptionArCtrl.text = item.descriptionAr;
    _descriptionElCtrl.text = item.descriptionEl;
    _sectionId        = item.sectionId;
    _isVisible        = item.isVisible;
    _level            = item.level.isNotEmpty
        ? item.level
        : (_isThesesCategory ? ThesisLevel.masters : '');
    _pdfFile          = null;
    _pdfBytes         = null;
    _pdfName          = item.pdfUrl.isNotEmpty ? _fileNameFromUrl(item.pdfUrl) : null;
    _pdfSizeMb        = null;
    _uploadProgress   = null;
    _pdfUrl           = item.pdfUrl;
    _cloudinaryPdfId  = item.cloudinaryPdfId;
    // If the existing PDF was stored as a Google Drive link, reopen the
    // form with the Drive tab pre-selected and the link filled back in.
    _useDriveUrl      = looksLikeDriveLink(item.pdfUrl);
    _driveUrlCtrl.text = _useDriveUrl ? item.pdfUrl : '';
    _driveUrlError    = null;
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
    _coverFile             = null;
    _coverBytes            = null;
    _coverName             = null;
    _coverUrl              = item.coverUrl;
    _coverProgress         = null;
    setState(() => _mode = _Mode.form);
  }

  void _backToList() => setState(() {
    _mode    = _Mode.list;
    _editing = null;
  });

  // ── Section description (constant card at the top of the list screen) ──────

  void _openSectionDescriptionEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionDescriptionSheet(category: widget.category),
    );
  }

  // ── Section title (drawer entry + list header override) ────────────────────

  void _openCategoryLabelEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryLabelSheet(
        category: widget.category,
        defaultLabelAr: widget.labelAr,
        defaultLabelEl: PdfCategory.labelEl[widget.category] ?? '',
      ),
    );
  }

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
    // Google Drive mode — skip Cloudinary entirely, store the direct link.
    if (_useDriveUrl) {
      final directUrl = driveShareLinkToDirectUrl(_driveUrlCtrl.text);
      if (directUrl == null) {
        setState(() => _driveUrlError = 'Not a valid Google Drive sharing link');
        return false;
      }
      _pdfUrl          = directUrl;
      _cloudinaryPdfId = '';
      return true;
    }

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

  // ── Pick + upload cover image ───────────────────────────────────────────────

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _coverName     = f.name;
      _coverUrl      = '';       // reset — new file needs upload
      _coverProgress = null;
      if (kIsWeb) {
        _coverBytes = f.bytes;
        _coverFile  = null;
      } else {
        _coverFile  = File(f.path!);
        _coverBytes = null;
      }
    });
  }

  Future<bool> _uploadCoverIfNeeded() async {
    final hasNewFile = (_coverFile != null) || (_coverBytes != null);
    if (!hasNewFile) return true; // already has URL or no cover — skip

    final folder = 'Ekklisia/${widget.category}/covers';
    setState(() => _coverProgress = 0);
    try {
      CloudinaryUploadResult result;
      if (kIsWeb && _coverBytes != null) {
        result = await _cloudinary.uploadCoverImageBytes(
          bytes:    _coverBytes!,
          fileName: _coverName ?? 'cover.jpg',
          folder:   folder,
          onProgress: (p) => setState(() => _coverProgress = p),
        );
      } else {
        result = await _cloudinary.uploadCoverImage(
          imageFile:  _coverFile!,
          folder:     folder,
          onProgress: (p) => setState(() => _coverProgress = p),
        );
      }
      _coverUrl = result.secureUrl;
      setState(() => _coverProgress = 1.0);
      return true;
    } catch (e) {
      setState(() => _coverProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cover upload failed: $e'),
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

      // 3b. Upload cover image if a new file was picked.
      final coverUploaded = await _uploadCoverIfNeeded();
      if (!coverUploaded) return;

      // 4. Build audio track list (skip any with no URL).
      final tracks = _audioTracks
          .where((e) => e.url.isNotEmpty)
          .map((e) => e.toModel())
          .toList();

      final titleAr = _titleArCtrl.text.trim();
      final titleEl = _titleElCtrl.text.trim();
      final descriptionAr = _descriptionArCtrl.text.trim();
      final descriptionEl = _descriptionElCtrl.text.trim();

      if (_editing == null) {
        final newItem = PdfContent(
          id:                   '',
          titleAr:              titleAr,
          titleEl:              titleEl,
          category:             widget.category,
          pdfUrl:               _pdfUrl,
          cloudinaryPdfId:      _cloudinaryPdfId,
          coverUrl:             _coverUrl,
          sortOrder:            0,
          isVisible:            _isVisible,
          createdAt:            DateTime.now(),
          audioTracks:          tracks,
          videoUrl:             _videoUrl,
          cloudinaryVideoId:    _cloudinaryVideoId,
          level:                _level,
          descriptionAr:        descriptionAr,
          descriptionEl:        descriptionEl,
          sectionId:            _sectionId,
        );
        final newId = await _repo.add(newItem);

        // Send push notification — only offered when adding new content
        // (not on edits, to avoid re-notifying users about existing items).
        if (_sendNotif) {
          try {
            await sl<NotificationService>().sendNewContentNotification(
              item:      newItem,
              contentId: newId,
              fcmTokens: const [],
              topic:     AppConstants.newContentTopic,
            );
          } catch (e) {
            debugPrint('[PdfContentManager] Notification failed: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Saved, but push notification failed: $e'),
                backgroundColor: Colors.orange.shade800,
              ));
            }
          }
        }
      } else {
        await _repo.update(_editing!.copyWith(
          titleAr:              titleAr,
          titleEl:              titleEl,
          pdfUrl:               _pdfUrl,
          cloudinaryPdfId:      _cloudinaryPdfId,
          coverUrl:             _coverUrl,
          isVisible:            _isVisible,
          audioTracks:          tracks,
          videoUrl:             _videoUrl,
          cloudinaryVideoId:    _cloudinaryVideoId,
          level:                _level,
          descriptionAr:        descriptionAr,
          descriptionEl:        descriptionEl,
          sectionId:            _sectionId,
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
      final ac = AdminC(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: ac.bgPrimary,
      body: _mode == _Mode.list ? _buildList() : _buildForm(),
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    final ac = AdminC(Theme.of(context).brightness);

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
                icon: Icon(Icons.arrow_back_ios_new,
                    color: ac.textSecondary, size: 18),
                onPressed: () => context.go('/admin/dashboard'),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallBtn(
                    icon:  Icons.title,
                    label: 'Section Title',
                    onTap: () => _openCategoryLabelEditor(context),
                  ),
                  const SizedBox(width: 8),
                  _SmallBtn(
                    icon:  Icons.notes_outlined,
                    label: 'Section Description',
                    onTap: () => _openSectionDescriptionEditor(context),
                  ),
                  if (_isArtworksCategory) ...[
                    const SizedBox(width: 8),
                    _SmallBtn(
                      icon:  Icons.category_outlined,
                      label: 'Sub-Sections',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ArtworkSectionManagerScreen(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _SmallBtn(
                    icon:    Icons.add,
                    label:   'Add Item',
                    onTap:   _openAdd,
                    primary: true,
                  ),
                ],
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
                  ? Center(
                      child: CircularProgressIndicator(
                          color: ac.gold))
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
    final ac = AdminC(Theme.of(context).brightness);

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
            icon: Icon(Icons.arrow_back_ios_new,
                color: ac.textSecondary, size: 18),
            onPressed: _backToList,
          ),
          trailing: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ac.gold))
              : TextButton.icon(
                  onPressed: _save,
                  icon: Icon(Icons.check,
                      color: ac.gold, size: 18),
                  label: Text('Save',
                      style: TextStyle(color: ac.gold)),
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

                  // ── Thesis level (theses category only) ─────────────────
                  if (_isThesesCategory) ...[
                    _FormCard(
                      title:   'Level',
                      titleAr: 'المستوى',
                      child: _ThesisLevelPicker(
                        value:    _level,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _level = v),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Cover Image ──────────────────────────────────────────
                  _FormCard(
                    title:   'Cover Image (Optional)',
                    titleAr: 'صورة الغلاف',
                    child: _CoverPickerTile(
                      existingUrl: _coverUrl,
                      localFile:   _coverFile,
                      localBytes:  _coverBytes,
                      onPick:      _saving ? null : _pickCover,
                      onRemove:    _saving
                          ? null
                          : () => setState(() {
                                _coverFile     = null;
                                _coverBytes    = null;
                                _coverName     = null;
                                _coverUrl      = '';
                                _coverProgress = null;
                              }),
                    ),
                  ),
                  if (_coverProgress != null && _coverProgress! < 1.0) ...[
                    const SizedBox(height: 8),
                    _UploadProgressBar(progress: _coverProgress!),
                  ],
                  const SizedBox(height: 14),

                  // ── Description (Art Works only) ────────────────────────
                  // Art Works items are a static visual showcase, not a
                  // document to open — so instead of a PDF upload, admins
                  // enter a bilingual description shown on the item's
                  // detail view alongside the cover image.
                  if (_isArtworksCategory) ...[
                    _FormCard(
                      title:   'Section',
                      titleAr: 'القسم',
                      child: StreamBuilder<List<ArtworkSection>>(
                        stream: sl<ArtworkSectionRepository>().watchSections(),
                        builder: (context, snap) {
                          final sections = snap.data ?? const <ArtworkSection>[];
                          final validValue = sections.any((s) => s.id == _sectionId)
                              ? _sectionId
                              : null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: validValue,
                                isExpanded: true,
                                dropdownColor: ac.bgElevated,
                                decoration: InputDecoration(
                                  hintText: sections.isEmpty
                                      ? 'No sections yet — add one below'
                                      : 'Select a section',
                                  hintStyle: TextStyle(
                                      color: ac.textSecondary.withValues(alpha: 0.5),
                                      fontSize: 13),
                                  filled: true,
                                  fillColor: ac.bgPrimary,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: ac.goldBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: ac.goldBorder)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: ac.gold, width: 1.5)),
                                ),
                                items: sections
                                    .map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(
                                            s.nameEl.isNotEmpty
                                                ? '${s.nameAr}  ·  ${s.nameEl}'
                                                : s.nameAr,
                                            style: TextStyle(
                                                color: ac.textPrimary, fontSize: 13),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _sectionId = v ?? ''),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ArtworkSectionManagerScreen(),
                                  ),
                                ),
                                child: Text(
                                  'Manage sections',
                                  style: TextStyle(
                                    color: ac.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FormCard(
                      title:   'Description',
                      titleAr: 'الوصف',
                      child: Column(
                        children: [
                          _Field(
                            controller:    _descriptionArCtrl,
                            label:         'Arabic Description',
                            hint:          'أدخل الوصف بالعربية',
                            textDirection: TextDirection.rtl,
                            fontFamily:    'Scheherazade',
                            maxLines:      5,
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            controller: _descriptionElCtrl,
                            label:      'Greek Description',
                            hint:       'Εισαγάγετε την περιγραφή στα ελληνικά',
                            maxLines:   5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                  // ── PDF Upload ─────────────────────────────────────────
                  _FormCard(
                    title:   'PDF File (Optional)',
                    titleAr: 'ملف PDF',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Source toggle
                        SourceToggleTabs(
                          useDriveUrl: _useDriveUrl,
                          onChanged: _saving
                              ? (_) {}
                              : (v) => setState(() {
                                    _useDriveUrl = v;
                                    if (v) {
                                      // Switching to Drive — clear any picked file.
                                      _pdfFile        = null;
                                      _pdfBytes       = null;
                                      _pdfName        = null;
                                      _pdfSizeMb      = null;
                                      _uploadProgress = null;
                                    } else {
                                      _driveUrlCtrl.clear();
                                      _driveUrlError = null;
                                    }
                                  }),
                        ),
                        const SizedBox(height: 10),

                        if (!_useDriveUrl) ...[
                          // Info line
                          Text(
                            'Upload a PDF to Cloudinary folder '
                            '"Ekklisia/${widget.category}".',
                            style: TextStyle(
                              color: ac.textSecondary
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
                        ] else ...[
                          DriveLinkInputCard(
                            controller: _driveUrlCtrl,
                            error: _driveUrlError,
                            onChanged: (v) => setState(() {
                              _driveUrlError = v.trim().isEmpty
                                  ? null
                                  : driveShareLinkToDirectUrl(v) == null
                                      ? 'Not a valid Google Drive sharing link'
                                      : null;
                            }),
                            onClear: () => setState(() {
                              _driveUrlCtrl.clear();
                              _driveUrlError = null;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ],

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
                            color: ac.textSecondary
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
                              color:        ac.bgMid,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: ac.goldBorder,
                                  width: 0.8),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add,
                                    size: 16,
                                    color: _saving
                                        ? ac.textSecondary
                                        : ac.gold),
                                SizedBox(width: 6),
                                Text(
                                  'Add Audio Track',
                                  style: TextStyle(
                                    color: _saving
                                        ? ac.textSecondary
                                        : ac.gold,
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
                            color: ac.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // URL text field
                        TextFormField(
                          initialValue: _videoUrl,
                          style: TextStyle(
                              color: ac.textPrimary,
                              fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Video URL (YouTube or direct link)',
                            labelStyle: TextStyle(
                                color: ac.textSecondary,
                                fontSize: 12),
                            hintText: 'https://youtube.com/... or https://res.cloudinary.com/...',
                            hintStyle: TextStyle(
                                color: ac.textSecondary,
                                fontSize: 11),
                            filled: true,
                            fillColor: ac.bgDeep,
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: ac.goldBorder),
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
                        SizedBox(height: 8),

                        // OR — file upload
                        Row(children: [
                          Expanded(child: Divider(color: ac.goldBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('OR',
                                style: TextStyle(
                                    color: ac.textSecondary
                                        .withValues(alpha: 0.6),
                                    fontSize: 11)),
                          ),
                          Expanded(child: Divider(color: ac.goldBorder)),
                        ]),
                        const SizedBox(height: 8),

                        // File picker button + upload progress
                        if (_videoUploadProgress != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(
                                value: _videoUploadProgress,
                                backgroundColor: ac.bgMid,
                                valueColor: AlwaysStoppedAnimation(
                                    ac.gold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Uploading… ${((_videoUploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: ac.textSecondary,
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
                                color: ac.bgDeep,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: ac.goldBorder,
                                    width: 0.5),
                              ),
                              child: Row(children: [
                                Icon(Icons.videocam_outlined,
                                    color: ac.gold, size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _videoName ?? _videoUrl,
                                    style: TextStyle(
                                        color: ac.textPrimary,
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
                                  child: Icon(Icons.close,
                                      color: ac.textSecondary,
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
                                color: ac.bgMid,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: ac.goldBorder,
                                    width: 0.8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_file,
                                      size: 16,
                                      color: _saving
                                          ? ac.textSecondary
                                          : ac.gold),
                                  SizedBox(width: 6),
                                  Text(
                                    'Upload Video File',
                                    style: TextStyle(
                                      color: _saving
                                          ? ac.textSecondary
                                          : ac.gold,
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
                              Text('Visible to users',
                                  style: TextStyle(
                                      color: ac.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 2),
                              Text(
                                'Hidden items exist but won\'t appear in the app.',
                                style: TextStyle(
                                    color: ac.textSecondary
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
                          activeColor: ac.gold,
                        ),
                      ],
                    ),
                  ),

                  // ── Push notification (new content only) ────────────────
                  if (_editing == null) ...[
                    const SizedBox(height: 14),
                    _FormCard(
                      title:   'Push Notification',
                      titleAr: 'إشعار',
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Notify all devices',
                                    style: TextStyle(
                                        color: ac.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text(
                                  'Sends a push notification when this item is saved.',
                                  style: TextStyle(
                                      color: ac.textSecondary
                                          .withValues(alpha: 0.8),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value:     _sendNotif,
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _sendNotif = v),
                            activeColor: ac.gold,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Save button ────────────────────────────────────────
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.maroon,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: ac.gold))
                          : Text(
                              isAdd ? 'Add Item' : 'Save Changes',
                              style: TextStyle(
                                  color: ac.goldLight,
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        ac.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.goldBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.drag_handle,
                color: ac.textSecondary, size: 20),
          ),

          // ── Order badge ─────────────────────────────────────────────────
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color:  ac.bgDeep,
              shape:  BoxShape.circle,
              border: Border.all(color: ac.goldBorder),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                    color:      ac.gold,
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
              color:        ac.bgDeep,
              borderRadius: BorderRadius.circular(4),
              border:       Border.all(color: ac.goldBorder),
            ),
            child: Icon(Icons.picture_as_pdf_outlined,
                color: ac.gold, size: 14),
          ),
          const SizedBox(width: 4),

          // ── Audio badge (shown when item has tracks) ─────────────────────
          if (item.hasAudio)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color:        ac.bgDeep,
                borderRadius: BorderRadius.circular(4),
                border:       Border.all(color: ac.goldBorder),
              ),
              child: Icon(Icons.music_note,
                  color: ac.gold, size: 14),
            ),

          // ── Level badge (theses category only) ────────────────────────────
          if (item.level.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color:        ac.bgDeep,
                borderRadius: BorderRadius.circular(4),
                border:       Border.all(color: ac.goldBorder),
              ),
              child: Text(
                item.level == ThesisLevel.doctoral ? 'PhD' : 'MA',
                style: TextStyle(
                    color: ac.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 6),

          // ── Titles ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titleAr.isNotEmpty ? item.titleAr : '—',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color:      ac.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.titleEl.isNotEmpty)
                  Text(
                    item.titleEl,
                    style: TextStyle(
                        color:    ac.textSecondary,
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
                    ? ac.gold
                    : ac.textSecondary,
              ),
              onPressed: onToggle,
            ),
          ),

          // ── Edit ─────────────────────────────────────────────────────────
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: ac.textSecondary),
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
// THESIS LEVEL PICKER — masters vs. doctoral, theses category only
// ════════════════════════════════════════════════════════════════════════════

class _ThesisLevelPicker extends StatelessWidget {
  const _ThesisLevelPicker({required this.value, required this.onChanged});

  final String value;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Row(
      children: [
        Expanded(
          child: _LevelOption(
            label: 'Masters — رسائل الماجستير',
            selected: value == ThesisLevel.masters,
            onTap: onChanged == null
                ? null
                : () => onChanged!(ThesisLevel.masters),
            ac: ac,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LevelOption(
            label: 'Doctoral — رسائل الدكتوراه',
            selected: value == ThesisLevel.doctoral,
            onTap: onChanged == null
                ? null
                : () => onChanged!(ThesisLevel.doctoral),
            ac: ac,
          ),
        ),
      ],
    );
  }
}

class _LevelOption extends StatelessWidget {
  const _LevelOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.ac,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final AdminC ac;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? ac.maroon.withValues(alpha: 0.25) : ac.bgMid,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? ac.gold : ac.goldBorder,
            width: selected ? 1.2 : 0.6,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: selected ? ac.gold : ac.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? ac.textPrimary : ac.textSecondary,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ac.bgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hasPdf
                ? ac.tealMid
                : ac.goldBorder,
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
                  ? ac.tealMid
                  : ac.goldDim,
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
                          ? ac.textPrimary
                          : ac.textSecondary,
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
                    style: TextStyle(
                        color:    ac.textSecondary,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: ac.goldDim, size: 18),
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
// COVER IMAGE PICKER TILE
// ════════════════════════════════════════════════════════════════════════════

class _CoverPickerTile extends StatelessWidget {
  const _CoverPickerTile({
    required this.existingUrl,
    required this.localFile,
    required this.localBytes,
    required this.onPick,
    required this.onRemove,
  });

  final String existingUrl;
  final File? localFile;
  final Uint8List? localBytes;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  bool get _hasCover =>
      existingUrl.isNotEmpty || localFile != null || localBytes != null;

  Widget _thumb(AdminC ac) {
    if (localBytes != null) {
      return Image.memory(localBytes!, width: 52, height: 52, fit: BoxFit.cover);
    }
    if (localFile != null) {
      return Image.file(localFile!, width: 52, height: 52, fit: BoxFit.cover);
    }
    if (existingUrl.isNotEmpty) {
      return CachedImage(
        url: existingUrl,
        fit: BoxFit.cover,
        errorWidget: Icon(Icons.image_outlined, color: ac.goldDim, size: 24),
      );
    }
    return Icon(Icons.image_outlined, color: ac.goldDim, size: 24);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ac.bgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hasCover ? ac.tealMid : ac.goldBorder,
            width: _hasCover ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 52, height: 52, child: _thumb(ac)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasCover ? 'Cover image set' : 'Select Cover Image',
                    style: TextStyle(
                      color: _hasCover ? ac.textPrimary : ac.textSecondary,
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasCover ? 'Tap to replace' : 'Shown in lists and the audio player',
                    style: TextStyle(color: ac.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_hasCover && onRemove != null)
              IconButton(
                icon: Icon(Icons.close, color: ac.textSecondary, size: 18),
                onPressed: onRemove,
                tooltip: 'Remove cover',
              )
            else
              Icon(Icons.chevron_right, color: ac.goldDim, size: 18),
          ],
        ),
      ),
    );
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
      final ac = AdminC(Theme.of(context).brightness);
    final done = progress >= 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              done ? 'Upload complete' : 'Uploading to Cloudinary…',
              style: TextStyle(
                  color:    ac.textSecondary,
                  fontSize: 11),
            ),
            Text(
              done ? 'Done ✓' : '${(progress * 100).round()}%',
              style: TextStyle(
                color: done
                    ? ac.tealMid
                    : ac.gold,
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
            backgroundColor: ac.bgElevated,
            valueColor: AlwaysStoppedAnimation(
                done ? ac.tealMid : ac.gold),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        left:   16,
        right:  16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color:  ac.bgDeep,
        border: Border(bottom: BorderSide(color: ac.goldBorder, width: 0.5)),
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
                    style: TextStyle(
                        color:      ac.goldLight,
                        fontSize:   16,
                        fontWeight: FontWeight.w700)),
                Text(titleAr,
                    style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color:      ac.textSecondary,
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
      final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary
              ? ac.maroon
              : ac.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: ac.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ac.gold),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color:      ac.gold,
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color:   ac.maroon.withValues(alpha: 0.9),
      child: Row(
        children: [
          Icon(Icons.swap_vert,
              color: ac.goldLight, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Drag to reorder — save to apply.',
                style: TextStyle(
                    color:    ac.goldLight,
                    fontSize: 12)),
          ),
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text('Cancel',
                style: TextStyle(color: ac.textSecondary)),
          ),
          SizedBox(width: 4),
          ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize:    Size.zero,
              tapTargetSize:  MaterialTapTargetSize.shrinkWrap,
            ),
            child: saving
                ? SizedBox(
                    width:  14,
                    height: 14,
                    child:  CircularProgressIndicator(
                        strokeWidth: 2,
                        color:       ac.bgDeep))
                : Text('Save Order',
                    style: TextStyle(
                        color:      ac.bgDeep,
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
      final ac = AdminC(Theme.of(context).brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✦',
              style: TextStyle(
                  color:    ac.goldDim,
                  fontSize: 40)),
          const SizedBox(height: 12),
          Text('No items yet',
              style: TextStyle(
                  color:      ac.goldLight,
                  fontSize:   14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Add the first PDF item for this category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:    ac.textSecondary,
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
      final ac = AdminC(Theme.of(context).brightness);
    return AlertDialog(
      backgroundColor: ac.bgElevated,
      title: Text('Delete Item',
          style: TextStyle(
              color:    ac.goldLight,
              fontSize: 15)),
      content: RichText(
        text: TextSpan(
          style: TextStyle(
              color:     ac.textSecondary,
              fontSize:  13,
              height:    1.5),
          children: [
            const TextSpan(text: 'Delete '),
            TextSpan(
              text: '"${item.titleAr.isNotEmpty ? item.titleAr : item.titleEl}"',
              style: TextStyle(
                  color:      ac.goldLight,
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
          child: Text('Cancel',
              style: TextStyle(color: ac.textSecondary)),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        ac.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ac.goldBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
                style: TextStyle(
                    color:         ac.goldLight,
                    fontSize:      12,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 0.5)),
            SizedBox(width: 6),
            Text(titleAr,
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color:      ac.textSecondary,
                    fontSize:   12)),
          ]),
          Divider(height: 14, color: ac.goldBorder),
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
      final ac = AdminC(Theme.of(context).brightness);
    final entry = widget.entry;
    final hasFile = entry.hasAudio;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        ac.bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: ac.goldBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: track # + remove button
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        ac.bgDeep,
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: ac.goldBorder),
              ),
              child: Text('Track ${widget.index + 1}',
                  style: TextStyle(
                    color:      ac.gold,
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
              duration: Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        ac.bgMid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFile
                      ? ac.tealMid
                      : ac.goldBorder,
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
                      ? ac.tealMid
                      : ac.goldDim,
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
                              ? ac.textPrimary
                              : ac.textSecondary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hasFile
                            ? 'Tap to replace'
                            : 'MP3, M4A, AAC…',
                        style: TextStyle(
                          color:    ac.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: ac.goldDim, size: 16),
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
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController       controller;
  final String                      label;
  final String                      hint;
  final String?                     fontFamily;
  final TextDirection?              textDirection;
  final String? Function(String?)? validator;
  final int                         maxLines;
  final TextInputType?              keyboardType;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color:      ac.textSecondary,
                fontSize:   11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextFormField(
          controller:    controller,
          textDirection: textDirection,
          validator:     validator,
          maxLines:      maxLines,
          keyboardType:  keyboardType,
          style: TextStyle(
            color:      ac.textPrimary,
            fontSize:   14,
            fontFamily: fontFamily,
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(
                color:    ac.textSecondary.withValues(alpha: 0.4),
                fontSize: 13),
            filled:    true,
            fillColor: ac.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ac.goldBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ac.goldBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: ac.gold, width: 1.5)),
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

// ════════════════════════════════════════════════════════════════════════════
// SECTION DESCRIPTION SHEET — the constant card shown at the top of the
// category's list screen (e.g. Art Works). Bilingual body text plus a
// dynamic list of "available at" link buttons.
// ════════════════════════════════════════════════════════════════════════════

class _CategoryLabelSheet extends StatefulWidget {
  const _CategoryLabelSheet({
    required this.category,
    required this.defaultLabelAr,
    required this.defaultLabelEl,
  });
  final String category;
  final String defaultLabelAr;
  final String defaultLabelEl;

  @override
  State<_CategoryLabelSheet> createState() => _CategoryLabelSheetState();
}

class _CategoryLabelSheetState extends State<_CategoryLabelSheet> {
  final _repo = sl<CategoryLabelRepository>();

  bool _loading = true;
  bool _saving  = false;

  late final _labelArCtrl = TextEditingController();
  late final _labelElCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final override = await _repo.fetch(widget.category);
    if (!mounted) return;
    setState(() {
      _labelArCtrl.text = (override != null && override.labelAr.isNotEmpty)
          ? override.labelAr
          : widget.defaultLabelAr;
      _labelElCtrl.text = (override != null && override.labelEl.isNotEmpty)
          ? override.labelEl
          : widget.defaultLabelEl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _labelArCtrl.dispose();
    _labelElCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.save(CategoryLabel(
        category: widget.category,
        labelAr:  _labelArCtrl.text.trim(),
        labelEl:  _labelElCtrl.text.trim(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ac.bgPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: ac.goldBorder, width: 0.5),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ac.goldBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Section Title',
                            style: TextStyle(
                                color: ac.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: ac.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: ac.goldBorder, height: 1),
                Flexible(
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: ac.gold)),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'The name shown for this section in the '
                                'app\'s side menu and on its screen header '
                                '— in both languages.',
                                style: TextStyle(
                                    color: ac.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                controller:    _labelArCtrl,
                                label:         'Arabic Title',
                                hint:          'مثال: أعمال فنية',
                                textDirection: TextDirection.rtl,
                                fontFamily:    'Scheherazade',
                              ),
                              const SizedBox(height: 12),
                              _Field(
                                controller: _labelElCtrl,
                                label:      'Greek Title',
                                hint:       'e.g. Έργα τέχνης',
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ac.maroon,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: _saving
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: ac.gold))
                                      : Text('Save',
                                          style: TextStyle(
                                              color: ac.gold,
                                              fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionDescriptionSheet extends StatefulWidget {
  const _SectionDescriptionSheet({required this.category});
  final String category;

  @override
  State<_SectionDescriptionSheet> createState() =>
      _SectionDescriptionSheetState();
}

class _SectionDescriptionSheetState extends State<_SectionDescriptionSheet> {
  final _repo = sl<SectionDescriptionRepository>();

  bool _loading = true;
  bool _saving  = false;

  final _descArCtrl = TextEditingController();
  final _descElCtrl = TextEditingController();
  List<_LinkEntry> _links = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final section = await _repo.fetch(widget.category);
    if (!mounted) return;
    setState(() {
      _descArCtrl.text = section?.descriptionAr ?? '';
      _descElCtrl.text = section?.descriptionEl ?? '';
      _links = (section?.links ?? const [])
          .map((l) => _LinkEntry(
                labelAr: l.labelAr,
                labelEl: l.labelEl,
                url: l.url,
              ))
          .toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _descArCtrl.dispose();
    _descElCtrl.dispose();
    for (final e in _links) e.dispose();
    super.dispose();
  }

  void _addLink() => setState(() => _links.add(_LinkEntry()));

  void _removeLink(int i) => setState(() {
        _links.removeAt(i).dispose();
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final links = _links
          .where((e) => e.urlCtrl.text.trim().isNotEmpty ||
              e.labelArCtrl.text.trim().isNotEmpty ||
              e.labelElCtrl.text.trim().isNotEmpty)
          .map((e) => SectionLink(
                labelAr: e.labelArCtrl.text.trim(),
                labelEl: e.labelElCtrl.text.trim(),
                url: e.urlCtrl.text.trim(),
              ))
          .toList();

      await _repo.save(SectionDescription(
        category: widget.category,
        descriptionAr: _descArCtrl.text.trim(),
        descriptionEl: _descElCtrl.text.trim(),
        links: links,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ac.bgPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: ac.goldBorder, width: 0.5),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ac.goldBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Section Description',
                            style: TextStyle(
                                color: ac.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: ac.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: ac.goldBorder, height: 1),
                Flexible(
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: ac.gold)),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Shown as a constant card at the top of this '
                                'category\'s screen — describes the section '
                                'as a whole, not a single item.',
                                style: TextStyle(
                                    color: ac.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                controller:    _descArCtrl,
                                label:         'Arabic Description',
                                hint:          'أدخل الوصف بالعربية',
                                textDirection: TextDirection.rtl,
                                fontFamily:    'Scheherazade',
                                maxLines:      6,
                              ),
                              const SizedBox(height: 12),
                              _Field(
                                controller: _descElCtrl,
                                label:      'Greek Description',
                                hint:       'Περιγραφή στα Ελληνικά',
                                maxLines:   6,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Available At — buttons',
                                        style: TextStyle(
                                            color: ac.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  TextButton.icon(
                                    onPressed: _addLink,
                                    icon: Icon(Icons.add,
                                        size: 16, color: ac.gold),
                                    label: Text('Add',
                                        style: TextStyle(color: ac.gold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (_links.isEmpty)
                                Text(
                                  'No buttons yet — e.g. a partner church or '
                                  'shop link.',
                                  style: TextStyle(
                                      color: ac.textSecondary
                                          .withValues(alpha: 0.7),
                                      fontSize: 11),
                                ),
                              ...List.generate(_links.length, (i) {
                                final e = _links[i];
                                return Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: ac.bgElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: ac.goldBorder, width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text('Button ${i + 1}',
                                                style: TextStyle(
                                                    color: ac.textSecondary,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                          GestureDetector(
                                            onTap: () => _removeLink(i),
                                            child: Icon(Icons.delete_outline,
                                                size: 18,
                                                color: ac.maroonMid),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _Field(
                                        controller:    e.labelArCtrl,
                                        label:         'Arabic Label',
                                        hint:          'مثال: كنيسة العذراء مريم',
                                        textDirection: TextDirection.rtl,
                                        fontFamily:    'Scheherazade',
                                      ),
                                      const SizedBox(height: 8),
                                      _Field(
                                        controller: e.labelElCtrl,
                                        label:      'Greek Label',
                                        hint:       'e.g. Coptic Smart Kids',
                                      ),
                                      const SizedBox(height: 8),
                                      _Field(
                                        controller:   e.urlCtrl,
                                        label:        'URL',
                                        hint:         'https://...',
                                        keyboardType: TextInputType.url,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ac.maroon,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: _saving
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: ac.gold))
                                      : Text('Save',
                                          style: TextStyle(
                                              color: ac.gold,
                                              fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mutable per-row form state for one "available at" link button.
class _LinkEntry {
  _LinkEntry({String labelAr = '', String labelEl = '', String url = ''})
      : labelArCtrl = TextEditingController(text: labelAr),
        labelElCtrl = TextEditingController(text: labelEl),
        urlCtrl     = TextEditingController(text: url);

  final TextEditingController labelArCtrl;
  final TextEditingController labelElCtrl;
  final TextEditingController urlCtrl;

  void dispose() {
    labelArCtrl.dispose();
    labelElCtrl.dispose();
    urlCtrl.dispose();
  }
}
