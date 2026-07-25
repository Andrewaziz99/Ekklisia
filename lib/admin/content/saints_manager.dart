// lib/admin/content/saints_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — Saints manager.
//
// Two modes:
//   • list  — table of all saints with CRUD actions
//   • edit  — full form: cover image, PDF (optional), audio, video, biography
//
// Media uploads go through CloudinaryDataSource.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../admin_l10n.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/saint_model.dart';
import '../../data/repositories/saints_repository.dart';
import '../../features/auth/auth_cubit.dart';
import '../utils/admin_colors.dart';
import '../utils/drive_link_utils.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kRadius = BorderRadius.all(Radius.circular(8));

enum _ScreenMode { list, edit }

// ════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ════════════════════════════════════════════════════════════════════════════

class SaintsManagerScreen extends StatefulWidget {
  const SaintsManagerScreen({super.key});

  @override
  State<SaintsManagerScreen> createState() => _SaintsManagerScreenState();
}

class _SaintsManagerScreenState extends State<SaintsManagerScreen> {
  final _repo = sl<SaintsRepository>();

  _ScreenMode _mode = _ScreenMode.list;
  SaintModel? _editing;

  void _openEdit(SaintModel? saint) =>
      setState(() { _editing = saint; _mode = _ScreenMode.edit; });

  void _backToList() =>
      setState(() { _editing = null; _mode = _ScreenMode.list; });

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    if (_mode == _ScreenMode.edit) {
      return _EditView(repo: _repo, initial: _editing, onDone: _backToList);
    }
    return _ListView(repo: _repo, onEdit: _openEdit);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIST VIEW
// ════════════════════════════════════════════════════════════════════════════

class _ListView extends StatefulWidget {
  const _ListView({required this.repo, required this.onEdit});
  final SaintsRepository repo;
  final void Function(SaintModel?) onEdit;

  @override
  State<_ListView> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  String _search = '';
  String? _deleteConfirmId;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return StreamBuilder<List<SaintModel>>(
      stream: widget.repo.watchAll(),
      builder: (context, snap) {
        final saints = (snap.data ?? [])
            .where((s) {
              final q = _search.toLowerCase();
              return q.isEmpty ||
                  s.nameEn.toLowerCase().contains(q) ||
                  s.nameAr.contains(q);
            })
            .toList();
        final loading = snap.connectionState == ConnectionState.waiting;

        return Column(children: [
          // ── Toolbar ───────────────────────────────────────────────────
          _Toolbar(
            title: context.adminL10n.saints,
            count: saints.length,
            onSearch: (q) => setState(() => _search = q),
            onAdd: () => widget.onEdit(null),
            onBulkUpload: () => context.go(Routes.adminCmsSaintsBulk),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: ac.gold,
                      strokeWidth: 2,
                    ),
                  )
                : saints.isEmpty
                    ? _EmptyState(onAdd: () => widget.onEdit(null))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: saints.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = saints[i];
                          return _SaintCard(
                            saint: s,
                            confirmingDelete: _deleteConfirmId == s.id,
                            onEdit: () => widget.onEdit(s),
                            onToggle: () => widget.repo
                                .togglePublished(s.id, !s.isPublished),
                            onDeleteTap: () => setState(
                                () => _deleteConfirmId = s.id),
                            onDeleteConfirm: () async {
                              await widget.repo.delete(s.id);
                              setState(() => _deleteConfirmId = null);
                            },
                            onDeleteCancel: () =>
                                setState(() => _deleteConfirmId = null),
                          );
                        },
                      ),
          ),
        ]);
      },
    );
  }
}

// ── Saint card ────────────────────────────────────────────────────────────────

class _SaintCard extends StatelessWidget {
  const _SaintCard({
    required this.saint,
    required this.confirmingDelete,
    required this.onEdit,
    required this.onToggle,
    required this.onDeleteTap,
    required this.onDeleteConfirm,
    required this.onDeleteCancel,
  });

  final SaintModel saint;
  final bool confirmingDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDeleteTap;
  final VoidCallback onDeleteConfirm;
  final VoidCallback onDeleteCancel;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: _kRadius,
        border: Border.all(
          color: confirmingDelete
              ? ac.maroon.withValues(alpha: 0.6)
              : ac.goldBorder,
          width: 0.5,
        ),
      ),
      child: confirmingDelete
          ? _DeleteConfirmRow(
              onConfirm: onDeleteConfirm,
              onCancel: onDeleteCancel,
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                // Cover thumb
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ac.bgMid,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: ac.goldBorder, width: 0.5),
                  ),
                  child: saint.hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(
                            saint.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _crossIcon(),
                          ),
                        )
                      : _crossIcon(),
                ),
                const SizedBox(width: 12),

                // Names + feast date + media chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saint.nameEn,
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        saint.nameAr,
                        style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Scheherazade',
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(children: [
                        if (saint.feastDate != null) ...[
                          _Chip(
                            label: saint.feastDate!,
                            color: ac.gold,
                          ),
                          SizedBox(width: 4),
                        ],
                        if (saint.hasPdf)
                          _Chip(
                              label: '📄 pdf',
                              color: ac.bronze),
                        if (saint.hasAudio) ...[
                          SizedBox(width: 4),
                          _Chip(
                              label: '♪ audio',
                              color: ac.tealMid),
                        ],
                        if (saint.hasVideo) ...[
                          SizedBox(width: 4),
                          _Chip(
                              label: '▶ video',
                              color: ac.plum),
                        ],
                      ]),
                    ],
                  ),
                ),

                // Status + actions
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onToggle,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: saint.isPublished
                              ? ac.tealMid.withValues(alpha: 0.15)
                              : ac.bgMid,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: saint.isPublished
                                ? ac.tealMid
                                : ac.goldBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          saint.isPublished ? 'ΕΝΕΡΓΟ' : 'ΠΡΌΧΕΙΡΟ',
                          style: TextStyle(
                            color: saint.isPublished
                                ? ac.tealMid
                                : ac.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _IconBtn(
                          icon: Icons.edit_outlined,
                          color: ac.gold,
                          onTap: onEdit),
                      SizedBox(width: 4),
                      _IconBtn(
                          icon: Icons.delete_outline,
                          color: ac.maroonMid,
                          onTap: onDeleteTap),
                    ]),
                  ],
                ),
              ]),
            ),
    );
  }

  Widget _crossIcon() => Center(
    child: Text('✦',
        style: TextStyle(
            color: EkklisiaColors.darkGoldBorder, fontSize: 18)),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// EDIT VIEW
// ════════════════════════════════════════════════════════════════════════════

class _EditView extends StatefulWidget {
  const _EditView({
    required this.repo,
    required this.initial,
    required this.onDone,
  });
  final SaintsRepository repo;
  final SaintModel?      initial;
  final VoidCallback     onDone;

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  final _formKey   = GlobalKey<FormState>();
  final _cloudinary = sl<CloudinaryDataSource>();

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _nameEn    = TextEditingController();
  final _nameAr    = TextEditingController();
  final _nameCop   = TextEditingController();
  final _feastDate = TextEditingController();
  final _patronEn  = TextEditingController();
  final _patronAr  = TextEditingController();
  final _bioEn     = TextEditingController();
  final _bioAr     = TextEditingController();

  bool _published = true;

  // ── Cover image ──────────────────────────────────────────────────────────────
  File?      _coverFile;
  Uint8List? _coverBytes;
  String?    _coverName;
  String     _coverUrl = '';
  String     _coverCloudId = '';
  double     _coverProgress = 0;
  bool       _coverUploading = false;

  // ── PDF (optional) ───────────────────────────────────────────────────────────
  File?      _pdfFile;
  Uint8List? _pdfBytes;
  String?    _pdfName;
  double?    _pdfSizeMb;
  String     _pdfUrl = '';
  String     _pdfCloudId = '';
  double     _pdfProgress = 0;
  bool       _pdfUploading = false;
  final _pdfUrlCtrl = TextEditingController();

  // ── Audio (optional) ─────────────────────────────────────────────────────────
  File?      _audioFile;
  Uint8List? _audioBytes;
  String?    _audioName;
  String     _audioUrl = '';
  String     _audioCloudId = '';
  double     _audioProgress = 0;
  bool       _audioUploading = false;

  // ── Video (optional) ─────────────────────────────────────────────────────────
  File?      _videoFile;
  Uint8List? _videoBytes;
  String?    _videoName;
  String     _videoUrl = '';
  String     _videoCloudId = '';
  double?    _videoProgress;
  final _videoUrlCtrl = TextEditingController();

  // ── Saving ────────────────────────────────────────────────────────────────────
  bool   _saving    = false;
  String _saveError = '';

  @override
  void initState() {
    super.initState();

    // Google Drive "Anyone with the link" share URLs are auto-converted to
    // their direct-download form (matches the Books upload flow).
    _pdfUrlCtrl.addListener(() {
      final v = _pdfUrlCtrl.text.trim();
      final driveUrl = driveShareLinkToDirectUrl(v);
      if (driveUrl != null && driveUrl != v) {
        _pdfUrlCtrl.value = _pdfUrlCtrl.value.copyWith(
          text: driveUrl,
          selection: TextSelection.collapsed(offset: driveUrl.length),
        );
        return; // listener re-fires with the converted text
      }
      if (v != _pdfUrl) setState(() { _pdfUrl = v; _pdfCloudId = ''; });
    });

    _videoUrlCtrl.addListener(() {
      final v = _videoUrlCtrl.text.trim();
      if (v != _videoUrl) {
        setState(() {
          _videoUrl = v;
          _videoCloudId = '';
          _videoFile = null;
          _videoBytes = null;
          _videoName = null;
        });
      }
    });

    final s = widget.initial;
    if (s != null) {
      _nameEn.text    = s.nameEn;
      _nameAr.text    = s.nameAr;
      _nameCop.text   = s.nameCoptic ?? '';
      _feastDate.text = s.feastDate ?? '';
      _patronEn.text  = s.patronOfEn ?? '';
      _patronAr.text  = s.patronOfAr ?? '';
      _bioEn.text     = s.biographyEn ?? '';
      _bioAr.text     = s.biographyAr ?? '';
      _published      = s.isPublished;
      _coverUrl       = s.imageUrl;
      _coverCloudId   = s.cloudinaryImageId;
      _pdfUrl         = s.pdfUrl;
      _pdfCloudId     = s.cloudinaryPdfId;
      _pdfUrlCtrl.text = s.pdfUrl;
      _audioUrl       = s.audioUrl;
      _audioCloudId   = s.cloudinaryAudioId;
      _videoUrl       = s.videoUrl;
      _videoCloudId   = s.cloudinaryVideoId;
      _videoUrlCtrl.text = s.videoUrl;
    }
  }

  @override
  void dispose() {
    _nameEn.dispose(); _nameAr.dispose(); _nameCop.dispose();
    _feastDate.dispose(); _patronEn.dispose(); _patronAr.dispose();
    _bioEn.dispose(); _bioAr.dispose();
    _pdfUrlCtrl.dispose(); _videoUrlCtrl.dispose();
    super.dispose();
  }

  // ── Pick helpers ─────────────────────────────────────────────────────────────

  Future<void> _pickCover() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 88);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _coverName  = img.name;
      _coverBytes = bytes;
      _coverFile  = kIsWeb ? null : File(img.path);
      _coverUrl   = '';
      _coverCloudId = '';
    });
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf'],
            withData: kIsWeb);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _pdfName   = f.name;
      _pdfSizeMb = (f.size / 1024 / 1024);
      _pdfFile   = kIsWeb ? null : File(f.path!);
      _pdfBytes  = kIsWeb ? f.bytes : null;
      _pdfUrl    = '';
      _pdfCloudId = '';
      _pdfUrlCtrl.clear();
    });
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.audio, withData: kIsWeb);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _audioName  = f.name;
      _audioFile  = kIsWeb ? null : File(f.path!);
      _audioBytes = kIsWeb ? f.bytes : null;
      _audioUrl   = '';
      _audioCloudId = '';
    });
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.video, withData: kIsWeb);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _videoName  = f.name;
      _videoFile  = kIsWeb ? null : File(f.path!);
      _videoBytes = kIsWeb ? f.bytes : null;
      _videoUrl   = '';
      _videoCloudId = '';
      _videoUrlCtrl.clear();
    });
  }

  // ── Upload helpers ────────────────────────────────────────────────────────────

  Future<void> _uploadCoverIfNeeded() async {
    if (_coverUrl.isNotEmpty || (_coverFile == null && _coverBytes == null))
      return;
    setState(() { _coverUploading = true; _coverProgress = 0; });
    try {
      final res = kIsWeb
          ? await _cloudinary.uploadCoverImageBytes(
              bytes: _coverBytes!,
              fileName: _coverName ?? 'cover',
              folder: 'Ekklisia/saints',
              onProgress: (p) => setState(() => _coverProgress = p))
          : await _cloudinary.uploadCoverImage(
              imageFile: _coverFile!,
              folder: 'Ekklisia/saints',
              onProgress: (p) => setState(() => _coverProgress = p));
      setState(() {
        _coverUrl     = res.secureUrl;
        _coverCloudId = res.publicId;
      });
    } finally {
      setState(() { _coverUploading = false; });
    }
  }

  Future<void> _uploadPdfIfNeeded() async {
    if (_pdfUrl.isNotEmpty || (_pdfFile == null && _pdfBytes == null)) return;
    setState(() { _pdfUploading = true; _pdfProgress = 0; });
    try {
      final res = kIsWeb
          ? await _cloudinary.uploadPdfBytes(
              bytes: _pdfBytes!,
              fileName: _pdfName ?? 'saint',
              folder: 'Ekklisia/saints',
              onProgress: (p) => setState(() => _pdfProgress = p))
          : await _cloudinary.uploadPdf(
              pdfFile: _pdfFile!,
              folder: 'Ekklisia/saints',
              onProgress: (p) => setState(() => _pdfProgress = p));
      setState(() {
        _pdfUrl     = res.secureUrl;
        _pdfCloudId = res.publicId;
      });
    } finally {
      setState(() { _pdfUploading = false; });
    }
  }

  Future<void> _uploadAudioIfNeeded() async {
    if (_audioUrl.isNotEmpty || (_audioFile == null && _audioBytes == null))
      return;
    setState(() { _audioUploading = true; _audioProgress = 0; });
    try {
      final res = kIsWeb
          ? await _cloudinary.uploadVideoBytes(
              bytes: _audioBytes!,
              fileName: _audioName ?? 'saint_audio',
              folder: 'Ekklisia/saints/audio',
              onProgress: (p) => setState(() => _audioProgress = p))
          : await _cloudinary.uploadVideo(
              videoFile: _audioFile!,
              folder: 'Ekklisia/saints/audio',
              onProgress: (p) => setState(() => _audioProgress = p));
      setState(() {
        _audioUrl     = res.secureUrl;
        _audioCloudId = res.publicId;
      });
    } finally {
      setState(() { _audioUploading = false; });
    }
  }

  Future<void> _uploadVideoIfNeeded() async {
    if (_videoUrl.isNotEmpty || (_videoFile == null && _videoBytes == null))
      return;
    setState(() => _videoProgress = 0);
    try {
      final res = kIsWeb
          ? await _cloudinary.uploadVideoBytes(
              bytes: _videoBytes!,
              fileName: _videoName ?? 'saint_video',
              folder: 'Ekklisia/saints/video',
              onProgress: (p) => setState(() => _videoProgress = p))
          : await _cloudinary.uploadVideo(
              videoFile: _videoFile!,
              folder: 'Ekklisia/saints/video',
              onProgress: (p) => setState(() => _videoProgress = p));
      setState(() {
        _videoUrl     = res.secureUrl;
        _videoCloudId = res.publicId;
        _videoProgress = null;
      });
    } catch (_) {
      setState(() => _videoProgress = null);
      rethrow;
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = ''; });
    try {
      await _uploadCoverIfNeeded();
      await _uploadPdfIfNeeded();
      await _uploadAudioIfNeeded();
      await _uploadVideoIfNeeded();

      final userId = context.read<AuthCubit>().state.user?.uid ?? '';
      final s = widget.initial;

      final saint = SaintModel(
        id:                s?.id ?? '',
        nameEn:            _nameEn.text.trim(),
        nameAr:            _nameAr.text.trim(),
        nameCoptic:        _nameCop.text.trim().isEmpty
                            ? null : _nameCop.text.trim(),
        feastDate:         _feastDate.text.trim().isEmpty
                            ? null : _feastDate.text.trim(),
        patronOfEn:        _patronEn.text.trim().isEmpty
                            ? null : _patronEn.text.trim(),
        patronOfAr:        _patronAr.text.trim().isEmpty
                            ? null : _patronAr.text.trim(),
        biographyEn:       _bioEn.text.trim().isEmpty
                            ? null : _bioEn.text.trim(),
        biographyAr:       _bioAr.text.trim().isEmpty
                            ? null : _bioAr.text.trim(),
        imageUrl:          _coverUrl,
        cloudinaryImageId: _coverCloudId,
        pdfUrl:            _pdfUrl,
        cloudinaryPdfId:   _pdfCloudId,
        audioUrl:          _audioUrl,
        cloudinaryAudioId: _audioCloudId,
        videoUrl:          _videoUrl,
        cloudinaryVideoId: _videoCloudId,
        isPublished:       _published,
        createdAt:         s?.createdAt ?? DateTime.now(),
        createdBy:         s?.createdBy.isEmpty ?? true ? userId : s!.createdBy,
      );

      await widget.repo.save(saint);
      widget.onDone();
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final isNew = widget.initial == null;
    return Column(children: [
      // ── Header bar ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: ac.bgDeep,
          border: Border(bottom: ac.borderSide),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: widget.onDone,
            child: Icon(Icons.arrow_back_ios_new,
                color: ac.gold, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isNew ? 'Προσθήκη Αγίου' : 'Επεξεργασία Αγίου',
                style: TextStyle(
                  color: ac.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isNew)
                Text(
                  widget.initial!.nameAr,
                  style: TextStyle(
                    color: ac.textSecondary,
                    fontFamily: 'Scheherazade',
                    fontSize: 13,
                  ),
                ),
            ]),
          ),
          // Save button
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _saving
                    ? ac.bgMid
                    : ac.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: ac.gold.withValues(alpha: 0.4),
                    width: 0.5),
              ),
              child: _saving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: ac.gold, strokeWidth: 2),
                    )
                  : Text(
                      isNew ? 'Δημιουργία' : 'Ενημέρωση',
                      style: TextStyle(
                        color: ac.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ]),
      ),

      if (_saveError.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ac.maroon.withValues(alpha: 0.15),
            borderRadius: _kRadius,
            border: Border.all(
                color: ac.maroon.withValues(alpha: 0.4)),
          ),
          child: Text(_saveError,
              style: TextStyle(
                  color: ac.maroonMid, fontSize: 12)),
        ),

      // ── Form ──────────────────────────────────────────────────────────
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // ── Cover image ─────────────────────────────────────────
              _FormCard(
                title: 'Εικόνα Εξωφύλλου',
                titleAr: 'الصورة',
                child: _CoverPicker(
                  url: _coverUrl,
                  localBytes: _coverBytes,
                  localFile: _coverFile,
                  uploading: _coverUploading,
                  progress: _coverProgress,
                  onPick: _pickCover,
                  onRemove: () => setState(() {
                    _coverUrl = ''; _coverCloudId = '';
                    _coverFile = null; _coverBytes = null;
                    _coverName = null;
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // ── Names ──────────────────────────────────────────────
              _FormCard(
                title: 'Ονόματα',
                titleAr: 'الأسماء',
                child: Column(children: [
                  _Field(
                    ctrl: _nameEn,
                    label: 'Ονομασία (Ελληνικά)',
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _nameAr,
                    label: 'Ονομασία (Αραβικά)  الاسم بالعربية',
                    required: true,
                    arabic: true,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _nameCop,
                    label: 'Κοπτικό Όνομα (προαιρετικό)',
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Details ────────────────────────────────────────────
              _FormCard(
                title: 'Λεπτομέρειες',
                titleAr: 'التفاصيل',
                child: Column(children: [
                  _Field(
                    ctrl: _feastDate,
                    label: 'Ημ. Εορτής (ΜΜ-ΗΗ, π.χ. 11-17)',
                    hint: '01-07',
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _patronEn,
                    label: 'Προστάτης (Ελληνικά)',
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _patronAr,
                    label: 'Προστάτης (Αραβικά)',
                    arabic: true,
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Biography ──────────────────────────────────────────
              _FormCard(
                title: 'Βιογραφία',
                titleAr: 'السيرة',
                child: Column(children: [
                  _Field(
                    ctrl: _bioEn,
                    label: 'Βιογραφία (Ελληνικά)',
                    multiline: true,
                    minLines: 4,
                    maxLines: 12,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _bioAr,
                    label: 'Βιογραφία (Αραβικά)  السيرة بالعربية',
                    multiline: true,
                    minLines: 4,
                    maxLines: 12,
                    arabic: true,
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── PDF (optional) ─────────────────────────────────────
              _FormCard(
                title: 'PDF (Προαιρετικό)',
                titleAr: 'ملف PDF',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Επισυνάψτε PDF ή επικολλήστε URL (Cloudinary ή Google Drive).',
                      style: TextStyle(
                          color: ac.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    // URL paste field — Drive share links auto-convert to a
                    // direct-download URL (same behaviour as the Books upload flow).
                    TextFormField(
                      controller: _pdfUrlCtrl,
                      style: TextStyle(
                          color: ac.textPrimary, fontSize: 13),
                      decoration: ac.inputDeco('Επικολλήστε URL PDF ή σύνδεσμο Drive…'),
                      onChanged: (v) {
                        if (v.trim().isNotEmpty) {
                          setState(() {
                            _pdfFile = null;
                            _pdfBytes = null;
                            _pdfName = null;
                          });
                        }
                      },
                    ),
                    if (looksLikeDriveLink(_pdfUrlCtrl.text) &&
                        driveShareLinkToDirectUrl(_pdfUrlCtrl.text) == null) ...[
                      SizedBox(height: 6),
                      Text(
                        "Doesn't look like a valid Drive share link — "
                        'make sure the full URL was pasted.',
                        style: TextStyle(
                            color: Colors.orange.shade300, fontSize: 10),
                      ),
                    ],
                    SizedBox(height: 10),
                    // Divider
                    Row(children: [
                      Expanded(child: Divider(color: ac.goldBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('Ή',
                            style: TextStyle(
                                color: ac.textSecondary,
                                fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: ac.goldBorder)),
                    ]),
                    const SizedBox(height: 10),
                    // File section
                    if (_pdfUploading)
                      _ProgressBar(progress: _pdfProgress)
                    else if (_pdfName != null && _pdfUrl.isEmpty)
                      _FileBadge(
                        name: _pdfName!,
                        sizeMb: _pdfSizeMb,
                        onRemove: () => setState(() {
                          _pdfFile = null; _pdfBytes = null;
                          _pdfName = null; _pdfSizeMb = null;
                        }),
                      )
                    else if (_pdfUrl.isNotEmpty && _pdfUrlCtrl.text.isEmpty)
                      _UrlBadge(
                        url: _pdfUrl,
                        onRemove: () => setState(() {
                          _pdfUrl = ''; _pdfCloudId = '';
                          _pdfUrlCtrl.clear();
                        }),
                      ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickPdf,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: ac.bgMid,
                          borderRadius: _kRadius,
                          border: Border.all(
                              color: ac.goldBorder, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_outlined,
                                color: ac.gold, size: 16),
                            SizedBox(width: 6),
                            Text('Επιλογή αρχείου PDF',
                                style: TextStyle(
                                    color: ac.gold,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Audio (optional) ───────────────────────────────────
              _FormCard(
                title: 'Ήχος (Προαιρετικό)',
                titleAr: 'الصوت',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Μεταφορτώστε αρχείο MP3 ή M4A.',
                      style: TextStyle(
                          color: ac.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    if (_audioUploading)
                      _ProgressBar(progress: _audioProgress)
                    else if (_audioName != null && _audioUrl.isEmpty)
                      _FileBadge(
                        name: _audioName!,
                        onRemove: () => setState(() {
                          _audioFile = null; _audioBytes = null;
                          _audioName = null;
                        }),
                      )
                    else if (_audioUrl.isNotEmpty)
                      _UrlBadge(
                        url: _audioUrl,
                        onRemove: () => setState(() {
                          _audioUrl = ''; _audioCloudId = '';
                        }),
                      ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickAudio,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: ac.bgMid,
                          borderRadius: _kRadius,
                          border: Border.all(
                              color: ac.goldBorder, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.audio_file_outlined,
                                color: ac.tealMid, size: 16),
                            SizedBox(width: 6),
                            Text('Επιλογή αρχείου ήχου',
                                style: TextStyle(
                                    color: ac.tealMid,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Video (optional) ───────────────────────────────────
              _FormCard(
                title: 'Βίντεο (Προαιρετικό)',
                titleAr: 'الفيديو',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Μεταφορτώστε βίντεο ή επικολλήστε URL YouTube/Cloudinary.',
                      style: TextStyle(
                          color: ac.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _videoUrlCtrl,
                      style: TextStyle(
                          color: ac.textPrimary, fontSize: 13),
                      decoration: ac.inputDeco('Επικολλήστε URL YouTube ή βίντεο…'),
                    ),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Divider(color: ac.goldBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('Ή',
                            style: TextStyle(
                                color: ac.textSecondary,
                                fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: ac.goldBorder)),
                    ]),
                    const SizedBox(height: 10),
                    if (_videoProgress != null)
                      _ProgressBar(progress: _videoProgress!)
                    else if (_videoName != null && _videoUrl.isEmpty)
                      _FileBadge(
                        name: _videoName!,
                        onRemove: () => setState(() {
                          _videoFile = null; _videoBytes = null;
                          _videoName = null;
                        }),
                      )
                    else if (_videoUrl.isNotEmpty && _videoUrlCtrl.text.isEmpty)
                      _UrlBadge(
                        url: _videoUrl,
                        onRemove: () => setState(() {
                          _videoUrl = ''; _videoCloudId = '';
                        }),
                      ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: ac.bgMid,
                          borderRadius: _kRadius,
                          border: Border.all(
                              color: ac.goldBorder, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_file_outlined,
                                color: ac.plum, size: 16),
                            SizedBox(width: 6),
                            Text('Επιλογή αρχείου βίντεο',
                                style: TextStyle(
                                    color: ac.plum,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Publish ────────────────────────────────────────────
              _FormCard(
                title: 'Ορατότητα',
                titleAr: 'الظهور',
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _published
                          ? 'Δημοσιευμένο — ορατό σε όλους'
                          : 'Πρόχειρο — ορατό μόνο σε διαχειριστές',
                      style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Switch(
                    value: _published,
                    onChanged: (v) => setState(() => _published = v),
                    activeColor: ac.tealMid,
                    inactiveThumbColor: ac.goldDim,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// COVER PICKER WIDGET
// ════════════════════════════════════════════════════════════════════════════

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.url,
    required this.localBytes,
    required this.localFile,
    required this.uploading,
    required this.progress,
    required this.onPick,
    required this.onRemove,
  });

  final String   url;
  final Uint8List? localBytes;
  final File?    localFile;
  final bool     uploading;
  final double   progress;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get _hasLocal => localBytes != null || localFile != null;
  bool get _hasAny   => url.isNotEmpty || _hasLocal;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return SizedBox(
      height: 140,
      child: Stack(children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ac.bgMid,
              borderRadius: _kRadius,
              border: Border.all(color: ac.goldBorder, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: _kRadius,
              child: _hasLocal
                  ? (localBytes != null
                      ? Image.memory(localBytes!, fit: BoxFit.cover)
                      : Image.file(localFile!, fit: BoxFit.cover))
                  : url.isNotEmpty
                      ? Image.network(url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(ac))
                      : _placeholder(ac),
            ),
          ),
        ),
        // Upload progress overlay
        if (uploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: _kRadius,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      color: ac.gold,
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                          color: ac.gold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Remove button
        if (_hasAny && !uploading)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ac.maroon.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        // Edit icon when no image
        if (!_hasAny)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ac.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: ac.goldBorder),
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: ac.gold, size: 16),
            ),
          ),
      ]),
    );
  }

  Widget _placeholder(AdminC ac) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.image_outlined,
          color: ac.goldBorder, size: 36),
      SizedBox(height: 8),
      Text('Πατήστε για προσθήκη εικόνας',
          style: TextStyle(
              color: ac.textSecondary, fontSize: 12)),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED FORM HELPERS
// ════════════════════════════════════════════════════════════════════════════

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
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: _kRadius,
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              Text(
                title,
                style: TextStyle(
                  color: ac.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 8),
              Text(
                titleAr,
                style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 11,
                  fontFamily: 'Scheherazade',
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
            child: Divider(
                height: 1,
                color: ac.goldBorder.withValues(alpha: 0.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.required = false,
    this.multiline = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.arabic = false,
  });

  final TextEditingController ctrl;
  final String  label;
  final String? hint;
  final bool    required;
  final bool    multiline;
  final int     minLines;
  final int     maxLines;
  final bool    arabic;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return TextFormField(
      controller: ctrl,
      minLines: multiline ? minLines : null,
      maxLines: multiline ? maxLines : 1,
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(
        color: ac.textPrimary,
        fontSize: 13,
        fontFamily: arabic ? 'Scheherazade' : null,
      ),
      decoration: ac.inputDeco(hint ?? label),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Υποχρεωτικό' : null
          : null,
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _Toolbar extends StatefulWidget {
  const _Toolbar({
    required this.title,
    required this.count,
    required this.onSearch,
    required this.onAdd,
    required this.onBulkUpload,
  });
  final String title;
  final int    count;
  final void Function(String) onSearch;
  final VoidCallback onAdd;
  final VoidCallback onBulkUpload;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  bool _searching = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        border: Border(bottom: ac.borderSide),
      ),
      child: Row(children: [
        Expanded(
          child: _searching
              ? TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(
                      color: ac.textPrimary, fontSize: 13),
                  decoration: ac.inputDeco(
                      '${context.adminL10n.search} ${context.adminL10n.saints}…'),
                  onChanged: widget.onSearch,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        textDirection: context.adminL10n.dir,
                        style: TextStyle(
                          fontFamily: context.adminL10n.fontFam,
                          color: ac.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(
                      '${widget.count}',
                      style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(width: 8),
        _IconBtn(
          icon: _searching ? Icons.close : Icons.search,
          color: ac.textSecondary,
          onTap: () {
            setState(() => _searching = !_searching);
            if (!_searching) {
              _ctrl.clear();
              widget.onSearch('');
            }
          },
        ),
        const SizedBox(width: 4),
        // Bulk upload button
        GestureDetector(
          onTap: widget.onBulkUpload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: ac.goldBorder, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.upload_file_outlined,
                  color: ac.textSecondary, size: 14),
              SizedBox(width: 4),
              Text(context.adminL10n.bulk,
                  style: TextStyle(
                      color: ac.textSecondary, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: widget.onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ac.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: ac.gold.withValues(alpha: 0.4),
                  width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.add, color: ac.gold, size: 14),
              SizedBox(width: 4),
              Text(context.adminL10n.add,
                  textDirection: context.adminL10n.dir,
                  style: TextStyle(
                      fontFamily: context.adminL10n.fontFam,
                      color: ac.gold, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
  );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Icon(icon, color: color, size: 15),
    ),
  );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LinearProgressIndicator(
        value: progress,
        backgroundColor: ac.bgMid,
        valueColor:
            AlwaysStoppedAnimation<Color>(ac.gold),
        minHeight: 3,
        borderRadius: BorderRadius.circular(2),
      ),
      SizedBox(height: 4),
      Text(
        'Μεταφόρτωση… ${(progress * 100).round()}%',
        style: TextStyle(
            color: ac.textSecondary, fontSize: 10),
      ),
    ],
  );
  }
}

class _FileBadge extends StatelessWidget {
  const _FileBadge({required this.name, this.sizeMb, required this.onRemove});
  final String   name;
  final double?  sizeMb;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: ac.bgMid,
      borderRadius: _kRadius,
      border: Border.all(color: ac.goldBorder, width: 0.5),
    ),
    child: Row(children: [
      Icon(Icons.insert_drive_file_outlined,
          color: ac.gold, size: 14),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          sizeMb != null ? '$name  (${sizeMb!.toStringAsFixed(1)} MB)' : name,
          style: TextStyle(
              color: ac.textPrimary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.close,
            color: ac.textSecondary, size: 14),
      ),
    ]),
  );
  }
}

class _UrlBadge extends StatelessWidget {
  const _UrlBadge({required this.url, required this.onRemove});
  final String   url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: ac.tealMid.withValues(alpha: 0.08),
      borderRadius: _kRadius,
      border: Border.all(
          color: ac.tealMid.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Row(children: [
      Icon(Icons.link, color: ac.tealMid, size: 14),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          url,
          style: TextStyle(
              color: ac.tealMid, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.close,
            color: ac.textSecondary, size: 14),
      ),
    ]),
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
                color: ac.goldBorder, fontSize: 40)),
        SizedBox(height: 12),
        Text('Δεν έχουν προστεθεί άγιοι',
            style: TextStyle(
                color: ac.textSecondary, fontSize: 14)),
        SizedBox(height: 4),
        Text('لا يوجد قديسون حتى الآن',
            style: TextStyle(
                color: ac.textSecondary,
                fontFamily: 'Scheherazade',
                fontSize: 14)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: ac.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: ac.gold.withValues(alpha: 0.4),
                  width: 0.5),
            ),
            child: Text('Προσθήκη Πρώτου Αγίου',
                style: TextStyle(
                    color: ac.gold, fontSize: 13)),
          ),
        ),
      ],
    ),
  );
  }
}

class _DeleteConfirmRow extends StatelessWidget {
  const _DeleteConfirmRow(
      {required this.onConfirm, required this.onCancel});
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(Icons.warning_amber_rounded,
          color: ac.maroonMid, size: 18),
      SizedBox(width: 8),
      Expanded(
        child: Text('Διαγραφή αυτού του αγίου;',
            style: TextStyle(
                color: ac.textPrimary, fontSize: 13)),
      ),
      TextButton(
        onPressed: onCancel,
        child: Text('Ακύρωση',
            style: TextStyle(color: ac.textSecondary)),
      ),
      SizedBox(width: 4),
      TextButton(
        onPressed: onConfirm,
        child: Text('Διαγραφή',
            style: TextStyle(color: ac.maroonMid)),
      ),
    ]),
  );
  }
}
