// lib/admin/content/agbeya_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — Agbeya (Coptic Book of Hours) manager.
//
// Two modes controlled by _ScreenMode enum:
//   • list  — table of all hours (incl. drafts) with CRUD actions
//   • edit  — full form for creating / editing a single hour
//
// Capabilities:
//   ✓  Create / Edit / Delete AgbeyaHour documents in Firestore
//   ✓  Upload audio file (MP3/M4A/AAC) → Cloudinary video resource
//   ✓  Upload cover image → Cloudinary image resource
//   ✓  Manage prayer sections (add / edit / remove, Arabic + Coptic + Greek)
//   ✓  Toggle published status per-hour
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/agbeya_model.dart';
import '../../data/repositories/agbeya_repository.dart';
import '../utils/admin_colors.dart';
import '../utils/drive_link_utils.dart';

// ── Hour names reference ──────────────────────────────────────────────────────
const _kHourNamesAr = {
  1: 'صلاة باكر',
  2: 'صلاة الساعة الثالثة',
  3: 'صلاة الساعة السادسة',
  4: 'صلاة الساعة التاسعة',
  5: 'صلاة الغروب',
  6: 'صلاة النوم',
  7: 'صلاة نصف الليل',
};

enum _ScreenMode { list, edit }

// ════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ════════════════════════════════════════════════════════════════════════════

class AgbeyaManagerScreen extends StatefulWidget {
  const AgbeyaManagerScreen({super.key});

  @override
  State<AgbeyaManagerScreen> createState() => _AgbeyaManagerScreenState();
}

class _AgbeyaManagerScreenState extends State<AgbeyaManagerScreen> {
  final _repo = sl<AgbeyaRepository>();

  _ScreenMode _mode = _ScreenMode.list;
  AgbeyaHour? _editing; // null → create new

  void _openEdit(AgbeyaHour? hour) =>
      setState(() { _editing = hour; _mode = _ScreenMode.edit; });

  void _backToList() =>
      setState(() { _editing = null; _mode = _ScreenMode.list; });

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    if (_mode == _ScreenMode.edit) {
      return _EditView(
        repo: _repo,
        initial: _editing,
        onDone: _backToList,
      );
    }
    return _ListView(repo: _repo, onEdit: _openEdit);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIST VIEW
// ════════════════════════════════════════════════════════════════════════════

class _ListView extends StatefulWidget {
  const _ListView({required this.repo, required this.onEdit});
  final AgbeyaRepository repo;
  final void Function(AgbeyaHour?) onEdit;

  @override
  State<_ListView> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  String? _deleteConfirmId;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return StreamBuilder<List<AgbeyaHour>>(
      stream: widget.repo.watchAllHours(),
      builder: (context, snap) {
        final hours = snap.data ?? [];
        final loading = snap.connectionState == ConnectionState.waiting;

        return Column(children: [
          // ── Toolbar ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: ac.bgDeep,
              border: Border(
                  bottom: BorderSide(
                      color: ac.goldBorder, width: 0.5)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agbeya Hours',
                        style: TextStyle(
                            color: ac.goldLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text('الأجبية',
                        style: TextStyle(
                            fontFamily: 'Scheherazade',
                            color: ac.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onEdit(null),
                icon: Icon(Icons.add,
                    size: 16, color: ac.bgDeep),
                label: Text('New Hour',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(ac.gold)))
                : hours.isEmpty
                    ? _EmptyState(onAdd: () => widget.onEdit(null))
                    : Stack(
                        children: [
                          ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: hours.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _HourRow(
                              hour: hours[i],
                              onEdit: () => widget.onEdit(hours[i]),
                              onToggle: () =>
                                  _togglePublish(context, hours[i]),
                              onDelete: () => setState(
                                  () => _deleteConfirmId = hours[i].id),
                            ),
                          ),
                          if (_deleteConfirmId != null)
                            _DeleteDialog(
                              onCancel: () =>
                                  setState(() => _deleteConfirmId = null),
                              onConfirm: () {
                                _delete(context, _deleteConfirmId!);
                                setState(() => _deleteConfirmId = null);
                              },
                            ),
                        ],
                      ),
          ),
        ]);
      },
    );
  }

  Future<void> _togglePublish(BuildContext context, AgbeyaHour hour) async {
    await widget.repo.togglePublish(hour.id,
        published: !hour.isPublished);
    if (mounted) {
      _snack(context,
          hour.isPublished ? 'Set to Draft' : 'Published');
    }
  }

  Future<void> _delete(BuildContext context, String id) async {
    await widget.repo.deleteHour(id);
    if (mounted) _snack(context, 'Hour deleted');
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

// ── Hour Row ──────────────────────────────────────────────────────────────────

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.hour,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final AgbeyaHour   hour;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final hourColor = _hourColor(hour.hourNumber, ac);

    return Container(
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Row(children: [
        // Colour strip
        Container(
          width: 4,
          height: 80,
          decoration: BoxDecoration(
            color: hourColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              bottomLeft: Radius.circular(11),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Hour number badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hourColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
                color: hourColor.withOpacity(0.6), width: 1),
          ),
          child: Center(
            child: Text(
              '${hour.hourNumber}',
              style: TextStyle(
                color: hourColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Metadata
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hour.titleAr.isNotEmpty
                    ? hour.titleAr
                    : (_kHourNamesAr[hour.hourNumber] ?? 'Hour ${hour.hourNumber}'),
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: ac.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Row(children: [
                _Chip(
                  label: '${hour.sections.length} sections',
                  color: ac.textSecondary,
                ),
                SizedBox(width: 6),
                if (hour.hasAudio)
                  _Chip(label: '♪ audio', color: ac.tealMid)
                else
                  _Chip(label: 'no audio', color: ac.goldDim),
                SizedBox(width: 4),
                if (hour.hasPdf)
                  _Chip(label: '📄 pdf', color: ac.bronze)
                else
                  _Chip(label: 'no pdf', color: ac.goldDim),
                if (hour.formattedDuration.isNotEmpty) ...[
                  SizedBox(width: 6),
                  _Chip(
                    label: hour.formattedDuration,
                    color: ac.textSecondary,
                  ),
                ],
              ]),
            ],
          ),
        ),

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
                    color: hour.isPublished
                        ? ac.tealMid.withOpacity(0.15)
                        : ac.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: hour.isPublished
                          ? ac.tealMid
                          : ac.goldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    hour.isPublished ? 'LIVE' : 'DRAFT',
                    style: TextStyle(
                      color: hour.isPublished
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

  Color _hourColor(int n, AdminC ac) {
    final colors = [
      ac.maroon,
      ac.bronze,
      EkklisiaColors.tealDark,
      ac.maroonMid,
      ac.plum,
      EkklisiaColors.ocean,
      EkklisiaColors.forest,
    ];
    return colors[(n - 1).clamp(0, colors.length - 1)];
  }
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
  final AgbeyaRepository repo;
  final AgbeyaHour?     initial;
  final VoidCallback    onDone;

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  final _formKey   = GlobalKey<FormState>();
  final _cloudinary = sl<CloudinaryDataSource>();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _titleAr  = TextEditingController();
  final _titleCop = TextEditingController();
  final _titleEl  = TextEditingController();
  final _descAr   = TextEditingController();
  final _durationCtrl = TextEditingController();

  int  _hourNumber = 1;
  bool _published  = false;

  // ── Audio tracks (up to 2) ────────────────────────────────────────────────
  late List<_TrackDraft> _tracks; // initialised in initState

  // ── Cover ─────────────────────────────────────────────────────────────────
  File?      _coverFile;
  Uint8List? _coverBytes;
  String?    _coverName;
  String     _coverUrl = '';
  double     _coverProgress = 0;
  bool       _coverUploading = false;

  // ── PDF (Phase 1) ─────────────────────────────────────────────────────────
  File?      _pdfFile;
  Uint8List? _pdfBytes;
  String?    _pdfName;
  double?    _pdfSizeMb;
  String     _pdfUrl = '';
  String     _pdfCloudinaryId = '';
  double     _pdfProgress = 0;
  bool       _pdfUploading = false;
  // Paste-URL field — lets the admin reuse a previously uploaded PDF
  final _pdfUrlCtrl = TextEditingController();

  // Paste-URL field for video
  final _videoUrlCtrl = TextEditingController();

  // ── Video ─────────────────────────────────────────────────────────────────
  String     _videoUrl          = '';
  String     _cloudinaryVideoId = '';
  File?      _videoFile;
  Uint8List? _videoBytes;
  String?    _videoName;
  double?    _videoUploadProgress;

  // ── Sections ──────────────────────────────────────────────────────────────
  late List<_SectionDraft> _sections;

  // ── Saving ────────────────────────────────────────────────────────────────
  bool   _saving    = false;
  String _saveError = '';

  @override
  void initState() {
    super.initState();
    // Keep _pdfUrl in sync when admin pastes a URL directly. Google Drive
    // "Anyone with the link" share URLs are auto-converted to their direct
    // -download form (matches the Books upload flow's Drive-link support).
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
      if (v != _pdfUrl) setState(() => _pdfUrl = v);
    });
    _videoUrlCtrl.addListener(() {
      final v = _videoUrlCtrl.text.trim();
      if (v != _videoUrl) {
        setState(() {
          _videoUrl          = v;
          _cloudinaryVideoId = '';
          _videoFile         = null;
          _videoBytes        = null;
          _videoName         = null;
        });
      }
    });
    final h = widget.initial;
    if (h != null) {
      _titleAr.text  = h.titleAr;
      _titleCop.text = h.titleCop;
      _titleEl.text  = h.titleEl;
      _descAr.text   = h.descriptionAr;
      _hourNumber    = h.hourNumber.clamp(1, 7);
      _published     = h.isPublished;
      _coverUrl         = h.coverUrl;
      _pdfUrl           = h.pdfUrl;
      _pdfCloudinaryId  = h.cloudinaryPdfId;
      _pdfUrlCtrl.text  = h.pdfUrl;
      _videoUrl          = h.videoUrl;
      _cloudinaryVideoId = h.cloudinaryVideoId;
      _videoUrlCtrl.text = h.videoUrl;
      // Load audio tracks — fall back to legacy single audioUrl
      if (h.audioTracks.isNotEmpty) {
        _tracks = h.audioTracks
            .take(2)
            .map((t) => _TrackDraft.fromTrack(t))
            .toList();
        // Pad to exactly 2 slots
        while (_tracks.length < 2) _tracks.add(_TrackDraft());
      } else if (h.audioUrl.isNotEmpty) {
        _tracks = [
          _TrackDraft(label: h.titleAr, url: h.audioUrl,
              durationSecs: h.durationSeconds),
          _TrackDraft(),
        ];
      } else {
        _tracks = [_TrackDraft(label: 'الشماس'), _TrackDraft(label: 'الكاهن')];
      }
      _sections = h.sections
          .map((s) => _SectionDraft.fromSection(s))
          .toList();
    } else {
      _tracks   = [_TrackDraft(label: 'الشماس'), _TrackDraft(label: 'الكاهن')];
      _sections = [];
    }
  }

  @override
  void dispose() {
    _titleAr.dispose();
    _titleCop.dispose();
    _titleEl.dispose();
    _descAr.dispose();
    _durationCtrl.dispose();
    _pdfUrlCtrl.dispose();
    _videoUrlCtrl.dispose();
    for (final t in _tracks) t.dispose();
    super.dispose();
  }

  // ── PDF picker + upload ───────────────────────────────────────────────────

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
      _pdfFile   = kIsWeb ? null : File(f.path!);
      _pdfBytes  = kIsWeb ? f.bytes : null;
    });
    await _uploadPdf();
  }

  Future<void> _uploadPdf() async {
    if (_pdfFile == null && _pdfBytes == null) return;
    setState(() { _pdfUploading = true; _pdfProgress = 0; });
    try {
      final result = kIsWeb
          ? await _cloudinary.uploadPdfBytes(
              bytes: _pdfBytes!,
              fileName: _pdfName!,
              folder: 'Ekklisia/agbeya/pdf',
              onProgress: (p) => setState(() => _pdfProgress = p),
            )
          : await _cloudinary.uploadPdf(
              pdfFile: _pdfFile!,
              folder: 'Ekklisia/agbeya/pdf',
              onProgress: (p) => setState(() => _pdfProgress = p),
            );
      setState(() {
        _pdfUrl          = result.secureUrl;
        _pdfCloudinaryId = result.publicId;
        _pdfUploading    = false;
        _pdfProgress     = 1;
      });
      _snack('PDF uploaded ✓');
    } catch (e) {
      setState(() { _pdfUploading = false; });
      _snack('PDF upload failed: $e', error: true);
    }
  }

  // ── Per-track audio picker + upload ──────────────────────────────────────

  Future<void> _pickTrackAudio(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final track = _tracks[index];
    setState(() {
      track.name  = f.name;
      track.file  = kIsWeb ? null : File(f.path!);
      track.bytes = kIsWeb ? f.bytes : null;
    });
    await _uploadTrackAudio(index);
  }

  Future<void> _uploadTrackAudio(int index) async {
    final track = _tracks[index];
    if (track.file == null && track.bytes == null) return;
    setState(() { track.uploading = true; track.progress = 0; });
    try {
      final result = kIsWeb
          ? await _cloudinary.uploadAudioBytes(
              bytes: track.bytes!,
              fileName: track.name!,
              folder: 'Ekklisia/agbeya/audio',
              onProgress: (p) => setState(() => track.progress = p),
            )
          : await _cloudinary.uploadAudio(
              audioFile: track.file!,
              folder: 'Ekklisia/agbeya/audio',
              onProgress: (p) => setState(() => track.progress = p),
            );
      setState(() {
        track.url      = result.secureUrl;
        track.uploading = false;
        track.progress  = 1;
      });
      _snack('Track ${index + 1} uploaded ✓');
    } catch (e) {
      setState(() { track.uploading = false; });
      _snack('Track ${index + 1} upload failed: $e', error: true);
    }
  }

  // ── Cover picker + upload ─────────────────────────────────────────────────

  Future<void> _pickCover() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (img == null) return;
    if (kIsWeb) {
      final bytes = await img.readAsBytes();
      setState(() { _coverBytes = bytes; _coverFile = null; _coverName = img.name; });
    } else {
      setState(() { _coverFile = File(img.path); _coverBytes = null; _coverName = img.name; });
    }
    await _uploadCover();
  }

  Future<void> _uploadCover() async {
    if (_coverFile == null && _coverBytes == null) return;
    setState(() { _coverUploading = true; _coverProgress = 0; });
    try {
      final result = kIsWeb
          ? await _cloudinary.uploadCoverImageBytes(
              bytes: _coverBytes!,
              fileName: _coverName!,
              folder: 'Ekklisia/agbeya',
              onProgress: (p) => setState(() => _coverProgress = p),
            )
          : await _cloudinary.uploadCoverImage(
              imageFile: _coverFile!,
              folder: 'Ekklisia/agbeya',
              onProgress: (p) => setState(() => _coverProgress = p),
            );
      setState(() {
        _coverUrl = result.secureUrl;
        _coverUploading = false;
        _coverProgress  = 1;
      });
      _snack('Cover uploaded ✓');
    } catch (e) {
      setState(() { _coverUploading = false; });
      _snack('Cover upload failed: $e', error: true);
    }
  }

  // ── Video picker + upload ─────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _videoName  = f.name;
      _videoFile  = kIsWeb ? null : File(f.path!);
      _videoBytes = kIsWeb ? f.bytes : null;
      _videoUrl   = '';
      _cloudinaryVideoId = '';
    });
  }

  Future<void> _uploadVideoIfNeeded() async {
    if (_videoFile == null && _videoBytes == null) return;
    setState(() => _videoUploadProgress = 0);
    try {
      final result = kIsWeb
          ? await _cloudinary.uploadVideoBytes(
              bytes: _videoBytes!,
              fileName: _videoName!,
              folder: 'Ekklisia/agbeya/video',
              onProgress: (p) => setState(() => _videoUploadProgress = p),
            )
          : await _cloudinary.uploadVideo(
              videoFile: _videoFile!,
              folder: 'Ekklisia/agbeya/video',
              onProgress: (p) => setState(() => _videoUploadProgress = p),
            );
      _videoUrl          = result.secureUrl;
      _cloudinaryVideoId = result.publicId;
      setState(() => _videoUploadProgress = null);
      _snack('Video uploaded ✓');
    } catch (e) {
      setState(() => _videoUploadProgress = null);
      _snack('Video upload failed: $e', error: true);
      rethrow;
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = ''; });

    try {
      await _uploadVideoIfNeeded();
    } catch (_) {
      setState(() => _saving = false);
      return;
    }

    final now = DateTime.now();
    final sections = _sections
        .map((d) => AgbeyaSection(
              titleAr: d.titleAr.text,
              titleCop: d.titleCop.text,
              titleEl: d.titleEl.text,
              textAr: d.textAr.text,
              textCop: d.textCop.text,
              textEl: d.textEl.text,
            ))
        .toList();

    // Build audio tracks — only include tracks with a URL
    final audioTracks = _tracks
        .where((t) => t.url.isNotEmpty)
        .map((t) => AgbeyaAudioTrack(
              labelAr: t.label.text.trim(),
              url: t.url,
              durationSeconds: int.tryParse(t.duration.text.trim()) ?? 0,
            ))
        .toList();

    final hour = AgbeyaHour(
      id: widget.initial?.id ?? '',
      hourNumber: _hourNumber,
      titleAr: _titleAr.text.trim(),
      titleCop: _titleCop.text.trim(),
      titleEl: _titleEl.text.trim(),
      descriptionAr: _descAr.text.trim(),
      // Legacy single-track fallback: use first track URL for backward compat
      audioUrl: audioTracks.isNotEmpty ? audioTracks.first.url : '',
      audioTracks: audioTracks,
      coverUrl: _coverUrl,
      pdfUrl: _pdfUrl,
      cloudinaryPdfId: _pdfCloudinaryId,
      durationSeconds: audioTracks.isNotEmpty
          ? audioTracks.first.durationSeconds
          : 0,
      sections: sections,
      isPublished: _published,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
      videoUrl:          _videoUrl,
      cloudinaryVideoId: _cloudinaryVideoId,
    );

    try {
      if (widget.initial == null) {
        await widget.repo.addHour(hour);
      } else {
        await widget.repo.updateHour(hour);
      }
      if (mounted) widget.onDone();
    } catch (e) {
      setState(() { _saving = false; _saveError = e.toString(); });
    }
  }

  InputDecoration _inputDec({required String hint, bool counter = false}) {
    final ac = AdminC(Theme.of(context).brightness);
    return ac.inputDeco(hint);
  }

  void _snack(String msg, {bool error = false}) {
    final ac = AdminC(Theme.of(context).brightness);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? ac.maroon : ac.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: error
                ? ac.maroonMid
                : ac.goldBorder,
            width: 0.5),
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(children: [
      // ── Top bar ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
        decoration: BoxDecoration(
          color: ac.bgDeep,
          border: Border(
              bottom: BorderSide(
                  color: ac.goldBorder, width: 0.5)),
        ),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: ac.gold, size: 18),
            onPressed: widget.onDone,
          ),
          Text(
            widget.initial == null ? 'New Agbeya Hour' : 'Edit Hour',
            style: TextStyle(
                color: ac.goldLight,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (_saving)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(ac.gold)),
            )
          else
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.gold,
                foregroundColor: ac.bgDeep,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ]),
      ),

      // ── Scrollable form ───────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(children: [
              // Error banner
              if (_saveError.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ac.maroon.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: ac.maroonMid, width: 0.5),
                  ),
                  child: Text(_saveError,
                      style: TextStyle(
                          color: ac.maroonMid, fontSize: 12)),
                ),

              // ── Hour Number ───────────────────────────────────────────
              _AdminCard(
                title: 'Hour Number',
                titleAr: 'رقم الساعة',
                child: DropdownButtonFormField<int>(
                  value: _hourNumber,
                  dropdownColor: ac.bgElevated,
                  style: TextStyle(
                      color: ac.textPrimary, fontSize: 14),
                  decoration: _inputDec(hint: 'Select hour'),
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                        '${i + 1} — ${_kHourNamesAr[i + 1] ?? ''}',
                        style: TextStyle(
                            fontFamily: 'Scheherazade',
                            color: ac.textPrimary,
                            fontSize: 14),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _hourNumber = v ?? 1),
                ),
              ),
              const SizedBox(height: 14),

              // ── Titles ────────────────────────────────────────────────
              _AdminCard(
                title: 'Titles',
                titleAr: 'العناوين',
                child: Column(children: [
                  _ArabicField(
                    controller: _titleAr,
                    label: 'Arabic Title *',
                    labelAr: 'العنوان بالعربية',
                    hint: 'صلاة باكر...',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _AdminField(
                    controller: _titleCop,
                    label: 'Coptic',
                    hint: 'Ⲡⲓϫⲱⲙ...',
                  ),
                  const SizedBox(height: 12),
                  _AdminField(
                    controller: _titleEl,
                    label: 'Greek',
                    hint: 'Ακολουθία...',
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Description ───────────────────────────────────────────
              _AdminCard(
                title: 'Description',
                titleAr: 'الوصف',
                child: _ArabicField(
                  controller: _descAr,
                  label: 'Arabic Description',
                  labelAr: 'الوصف',
                  hint: 'وصف الصلاة...',
                  maxLines: 3,
                  required: false,
                ),
              ),
              const SizedBox(height: 14),

              // ── Audio Tracks (up to 2) ────────────────────────────────
              _AdminCard(
                title: 'Audio Tracks',
                titleAr: 'أصوات الساعة',
                child: Column(children: [
                  ...List.generate(_tracks.length, (i) {
                    final track    = _tracks[i];
                    final isFirst  = i == 0;
                    final accent   = isFirst
                        ? ac.gold
                        : ac.tealMid;
                    return Container(
                      margin: EdgeInsets.only(bottom: i < _tracks.length - 1 ? 14 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: accent.withOpacity(0.25), width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Track header
                          Row(children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: accent.withOpacity(0.5), width: 0.8),
                              ),
                              child: Center(
                                child: Text('${i + 1}', style: TextStyle(
                                    color: accent, fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isFirst
                                  ? 'Track 1'
                                  : 'Track 2 (optional)',
                              style: TextStyle(
                                  color: accent, fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                            if (!isFirst && track.url.isEmpty) ...[
                              SizedBox(width: 6),
                              Text('اختياري', style: TextStyle(
                                  fontFamily: 'Scheherazade',
                                  color: ac.textSecondary,
                                  fontSize: 11)),
                            ],
                          ]),
                          const SizedBox(height: 10),
                          // Label field
                          _ArabicField(
                            controller: track.label,
                            label: 'Label',
                            labelAr: 'الاسم',
                            hint: isFirst ? 'الشماس' : 'الكاهن',
                            required: false,
                          ),
                          const SizedBox(height: 10),
                          // File upload zone or URL badge
                          if (track.url.isNotEmpty && !track.uploading)
                            _UrlBadge(
                              icon: Icons.audiotrack,
                              label: 'Track ${i + 1} uploaded',
                              labelAr: 'تم رفع الصوت',
                              url: track.url,
                              onClear: () => setState(() {
                                track.url = ''; track.progress = 0;
                              }),
                              onReplace: () => _pickTrackAudio(i),
                            )
                          else
                            _DropZone(
                              icon: Icons.audiotrack_outlined,
                              title: track.uploading
                                  ? 'Uploading… ${(track.progress * 100).round()}%'
                                  : 'Select Audio File',
                              titleAr: 'اختر ملف صوتي',
                              subtitle: 'MP3 / M4A / AAC / WAV',
                              hasFile: track.file != null || track.bytes != null,
                              fileName: track.name,
                              borderColor: track.url.isNotEmpty
                                  ? ac.tealMid
                                  : ac.goldBorder,
                              onTap: track.uploading ? null : () => _pickTrackAudio(i),
                            ),
                          if (track.uploading) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: track.progress,
                                minHeight: 5,
                                backgroundColor: ac.bgElevated,
                                valueColor: AlwaysStoppedAnimation(accent),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Duration per track
                          _AdminField(
                            controller: track.duration,
                            label: 'Duration (seconds)',
                            hint: '1420',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    );
                  }),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Cover image ───────────────────────────────────────────
              _AdminCard(
                title: 'Cover Image',
                titleAr: 'صورة الغلاف',
                child: Column(children: [
                  if (_coverUrl.isNotEmpty && !_coverUploading)
                    _UrlBadge(
                      icon: Icons.image,
                      label: 'Cover uploaded',
                      labelAr: 'تم رفع الصورة',
                      url: _coverUrl,
                      onClear: () =>
                          setState(() { _coverUrl = ''; _coverProgress = 0; }),
                      onReplace: _pickCover,
                    )
                  else
                    _DropZone(
                      icon: Icons.image_outlined,
                      title: _coverUploading
                          ? 'Uploading… ${(_coverProgress * 100).round()}%'
                          : 'Select Cover Image',
                      titleAr: 'اختر صورة الغلاف',
                      subtitle: 'JPEG / PNG',
                      hasFile: _coverFile != null || _coverBytes != null,
                      fileName: _coverName,
                      borderColor: _coverUrl.isNotEmpty
                          ? ac.tealMid
                          : ac.goldBorder,
                      onTap: _coverUploading ? null : _pickCover,
                    ),
                  if (_coverUploading) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _coverProgress,
                        minHeight: 5,
                        backgroundColor: ac.bgElevated,
                        valueColor: AlwaysStoppedAnimation(
                            ac.gold),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),

              // ── PDF — Phase 1 ────────────────────────────────────────
              _AdminCard(
                title: 'PDF Content  (Phase 1)',
                titleAr: 'ملف PDF',
                child: Column(children: [
                  // Phase label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ac.goldSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: ac.goldBorder, width: 0.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 14, color: ac.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phase 1: users read this PDF while the audio plays. '
                          'Phase 2 text sections can be added separately.',
                          style: TextStyle(
                              color: ac.textSecondary,
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),

                  if (_pdfUrl.isNotEmpty && !_pdfUploading)
                    _UrlBadge(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF uploaded',
                      labelAr: 'تم رفع PDF',
                      url: _pdfUrl,
                      onClear: () => setState(() {
                        _pdfUrl          = '';
                        _pdfCloudinaryId = '';
                        _pdfProgress     = 0;
                      }),
                      onReplace: _pickPdf,
                    )
                  else
                    _DropZone(
                      icon: Icons.picture_as_pdf_outlined,
                      title: _pdfUploading
                          ? 'Uploading… ${(_pdfProgress * 100).round()}%'
                          : 'Select PDF File',
                      titleAr: 'اختر ملف PDF',
                      subtitle: _pdfSizeMb != null
                          ? '${_pdfSizeMb!.toStringAsFixed(1)} MB selected'
                          : 'PDF — max 100 MB',
                      hasFile: _pdfFile != null || _pdfBytes != null,
                      fileName: _pdfName,
                      borderColor: _pdfUrl.isNotEmpty
                          ? ac.tealMid
                          : ac.goldBorder,
                      onTap: _pdfUploading ? null : _pickPdf,
                    ),
                  if (_pdfUploading) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _pdfProgress,
                        minHeight: 5,
                        backgroundColor: ac.bgElevated,
                        valueColor: AlwaysStoppedAnimation(
                            ac.gold),
                      ),
                    ),
                  ],

                  // ── Paste URL directly (reuse an existing upload) ─────
                  SizedBox(height: 14),
                  Divider(color: ac.goldBorder.withOpacity(0.5), height: 1),
                  SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.link, size: 14, color: ac.goldDim),
                    SizedBox(width: 6),
                    Text(
                      'Or paste a Cloudinary or Google Drive URL directly',
                      style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '(لإعادة استخدام PDF)',
                      style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: ac.textSecondary,
                          fontSize: 11),
                    ),
                  ]),
                  SizedBox(height: 4),
                  Text(
                    'Google Drive "Anyone with the link" share URLs are '
                    'converted to a direct-download link automatically.',
                    style: TextStyle(
                        color: ac.textSecondary.withOpacity(0.7),
                        fontSize: 10),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _pdfUrlCtrl,
                    style: TextStyle(
                        color: ac.textPrimary, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'https://res.cloudinary.com/… or Drive link',
                      hintStyle: TextStyle(
                          color: ac.textSecondary, fontSize: 11),
                      filled: true,
                      fillColor: ac.bgElevated,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      suffixIcon: _pdfUrlCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  size: 14,
                                  color: ac.textSecondary),
                              onPressed: () {
                                _pdfUrlCtrl.clear();
                                setState(() {
                                  _pdfUrl          = '';
                                  _pdfCloudinaryId = '';
                                });
                              },
                            )
                          : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: _pdfUrl.isNotEmpty
                                ? ac.tealMid.withOpacity(0.5)
                                : ac.goldBorder,
                            width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: ac.gold, width: 1),
                      ),
                    ),
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
                ]),
              ),
              const SizedBox(height: 14),

              // ── Video ─────────────────────────────────────────────────
              _AdminCard(
                title: 'Video',
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

                    // URL paste field
                    TextField(
                      controller: _videoUrlCtrl,
                      style: TextStyle(
                          color: ac.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        hintText:
                            'https://youtube.com/... or https://res.cloudinary.com/...',
                        hintStyle: TextStyle(
                            color: ac.textSecondary,
                            fontSize: 11),
                        filled: true,
                        fillColor: ac.bgElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: _videoUrlCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    size: 14,
                                    color: ac.textSecondary),
                                onPressed: () {
                                  _videoUrlCtrl.clear();
                                  setState(() {
                                    _videoUrl          = '';
                                    _cloudinaryVideoId = '';
                                  });
                                },
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: _videoUrl.isNotEmpty
                                  ? ac.tealMid.withOpacity(0.5)
                                  : ac.goldBorder,
                              width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: ac.gold, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // OR divider
                    Row(children: [
                      Expanded(
                          child:
                              Divider(color: ac.goldBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('OR',
                            style: TextStyle(
                                color: ac.textSecondary
                                    .withValues(alpha: 0.6),
                                fontSize: 11)),
                      ),
                      Expanded(
                          child:
                              Divider(color: ac.goldBorder)),
                    ]),
                    const SizedBox(height: 8),

                    // Upload progress or file badge + pick button
                    if (_videoUploadProgress != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _videoUploadProgress,
                              minHeight: 5,
                              backgroundColor: ac.bgElevated,
                              valueColor: AlwaysStoppedAnimation(
                                  ac.gold),
                            ),
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
                      if (_videoName != null)
                        _UrlBadge(
                          icon: Icons.videocam_outlined,
                          label: 'Video selected',
                          labelAr: 'تم اختيار الفيديو',
                          url: _videoName!,
                          onClear: () => setState(() {
                            _videoFile         = null;
                            _videoBytes        = null;
                            _videoName         = null;
                            _videoUrl          = '';
                            _cloudinaryVideoId = '';
                            _videoUrlCtrl.clear();
                          }),
                          onReplace: _pickVideo,
                        )
                      else
                        _DropZone(
                          icon: Icons.videocam_outlined,
                          title: 'Select Video File',
                          titleAr: 'اختر ملف فيديو',
                          subtitle: 'MP4 / MOV / MKV',
                          hasFile: false,
                          borderColor: ac.goldBorder,
                          onTap: _saving ? null : _pickVideo,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Publish toggle ────────────────────────────────────────
              _AdminCard(
                title: 'Publish Settings',
                titleAr: 'إعدادات النشر',
                child: _ToggleRow(
                  label: 'Published',
                  labelAr: 'منشور',
                  sub: 'Visible to all app users',
                  value: _published,
                  onChange: (v) => setState(() => _published = v),
                ),
              ),
              const SizedBox(height: 14),

              // ── Sections ──────────────────────────────────────────────
              _SectionsEditor(
                sections: _sections,
                onAdd: () => setState(
                    () => _sections.add(_SectionDraft())),
                onRemove: (i) =>
                    setState(() => _sections.removeAt(i)),
              ),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ),
    ]);
  }

}

// ════════════════════════════════════════════════════════════════════════════
// SECTIONS EDITOR
// ════════════════════════════════════════════════════════════════════════════

// ── Track draft ───────────────────────────────────────────────────────────────
// Mutable state for one audio track while the admin is editing.

class _TrackDraft {
  final TextEditingController label;
  final TextEditingController duration; // seconds as string
  File?      file;
  Uint8List? bytes;
  String?    name;
  String     url;
  double     progress;
  bool       uploading;

  _TrackDraft({
    String label        = '',
    String url          = '',
    int    durationSecs = 0,
  })  : label    = TextEditingController(text: label),
        duration = TextEditingController(
            text: durationSecs > 0 ? '$durationSecs' : ''),
        url      = url,
        progress = 0,
        uploading = false;

  factory _TrackDraft.fromTrack(AgbeyaAudioTrack t) => _TrackDraft(
        label:        t.labelAr,
        url:          t.url,
        durationSecs: t.durationSeconds,
      );

  void dispose() {
    label.dispose();
    duration.dispose();
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _SectionDraft {
  final TextEditingController titleAr  = TextEditingController();
  final TextEditingController titleCop = TextEditingController();
  final TextEditingController titleEl  = TextEditingController();
  final TextEditingController textAr   = TextEditingController();
  final TextEditingController textCop  = TextEditingController();
  final TextEditingController textEl   = TextEditingController();
  bool expanded = true;

  _SectionDraft();

  _SectionDraft.fromSection(AgbeyaSection s) {
    titleAr.text  = s.titleAr;
    titleCop.text = s.titleCop;
    titleEl.text  = s.titleEl;
    textAr.text   = s.textAr;
    textCop.text  = s.textCop;
    textEl.text   = s.textEl;
  }

  void dispose() {
    titleAr.dispose();
    titleCop.dispose();
    titleEl.dispose();
    textAr.dispose();
    textCop.dispose();
    textEl.dispose();
  }
}

class _SectionsEditor extends StatefulWidget {
  const _SectionsEditor({
    required this.sections,
    required this.onAdd,
    required this.onRemove,
  });
  final List<_SectionDraft> sections;
  final VoidCallback         onAdd;
  final void Function(int)   onRemove;

  @override
  State<_SectionsEditor> createState() => _SectionsEditorState();
}

class _SectionsEditorState extends State<_SectionsEditor> {
  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return _AdminCard(
      title: 'Prayer Sections',
      titleAr: 'أقسام الصلاة',
      child: Column(children: [
        // Section cards
        ...widget.sections.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return _SectionCard(
            draft: s,
            index: i,
            onRemove: () => widget.onRemove(i),
            onToggle: () => setState(() => s.expanded = !s.expanded),
          );
        }),

        const SizedBox(height: 12),

        // Add section button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onAdd,
            icon: Icon(Icons.add,
                size: 16, color: ac.gold),
            label: Text('Add Section  |  أضف قسم',
                style: TextStyle(
                    color: ac.gold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                  color: ac.goldBorder, width: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.draft,
    required this.index,
    required this.onRemove,
    required this.onToggle,
  });
  final _SectionDraft draft;
  final int           index;
  final VoidCallback  onRemove;
  final VoidCallback  onToggle;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: ac.goldBorder, width: 0.5),
      ),
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────
        InkWell(
          onTap: onToggle,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ac.bgMid,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: ac.goldBorder, width: 0.5),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: ac.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.titleAr.text.isNotEmpty
                      ? draft.titleAr.text
                      : 'Section ${index + 1}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: ac.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                draft.expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: ac.goldDim,
                size: 18,
              ),
              SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close,
                    color: ac.maroonMid, size: 16),
              ),
            ]),
          ),
        ),

        // ── Expanded fields ───────────────────────────────────────────
        if (draft.expanded) ...[
          Divider(height: 1, color: ac.goldBorder),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              // Titles row
              Row(children: [
                Expanded(child: _AdminField(
                    controller: draft.titleAr,
                    label: 'Title (AR)',
                    hint: 'عنوان القسم',
                    rtl: true,
                    fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: _AdminField(
                    controller: draft.titleCop,
                    label: 'Title (Cop)',
                    hint: 'Ⲡⲓⲱ...')),
                const SizedBox(width: 8),
                Expanded(child: _AdminField(
                    controller: draft.titleEl,
                    label: 'Title (El)',
                    hint: 'Τίτλος...')),
              ]),
              const SizedBox(height: 10),

              // Arabic text (main)
              _ArabicField(
                controller: draft.textAr,
                label: 'Arabic Text',
                labelAr: 'النص العربي',
                hint: 'أدخل نص الصلاة بالعربية...',
                maxLines: 6,
                required: false,
              ),
              const SizedBox(height: 10),

              // Coptic text
              _AdminField(
                controller: draft.textCop,
                label: 'Coptic Text',
                hint: 'Ⲡⲓϫⲱⲙ...',
                maxLines: 5,
              ),
              const SizedBox(height: 10),

              // Greek text
              _AdminField(
                controller: draft.textEl,
                label: 'Greek Text',
                hint: 'Κύριε ελέησον...',
                maxLines: 5,
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED ADMIN WIDGETS (self-contained, mirror upload_book_screen patterns)
// ════════════════════════════════════════════════════════════════════════════

class _AdminCard extends StatelessWidget {
  const _AdminCard(
      {required this.title,
      required this.titleAr,
      required this.child});
  final String title;
  final String titleAr;
  final Widget child;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ac.goldBorder, width: 0.5),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: ac.gold,
                  borderRadius: BorderRadius.circular(2))),
          SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: ac.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          SizedBox(width: 6),
          Text(titleAr,
              style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: ac.textSecondary,
                  fontSize: 11)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

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
      final ac = AdminC(Theme.of(context).brightness);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: TextStyle(
                color: ac.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        SizedBox(width: 6),
        Text(labelAr,
            style: TextStyle(
                fontFamily: 'Scheherazade',
                color: ac.textSecondary,
                fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        style: TextStyle(
            fontFamily: 'Scheherazade',
            color: ac.textPrimary,
            fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontFamily: 'Scheherazade',
              color: ac.textSecondary,
              fontSize: 14),
          filled: true,
          fillColor: ac.bgElevated,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: ac.goldBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: ac.gold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Colors.redAccent, width: 1.5),
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null
            : null,
      ),
    ]);
  }
}

class _AdminField extends StatelessWidget {
  const _AdminField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.rtl = false,
    this.fontSize = 13,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final int    maxLines;
  final bool   rtl;
  final double fontSize;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: ac.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        style: TextStyle(
            fontFamily: rtl ? 'Scheherazade' : null,
            color: ac.textPrimary,
            fontSize: fontSize),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: ac.textSecondary, fontSize: 12),
          filled: true,
          fillColor: ac.bgElevated,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: ac.goldBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: ac.gold, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.labelAr,
    required this.sub,
    required this.value,
    required this.onChange,
  });
  final String   label;
  final String   labelAr;
  final String   sub;
  final bool     value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: ac.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            SizedBox(width: 6),
            Text(labelAr,
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary,
                    fontSize: 12)),
          ]),
          SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                  color: ac.textSecondary, fontSize: 11)),
        ]),
      ),
      const SizedBox(width: 16),
      GestureDetector(
        onTap: () => onChange(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: value
                ? ac.gold
                : ac.bgElevated,
            border: Border.all(
                color: value
                    ? ac.gold
                    : ac.goldBorder,
                width: 0.5),
          ),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 22 : 2,
              top: 3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? ac.bgDeep
                      : ac.textSecondary,
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.icon,
    required this.title,
    required this.titleAr,
    required this.subtitle,
    required this.hasFile,
    required this.borderColor,
    required this.onTap,
    this.fileName,
  });
  final IconData    icon;
  final String      title;
  final String      titleAr;
  final String      subtitle;
  final bool        hasFile;
  final Color       borderColor;
  final VoidCallback? onTap;
  final String?     fileName;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ac.bgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: hasFile ? 1.0 : 0.5),
        ),
        child: Row(children: [
          Icon(
            hasFile ? Icons.check_circle_outline : icon,
            size: 26,
            color: hasFile
                ? ac.tealMid
                : ac.goldDim,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasFile ? (fileName ?? title) : title,
                style: TextStyle(
                    color: hasFile
                        ? ac.textPrimary
                        : ac.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              Text(subtitle,
                  style: TextStyle(
                      color: ac.textSecondary, fontSize: 10)),
              Text(titleAr,
                  style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: ac.textSecondary,
                      fontSize: 10)),
            ]),
          ),
          Icon(Icons.chevron_right,
              color: ac.goldDim, size: 16),
        ]),
      ),
    );
  }
}

// Shows when a file is already uploaded — with clear + replace actions
class _UrlBadge extends StatelessWidget {
  const _UrlBadge({
    required this.icon,
    required this.label,
    required this.labelAr,
    required this.url,
    required this.onClear,
    required this.onReplace,
  });
  final IconData     icon;
  final String       label;
  final String       labelAr;
  final String       url;
  final VoidCallback onClear;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ac.tealMid.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: ac.tealMid.withOpacity(0.4), width: 0.8),
      ),
      child: Row(children: [
        Icon(icon, color: ac.tealMid, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: ac.tealMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            Text(labelAr,
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary,
                    fontSize: 11)),
            Text(
              url.length > 40 ? '…${url.substring(url.length - 40)}' : url,
              style: TextStyle(
                  color: ac.textSecondary, fontSize: 9),
            ),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.swap_horiz,
              color: ac.gold, size: 18),
          tooltip: 'Replace',
          onPressed: onReplace,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          icon: Icon(Icons.close,
              color: ac.maroonMid, size: 16),
          tooltip: 'Remove',
          onPressed: onClear,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color  color;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 9)),
      );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_stories_outlined,
              size: 52, color: ac.goldDim),
          SizedBox(height: 16),
          Text('No hours yet',
              style: TextStyle(
                  color: ac.textSecondary, fontSize: 16)),
          SizedBox(height: 8),
          Text('لا توجد ساعات بعد',
              style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: ac.textSecondary,
                  fontSize: 14)),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add,
                size: 18, color: ac.bgDeep),
            label: Text('Add First Hour',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ac.bgDeep)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.gold,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog(
      {required this.onCancel, required this.onConfirm});
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
        onTap: onCancel,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ac.bgMid,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: ac.maroon, width: 0.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded,
                      color: ac.maroonMid, size: 40),
                  SizedBox(height: 12),
                  Text('Delete Hour',
                      style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'This permanently removes the hour and its sections '
                    'from Firestore. Delete the Cloudinary audio asset separately.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ac.textSecondary,
                          side: BorderSide(
                              color: ac.goldBorder, width: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ac.maroon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Delete',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
  }
}
