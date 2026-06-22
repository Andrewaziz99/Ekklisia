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
//   • Name AR / Cop / El
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/models/book_category_model.dart';
import '../../data/repositories/book_category_repository.dart';
import '../utils/admin_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kNavy = EkklisiaColors.darkBgDeep;
const _kGold = EkklisiaColors.darkGold;

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

class _BookCategoryManagerScreenState extends State<BookCategoryManagerScreen> {
  final _repo = sl<BookCategoryRepository>();

  _Mode _mode = _Mode.list;
  BookCategory? _editing; // null → adding new

  // ── Edit-form state ─────────────────────────────────────────────────────────
  final _nameArCtrl = TextEditingController();
  final _nameCopCtrl = TextEditingController();
  final _nameElCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _isVisible = true;

  // ── Reorder buffer ──────────────────────────────────────────────────────────
  List<BookCategory>? _reorderBuffer;
  bool _reordering = false;

  @override
  void dispose() {
    _nameArCtrl.dispose();
    _nameCopCtrl.dispose();
    _nameElCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _openAdd() {
    _editing = null;
    _nameArCtrl.clear();
    _nameCopCtrl.clear();
    _nameElCtrl.clear();
    _isVisible = true;
    setState(() => _mode = _Mode.edit);
  }

  void _openEdit(BookCategory cat) {
    _editing = cat;
    _nameArCtrl.text = cat.nameAr;
    _nameCopCtrl.text = cat.nameCop;
    _nameElCtrl.text = cat.nameEl;
    _isVisible = cat.isVisible;
    setState(() => _mode = _Mode.edit);
  }

  void _backToList() => setState(() {
    _mode = _Mode.list;
    _editing = null;
  });

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final nameAr = _nameArCtrl.text.trim();
      final nameCop = _nameCopCtrl.text.trim();
      final nameEl = _nameElCtrl.text.trim();

      if (_editing == null) {
        // Add — put it at the end (sortOrder = current count)
        final existing = await _repo.fetchCategories();
        await _repo.addCategory(
          BookCategory(
            id: '',
            nameAr: nameAr,
            nameCop: nameCop,
            nameEl: nameEl,
            sortOrder: existing.length,
            isVisible: _isVisible,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await _repo.updateCategory(
          _editing!.copyWith(
            nameAr: nameAr,
            nameCop: nameCop,
            nameEl: nameEl,
            isVisible: _isVisible,
          ),
        );
      }
      if (mounted) _backToList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade800,
          ),
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
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  Future<void> _seed() async {
    final ac = AdminC(Theme.of(context).brightness);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ac.bgElevated,
        title: Text(
          'Seed Default Categories',
          style: TextStyle(color: ac.goldLight, fontSize: 15),
        ),
        content: Text(
          'This will add the 9 default Coptic book categories to Firestore.\n\n'
          'It only runs if the collection is empty.',
          style: TextStyle(color: ac.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: ac.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Seed',
              style: TextStyle(color: ac.gold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final count = await _repo.seedDefaults();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Seeded $count default categories.'
                : 'Collection is not empty — nothing seeded.',
          ),
          backgroundColor: ac.bgElevated,
        ),
      );
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
          SnackBar(
            content: Text('Reorder failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      body: _mode == _Mode.list ? _buildList() : _buildForm(),
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    final ac = AdminC(Theme.of(context).brightness);

    return StreamBuilder<List<BookCategory>>(
      stream: _repo.watchCategories(),
      builder: (context, snap) {
        final categories =
            _reorderBuffer ??
            (snap.hasData ? snap.data! : const <BookCategory>[]);
        final loading =
            snap.connectionState == ConnectionState.waiting &&
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
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ac.gold,
                      ),
                    )
                  : categories.isEmpty
                  ? _EmptyState(onSeed: _seed, onAdd: _openAdd)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      onReorderStart: (_) =>
                          _onReorderStart(snap.data ?? categories),
                      onReorder: _onReorder,
                      onReorderEnd: (_) {},
                      itemCount: categories.length,
                      itemBuilder: (_, i) => _CategoryRow(
                        key: ValueKey(categories[i].id),
                        cat: categories[i],
                        index: i,
                        onEdit: () => _openEdit(categories[i]),
                        onDelete: () => _delete(categories[i]),
                        onToggle: () => _repo.toggleVisibility(categories[i]),
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
    final ac = AdminC(Theme.of(context).brightness);

    final isAdd = _editing == null;
    return Column(
      children: [
        // Header
        _Header(
          title: isAdd ? 'Add Category' : 'Edit Category',
          titleAr: isAdd ? 'إضافة تصنيف' : 'تعديل التصنيف',
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: ac.textSecondary,
              size: 18,
            ),
            onPressed: _backToList,
          ),
          trailing: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ac.gold,
                  ),
                )
              : TextButton.icon(
                  onPressed: _save,
                  icon: Icon(
                    Icons.check,
                    color: ac.gold,
                    size: 18,
                  ),
                  label: Text(
                    'Save',
                    style: TextStyle(color: ac.gold),
                  ),
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
                              Text(
                                'Visible to readers',
                                style: TextStyle(
                                  color: ac.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Hidden categories still exist but won\'t appear in the Books Library filter.',
                                style: TextStyle(
                                  color: ac.textSecondary
                                      .withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isVisible,
                          onChanged: (v) => setState(() => _isVisible = v),
                          activeColor: ac.gold,
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
                        backgroundColor: ac.maroon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: ac.gold,
                              ),
                            )
                          : Text(
                              isAdd ? 'Add Category' : 'Save Changes',
                              style: TextStyle(
                                color: ac.goldLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.goldBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.drag_handle,
              color: ac.textSecondary,
              size: 18,
            ),
          ),

          // ── Order badge ────────────────────────────────────────────────
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _kNavy,
              shape: BoxShape.circle,
              border: Border.all(color: ac.goldBorder),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: _kGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Names ──────────────────────────────────────────────────────
          // NOTE: the raw Firestore ID is intentionally omitted from this
          // row — it overflowed on narrow phones. It is visible in the edit
          // form if needed for debugging.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cat.nameAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cat.nameEl.isNotEmpty)
                  Text(
                    cat.nameEl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ac.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // ── Compact action buttons ─────────────────────────────────────
          // Use SizedBox-wrapped GestureDetectors instead of IconButton to
          // keep each tap-target at 36 px rather than the default 48 px.
          _RowAction(
            icon: cat.isVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: cat.isVisible
                ? ac.gold
                : ac.textSecondary,
            tooltip: cat.isVisible ? 'Visible' : 'Hidden',
            onTap: onToggle,
          ),
          _RowAction(
            icon: Icons.edit_outlined,
            color: ac.textSecondary,
            tooltip: 'Edit',
            onTap: onEdit,
          ),
          _RowAction(
            icon: Icons.delete_outline,
            color: Colors.red.shade400,
            tooltip: 'Delete',
            onTap: onDelete,
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _kNavy,
        border: Border(bottom: BorderSide(color: ac.goldBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          if (leading == null) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ac.goldLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  titleAr,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary,
                    fontSize: 12,
                  ),
                ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? ac.maroon : ac.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ac.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _kGold),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: _kGold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: ac.maroon.withValues(alpha: 0.9),
      child: Row(
        children: [
          Icon(
            Icons.swap_vert,
            color: ac.goldLight,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Drag to reorder — save to apply.',
              style: TextStyle(color: ac.goldLight, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(color: ac.textSecondary),
            ),
          ),
          SizedBox(width: 4),
          ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: saving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ac.bgDeep,
                    ),
                  )
                : Text(
                    'Save Order',
                    style: TextStyle(
                      color: ac.bgDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '✦',
            style: TextStyle(color: ac.goldDim, fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            'No categories yet',
            style: TextStyle(
              color: ac.goldLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Seed the 9 default Coptic categories, or add a custom one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ac.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SmallBtn(
                icon: Icons.auto_fix_high_outlined,
                label: 'Seed Defaults',
                onTap: onSeed,
              ),
              const SizedBox(width: 10),
              _SmallBtn(
                icon: Icons.add,
                label: 'Add Category',
                onTap: onAdd,
                primary: true,
              ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return AlertDialog(
      backgroundColor: ac.bgElevated,
      title: Text(
        'Delete Category',
        style: TextStyle(color: ac.goldLight, fontSize: 15),
      ),
      content: RichText(
        text: TextSpan(
          style: TextStyle(
            color: ac.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Delete '),
            TextSpan(
              text: '"${cat.nameAr}"',
              style: TextStyle(
                color: ac.goldLight,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(
              text:
                  '?\n\nBooks using this category will lose their '
                  'category assignment. This cannot be undone.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: ac.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Delete',
            style: TextStyle(
              color: Colors.red.shade400,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.goldBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ac.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 6),
              Text(
                titleAr,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: ac.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Divider(height: 14, color: ac.goldBorder),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ac.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          textDirection: textDirection,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            color: ac.textPrimary,
            fontSize: 14,
            fontFamily: fontFamily,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: ac.textSecondary.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            filled: true,
            fillColor: EkklisiaColors.bgPrimary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ac.goldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ac.goldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: ac.gold,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade700),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _RowAction — compact 36 × 36 icon tap target for _CategoryRow
// ════════════════════════════════════════════════════════════════════════════

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Icon(icon, size: 18, color: color)),
        ),
      ),
    );
  }
}
