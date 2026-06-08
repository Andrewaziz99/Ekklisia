// lib/admin/content/book_category_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — manage book categories (add / edit / delete / reorder).
//
// List view:
//   • Drag-to-reorder
//   • Visibility toggle
//   • Edit / Delete per row
//   • "Seed Defaults" button (one-time setup)
//   • "Add Category" FAB
//
// Edit/Add form:
//   • Slug (stable key, e.g. 'bible')
//   • Name AR / Cop / El
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/models/book_category_model.dart';
import '../../data/repositories/book_category_repository.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kNavy    = EkklisiaColors.bgDeep;
const _kGold    = EkklisiaColors.gold;
const _kBorder  = EkklisiaColors.goldBorder;

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════

class BookCategoryManagerScreen extends StatefulWidget {
  const BookCategoryManagerScreen({super.key});

  @override
  State<BookCategoryManagerScreen> createState() =>
      _BookCategoryManagerScreenState();
}

enum _Mode { list, edit }

class _BookCategoryManagerScreenState
    extends State<BookCategoryManagerScreen> {
  final _repo = sl<BookCategoryRepository>();

  _Mode _mode = _Mode.list;
  BookCategory? _editing; // null → adding new

  // ── Edit-form state ─────────────────────────────────────────────────────────
  final _slugCtrl   = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _nameCopCtrl= TextEditingController();
  final _nameElCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool _saving      = false;
  bool _isVisible   = true;

  // ── Reorder buffer ──────────────────────────────────────────────────────────
  List<BookCategory>? _reorderBuffer;
  bool _reordering = false;

  @override
  void dispose() {
    _slugCtrl.dispose();
    _nameArCtrl.dispose();
    _nameCopCtrl.dispose();
    _nameElCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _openAdd() {
    _editing = null;
    _slugCtrl.clear();
    _nameArCtrl.clear();
    _nameCopCtrl.clear();
    _nameElCtrl.clear();
    _isVisible = true;
    setState(() => _mode = _Mode.edit);
  }

  void _openEdit(BookCategory cat) {
    _editing = cat;
    _slugCtrl.text   = cat.slug;
    _nameArCtrl.text = cat.nameAr;
    _nameCopCtrl.text= cat.nameCop;
    _nameElCtrl.text = cat.nameEl;
    _isVisible       = cat.isVisible;
    setState(() => _mode = _Mode.edit);
  }

  void _backToList() => setState(() { _mode = _Mode.list; _editing = null; });

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final slug    = _slugCtrl.text.trim().toLowerCase();
      final nameAr  = _nameArCtrl.text.trim();
      final nameCop = _nameCopCtrl.text.trim();
      final nameEl  = _nameElCtrl.text.trim();

      if (_editing == null) {
        // Add — put it at the end (sortOrder = current count)
        final existing = await _repo.fetchCategories();
        await _repo.addCategory(BookCategory(
          id:        '',
          slug:      slug,
          nameAr:    nameAr,
          nameCop:   nameCop,
          nameEl:    nameEl,
          sortOrder: existing.length,
          isVisible: _isVisible,
          createdAt: DateTime.now(),
        ));
      } else {
        await _repo.updateCategory(_editing!.copyWith(
          slug:      slug,
          nameAr:    nameAr,
          nameCop:   nameCop,
          nameEl:    nameEl,
          isVisible: _isVisible,
        ));
      }
      if (mounted) _backToList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _delete(BookCategory cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(cat: cat),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.deleteCategory(cat.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'),
              backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  Future<void> _seed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EkklisiaColors.bgElevated,
        title: const Text('Seed Default Categories',
            style: TextStyle(color: EkklisiaColors.goldLight, fontSize: 15)),
        content: const Text(
          'This will add the 9 default Coptic book categories to Firestore.\n\n'
          'It only runs if the collection is empty.',
          style: TextStyle(color: EkklisiaColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: EkklisiaColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seed',
                style: TextStyle(color: EkklisiaColors.gold)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final count = await _repo.seedDefaults();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count > 0
            ? 'Seeded $count default categories.'
            : 'Collection is not empty — nothing seeded.'),
        backgroundColor: EkklisiaColors.bgElevated,
      ));
    }
  }

  // ── Reorder ─────────────────────────────────────────────────────────────────

  void _onReorderStart(List<BookCategory> current) =>
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
      await _repo.reorderCategories(_reorderBuffer!);
      _reorderBuffer = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reorder failed: $e'),
              backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      body: _mode == _Mode.list ? _buildList() : _buildForm(),
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    return StreamBuilder<List<BookCategory>>(
      stream: _repo.watchCategories(),
      builder: (context, snap) {
        final categories = _reorderBuffer ??
            (snap.hasData ? snap.data! : const <BookCategory>[]);
        final loading = snap.connectionState == ConnectionState.waiting &&
            categories.isEmpty;

        return Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _Header(
              title: 'Book Categories',
              titleAr: 'تصنيفات الكتب',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seed defaults
                  _SmallBtn(
                    icon: Icons.auto_fix_high_outlined,
                    label: 'Seed Defaults',
                    onTap: _seed,
                  ),
                  const SizedBox(width: 8),
                  // Add
                  _SmallBtn(
                    icon: Icons.add,
                    label: 'Add Category',
                    onTap: _openAdd,
                    primary: true,
                  ),
                ],
              ),
            ),

            // ── Pending reorder banner ─────────────────────────────────────
            if (_reorderBuffer != null)
              _ReorderBanner(
                saving: _reordering,
                onSave: _commitReorder,
                onCancel: () => setState(() => _reorderBuffer = null),
              ),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: EkklisiaColors.gold))
                  : categories.isEmpty
                      ? _EmptyState(onSeed: _seed, onAdd: _openAdd)
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          onReorderStart: (_) =>
                              _onReorderStart(
                                  snap.data ?? categories),
                          onReorder: _onReorder,
                          onReorderEnd: (_) {},
                          itemCount: categories.length,
                          itemBuilder: (_, i) => _CategoryRow(
                            key: ValueKey(categories[i].id),
                            cat: categories[i],
                            index: i,
                            onEdit:   () => _openEdit(categories[i]),
                            onDelete: () => _delete(categories[i]),
                            onToggle: () =>
                                _repo.toggleVisibility(categories[i]),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  // ── Edit/Add form ──────────────────────────────────────────────────────────

  Widget _buildForm() {
    final isAdd = _editing == null;
    return Column(
      children: [
        // Header
        _Header(
          title: isAdd ? 'Add Category' : 'Edit Category',
          titleAr: isAdd ? 'إضافة تصنيف' : 'تعديل التصنيف',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: EkklisiaColors.textSecondary, size: 18),
            onPressed: _backToList,
          ),
          trailing: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: EkklisiaColors.gold))
              : TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check,
                      color: EkklisiaColors.gold, size: 18),
                  label: const Text('Save',
                      style: TextStyle(color: EkklisiaColors.gold)),
                ),
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Slug ──────────────────────────────────────────────────
                  _FormCard(
                    title: 'Slug (Category Key)',
                    titleAr: 'المفتاح',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A short lowercase identifier used internally (e.g. "bible", "hymns"). '
                          'Books reference this key — changing it after books are linked will break the link.',
                          style: TextStyle(
                            color: EkklisiaColors.textSecondary
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _slugCtrl,
                          label: 'Slug *',
                          hint: 'e.g. bible, prayers, liturgy',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-z0-9_\-]')),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Required';
                            if (!RegExp(r'^[a-z0-9_\-]+$').hasMatch(v.trim()))
                              return 'Only lowercase letters, digits, _ and -';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Names ─────────────────────────────────────────────────
                  _FormCard(
                    title: 'Display Names',
                    titleAr: 'أسماء العرض',
                    child: Column(
                      children: [
                        _Field(
                          controller: _nameArCtrl,
                          label: 'Arabic Name *',
                          hint: 'مثال: الإنجيل',
                          textDirection: TextDirection.rtl,
                          fontFamily: 'Scheherazade',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _nameCopCtrl,
                          label: 'Coptic Name (optional)',
                          hint: '',
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _nameElCtrl,
                          label: 'Greek Name (optional)',
                          hint: 'e.g. Βίβλος',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Visibility ────────────────────────────────────────────
                  _FormCard(
                    title: 'Visibility',
                    titleAr: 'الظهور',
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Visible to readers',
                                  style: TextStyle(
                                      color: EkklisiaColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                'Hidden categories still exist but won\'t appear in the Books Library filter.',
                                style: TextStyle(
                                    color: EkklisiaColors.textSecondary
                                        .withValues(alpha: 0.8),
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isVisible,
                          onChanged: (v) => setState(() => _isVisible = v),
                          activeColor: EkklisiaColors.gold,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save button ───────────────────────────────────────────
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EkklisiaColors.maroon,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: EkklisiaColors.gold))
                          : Text(
                              isAdd ? 'Add Category' : 'Save Changes',
                              style: const TextStyle(
                                  color: EkklisiaColors.goldLight,
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.cat,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final BookCategory cat;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.drag_handle,
                color: EkklisiaColors.textSecondary, size: 20),
          ),

          // ── Order badge ────────────────────────────────────────────────
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _kNavy,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: _kGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Slug chip ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _kBorder),
            ),
            child: Text(
              cat.slug,
              style: const TextStyle(
                  color: _kGold, fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 10),

          // ── Names ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.nameAr,
                  style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkklisiaColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cat.nameEl.isNotEmpty)
                  Text(
                    cat.nameEl,
                    style: const TextStyle(
                        color: EkklisiaColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),

          // ── Visibility toggle ──────────────────────────────────────────
          Tooltip(
            message: cat.isVisible ? 'Visible' : 'Hidden',
            child: IconButton(
              icon: Icon(
                cat.isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: cat.isVisible
                    ? EkklisiaColors.gold
                    : EkklisiaColors.textSecondary,
              ),
              onPressed: onToggle,
            ),
          ),

          // ── Edit ───────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: EkklisiaColors.textSecondary),
            onPressed: onEdit,
          ),

          // ── Delete ─────────────────────────────────────────────────────
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
// HELPERS / SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.titleAr,
    this.leading,
    this.trailing,
  });
  final String title;
  final String titleAr;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: _kNavy,
        border:
            Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
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
                    style: const TextStyle(
                        color: EkklisiaColors.goldLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(titleAr,
                    style: const TextStyle(
                      fontFamily: 'Scheherazade',
                      color: EkklisiaColors.textSecondary,
                      fontSize: 12,
                    )),
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary
              ? EkklisiaColors.maroon
              : EkklisiaColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _kGold),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: _kGold, fontSize: 11, fontWeight: FontWeight.w600)),
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
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: EkklisiaColors.maroon.withValues(alpha: 0.9),
      child: Row(
        children: [
          const Icon(Icons.swap_vert, color: EkklisiaColors.goldLight, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Drag to reorder — save to apply.',
                style: TextStyle(color: EkklisiaColors.goldLight, fontSize: 12)),
          ),
          TextButton(
            onPressed: saving ? null : onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: EkklisiaColors.textSecondary)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: EkklisiaColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EkklisiaColors.bgDeep))
                : const Text('Save Order',
                    style: TextStyle(
                        color: EkklisiaColors.bgDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSeed, required this.onAdd});
  final VoidCallback onSeed;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✦',
              style:
                  TextStyle(color: EkklisiaColors.goldDim, fontSize: 40)),
          const SizedBox(height: 12),
          const Text('No categories yet',
              style: TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Seed the 9 default Coptic categories, or add a custom one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: EkklisiaColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SmallBtn(icon: Icons.auto_fix_high_outlined,
                  label: 'Seed Defaults', onTap: onSeed),
              const SizedBox(width: 10),
              _SmallBtn(icon: Icons.add, label: 'Add Category',
                  onTap: onAdd, primary: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.cat});
  final BookCategory cat;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: EkklisiaColors.bgElevated,
      title: const Text('Delete Category',
          style: TextStyle(color: EkklisiaColors.goldLight, fontSize: 15)),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(
              color: EkklisiaColors.textSecondary, fontSize: 13, height: 1.5),
          children: [
            const TextSpan(text: 'Delete '),
            TextSpan(
              text: '"${cat.nameAr}" (${cat.slug})',
              style: const TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontWeight: FontWeight.w700),
            ),
            const TextSpan(
                text: '?\n\nBooks using this category slug will lose their '
                    'category assignment. This cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: EkklisiaColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete',
              style: TextStyle(color: Colors.red.shade400,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
                style: const TextStyle(
                    color: EkklisiaColors.goldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(width: 6),
            Text(titleAr,
                style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkklisiaColors.textSecondary,
                    fontSize: 12)),
          ]),
          const Divider(height: 14, color: EkklisiaColors.goldBorder),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.fontFamily,
    this.textDirection,
    this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? fontFamily;
  final TextDirection? textDirection;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: EkklisiaColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          textDirection: textDirection,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            color: EkklisiaColors.textPrimary,
            fontSize: 14,
            fontFamily: fontFamily,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: EkklisiaColors.textSecondary.withValues(alpha: 0.4),
                fontSize: 13),
            filled: true,
            fillColor: EkklisiaColors.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: EkklisiaColors.goldBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: EkklisiaColors.goldBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: EkklisiaColors.gold, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.red.shade700)),
          ),
        ),
      ],
    );
  }
}
