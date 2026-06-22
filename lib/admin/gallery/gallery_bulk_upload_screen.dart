// lib/admin/gallery/gallery_bulk_upload_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Gallery Bulk Upload.
// Pick multiple images (or drag-and-drop on web/desktop).
// Each row has editable AR + EL title fields pre-filled from the filename stem.
// Upload all sequentially with per-file progress.
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
import '../../data/repositories/gallery_repository.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../admin_l10n.dart';
import '../utils/admin_colors.dart';

// ── File row state ────────────────────────────────────────────────────────────

enum _RowStatus { pending, uploading, done, failed }

class _FileRow {
  _FileRow({required this.file})
    : titleArCtrl = TextEditingController(text: _stem(file.name)),
      titleElCtrl = TextEditingController(text: _stem(file.name));

  final PlatformFile file;
  final TextEditingController titleArCtrl;
  final TextEditingController titleElCtrl;
  _RowStatus status = _RowStatus.pending;
  double progress = 0;
  String? error;

  static String _stem(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? name : name.substring(0, i);
  }

  void dispose() {
    titleArCtrl.dispose();
    titleElCtrl.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GalleryBulkUploadScreen extends StatefulWidget {
  const GalleryBulkUploadScreen({super.key});

  @override
  State<GalleryBulkUploadScreen> createState() =>
      _GalleryBulkUploadScreenState();
}

class _GalleryBulkUploadScreenState extends State<GalleryBulkUploadScreen> {
  final _repo = sl<GalleryRepository>();
  final List<_FileRow> _rows = [];
  bool _uploading = false;
  bool _isDragging = false;

  static const _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
  };

  // ── Drag-and-drop handler ────────────────────────────────────────────────

  Future<void> _addFromDrop(List<XFile> files) async {
    final imageFiles = files.where(
      (f) => _imageExts.contains(f.name.split('.').last.toLowerCase()),
    );
    for (final xfile in imageFiles) {
      final Uint8List bytes = await xfile.readAsBytes();
      final pf = PlatformFile(
        name: xfile.name,
        size: bytes.length,
        path: kIsWeb ? null : xfile.path,
        bytes: kIsWeb ? bytes : null,
      );
      _rows.add(_FileRow(file: pf));
    }
    setState(() {});
  }

  // ── File picker ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        _rows.add(_FileRow(file: f));
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
        if (kIsWeb && row.file.bytes != null) {
          await _repo.uploadAndSaveBytes(
            bytes: row.file.bytes!,
            fileName: row.file.name,
            titleAr: row.titleArCtrl.text.trim(),
            titleEl: row.titleElCtrl.text.trim(),
            createdBy: _uid,
            onProgress: (p) => setState(() => row.progress = p),
          );
        } else if (!kIsWeb && row.file.path != null) {
          await _repo.uploadAndSave(
            imageFile: File(row.file.path!),
            titleAr: row.titleArCtrl.text.trim(),
            titleEl: row.titleElCtrl.text.trim(),
            createdBy: _uid,
            onProgress: (p) => setState(() => row.progress = p),
          );
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
      final ac = AdminC(Theme.of(context).brightness);
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
          // ── Main scaffold ──────────────────────────────────────────────
          Scaffold(
            backgroundColor: EkklisiaColors.bgPrimary,
            body: Column(
              children: [
                // Toolbar
                _Toolbar(
                  title: l.galleryBulkUpload,
                  isGreek: isGreek,
                  onAdd: _uploading ? null : _pickFiles,
                ),
                // File list
                Expanded(
                  child: _rows.isEmpty
                      ? _EmptyHint(l: l)
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _rows.length,
                          itemBuilder: (ctx, i) =>
                              _RowTile(row: _rows[i], l: l, isGreek: isGreek),
                        ),
                ),
                // Bottom bar
                if (_rows.isNotEmpty)
                  _BottomBar(
                    pending: pending,
                    done: done,
                    failed: failed,
                    uploading: _uploading,
                    l: l,
                    isGreek: isGreek,
                    onUpload: pending > 0 && !_uploading ? _uploadAll : null,
                  ),
              ],
            ),
          ),
          // ── Drag overlay ───────────────────────────────────────────────
          if (_isDragging) const _DragOverlay(),
        ],
      ),
    );
  }
}

// ── Drag overlay ──────────────────────────────────────────────────────────────
// NOTE: uses SizedBox.expand (not Positioned.fill) so it works as a
// non-positioned Stack child and still fills the available space.

class _DragOverlay extends StatelessWidget {
  const _DragOverlay();

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
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
                    color: ac.gold,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  color: ac.gold.withValues(alpha: 0.08),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: ac.gold,
                  size: 64,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Drop images here',
                style: TextStyle(
                  color: ac.gold,
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

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.isGreek,
    required this.onAdd,
  });

  final String title;
  final bool isGreek;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgPrimary,
        border: Border(bottom: BorderSide(color: Color(0xFF2A3A50), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: ac.gold,
                fontSize: isGreek ? 16 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add_photo_alternate, size: 16),
            label: Text(l.addFiles),
            style: FilledButton.styleFrom(
              backgroundColor: ac.gold,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ── File row tile ─────────────────────────────────────────────────────────────

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.l, required this.isGreek});

  final _FileRow row;
  final AdminL10n l;
  final bool isGreek;

  Color get _statusColor => switch (row.status) {
    _RowStatus.done => Colors.green,
    _RowStatus.failed => Colors.red,
    _RowStatus.uploading => EkklisiaColors.darkGold,
    _RowStatus.pending => Colors.white24,
  };

  IconData get _statusIcon => switch (row.status) {
    _RowStatus.done => Icons.check_circle,
    _RowStatus.failed => Icons.error_outline,
    _RowStatus.uploading => Icons.upload,
    _RowStatus.pending => Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
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
              Icon(_statusIcon, color: _statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.file.name,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(row.file.size / 1024).toStringAsFixed(0)} KB',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          if (row.status == _RowStatus.uploading) ...[
            SizedBox(height: 6),
            LinearProgressIndicator(
              value: row.progress,
              color: ac.gold,
              backgroundColor: Colors.white12,
              minHeight: 3,
            ),
          ],
          if (row.status != _RowStatus.done) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.titleArCtrl,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Scheherazade',
                    ),
                    decoration: InputDecoration(
                      labelText: l.titleAr,
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.titleElCtrl,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l.titleEl,
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(),
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
                style: TextStyle(color: Colors.redAccent, fontSize: 11),
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pending,
    required this.done,
    required this.failed,
    required this.uploading,
    required this.l,
    required this.isGreek,
    required this.onUpload,
  });

  final int pending;
  final int done;
  final int failed;
  final bool uploading;
  final AdminL10n l;
  final bool isGreek;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
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
          Spacer(),
          FilledButton(
            onPressed: onUpload,
            style: FilledButton.styleFrom(
              backgroundColor: ac.gold,
              foregroundColor: Colors.black,
            ),
            child: uploading
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

// ── Empty hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.l});
  final AdminL10n l;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            size: 56,
            color: Colors.white24,
          ),
          const SizedBox(height: 12),
          Text(
            l.noFilesSelected,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            l.filenameHint,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
