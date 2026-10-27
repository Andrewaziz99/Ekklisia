// lib/admin/content/agbeya_intro_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Agbeya Intro.
// One shared audio intro (Arabic + Greek) that automatically plays before
// whichever track the user picks, for any hour. Single doc:
// config/agbeya_intro (see AgbeyaIntroRepository). Playback wiring lives in
// track_picker_sheet.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/agbeya_intro_model.dart';
import '../../data/repositories/agbeya_intro_repository.dart';
import '../utils/admin_colors.dart';

class AgbeyaIntroManagerScreen extends StatefulWidget {
  const AgbeyaIntroManagerScreen({super.key});

  @override
  State<AgbeyaIntroManagerScreen> createState() =>
      _AgbeyaIntroManagerScreenState();
}

class _AgbeyaIntroManagerScreenState extends State<AgbeyaIntroManagerScreen> {
  final _repo = sl<AgbeyaIntroRepository>();
  final _cloudinary = sl<CloudinaryDataSource>();

  late final TextEditingController _durationArCtrl;
  late final TextEditingController _durationElCtrl;

  String _urlAr = '';
  String _urlEl = '';

  // Arabic upload state
  File? _fileAr;
  Uint8List? _bytesAr;
  String? _nameAr;
  bool _uploadingAr = false;
  double _progressAr = 0;

  // Greek upload state
  File? _fileEl;
  Uint8List? _bytesEl;
  String? _nameEl;
  bool _uploadingEl = false;
  double _progressEl = 0;

  bool _loading = true;
  bool _saving = false;
  String _saveMessage = '';

  @override
  void initState() {
    super.initState();
    _durationArCtrl = TextEditingController();
    _durationElCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final intro = await _repo.fetch();
    if (!mounted) return;
    setState(() {
      _urlAr = intro.urlAr;
      _urlEl = intro.urlEl;
      _durationArCtrl.text =
          intro.durationArSeconds > 0 ? '${intro.durationArSeconds}' : '';
      _durationElCtrl.text =
          intro.durationElSeconds > 0 ? '${intro.durationElSeconds}' : '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _durationArCtrl.dispose();
    _durationElCtrl.dispose();
    super.dispose();
  }

  // ── Upload: Arabic ───────────────────────────────────────────────────────

  Future<void> _pickAr() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _nameAr  = f.name;
      _fileAr  = kIsWeb ? null : File(f.path!);
      _bytesAr = kIsWeb ? f.bytes : null;
    });
    await _uploadAr();
  }

  Future<void> _uploadAr() async {
    if (_fileAr == null && _bytesAr == null) return;
    setState(() { _uploadingAr = true; _progressAr = 0; });
    try {
      final result = kIsWeb
          ? await _cloudinary.uploadAudioBytes(
              bytes: _bytesAr!,
              fileName: _nameAr!,
              folder: 'Ekklisia/agbeya/intro',
              onProgress: (p) => setState(() => _progressAr = p),
            )
          : await _cloudinary.uploadAudio(
              audioFile: _fileAr!,
              folder: 'Ekklisia/agbeya/intro',
              onProgress: (p) => setState(() => _progressAr = p),
            );
      setState(() {
        _urlAr = result.secureUrl;
        _uploadingAr = false;
        _progressAr = 1;
      });
      _snack('Arabic intro uploaded ✓');
    } catch (e) {
      setState(() { _uploadingAr = false; });
      _snack('Arabic intro upload failed: $e', error: true);
    }
  }

  // ── Upload: Greek ─────────────────────────────────────────────────────────

  Future<void> _pickEl() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _nameEl  = f.name;
      _fileEl  = kIsWeb ? null : File(f.path!);
      _bytesEl = kIsWeb ? f.bytes : null;
    });
    await _uploadEl();
  }

  Future<void> _uploadEl() async {
    if (_fileEl == null && _bytesEl == null) return;
    setState(() { _uploadingEl = true; _progressEl = 0; });
    try {
      final result = kIsWeb
          ? await _cloudinary.uploadAudioBytes(
              bytes: _bytesEl!,
              fileName: _nameEl!,
              folder: 'Ekklisia/agbeya/intro',
              onProgress: (p) => setState(() => _progressEl = p),
            )
          : await _cloudinary.uploadAudio(
              audioFile: _fileEl!,
              folder: 'Ekklisia/agbeya/intro',
              onProgress: (p) => setState(() => _progressEl = p),
            );
      setState(() {
        _urlEl = result.secureUrl;
        _uploadingEl = false;
        _progressEl = 1;
      });
      _snack('Greek intro uploaded ✓');
    } catch (e) {
      setState(() { _uploadingEl = false; });
      _snack('Greek intro upload failed: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
    ));
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saveMessage = ''; });
    try {
      await _repo.save(AgbeyaIntroModel(
        urlAr: _urlAr,
        durationArSeconds: int.tryParse(_durationArCtrl.text.trim()) ?? 0,
        urlEl: _urlEl,
        durationElSeconds: int.tryParse(_durationElCtrl.text.trim()) ?? 0,
      ));
      if (!mounted) return;
      setState(() { _saving = false; _saveMessage = 'Saved.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveMessage = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);

    return Scaffold(
      backgroundColor: ac.bgPrimary,
      appBar: AppBar(
        backgroundColor: ac.bgDeep,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agbeya Intro',
                style: TextStyle(
                    color: ac.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            Text('مقدمة الأجبية • Εισαγωγή Προσευχών',
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary,
                    fontSize: 11)),
          ],
        ),
        actions: [
          if (_saving)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                      color: ac.gold, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                strokeWidth: 2,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'This single intro plays automatically before any Agbeya '
                  'hour\'s chosen track — in the language currently selected '
                  'in the app. Leave a language empty to skip the intro for it.',
                  style: TextStyle(color: ac.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 14),
                if (_saveMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _saveMessage.startsWith('Failed')
                          ? const Color(0xFF8C2B2B).withValues(alpha: 0.12)
                          : const Color(0xFF2E7D52).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_saveMessage,
                        style: TextStyle(
                          color: _saveMessage.startsWith('Failed')
                              ? const Color(0xFFE57373)
                              : const Color(0xFF3A8C5A),
                          fontSize: 12,
                        )),
                  ),
                _AdminCard(
                  title: 'Arabic Intro',
                  titleAr: 'المقدمة بالعربية',
                  child: Column(children: [
                    if (_urlAr.isNotEmpty && !_uploadingAr)
                      _UrlBadge(
                        url: _urlAr,
                        onClear: () => setState(() { _urlAr = ''; _progressAr = 0; }),
                        onReplace: _pickAr,
                      )
                    else
                      _DropZone(
                        uploading: _uploadingAr,
                        progress: _progressAr,
                        hasFile: _fileAr != null || _bytesAr != null,
                        fileName: _nameAr,
                        onTap: _uploadingAr ? null : _pickAr,
                      ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _durationArCtrl,
                      label: 'Duration (seconds)',
                      hint: '30',
                      keyboardType: TextInputType.number,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                _AdminCard(
                  title: 'Greek Intro',
                  titleAr: 'المقدمة باليونانية',
                  child: Column(children: [
                    if (_urlEl.isNotEmpty && !_uploadingEl)
                      _UrlBadge(
                        url: _urlEl,
                        onClear: () => setState(() { _urlEl = ''; _progressEl = 0; }),
                        onReplace: _pickEl,
                      )
                    else
                      _DropZone(
                        uploading: _uploadingEl,
                        progress: _progressEl,
                        hasFile: _fileEl != null || _bytesEl != null,
                        fileName: _nameEl,
                        onTap: _uploadingEl ? null : _pickEl,
                      ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _durationElCtrl,
                      label: 'Duration (seconds)',
                      hint: '30',
                      keyboardType: TextInputType.number,
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}

// ── Small local widgets (mirrors agbeya_manager.dart styling) ─────────────────

class _AdminCard extends StatelessWidget {
  const _AdminCard(
      {required this.title, required this.titleAr, required this.child});
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
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: ac.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: ac.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
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
        keyboardType: keyboardType,
        style: TextStyle(color: ac.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: ac.textSecondary, fontSize: 12),
          filled: true,
          fillColor: ac.bgElevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ac.gold, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.uploading,
    required this.progress,
    required this.hasFile,
    required this.onTap,
    this.fileName,
  });
  final bool uploading;
  final double progress;
  final bool hasFile;
  final VoidCallback? onTap;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.bgMid,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: hasFile ? ac.tealMid : ac.goldBorder,
                width: hasFile ? 1.0 : 0.5),
          ),
          child: Row(children: [
            Icon(
              hasFile ? Icons.check_circle_outline : Icons.audiotrack_outlined,
              size: 26,
              color: hasFile ? ac.tealMid : ac.goldDim,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                uploading
                    ? 'Uploading… ${(progress * 100).round()}%'
                    : (hasFile ? (fileName ?? 'Selected') : 'Select Audio File'),
                style: TextStyle(
                    color: hasFile ? ac.textPrimary : ac.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: ac.goldDim, size: 16),
          ]),
        ),
        if (uploading) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: ac.bgElevated,
              valueColor: AlwaysStoppedAnimation(ac.gold),
            ),
          ),
        ],
      ]),
    );
  }
}

class _UrlBadge extends StatelessWidget {
  const _UrlBadge({
    required this.url,
    required this.onClear,
    required this.onReplace,
  });
  final String url;
  final VoidCallback onClear;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ac.tealMid.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ac.tealMid.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(children: [
        Icon(Icons.audiotrack, color: ac.tealMid, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            url.length > 40 ? '…${url.substring(url.length - 40)}' : url,
            style: TextStyle(color: ac.textSecondary, fontSize: 10),
          ),
        ),
        IconButton(
          icon: Icon(Icons.swap_horiz, color: ac.gold, size: 18),
          tooltip: 'Replace',
          onPressed: onReplace,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          icon: Icon(Icons.close, color: ac.maroonMid, size: 16),
          tooltip: 'Remove',
          onPressed: onClear,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }
}
