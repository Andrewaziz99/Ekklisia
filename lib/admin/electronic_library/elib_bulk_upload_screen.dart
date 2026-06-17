// lib/admin/electronic_library/elib_bulk_upload_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Elib Bulk Upload.
// The sectionId is passed as route extra.
// Pick multiple video or audio files.
// Each row: filename → editable AR + EL titles, media type toggle.
// Upload all sequentially.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/models/elib_item_model.dart';
import '../../data/repositories/elib_repository.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../admin_l10n.dart';

// ── Row state ─────────────────────────────────────────────────────────────────

enum _RowStatus { pending, uploading, done, failed }

class _FileRow {
  _FileRow({required this.file, required ElibMediaType defaultType})
    : titleArCtrl = TextEditingController(text: _stem(file.name)),
      titleElCtrl = TextEditingController(text: _stem(file.name)),
      mediaType = defaultType;

  final PlatformFile file;
  final TextEditingController titleArCtrl;
  final TextEditingController titleElCtrl;
  ElibMediaType mediaType;
  _RowStatus status = _RowStatus.pending;
  double progress = 0;
  String? error;

  static String _stem(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? name : name.substring(0, i);
  }

  static ElibMediaType _guessType(String name) {
    final ext = name.split('.').last.toLowerCase();
    const audioExts = {'mp3', 'aac', 'wav', 'ogg', 'm4a', 'flac'};
    return audioExts.contains(ext) ? ElibMediaType.audio : ElibMediaType.video;
  }

  void dispose() {
    titleArCtrl.dispose();
    titleElCtrl.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ElibBulkUploadScreen extends StatefulWidget {
  const ElibBulkUploadScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  State<ElibBulkUploadScreen> createState() => _ElibBulkUploadScreenState();
}

class _ElibBulkUploadScreenState extends State<ElibBulkUploadScreen> {
  final _repo = sl<ElibRepository>();
  final List<_FileRow> _rows = [];
  bool _uploading = false;
  bool _isDragging = false;

  static const _mediaExts = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    'mp3',
    'aac',
    'wav',
    'm4a',
    'ogg',
    'flac',
  };

  // ── Drag-and-drop handler ────────────────────────────────────────────────

  Future<void> _addFromDrop(List<XFile> files) async {
    final mediaFiles = files.where(
      (f) => _mediaExts.contains(f.name.split('.').last.toLowerCase()),
    );
    for (final xfile in mediaFiles) {
      final Uint8List bytes = await xfile.readAsBytes();
      final pf = PlatformFile(
        name: xfile.name,
        size: bytes.length,
        path: kIsWeb ? null : xfile.path,
        bytes: kIsWeb ? bytes : null,
      );
      _rows.add(
        _FileRow(file: pf, defaultType: _FileRow._guessType(xfile.name)),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  // ── File picker ──────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'mp3',
        'aac',
        'wav',
        'm4a',
        'ogg',
        'flac',
      ],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        _rows.add(_FileRow(file: f, defaultType: _FileRow._guessType(f.name)));
      }
    });
  }

  String get _uid => context.read<AuthCubit>().state.user?.uid ?? '';

  // ── Upload ───────────────────────────────────────────────────────────────

  Future<void> _uploadAll() async {
    final pending = _rows.where((r) => r.status == _RowStatus.pending).toList();
    if (pending.isEmpty) return;
    setState(() => _uploading = true);

    for (final row in pending) {
      setState(() {
        row.status = _RowStatus.uploading;
        row.progress = 0;
      });
      try {
        final isAudio = row.mediaType == ElibMediaType.audio;
        if (kIsWeb && row.file.bytes != null) {
          if (isAudio) {
            await _repo.uploadAudioAndSaveBytes(
              bytes: row.file.bytes!,
              fileName: row.file.name,
              sectionId: widget.sectionId,
              titleAr: row.titleArCtrl.text.trim(),
              titleEl: row.titleElCtrl.text.trim(),
              createdBy: _uid,
              onProgress: (p) => setState(() => row.progress = p),
            );
          } else {
            await _repo.uploadVideoAndSaveBytes(
              bytes: row.file.bytes!,
              fileName: row.file.name,
              sectionId: widget.sectionId,
              titleAr: row.titleArCtrl.text.trim(),
              titleEl: row.titleElCtrl.text.trim(),
              createdBy: _uid,
              onProgress: (p) => setState(() => row.progress = p),
            );
          }
        } else if (!kIsWeb && row.file.path != null) {
          if (isAudio) {
            await _repo.uploadAudioAndSave(
              file: File(row.file.path!),
              sectionId: widget.sectionId,
              titleAr: row.titleArCtrl.text.trim(),
              titleEl: row.titleElCtrl.text.trim(),
              createdBy: _uid,
              onProgress: (p) => setState(() => row.progress = p),
            );
          } else {
            await _repo.uploadVideoAndSave(
              file: File(row.file.path!),
              sectionId: widget.sectionId,
              titleAr: row.titleArCtrl.text.trim(),
              titleEl: row.titleElCtrl.text.trim(),
              createdBy: _uid,
              onProgress: (p) => setState(() => row.progress = p),
            );
          }
        }
        setState(() => row.status = _RowStatus.done);
      } catch (e) {
        setState(() {
          row.status = _RowStatus.failed;
          row.error = e.toString();
        });
      }
    }
    setState(() => _uploading = false);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = context.adminL10n;
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );
    final pending = _rows.where((r) => r.status == _RowStatus.pending).length;
    final done = _rows.where((r) => r.status == _RowStatus.done).length;
    final failed = _rows.where((r) => r.status == _RowStatus.failed).length;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        if (!_uploading) await _addFromDrop(detail.files);
      },
      child: Stack(
        children: [
          // ── Main scaffold ────────────────────────────────────────────────
          Scaffold(
            backgroundColor: EkklisiaColors.bgPrimary,
            body: Column(
              children: [
                // Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: EkklisiaColors.bgPrimary,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A3A50)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.elibBulkUpload,
                          style: TextStyle(
                            fontFamily: isGreek ? null : 'Scheherazade',
                            color: EkklisiaColors.gold,
                            fontSize: isGreek ? 16 : 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _uploading ? null : _pickFiles,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l.addFiles),
                        style: FilledButton.styleFrom(
                          backgroundColor: EkklisiaColors.gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                // File list
                Expanded(
                  child: _rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.video_library_outlined,
                                size: 56,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l.noFilesSelected,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _rows.length,
                          itemBuilder: (ctx, i) => _RowTile(
                            row: _rows[i],
                            l: l,
                            isGreek: isGreek,
                            onTypeChange: (t) =>
                                setState(() => _rows[i].mediaType = t),
                          ),
                        ),
                ),
                // Bottom bar
                if (_rows.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D1B2A),
                      border: Border(top: BorderSide(color: Color(0xFF2A3A50))),
                    ),
                    child: Row(
                      children: [
                        if (done > 0) _chip('$done ✓', Colors.green),
                        if (failed > 0) ...[
                          const SizedBox(width: 6),
                          _chip('$failed ✗', Colors.red),
                        ],
                        if (pending > 0) ...[
                          const SizedBox(width: 6),
                          _chip('$pending …', Colors.white38),
                        ],
                        const Spacer(),
                        FilledButton(
                          onPressed: pending > 0 && !_uploading
                              ? _uploadAll
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: EkklisiaColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          child: _uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(l.uploadAllN(pending)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ── Drag overlay ─────────────────────────────────────────────────
          if (_isDragging) const _ElibDragOverlay(),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11)),
  );
}

// ── Row tile ──────────────────────────────────────────────────────────────────

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.row,
    required this.l,
    required this.isGreek,
    required this.onTypeChange,
  });

  final _FileRow row;
  final AdminL10n l;
  final bool isGreek;
  final ValueChanged<ElibMediaType> onTypeChange;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    switch (row.status) {
      case _RowStatus.done:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case _RowStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      case _RowStatus.uploading:
        statusColor = EkklisiaColors.gold;
        statusIcon = Icons.upload;
        break;
      default:
        statusColor = Colors.white24;
        statusIcon = row.mediaType == ElibMediaType.audio
            ? Icons.audiotrack_outlined
            : Icons.videocam_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF162535),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3A50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.file.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(row.file.size / 1024).toStringAsFixed(0)} KB',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          if (row.status == _RowStatus.uploading) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: row.progress,
              color: EkklisiaColors.gold,
              backgroundColor: Colors.white12,
              minHeight: 3,
            ),
          ],
          if (row.status != _RowStatus.done) ...[
            const SizedBox(height: 8),
            // Type toggle
            Row(
              children: [
                ChoiceChip(
                  label: Text(l.video, style: const TextStyle(fontSize: 11)),
                  selected: row.mediaType == ElibMediaType.video,
                  onSelected: (_) => onTypeChange(ElibMediaType.video),
                  selectedColor: Colors.blue.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l.audio, style: const TextStyle(fontSize: 11)),
                  selected: row.mediaType == ElibMediaType.audio,
                  onSelected: (_) => onTypeChange(ElibMediaType.audio),
                  selectedColor: EkklisiaColors.gold.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.titleArCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Scheherazade',
                    ),
                    decoration: InputDecoration(
                      labelText: l.titleAr,
                      labelStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.titleElCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l.titleEl,
                      labelStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (row.status == _RowStatus.failed && row.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                row.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Drag overlay ──────────────────────────────────────────────────────────────
// NOTE: uses SizedBox.expand (not Positioned.fill) so it works as a
// non-positioned Stack child and still fills the available space.
// Positioned.fill must be a *direct* child of Stack — returning it from
// a widget's build() violates that constraint and causes a Flutter assertion.

class _ElibDragOverlay extends StatelessWidget {
  const _ElibDragOverlay();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: EkklisiaColors.gold,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  color: EkklisiaColors.gold.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: EkklisiaColors.gold,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Drop video / audio files here',
                style: TextStyle(
                  color: EkklisiaColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
