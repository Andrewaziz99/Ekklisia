import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/book_category_model.dart';
import '../../data/repositories/book_category_repository.dart';
import '../../core/router/app_router.dart';
import '../../data/repositories/books_repository.dart';
import '../../features/auth/auth_cubit.dart';
import '../../services/notification_service.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});
  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  // ── Stepper ─────────────────────────────────────────────────────────────
  int _step = 0; // 0=files  1=metadata  2=review

  // ── Files ────────────────────────────────────────────────────────────────
  File?   _pdfFile;
  Uint8List? _pdfBytes;
  File?   _coverFile;
  Uint8List? _coverBytes;
  String? _pdfName;
  String? _coverName;
  double? _pdfSizeMb;

  // ── Metadata form ────────────────────────────────────────────────────────
  final _formKey  = GlobalKey<FormState>();
  final _titleAr  = TextEditingController();
  final _titleCop = TextEditingController();
  final _titleEl  = TextEditingController();
  final _descAr   = TextEditingController();
  final _tags     = TextEditingController();
  String  _category  = '';
  bool    _publishNow  = true;
  bool    _sendNotif   = true;

  // ── Categories (loaded from Firestore, falls back to constants) ──────────
  List<BookCategory> _categories = [];
  bool _categoriesLoading = true;

  // ── Upload state ─────────────────────────────────────────────────────────
  bool    _uploading    = false;
  double  _pdfProgress  = 0;
  double  _coverProgress= 0;
  double  _dbProgress   = 0;
  String  _progressStep = '';
  bool    _done         = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await sl<BookCategoryRepository>()
          .fetchCategories(visibleOnly: true);
      if (mounted) {
        setState(() {
          _categories = cats;
          _categoriesLoading = false;
        });
      }
    } catch (_) {
      // Fallback: build BookCategory stubs from the hardcoded constants
      if (mounted) {
        setState(() {
          _categories = AppConstants.bookCategories
              .asMap()
              .entries
              .map((e) => BookCategory(
                    id: e.value,
                    slug: e.value,
                    nameAr: e.value,
                    sortOrder: e.key,
                    createdAt: DateTime.now(),
                  ))
              .toList();
          _categoriesLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleAr.dispose(); _titleCop.dispose(); _titleEl.dispose();
    _descAr.dispose();  _tags.dispose();
    super.dispose();
  }

  // ── Pick PDF ─────────────────────────────────────────────────────────────

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
      _pdfSizeMb = (f.size) / (1024 * 1024);
      if (kIsWeb) {
        _pdfBytes = f.bytes;
        _pdfFile  = null;
      } else {
        _pdfFile  = File(f.path!);
        _pdfBytes = null;
      }
    });
  }

  // ── Pick cover ───────────────────────────────────────────────────────────

  Future<void> _pickCover() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, maxHeight: 1200,
      imageQuality: 85,
    );
    if (img == null) return;
    if (kIsWeb) {
      final bytes = await img.readAsBytes();
      setState(() {
        _coverBytes = bytes;
        _coverFile  = null;
        _coverName  = img.name;
      });
    } else {
      setState(() {
        _coverFile  = File(img.path);
        _coverBytes = null;
        _coverName  = img.name;
      });
    }
  }

  // ── Upload ───────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    setState(() { _uploading = true; _progressStep = 'Preparing…'; });

    final authState = context.read<AuthCubit>().state;
    final repo      = sl<BooksRepository>();
    final notifSvc  = sl<NotificationService>();

    try {
      final book = await repo.addBook(
        pdfFile:        _pdfFile,
        pdfBytes:       _pdfBytes,
        pdfName:        _pdfName ?? 'book.pdf',
        coverImageFile: _coverFile,
        coverImageBytes: _coverBytes,
        coverImageName: _coverName ?? 'cover.jpg',
        titleAr:       _titleAr.text.trim(),
        titleCop:      _titleCop.text.trim(),
        titleEl:       _titleEl.text.trim(),
        descriptionAr: _descAr.text.trim(),
        category:      _category,
        addedByUid:    authState.user?.uid ?? '',
        tags: _tags.text.isNotEmpty
            ? _tags.text.split(',').map((t) => t.trim()).toList()
            : [],
        onProgress: (step, pct) {
          setState(() {
            _progressStep = step;
            if (step.contains('PDF'))   _pdfProgress   = pct;
            if (step.contains('cover')) _coverProgress = pct;
            if (step.contains('data'))  _dbProgress    = pct;
          });
        },
      );

      setState(() { _dbProgress = 1.0; });

      // Send push notification
      if (_sendNotif) {
        setState(() => _progressStep = 'Sending push notification…');
        await notifSvc.sendNewBookNotification(
          book: book,
          fcmTokens: const [],
          topic: AppConstants.newBooksTopic,
        );
      }

      setState(() { _done = true; _progressStep = 'Done!'; });

    } catch (e) {
      setState(() { _uploading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e',
              style: const TextStyle(fontFamily: 'Scheherazade')),
          backgroundColor: EkklisiaColors.maroon,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _Stepper(current: _step),
        const SizedBox(height: 24),
        if (_step == 0) _filesStep(),
        if (_step == 1) _metadataStep(),
        if (_step == 2) _reviewStep(),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // STEP 0 — FILES
  // ════════════════════════════════════════════════════════════════════════
  Widget _filesStep() {
    return Column(children: [
      // PDF drop zone
      _DropZone(
        icon: Icons.picture_as_pdf_outlined,
        title: 'Select PDF Book',
        titleAr: 'اختر ملف PDF',
        subtitle: 'Tap to browse — Max 100MB',
        hasFile: _pdfFile != null || _pdfBytes != null,
        fileName: _pdfName,
        fileInfo: _pdfSizeMb != null
            ? '${_pdfSizeMb!.toStringAsFixed(2)} MB'
            : null,
        borderColor: (_pdfFile != null || _pdfBytes != null)
            ? EkklisiaColors.tealMid
            : EkklisiaColors.goldBorder,
        onTap: _pickPdf,
      ),
      const SizedBox(height: 16),

      // Cover image
      _DropZone(
        icon: Icons.image_outlined,
        title: 'Cover Image',
        titleAr: 'صورة الغلاف (اختياري)',
        subtitle: 'JPEG / PNG — 280×400 px recommended',
        hasFile: _coverFile != null || _coverBytes != null,
        fileName: (_coverFile != null || _coverBytes != null)
            ? 'Cover selected'
            : null,
        borderColor: (_coverFile != null || _coverBytes != null)
            ? EkklisiaColors.tealMid
            : EkklisiaColors.goldBorder,
        leadingWidget: (_coverFile != null || _coverBytes != null)
            ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: kIsWeb
                ? Image.memory(_coverBytes!,
                    width: 40, height: 56, fit: BoxFit.cover)
                : Image.file(_coverFile!,
                    width: 40, height: 56, fit: BoxFit.cover))
            : null,
        onTap: _pickCover,
      ),
      const SizedBox(height: 28),

      _StepNavRow(
        onNext: (_pdfFile != null || _pdfBytes != null)
            ? () => setState(() => _step = 1)
            : null,
        nextLabel: 'Continue',
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════
  // STEP 1 — METADATA
  // ════════════════════════════════════════════════════════════════════════
  Widget _metadataStep() {
    return Form(
      key: _formKey,
      child: Column(children: [
        // Titles card
        _AdminCard(
          title: 'Book Titles',
          titleAr: 'عناوين الكتاب',
          child: Column(children: [
            _ArabicField(
              controller: _titleAr,
              label: 'Arabic Title',
              labelAr: 'العنوان بالعربية *',
              hint: 'أدخل عنوان الكتاب',
              required: true,
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _AdminField(
                controller: _titleCop,
                label: 'Coptic',
                hint: 'Ⲡⲓϫⲱⲙ...',
              )),
              const SizedBox(width: 12),
              Expanded(child: _AdminField(
                controller: _titleEl,
                label: 'Greek',
                hint: 'Τίτλος...',
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Category
        _AdminCard(
          title: 'Category & Tags',
          titleAr: 'التصنيف والوسوم',
          child: Column(children: [
            _label('Category *'),
            const SizedBox(height: 6),
            _categoriesLoading
                ? const SizedBox(
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EkklisiaColors.gold),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: _category.isNotEmpty &&
                            _categories.any((c) => c.slug == _category)
                        ? _category
                        : null,
                    dropdownColor: EkklisiaColors.bgElevated,
                    style: const TextStyle(
                        color: EkklisiaColors.textPrimary, fontSize: 14),
                    decoration: _inputDec(hint: 'Select a category'),
                    items: {for (final c in _categories) c.slug: c}
                        .values
                        .map((c) => DropdownMenuItem(
                              value: c.slug,
                              child: Text(
                                c.nameAr.isNotEmpty ? c.nameAr : c.slug,
                                style: const TextStyle(
                                    fontFamily: 'Scheherazade',
                                    color: EkklisiaColors.textPrimary),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? ''),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
            const SizedBox(height: 14),
            _ArabicField(
              controller: _tags,
              label: 'Tags (comma-separated)',
              labelAr: 'الوسوم',
              hint: 'قداس، صلاة، طقس',
              required: false,
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Description
        _AdminCard(
          title: 'Description',
          titleAr: 'الوصف',
          child: _ArabicField(
            controller: _descAr,
            label: 'Arabic Description',
            labelAr: 'الوصف بالعربية',
            hint: 'أدخل وصف الكتاب…',
            maxLines: 4,
            required: false,
          ),
        ),
        const SizedBox(height: 16),

        // Publish settings
        _AdminCard(
          title: 'Publish Settings',
          titleAr: 'إعدادات النشر',
          child: Column(children: [
            _ToggleRow(
              label:   'Publish Immediately',
              labelAr: 'نشر فوراً',
              sub:     'Visible to all users right after upload',
              value:   _publishNow,
              onChange:(v) => setState(() => _publishNow = v),
            ),
            const Divider(height: 20, color: EkklisiaColors.goldBorder),
            _ToggleRow(
              label:   'Send Push Notification',
              labelAr: 'إرسال إشعار',
              sub:     'Notify all devices via Supabase edge function',
              value:   _sendNotif,
              onChange:(v) => setState(() => _sendNotif = v),
            ),
          ]),
        ),
        const SizedBox(height: 28),

        _StepNavRow(
          onBack: () => setState(() => _step = 0),
          onNext: () {
            if (_formKey.currentState?.validate() ?? false) {
              setState(() => _step = 2);
            }
          },
          nextLabel: 'Review',
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // STEP 2 — REVIEW
  // ════════════════════════════════════════════════════════════════════════
  Widget _reviewStep() {
    if (_uploading || _done) return _uploadProgress();

    return Column(children: [
      _AdminCard(
        title: 'Upload Summary',
        titleAr: 'ملخص الرفع',
        child: Column(children: [
          _SummaryRow('PDF File',     _pdfName ?? '—'),
          _SummaryRow('Size',         '${_pdfSizeMb?.toStringAsFixed(2) ?? '—'} MB'),
          _SummaryRow('Cover',        (_coverFile != null || _coverBytes != null) ? 'Selected' : 'None'),
          _SummaryRow('Arabic Title', _titleAr.text, rtl: true),
          _SummaryRow('Category',     _category),
          _SummaryRow('Publish',      _publishNow ? 'Immediately' : 'Draft'),
          _SummaryRow('Notification', _sendNotif ? 'Yes — push to all' : 'No'),
        ]),
      ),
      const SizedBox(height: 16),

      if (_sendNotif)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EkklisiaColors.goldSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: EkklisiaColors.goldBorder, width: 0.5),
          ),
          child: const Row(children: [
            Icon(Icons.notifications_active_outlined,
                size: 18, color: EkklisiaColors.gold),
            SizedBox(width: 10),
            Expanded(child: Text(
              'A push notification will be sent to all registered devices '
                  'via the Supabase send-notifications edge function.',
              style: TextStyle(
                  color: EkklisiaColors.textSecondary, fontSize: 12,
                  height: 1.5),
            )),
          ]),
        ),
      const SizedBox(height: 28),

      _StepNavRow(
        onBack: () => setState(() => _step = 1),
        onNext: _upload,
        nextLabel: 'Upload & Publish',
        nextIcon: Icons.upload,
        nextColor: EkklisiaColors.gold,
      ),
    ]);
  }

  // ── Upload Progress ───────────────────────────────────────────────────────

  Widget _uploadProgress() {
    return _AdminCard(
      title: _done ? '✓  Upload Complete' : 'Uploading…',
      titleAr: _done ? 'اكتمل الرفع' : 'جارٍ الرفع…',
      child: Column(children: [
        _ProgressBar(
            label: 'PDF → Cloudinary',
            progress: _pdfProgress, done: _pdfProgress >= 1),
        const SizedBox(height: 14),
        if (_coverFile != null || _coverBytes != null) ...[
          _ProgressBar(
              label: 'Cover → Cloudinary',
              progress: _coverProgress, done: _coverProgress >= 1),
          const SizedBox(height: 14),
        ],
        _ProgressBar(
            label: 'Metadata → Firestore',
            progress: _dbProgress, done: _dbProgress >= 1),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(_progressStep,
              key: ValueKey(_progressStep),
              style: const TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 12, fontStyle: FontStyle.italic)),
        ),
        if (_done) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(Routes.adminBooks),
              style: ElevatedButton.styleFrom(
                backgroundColor: EkklisiaColors.gold,
                foregroundColor: EkklisiaColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View All Books',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(text, style: const TextStyle(
      color: EkklisiaColors.textSecondary,
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8,
    )),
  );

  InputDecoration _inputDec({String hint = ''}) => InputDecoration(
    hintText:       hint,
    hintStyle:      const TextStyle(
        color: EkklisiaColors.textSecondary, fontSize: 13),
    filled:         true,
    fillColor:      EkklisiaColors.bgElevated,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder:  OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
          color: EkklisiaColors.goldBorder, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: EkklisiaColors.gold, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED ADMIN WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _Stepper extends StatelessWidget {
  const _Stepper({required this.current});
  final int current;

  static const _steps = ['Select Files', 'Details', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Row(children: List.generate(_steps.length * 2 - 1, (i) {
      if (i.isOdd) {
        // Connector line
        final filled = (i ~/ 2) < current;
        return Expanded(child: Container(
            height: 1,
            color: filled
                ? EkklisiaColors.gold
                : EkklisiaColors.goldBorder));
      }
      final idx  = i ~/ 2;
      final done = idx < current;
      final active = idx == current;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? EkklisiaColors.gold
                : active
                ? EkklisiaColors.goldSubtle
                : Colors.transparent,
            border: Border.all(
              color: (done || active)
                  ? EkklisiaColors.gold
                  : EkklisiaColors.goldBorder,
              width: 1.5,
            ),
          ),
          child: Center(child: done
              ? const Icon(Icons.check,
              size: 14, color: EkklisiaColors.bgDeep)
              : Text('${idx + 1}', style: TextStyle(
              color: active
                  ? EkklisiaColors.gold
                  : EkklisiaColors.textSecondary,
              fontSize: 11, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(height: 4),
        Text(_steps[idx], style: TextStyle(
          color: active
              ? EkklisiaColors.textPrimary
              : EkklisiaColors.textSecondary,
          fontSize: 9, fontWeight: FontWeight.w500,
        )),
      ]);
    }));
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
    this.fileInfo,
    this.leadingWidget,
  });
  final IconData  icon;
  final String    title;
  final String    titleAr;
  final String    subtitle;
  final bool      hasFile;
  final Color     borderColor;
  final VoidCallback onTap;
  final String?   fileName;
  final String?   fileInfo;
  final Widget?   leadingWidget;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        EkklisiaColors.bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: borderColor, width: hasFile ? 1.0 : 0.5,
              style: hasFile ? BorderStyle.solid : BorderStyle.solid),
        ),
        child: Row(children: [
          if (leadingWidget != null) ...[
            leadingWidget!,
            const SizedBox(width: 14),
          ] else ...[
            Icon(hasFile ? Icons.check_circle_outline : icon,
                size: 28,
                color: hasFile
                    ? EkklisiaColors.tealMid
                    : EkklisiaColors.goldDim),
            const SizedBox(width: 14),
          ],
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hasFile ? (fileName ?? title) : title,
                  style: TextStyle(
                      color: hasFile
                          ? EkklisiaColors.textPrimary
                          : EkklisiaColors.textSecondary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                hasFile
                    ? (fileInfo ?? 'Tap to change')
                    : subtitle,
                style: const TextStyle(
                    color: EkklisiaColors.textSecondary,
                    fontSize: 11),
              ),
              Text(titleAr, style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color: EkklisiaColors.textSecondary, fontSize: 11)),
            ],
          )),
          Icon(Icons.chevron_right,
              color: EkklisiaColors.goldDim, size: 18),
        ]),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title, required this.titleAr, required this.child});
  final String title;
  final String titleAr;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 16,
              decoration: BoxDecoration(
                  color: EkklisiaColors.gold,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              color: EkklisiaColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(titleAr, style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(
            color: EkklisiaColors.textSecondary,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(width: 6),
        Text(labelAr, style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.textSecondary, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller:    controller,
        textDirection: TextDirection.rtl,
        maxLines:      maxLines,
        style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: EkklisiaColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkklisiaColors.textSecondary, fontSize: 14),
          filled:    true,
          fillColor: EkklisiaColors.bgElevated,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: EkklisiaColors.goldBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: EkklisiaColors.gold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
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
    required this.hint});
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: EkklisiaColors.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        style: const TextStyle(
            color: EkklisiaColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              color: EkklisiaColors.textSecondary, fontSize: 12),
          filled:    true,
          fillColor: EkklisiaColors.bgElevated,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: EkklisiaColors.goldBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: EkklisiaColors.gold, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label, required this.labelAr,
    required this.sub,   required this.value,
    required this.onChange,
  });
  final String   label;
  final String   labelAr;
  final String   sub;
  final bool     value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(
                color: EkklisiaColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(labelAr, style: const TextStyle(
                fontFamily: 'Scheherazade',
                color: EkklisiaColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(
              color: EkklisiaColors.textSecondary, fontSize: 11)),
        ],
      )),
      const SizedBox(width: 16),
      GestureDetector(
        onTap: () => onChange(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 24,
          color: value
              ? EkklisiaColors.gold
              : EkklisiaColors.bgElevated,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 22 : 2, top: 3,
              child: Container(
                  width: 18, height: 18, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value
                    ? EkklisiaColors.bgDeep
                    : EkklisiaColors.textSecondary,
              )),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.rtl = false});
  final String label;
  final String value;
  final bool   rtl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(
              color: EkklisiaColors.textSecondary,
              fontSize: 11, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontFamily: rtl ? 'Scheherazade' : null,
              color: EkklisiaColors.textPrimary,
              fontSize: rtl ? 14 : 12,
            ))),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.progress,
    required this.done});
  final String label;
  final double progress;
  final bool   done;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(
            color: EkklisiaColors.textSecondary, fontSize: 12)),
        Text(
          done ? 'Done ✓' : '${(progress * 100).round()}%',
          style: TextStyle(
            color: done
                ? EkklisiaColors.tealMid
                : EkklisiaColors.gold,
            fontSize: 11, fontWeight: FontWeight.w700,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: EkklisiaColors.bgElevated,
          valueColor: AlwaysStoppedAnimation(
              done ? EkklisiaColors.tealMid : EkklisiaColors.gold),
        ),
      ),
    ]);
  }
}

class _StepNavRow extends StatelessWidget {
  const _StepNavRow({
    this.onBack,
    this.onNext,
    this.nextLabel = 'Continue',
    this.nextIcon,
    this.nextColor = EkklisiaColors.gold,
  });
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String  nextLabel;
  final IconData? nextIcon;
  final Color   nextColor;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (onBack != null) ...[
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            foregroundColor: EkklisiaColors.textSecondary,
            side: const BorderSide(
                color: EkklisiaColors.goldBorder, width: 0.5),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('← Back',
              style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onNext,
          icon: Icon(nextIcon ?? Icons.arrow_forward,
              size: 18,
              color: onNext == null
                  ? EkklisiaColors.textSecondary
                  : EkklisiaColors.bgDeep),
          label: Text(nextLabel,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: onNext == null
                ? EkklisiaColors.goldDim.withOpacity(0.4)
                : nextColor,
            foregroundColor: EkklisiaColors.bgDeep,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]);
  }
}