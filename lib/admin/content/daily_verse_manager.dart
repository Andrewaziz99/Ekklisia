// lib/admin/content/daily_verse_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin screen for managing the Daily Bible Verse feature.
// Admins can:
//   • See all scheduled verses (list, newest first)
//   • Add a new verse for any date (or today)
//   • Edit an existing verse
//   • Toggle active/inactive
//   • Delete a verse
//
// Verses can also be loaded from a docx file — the admin copies and pastes
// the text into the form fields.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/models/daily_verse_model.dart';
import '../../data/repositories/daily_verse_repository.dart';
import '../utils/admin_colors.dart';

class DailyVerseManagerScreen extends StatefulWidget {
  const DailyVerseManagerScreen({super.key});

  @override
  State<DailyVerseManagerScreen> createState() =>
      _DailyVerseManagerScreenState();
}

class _DailyVerseManagerScreenState extends State<DailyVerseManagerScreen> {
  final _repo = sl<DailyVerseRepository>();
  List<DailyVerseModel> _verses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final verses = await _repo.fetchAllVerses();
      setState(() { _verses = verses; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openForm([DailyVerseModel? existing]) async {
    final ac = AdminC(Theme.of(context).brightness);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VerseForm(
        existing: existing,
        repo: _repo,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(DailyVerseModel v) async {
    await _repo.toggleActive(v.id, !v.isActive);
    _load();
  }

  Future<void> _resetSent(DailyVerseModel v) async {
    await _repo.resetSentDate(v.id);
    _load();
  }

  Future<void> _resetAllSent() async {
    final ac = AdminC(Theme.of(context).brightness);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ac.bgElevated,
        title: Text('Reset full cycle?',
            style: TextStyle(color: ac.goldLight)),
        content: Text(
          'This will clear the sent date on every verse so the '
          'rotation restarts from verse #1. Continue?',
          style: TextStyle(color: ac.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ac.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset All',
                style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    await _repo.resetAllSentDates();
    _load();
  }

  Future<void> _delete(DailyVerseModel v) async {
    final ac = AdminC(Theme.of(context).brightness);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ac.bgElevated,
        title: Text('Delete verse?',
            style: TextStyle(color: ac.goldLight)),
        content: Text('Delete verse #${v.order}?',
            style: TextStyle(color: ac.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ac.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.deleteVerse(v.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: ac.bgDeep,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: ac.bgMid,
              border: Border(
                  bottom:
                      BorderSide(color: ac.goldBorder, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined,
                    color: ac.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Verse',
                          style: TextStyle(
                              color: ac.goldLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text('آية اليوم — manage scheduled verses',
                          style: TextStyle(
                              fontFamily: 'Scheherazade',
                              color: ac.textSecondary,
                              fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh,
                      color: ac.textSecondary, size: 18),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt,
                      color: Colors.orangeAccent, size: 18),
                  onPressed: _resetAllSent,
                  tooltip: 'Reset full cycle',
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ac.goldSubtle,
                    foregroundColor: ac.goldLight,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color: ac.goldBorder, width: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openForm(),
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(ac.gold),
                      strokeWidth: 2,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      )
                    : _verses.isEmpty
                        ? _EmptyState()
                        : RefreshIndicator(
                            color: ac.gold,
                            backgroundColor: ac.bgMid,
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _verses.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _VerseTile(
                                verse: _verses[i],
                                onEdit: () => _openForm(_verses[i]),
                                onToggle: () => _toggleActive(_verses[i]),
                                onResetSent: () => _resetSent(_verses[i]),
                                onDelete: () => _delete(_verses[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Verse tile ────────────────────────────────────────────────────────────────

class _VerseTile extends StatelessWidget {
  const _VerseTile({
    required this.verse,
    required this.onEdit,
    required this.onToggle,
    required this.onResetSent,
    required this.onDelete,
  });

  final DailyVerseModel verse;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onResetSent;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order + status row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Order badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ac.goldSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: ac.goldBorder, width: 0.5),
                  ),
                  child: Text(
                    '#${verse.order}',
                    style: TextStyle(
                      color: ac.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sent / pending badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: verse.isSent
                        ? ac.tealMid.withOpacity(0.12)
                        : ac.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: verse.isSent
                          ? ac.tealMid.withOpacity(0.4)
                          : ac.goldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    verse.isSent ? verse.sentDate : 'PENDING',
                    style: TextStyle(
                      color: verse.isSent
                          ? ac.tealMid
                          : ac.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Active/hidden badge
                if (!verse.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ac.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: ac.goldBorder, width: 0.5),
                    ),
                    child: Text('HIDDEN',
                        style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        )),
                  ),
                Spacer(),
                // Actions
                _iconBtn(Icons.visibility_outlined, onToggle,
                    verse.isActive
                        ? ac.tealMid
                        : ac.textSecondary,
                    tooltip: verse.isActive ? 'Hide' : 'Show'),
                if (verse.isSent)
                  _iconBtn(Icons.refresh, onResetSent,
                      ac.textSecondary,
                      tooltip: 'Reset sent date'),
                _iconBtn(Icons.edit_outlined, onEdit, ac.gold,
                    tooltip: 'Edit'),
                _iconBtn(Icons.delete_outline, onDelete, Colors.redAccent,
                    tooltip: 'Delete'),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: ac.goldBorder,
              indent: 14,
              endIndent: 14),
          // Verse preview
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              verse.verseAr,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: ac.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          if (verse.referenceAr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  verse.referenceAr,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.goldDim,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, Color color,
          {String? tooltip}) =>
      IconButton(
        icon: Icon(icon, size: 18, color: color),
        onPressed: onTap,
        tooltip: tooltip,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      );
}

// ── Add / Edit form ───────────────────────────────────────────────────────────

class _VerseForm extends StatefulWidget {
  const _VerseForm({required this.repo, this.existing});
  final DailyVerseRepository repo;
  final DailyVerseModel? existing;

  @override
  State<_VerseForm> createState() => _VerseFormState();
}

class _VerseFormState extends State<_VerseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _orderCtrl;
  late final TextEditingController _verseArCtrl;
  late final TextEditingController _refArCtrl;
  late final TextEditingController _verseElCtrl;
  late final TextEditingController _refElCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _orderCtrl   = TextEditingController(text: e != null ? '${e.order}' : '');
    _verseArCtrl = TextEditingController(text: e?.verseAr     ?? '');
    _refArCtrl   = TextEditingController(text: e?.referenceAr ?? '');
    _verseElCtrl = TextEditingController(text: e?.verseEl     ?? '');
    _refElCtrl   = TextEditingController(text: e?.referenceEl ?? '');
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _verseArCtrl.dispose();
    _refArCtrl.dispose();
    _verseElCtrl.dispose();
    _refElCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final verse = DailyVerseModel(
        id:          widget.existing?.id ?? '',   // empty = Firestore generates ID
        order:       int.parse(_orderCtrl.text.trim()),
        verseAr:     _verseArCtrl.text.trim(),
        referenceAr: _refArCtrl.text.trim(),
        verseEl:     _verseElCtrl.text.trim(),
        referenceEl: _refElCtrl.text.trim(),
        isActive:    widget.existing?.isActive ?? true,
        sentDate:    widget.existing?.sentDate ?? '',
      );
      await widget.repo.saveVerse(verse);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: ac.goldBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                isEdit ? 'Edit Verse' : 'Add Daily Verse',
                style: TextStyle(
                  color: ac.goldLight,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'إضافة / تعديل آية اليوم',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: ac.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Order field
              _field(
                controller: _orderCtrl,
                label: 'Order (1 = first to send)',
                hint: '1',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Arabic verse
              _fieldLabel('Verse (Arabic) — النص العربي'),
              const SizedBox(height: 6),
              _textArea(
                controller: _verseArCtrl,
                textDir: TextDirection.rtl,
                fontFamily: 'Scheherazade',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Arabic reference
              _field(
                controller: _refArCtrl,
                label: 'Reference (Arabic) — المرجع',
                hint: 'يوحنا ٣:١٦',
                textDir: TextDirection.rtl,
                fontFamily: 'Scheherazade',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Greek verse (optional)
              _fieldLabel('Verse (Greek) — optional'),
              const SizedBox(height: 6),
              _textArea(
                controller: _verseElCtrl,
                textDir: TextDirection.ltr,
              ),
              const SizedBox(height: 14),

              // Greek reference (optional)
              _field(
                controller: _refElCtrl,
                label: 'Reference (Greek) — optional',
                hint: 'Ιωάννης 3:16',
              ),
              const SizedBox(height: 24),

              // Save button
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ac.goldSubtle,
                  foregroundColor: ac.goldLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: ac.goldBorder, width: 0.5),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              ac.goldLight),
                        ),
                      )
                    : Text(isEdit ? 'Save Changes' : 'Add Verse',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final ac = AdminC(Theme.of(context).brightness);
    return Text(
        text,
        style: TextStyle(
          color: ac.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    TextDirection textDir = TextDirection.ltr,
    String? fontFamily,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final ac = AdminC(Theme.of(context).brightness);
    return TextFormField(
        controller: controller,
        enabled: enabled,
        textDirection: textDir,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          fontFamily: fontFamily,
          color: ac.textPrimary,
          fontSize: fontFamily != null ? 16 : 14,
        ),
        decoration: ac.inputDeco(hint ?? label ?? ''),
      );
  }

  Widget _textArea({
    required TextEditingController controller,
    TextDirection textDir = TextDirection.ltr,
    String? fontFamily,
    String? Function(String?)? validator,
  }) {
    final ac = AdminC(Theme.of(context).brightness);
    return TextFormField(
        controller: controller,
        maxLines: 4,
        textDirection: textDir,
        validator: validator,
        style: TextStyle(
          fontFamily: fontFamily,
          color: ac.textPrimary,
          fontSize: fontFamily != null ? 17 : 14,
          height: 1.7,
        ),
        decoration: ac.inputDeco(''),
      );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: ac.goldBorder, width: 0.5),
              color: ac.bgMid,
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 36, color: ac.goldDim),
          ),
          SizedBox(height: 16),
          Text(
            'No verses scheduled yet',
            style: TextStyle(
                color: ac.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'لا توجد آيات مجدولة',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              color: ac.goldDim,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
