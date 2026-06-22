// lib/admin/saints/saints_bulk_upload_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bulk upload screen for the Saints section.
//
// • Pick multiple video / audio / PDF files at once
// • Filename (without extension) pre-fills the saint name (both AR & EN)
// • User can edit nameAr and nameEn per row before uploading
// • Files upload sequentially; progress shown per row
// • Each successful upload creates a new SaintModel in Firestore
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/saint_model.dart';
import '../../data/repositories/saints_repository.dart';
import '../../features/auth/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../admin_l10n.dart';
import '../utils/admin_colors.dart';

// ── Media type ────────────────────────────────────────────────────────────────

enum _SaintMediaType { video, audio, pdf }

extension _SaintMediaTypeX on _SaintMediaType {
  String get label {
    switch (this) {
      case _SaintMediaType.video: return 'Video';
      case _SaintMediaType.audio: return 'Audio';
      case _SaintMediaType.pdf:   return 'PDF';
    }
  }

  Color get color {
    switch (this) {
      case _SaintMediaType.video: return const Color(0xFF7B5EA7);
      case _SaintMediaType.audio: return const Color(0xFF2E7D82);
      case _SaintMediaType.pdf:   return const Color(0xFFB54A2E);
    }
  }

  IconData get icon {
    switch (this) {
      case _SaintMediaType.video: return Icons.videocam_outlined;
      case _SaintMediaType.audio: return Icons.headphones_outlined;
      case _SaintMediaType.pdf:   return Icons.picture_as_pdf_outlined;
    }
  }

  String get cloudinaryFolder {
    switch (this) {
      case _SaintMediaType.video: return 'Ekklisia/saints/video';
      case _SaintMediaType.audio: return 'Ekklisia/saints/audio';
      case _SaintMediaType.pdf:   return 'Ekklisia/saints';
    }
  }
}

// ── Row status ────────────────────────────────────────────────────────────────

enum _RowStatus { pending, uploading, done, error }

// ── File row data ─────────────────────────────────────────────────────────────

class _FileRow {
  _FileRow({
    required this.fileName,
    required this.mediaType,
    this.file,
    this.fileBytes,
    required this.fileSizeMb,
  })  : nameArCtrl = TextEditingController(text: _stem(fileName)),
        nameEnCtrl = TextEditingController(text: _stem(fileName));

  final String fileName;
  final _SaintMediaType mediaType;
  final File? file;
  final Uint8List? fileBytes;
  final double fileSizeMb;

  final TextEditingController nameArCtrl;
  final TextEditingController nameEnCtrl;

  _RowStatus status = _RowStatus.pending;
  double progress = 0;
  String? errorMsg;

  void dispose() {
    nameArCtrl.dispose();
    nameEnCtrl.dispose();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _ext(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
}

String _stem(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot >= 0 ? fileName.substring(0, dot) : fileName;
}

_SaintMediaType _detectType(String fileName) {
  const videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};
  const audioExts = {'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'opus'};
  final e = _ext(fileName);
  if (videoExts.contains(e)) return _SaintMediaType.video;
  if (audioExts.contains(e)) return _SaintMediaType.audio;
  return _SaintMediaType.pdf;
}

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════

class SaintsBulkUploadScreen extends StatefulWidget {
  const SaintsBulkUploadScreen({super.key});

  @override
  State<SaintsBulkUploadScreen> createState() => _SaintsBulkUploadScreenState();
}

class _SaintsBulkUploadScreenState extends State<SaintsBulkUploadScreen> {
  final _repo = sl<SaintsRepository>();
  final _cloudinary = sl<CloudinaryDataSource>();
  final List<_FileRow> _rows = [];

  bool _uploading = false;

  int get _doneCount   => _rows.where((r) => r.status == _RowStatus.done).length;
  int get _errorCount  => _rows.where((r) => r.status == _RowStatus.error).length;
  int get _pendingCount => _rows.where((r) => r.status == _RowStatus.pending).length;

  // ── File picker ─────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v',
        'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'opus',
      ],
    );
    if (result == null) return;

    final newRows = result.files.map((pf) {
      final sizeMb = (pf.size / (1024 * 1024));
      return _FileRow(
        fileName: pf.name,
        mediaType: _detectType(pf.name),
        file: kIsWeb ? null : (pf.path != null ? File(pf.path!) : null),
        fileBytes: kIsWeb ? pf.bytes : null,
        fileSizeMb: sizeMb,
      );
    }).toList();

    setState(() => _rows.addAll(newRows));
  }

  // ── Upload all ──────────────────────────────────────────────────────────────

  Future<void> _uploadAll() async {
    final pending = _rows.where((r) => r.status == _RowStatus.pending).toList();
    if (pending.isEmpty) return;

    final userId = context.read<AuthCubit>().state.user?.uid ?? '';

    setState(() => _uploading = true);

    for (final row in pending) {
      if (!mounted) break;
      setState(() {
        row.status = _RowStatus.uploading;
        row.progress = 0;
      });

      try {
        CloudinaryUploadResult result;

        if (row.mediaType == _SaintMediaType.pdf) {
          // ── PDF ──────────────────────────────────────────────────────
          if (row.fileBytes != null) {
            result = await _cloudinary.uploadPdfBytes(
              bytes: row.fileBytes!,
              fileName: row.fileName,
              folder: _SaintMediaType.pdf.cloudinaryFolder,
              onProgress: (p) => setState(() => row.progress = p),
            );
          } else {
            result = await _cloudinary.uploadPdf(
              pdfFile: row.file!,
              folder: _SaintMediaType.pdf.cloudinaryFolder,
              onProgress: (p) => setState(() => row.progress = p),
            );
          }

          final saint = SaintModel(
            id: '',
            nameAr: row.nameArCtrl.text.trim(),
            nameEn: row.nameEnCtrl.text.trim(),
            pdfUrl: result.secureUrl,
            cloudinaryPdfId: result.publicId,
            isPublished: false,
            createdAt: DateTime.now(),
            createdBy: userId,
          );
          await _repo.save(saint);

        } else if (row.mediaType == _SaintMediaType.audio) {
          // ── Audio ─────────────────────────────────────────────────────
          if (row.fileBytes != null) {
            result = await _cloudinary.uploadAudioBytes(
              bytes: row.fileBytes!,
              fileName: row.fileName,
              folder: row.mediaType.cloudinaryFolder,
              onProgress: (p) => setState(() => row.progress = p),
            );
          } else {
            result = await _cloudinary.uploadAudio(
              audioFile: row.file!,
              folder: row.mediaType.cloudinaryFolder,
              onProgress: (p) => setState(() => row.progress = p),
            );
          }
        } else {
          // ── Video ─────────────────────────────────────────────────────
          if (row.fileBytes != null) {
            result = await _cloudinary.uploadVideoBytes(
              bytes: row.fileBytes!,
              fileName: row.fileName,
              folder: row.mediaType.cloudinaryFolder,
              onProgress: (p) => setState(() => row.progress = p),
            );
          } else {
            result = await _cloudinary.uploadVideo(
              videoFile: row.file!,
              folder: row.mediaType.cloudinaryFolder,
              onProgress: (p) => setState(() => row.progress = p),
            );
          }

          final saint = SaintModel(
            id: '',
            nameAr: row.nameArCtrl.text.trim(),
            nameEn: row.nameEnCtrl.text.trim(),
            audioUrl: row.mediaType == _SaintMediaType.audio
                ? result.secureUrl
                : '',
            cloudinaryAudioId: row.mediaType == _SaintMediaType.audio
                ? result.publicId
                : '',
            videoUrl: row.mediaType == _SaintMediaType.video
                ? result.secureUrl
                : '',
            cloudinaryVideoId: row.mediaType == _SaintMediaType.video
                ? result.publicId
                : '',
            isPublished: false,
            createdAt: DateTime.now(),
            createdBy: userId,
          );
          await _repo.save(saint);
        }

        if (mounted) setState(() { row.status = _RowStatus.done; row.progress = 1; });
      } catch (e) {
        if (mounted) {
          setState(() {
            row.status = _RowStatus.error;
            row.errorMsg = e.toString();
          });
        }
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  // ── Remove a row ─────────────────────────────────────────────────────────────

  void _removeRow(int index) {
    _rows[index].dispose();
    setState(() => _rows.removeAt(index));
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _rows.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _FileRowCard(
                    row: _rows[i],
                    onRemove: _rows[i].status == _RowStatus.pending
                        ? () => _removeRow(i)
                        : null,
                    onSetState: () => setState(() {}),
                  ),
                ),
        ),
        if (_rows.isNotEmpty) _buildBottomBar(),
      ],
    );
  }

  // ── Toolbar ──────────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    final ac = AdminC(Theme.of(context).brightness);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        border: Border(
          bottom: BorderSide(color: ac.goldBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.adminL10n.bulkUploadSaints,
                textDirection: context.adminL10n.dir,
                style: TextStyle(
                  fontFamily: context.adminL10n.fontFam,
                  color: ac.goldLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Add files button
          if (!_uploading)
            OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: Icon(Icons.add, size: 16),
              label: Text(context.adminL10n.addFiles),
              style: OutlinedButton.styleFrom(
                foregroundColor: ac.gold,
                side: BorderSide(color: ac.goldBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final ac = AdminC(Theme.of(context).brightness);

    final hasPending = _pendingCount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        border: Border(
          top: BorderSide(color: ac.goldBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Status pills
          _StatusPill(label: context.adminL10n.pendingCount(_pendingCount), color: ac.textSecondary),
          const SizedBox(width: 6),
          if (_doneCount > 0)
            _StatusPill(label: context.adminL10n.doneCount(_doneCount), color: Colors.green),
          if (_errorCount > 0) ...[
            const SizedBox(width: 6),
            _StatusPill(label: context.adminL10n.failedCount(_errorCount), color: Colors.redAccent),
          ],
          const Spacer(),
          if (!_uploading && hasPending)
            ElevatedButton.icon(
              onPressed: _uploadAll,
              icon: Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text(context.adminL10n.uploadAllN(_pendingCount)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (_uploading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ac.gold,
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final ac = AdminC(Theme.of(context).brightness);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 56,
            color: ac.goldDim,
          ),
          const SizedBox(height: 16),
          Text(
            context.adminL10n.noFilesSelected,
            textDirection: context.adminL10n.dir,
            style: TextStyle(
              fontFamily: context.adminL10n.fontFam,
              color: ac.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.adminL10n.filenameHint,
            textAlign: TextAlign.center,
            textDirection: context.adminL10n.dir,
            style: TextStyle(
              fontFamily: context.adminL10n.fontFam,
              color: ac.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: Icon(Icons.add, size: 16),
            label: Text(context.adminL10n.addFiles),
            style: OutlinedButton.styleFrom(
              foregroundColor: ac.gold,
              side: BorderSide(color: ac.goldBorder),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FILE ROW CARD
// ════════════════════════════════════════════════════════════════════════════

class _FileRowCard extends StatelessWidget {
  const _FileRowCard({
    required this.row,
    required this.onRemove,
    required this.onSetState,
  });

  final _FileRow row;
  final VoidCallback? onRemove;
  final VoidCallback onSetState;

  Color get _borderColor {
    switch (row.status) {
      case _RowStatus.done:     return Colors.green.withOpacity(0.6);
      case _RowStatus.error:    return Colors.redAccent.withOpacity(0.6);
      case _RowStatus.uploading: return EkklisiaColors.darkGold.withOpacity(0.5);
      default:                  return EkklisiaColors.darkGoldBorder;
    }
  }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final type = row.mediaType;
    final isDone = row.status == _RowStatus.done;
    final isError = row.status == _RowStatus.error;
    final isUploading = row.status == _RowStatus.uploading;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: type badge + filename + remove ─────────────────────────
          Row(
            children: [
              // Media type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: type.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: type.color.withOpacity(0.5), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon, size: 12, color: type.color),
                    const SizedBox(width: 4),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: type.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ac.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              // Size
              Text(
                '${row.fileSizeMb.toStringAsFixed(1)} MB',
                style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 10,
                ),
              ),
              // Status icon / remove
              const SizedBox(width: 8),
              if (isDone)
                const Icon(Icons.check_circle, size: 18, color: Colors.green)
              else if (isError)
                Tooltip(
                  message: row.errorMsg ?? 'Upload failed',
                  child: const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
                )
              else if (isUploading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ac.gold,
                  ),
                )
              else if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: ac.textSecondary,
                  ),
                ),
            ],
          ),

          // ── Progress bar ──────────────────────────────────────────────────
          if (isUploading || isDone) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: row.progress,
                minHeight: 3,
                backgroundColor: ac.bgDeep,
                valueColor: AlwaysStoppedAnimation(
                  isDone ? Colors.green : ac.gold,
                ),
              ),
            ),
          ],

          // ── Name fields (only when pending or error) ─────────────────────
          if (!isDone) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NameField(
                    controller: row.nameArCtrl,
                    hint: context.adminL10n.saintNameAr,
                    arabicFont: true,
                    enabled: !isUploading,
                    onChanged: (_) => onSetState(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NameField(
                    controller: row.nameEnCtrl,
                    hint: context.adminL10n.saintNameEl,
                    arabicFont: false,
                    enabled: !isUploading,
                    onChanged: (_) => onSetState(),
                  ),
                ),
              ],
            ),
          ],

          // ── Error message ─────────────────────────────────────────────────
          if (isError && row.errorMsg != null) ...[
            const SizedBox(height: 6),
            Text(
              row.errorMsg!,
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.hint,
    required this.arabicFont,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final bool arabicFont;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: arabicFont ? TextAlign.right : TextAlign.left,
      textDirection: arabicFont ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(
        color: ac.textPrimary,
        fontSize: 13,
        fontFamily: arabicFont ? 'Scheherazade' : null,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: ac.textSecondary,
          fontSize: 12,
          fontFamily: arabicFont ? 'Scheherazade' : null,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: ac.bgDeep,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: ac.gold, width: 1),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
