// lib/admin/content/game_manager_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS for game questions.
//
// Layout:
//   • Tab bar: Guess Who | MCQ
//   • Each tab: streamed list of questions
//   • FAB → _GameFormScreen (add / edit)
//   • Image upload via FilePicker → Cloudinary covers bucket
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/game_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../shared/widgets/cached_image.dart';
import '../utils/admin_colors.dart';
// TEMPORARY — see mcq_seed_data.dart header. Remove this import + the
// "Seed Questions" button below once the one-time bulk seed has been run.
import 'mcq_seed_data.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
// Fixed brand navy for the header banner — intentionally the same in both
// themes (matches the app-wide header treatment elsewhere).
const _kNavy    = Color(0xFF1B2A4A);
// (was: hardcoded-dark _kGold / _kBg / _kBgDeep / _kText / _kTextSub aliases
// — replaced with ac.gold / ac.bgPrimary / ac.bgDeep / ac.textPrimary /
// ac.textSecondary at each call site so this screen follows the app theme)

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class GameManagerScreen extends StatelessWidget {
  const GameManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ac.bgPrimary,
        appBar: AppBar(
          backgroundColor: ac.bgDeep,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Game Questions',
                  style: TextStyle(
                      color: ac.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              Text('الألعاب • Παιχνίδια',
                  style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: ac.textSecondary,
                      fontSize: 11)),
            ],
          ),
          // TEMPORARY — one-time bulk seeder for the researched Coptic MCQ
          // trivia set. Remove this action + the import above +
          // mcq_seed_data.dart once the seed has been run successfully.
          actions: [
            IconButton(
              tooltip: 'Seed MCQ Questions (one-time)',
              icon: Icon(Icons.cloud_upload_outlined, color: ac.gold),
              onPressed: () => _confirmAndSeedMcq(context),
            ),
          ],
          bottom: TabBar(
            labelColor: ac.gold,
            unselectedLabelColor: ac.textSecondary,
            indicatorColor: ac.gold,
            indicatorWeight: 2,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_retouching_natural_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Guess Who', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('MCQ Quiz', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QuestionList(type: GameType.guessWho),
            _QuestionList(type: GameType.mcq),
          ],
        ),
        floatingActionButton: _AddFab(),
      ),
    );
  }
}

// ── TEMPORARY: one-time MCQ bulk seeder ─────────────────────────────────────
// See mcq_seed_data.dart header — delete this section (and the import + the
// AppBar action above) once the seed has been run successfully.

Future<void> _confirmAndSeedMcq(BuildContext context) async {
  final ac = AdminC(Theme.of(context).brightness);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: ac.bgDeep,
      title: Text('Seed ${mcqSeedQuestions.length} MCQ Questions?',
          style: TextStyle(color: ac.textPrimary, fontSize: 14)),
      content: Text(
        'This adds ${mcqSeedQuestions.length} researched Coptic Orthodox '
        'trivia questions (Bible, Liturgy & Agbeya, Saints, Church History) '
        'to the MCQ tab, in Arabic and Greek. Safe to run once — running it '
        'again will add duplicates.',
        style: TextStyle(color: ac.textSecondary, fontSize: 12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: Text('Cancel', style: TextStyle(color: ac.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: const Text('Seed Now'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final repo = sl<GameRepository>();
  int done = 0;
  int failed = 0;
  final total = mcqSeedQuestions.length;

  final progressNotifier = ValueNotifier<int>(0);

  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: ac.bgDeep,
      content: ValueListenableBuilder<int>(
        valueListenable: progressNotifier,
        builder: (_, count, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 14),
            Text('Seeding $count / $total…',
                style: TextStyle(color: ac.textPrimary, fontSize: 13)),
          ],
        ),
      ),
    ),
  );

  for (final q in mcqSeedQuestions) {
    try {
      await repo.add(GameQuestion(
        id: '',
        type: GameType.mcq,
        questionAr: q.qAr,
        questionEl: q.qEl,
        imageUrl: '',
        cloudinaryImageId: '',
        choices: List.generate(
          4,
          (i) => GameChoice(textAr: q.choicesAr[i], textEl: q.choicesEl[i]),
        ),
        correctIndex: q.correct,
        category: q.category,
        isVisible: true,
        sortOrder: 0,
        createdAt: DateTime.now(),
      ));
      done++;
    } catch (_) {
      failed++;
    }
    progressNotifier.value = done + failed;
  }

  if (context.mounted) Navigator.pop(context); // close progress dialog
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Seeded $done MCQ questions successfully.'
              : 'Seeded $done questions, $failed failed.',
        ),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final type = controller.index == 0
            ? GameType.guessWho
            : GameType.mcq;
        return FloatingActionButton.extended(
          heroTag: 'game_add_fab',
          backgroundColor: _kNavy,
          foregroundColor: ac.gold,
          icon: const Icon(Icons.add),
          label: Text(
            type == GameType.guessWho ? 'Add Guess Who' : 'Add MCQ',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _GameFormScreen(type: type),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// QUESTION LIST
// ═════════════════════════════════════════════════════════════════════════════

class _QuestionList extends StatelessWidget {
  const _QuestionList({required this.type});
  final GameType type;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final repo = sl<GameRepository>();

    return StreamBuilder<List<GameQuestion>>(
      stream: repo.watchAll(type: type),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
              strokeWidth: 2,
            ),
          );
        }
        final questions = snap.data ?? [];
        if (questions.isEmpty) {
          return _EmptyState(type: type);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: questions.length,
          itemBuilder: (context, i) =>
              _QuestionTile(question: questions[i]),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.type});
  final GameType type;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == GameType.guessWho
                ? Icons.face_retouching_natural_outlined
                : Icons.quiz_outlined,
            color: ac.gold.withValues(alpha: 0.3),
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            type == GameType.guessWho
                ? 'No "Guess Who" questions yet'
                : 'No MCQ questions yet',
            style: TextStyle(
                color: ac.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add one',
            style: TextStyle(color: ac.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Question tile ─────────────────────────────────────────────────────────────

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});
  final GameQuestion question;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final repo         = sl<GameRepository>();
    final correctChoice = question.correctChoice;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),

        // ── Leading: image thumb or icon ─────────────────────────────────
        leading: question.imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedImage(
                  url: question.imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: const _FallbackIcon(type: GameType.guessWho),
                ),
              )
            : _FallbackIcon(type: question.type),

        // ── Title: question text ─────────────────────────────────────────
        title: Text(
          question.questionAr.isNotEmpty
              ? question.questionAr
              : (question.questionEl.isNotEmpty
                  ? question.questionEl
                  : '(no question text)'),
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: ac.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // ── Subtitle: correct answer + category ──────────────────────────
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (correctChoice != null)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF3A8C5A), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    correctChoice.textAr.isNotEmpty
                        ? correctChoice.textAr
                        : correctChoice.textEl,
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: Color(0xFF3A8C5A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            if (question.category.isNotEmpty)
              Text(
                question.category,
                style: TextStyle(
                    color: ac.textSecondary, fontSize: 10),
              ),
          ],
        ),

        // ── Trailing: visibility + actions ──────────────────────────────
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Visibility toggle
            GestureDetector(
              onTap: () => repo.toggleVisibility(question),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: question.isVisible
                      ? ac.gold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ac.goldBorder, width: 0.5),
                ),
                child: Icon(
                  question.isVisible
                      ? Icons.visibility
                      : Icons.visibility_off_outlined,
                  size: 14,
                  color: question.isVisible ? ac.gold : ac.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Edit
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _GameFormScreen(
                    type: question.type,
                    editing: question,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ac.goldBorder, width: 0.5),
                ),
                child: Icon(Icons.edit_outlined,
                    size: 14, color: ac.textSecondary),
              ),
            ),
            const SizedBox(width: 6),

            // Delete
            GestureDetector(
              onTap: () => _confirmDelete(context, repo),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ac.goldBorder, width: 0.5),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 14, color: Color(0xFF8B3535)),
              ),
            ),
          ],
        ),

        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _GameFormScreen(
              type: question.type,
              editing: question,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, GameRepository repo) async {
    final ac = AdminC(Theme.of(context).brightness);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ac.bgDeep,
        title: Text('Delete Question?',
            style: TextStyle(color: ac.textPrimary, fontSize: 14)),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(color: ac.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel',
                style: TextStyle(color: ac.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFB03535))),
          ),
        ],
      ),
    );
    if (confirmed == true) await repo.delete(question.id);
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.type});
  final GameType type;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        type == GameType.guessWho
            ? Icons.face_retouching_natural_outlined
            : Icons.quiz_outlined,
        color: ac.gold.withValues(alpha: 0.5),
        size: 24,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FORM SCREEN  (add / edit)
// ═════════════════════════════════════════════════════════════════════════════

class _GameFormScreen extends StatefulWidget {
  const _GameFormScreen({required this.type, this.editing});
  final GameType     type;
  final GameQuestion? editing;

  @override
  State<_GameFormScreen> createState() => _GameFormScreenState();
}

class _GameFormScreenState extends State<_GameFormScreen> {
  // Controllers
  late final TextEditingController _questionArCtrl;
  late final TextEditingController _questionElCtrl;
  late final TextEditingController _categoryCtrl;
  late final List<TextEditingController> _choiceArCtrls;
  late final List<TextEditingController> _choiceElCtrls;

  int     _correctIndex = 0;
  bool    _isVisible    = true;
  bool    _isSaving     = false;
  String  _saveError    = '';

  // Image state
  File?      _imageFile;
  Uint8List? _imageBytes;
  String?    _imageFileName;
  String     _imageUrl           = '';
  String     _cloudinaryImageId  = '';
  double?    _imageUploadProgress;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final q = widget.editing;
    _questionArCtrl = TextEditingController(text: q?.questionAr ?? '');
    _questionElCtrl = TextEditingController(text: q?.questionEl ?? '');
    _categoryCtrl   = TextEditingController(text: q?.category   ?? '');
    _correctIndex   = q?.correctIndex ?? 0;
    _isVisible      = q?.isVisible    ?? true;
    _imageUrl           = q?.imageUrl          ?? '';
    _cloudinaryImageId  = q?.cloudinaryImageId ?? '';

    // Initialise 4 choice controllers
    _choiceArCtrls = List.generate(4, (i) {
      final text = (q != null && i < q.choices.length)
          ? q.choices[i].textAr
          : '';
      return TextEditingController(text: text);
    });
    _choiceElCtrls = List.generate(4, (i) {
      final text = (q != null && i < q.choices.length)
          ? q.choices[i].textEl
          : '';
      return TextEditingController(text: text);
    });
  }

  @override
  void dispose() {
    _questionArCtrl.dispose();
    _questionElCtrl.dispose();
    _categoryCtrl.dispose();
    for (final c in [..._choiceArCtrls, ..._choiceElCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Image picker ─────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _imageFileName = file.name;
      if (kIsWeb) {
        _imageBytes = file.bytes;
        _imageFile  = null;
      } else {
        _imageFile  = File(file.path!);
        _imageBytes = null;
      }
      // Clear existing URL so we re-upload
      _imageUrl          = '';
      _cloudinaryImageId = '';
    });
  }

  Future<void> _uploadImageIfNeeded() async {
    if (_imageFile == null && _imageBytes == null) return;
    final cloudinary = sl<CloudinaryDataSource>();
    setState(() => _imageUploadProgress = 0);
    try {
      CloudinaryUploadResult result;
      if (kIsWeb && _imageBytes != null) {
        result = await cloudinary.uploadCoverImageBytes(
          bytes:    _imageBytes!,
          fileName: _imageFileName ?? 'game_image.jpg',
          folder:   'Ekklisia/game_questions',
          onProgress: (p) =>
              setState(() => _imageUploadProgress = p),
        );
      } else {
        result = await cloudinary.uploadCoverImage(
          imageFile: _imageFile!,
          folder:    'Ekklisia/game_questions',
          onProgress: (p) =>
              setState(() => _imageUploadProgress = p),
        );
      }
      setState(() {
        _imageUrl          = result.secureUrl;
        _cloudinaryImageId = result.publicId;
        _imageUploadProgress = null;
        _imageFile   = null;
        _imageBytes  = null;
      });
    } catch (e) {
      setState(() => _imageUploadProgress = null);
      rethrow;
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Validate
    final questionText = _questionArCtrl.text.trim();
    if (questionText.isEmpty) {
      setState(() => _saveError = 'Question text (AR) is required.');
      return;
    }

    // For Guess Who, image is required (either existing or pending)
    final hasImage = _imageUrl.isNotEmpty ||
        _imageFile != null ||
        _imageBytes != null;
    if (widget.type == GameType.guessWho && !hasImage) {
      setState(() => _saveError =
          'An image is required for "Guess Who" questions.');
      return;
    }

    // At least A choices must have text
    final choices = List.generate(4, (i) => GameChoice(
          textAr: _choiceArCtrls[i].text.trim(),
          textEl: _choiceElCtrls[i].text.trim(),
        ));
    if (choices.any((c) => c.textAr.isEmpty && c.textEl.isEmpty)) {
      setState(() => _saveError = 'All 4 choices must have at least one language filled.');
      return;
    }
    if (_correctIndex < 0 || _correctIndex >= 4) {
      setState(() => _saveError = 'Select a correct answer.');
      return;
    }

    setState(() { _isSaving = true; _saveError = ''; });

    try {
      // Upload image if a new file was picked
      if (_imageFile != null || _imageBytes != null) {
        await _uploadImageIfNeeded();
      }

      final repo = sl<GameRepository>();

      if (_isEdit) {
        await repo.update(widget.editing!.copyWith(
          questionAr:        _questionArCtrl.text.trim(),
          questionEl:        _questionElCtrl.text.trim(),
          imageUrl:          _imageUrl,
          cloudinaryImageId: _cloudinaryImageId,
          choices:           choices,
          correctIndex:      _correctIndex,
          category:          _categoryCtrl.text.trim(),
          isVisible:         _isVisible,
        ));
      } else {
        await repo.add(GameQuestion(
          id:                '',
          type:              widget.type,
          questionAr:        _questionArCtrl.text.trim(),
          questionEl:        _questionElCtrl.text.trim(),
          imageUrl:          _imageUrl,
          cloudinaryImageId: _cloudinaryImageId,
          choices:           choices,
          correctIndex:      _correctIndex,
          category:          _categoryCtrl.text.trim(),
          isVisible:         _isVisible,
          sortOrder:         0,
          createdAt:         DateTime.now(),
        ));
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saveError = e.toString();
        _isSaving  = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final typeLabel = widget.type == GameType.guessWho
        ? 'Guess Who — من هو؟'
        : 'MCQ — اختبار';

    return Scaffold(
      backgroundColor: ac.bgPrimary,
      appBar: AppBar(
        backgroundColor: ac.bgDeep,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit Question' : 'New Question',
              style: TextStyle(
                  color: ac.gold, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(typeLabel,
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          if (_isSaving)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(ac.gold),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Error banner
          if (_saveError.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8C2B2B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF8C2B2B).withValues(alpha: 0.4)),
              ),
              child: Text(_saveError,
                  style: TextStyle(
                      color: Color(0xFFE57373), fontSize: 12)),
            ),

          // ── Image ──────────────────────────────────────────────────────
          _FormCard(
            label: widget.type == GameType.guessWho
                ? 'Question Image (Required)'
                : 'Image (Optional)',
            child: Column(
              children: [
                if (_imageUrl.isNotEmpty && _imageFile == null && _imageBytes == null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedImage(
                      url: _imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (_imageFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _imageFile!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (_imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imageBytes!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_imageUploadProgress != null)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _imageUploadProgress,
                        backgroundColor:
                            ac.gold.withValues(alpha: 0.15),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(ac.gold),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ac.gold,
                    side: BorderSide(
                        color: ac.gold.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(
                    _imageUrl.isNotEmpty ||
                            _imageFile != null ||
                            _imageBytes != null
                        ? 'Change Image'
                        : 'Pick Image',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: _pickImage,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Question Text ─────────────────────────────────────────────
          _FormCard(
            label: 'Question Text',
            child: Column(
              children: [
                _Field(
                  controller: _questionArCtrl,
                  label: 'Arabic (AR) *',
                  hint: widget.type == GameType.guessWho
                      ? 'من هو هذا الشخص؟'
                      : 'اكتب السؤال هنا',
                  textDirection: TextDirection.rtl,
                  fontFamily: 'Scheherazade',
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _questionElCtrl,
                  label: 'Greek (EL)',
                  hint: widget.type == GameType.guessWho
                      ? 'Ποιος είναι αυτό το πρόσωπο;'
                      : 'Γράψε την ερώτηση εδώ',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Choices ───────────────────────────────────────────────────
          _FormCard(
            label: 'Answer Choices  (select correct ✓)',
            child: Column(
              children: List.generate(4, (i) {
                final isCorrect = _correctIndex == i;
                final letter = String.fromCharCode(65 + i); // A-D
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFF2E7D52).withValues(alpha: 0.1)
                        : ac.bgDeep.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? Color(0xFF2E7D52)
                          : ac.goldBorder,
                      width: isCorrect ? 1.2 : 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: letter badge + "Mark correct"
                      Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCorrect
                                  ? Color(0xFF2E7D52)
                                  : ac.bgDeep,
                              border: Border.all(
                                  color: isCorrect
                                      ? Color(0xFF2E7D52)
                                      : ac.goldBorder),
                            ),
                            child: Center(
                              child: Text(letter,
                                  style: TextStyle(
                                    color: isCorrect
                                        ? Colors.white
                                        : ac.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Choice',
                              style: TextStyle(
                                  color: ac.textSecondary,
                                  fontSize: 11)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _correctIndex = i),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isCorrect
                                      ? const Color(0xFF2E7D52)
                                      : ac.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCorrect ? 'Correct ✓' : 'Mark correct',
                                  style: TextStyle(
                                    color: isCorrect
                                        ? const Color(0xFF2E7D52)
                                        : ac.textSecondary,
                                    fontSize: 11,
                                    fontWeight: isCorrect
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // AR
                      _Field(
                        controller: _choiceArCtrls[i],
                        label: 'Arabic',
                        hint: 'الاختيار $letter',
                        textDirection: TextDirection.rtl,
                        fontFamily: 'Scheherazade',
                        dense: true,
                      ),
                      const SizedBox(height: 6),
                      // EL
                      _Field(
                        controller: _choiceElCtrls[i],
                        label: 'Greek',
                        hint: 'Επιλογή $letter',
                        dense: true,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 12),

          // ── Category + Visibility ─────────────────────────────────────
          _FormCard(
            label: 'Category & Visibility',
            child: Column(
              children: [
                _Field(
                  controller: _categoryCtrl,
                  label: 'Category (optional)',
                  hint: 'e.g. Saints, Liturgy, History',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Visible to users',
                        style: TextStyle(
                            color: ac.textPrimary, fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: _isVisible,
                      onChanged: (v) =>
                          setState(() => _isVisible = v),
                      activeColor: ac.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Save button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: ac.gold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(ac.gold),
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEdit ? 'Update Question' : 'Add Question',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form card container ───────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: ac.gold,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.textDirection = TextDirection.ltr,
    this.fontFamily,
    this.dense = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String  label;
  final String? hint;
  final TextDirection textDirection;
  final String? fontFamily;
  final bool    dense;
  final int     maxLines;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: ac.textSecondary, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          textDirection: textDirection,
          maxLines: maxLines,
          style: TextStyle(
            fontFamily: fontFamily,
            color: ac.textPrimary,
            fontSize: dense ? 13 : 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: fontFamily,
              color: ac.textSecondary.withValues(alpha: 0.5),
              fontSize: dense ? 12 : 13,
            ),
            filled: true,
            fillColor: ac.bgPrimary,
            isDense: dense,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: dense ? 8 : 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: ac.goldBorder, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: ac.goldBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: ac.gold, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
