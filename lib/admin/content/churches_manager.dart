// lib/admin/content/churches_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — Churches & Priests manager.
//
// Two independent tabs, backed by two independent Firestore collections:
//   • Churches — nameAr, nameEn, mapsUrl, published toggle. No priest data
//     lives here anymore, so editing a church never touches its priests.
//   • Priests  — name, phone, image, and a church (picked from the existing
//     churches list, or free-typed text if the church isn't registered
//     yet). Editing a priest never touches the church document.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../admin_l10n.dart';
import '../../data/datasources/cloudinary/cloudinary_datasource.dart';
import '../../data/models/bishop_model.dart';
import '../../data/models/church_model.dart';
import '../../data/models/priest_model.dart';
import '../../data/repositories/bishop_repository.dart';
import '../../data/repositories/churches_repository.dart';
import '../../data/repositories/priests_repository.dart';
import '../utils/admin_colors.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kRadius = BorderRadius.all(Radius.circular(8));

enum _ScreenMode { list, edit }

// ════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ════════════════════════════════════════════════════════════════════════════

class ChurchesManagerScreen extends StatefulWidget {
  const ChurchesManagerScreen({super.key});

  @override
  State<ChurchesManagerScreen> createState() => _ChurchesManagerScreenState();
}

class _ChurchesManagerScreenState extends State<ChurchesManagerScreen> with TickerProviderStateMixin {
  final _churchesRepo = sl<ChurchesRepository>();
  final _priestsRepo = sl<PriestsRepository>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // One-time copy of any priests still embedded in old church documents
    // into the top-level 'priests' collection (see PriestsRepository).
    // Deliberately triggered here rather than at app startup: this screen
    // only opens under an authenticated admin session, which is what
    // Firestore's security rules require to write to these collections.
    _priestsRepo.migrateFromChurchesIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;

    return Column(
      children: [
        // ── Tab bar ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: ac.bgDeep,
            border: Border(bottom: ac.borderSide),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                text: l.churches,
                height: 48,
              ),
              Tab(
                text: 'Ιερείς • ${l.priests}',
                height: 48,
              ),
            ],
            labelColor: ac.gold,
            unselectedLabelColor: ac.textSecondary,
            indicatorColor: ac.gold,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Tab content ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Churches tab
              _ChurchesTab(repo: _churchesRepo),
              // Priests tab
              _PriestsTab(churchesRepo: _churchesRepo, priestsRepo: _priestsRepo),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CHURCHES TAB
// ════════════════════════════════════════════════════════════════════════════

class _ChurchesTab extends StatefulWidget {
  const _ChurchesTab({required this.repo});
  final ChurchesRepository repo;

  @override
  State<_ChurchesTab> createState() => _ChurchesTabState();
}

class _ChurchesTabState extends State<_ChurchesTab> {
  _ScreenMode _mode = _ScreenMode.list;
  ChurchModel? _editing;

  void _openEdit(ChurchModel? church) =>
      setState(() { _editing = church; _mode = _ScreenMode.edit; });

  void _backToList() =>
      setState(() { _editing = null; _mode = _ScreenMode.list; });

  @override
  Widget build(BuildContext context) {
    if (_mode == _ScreenMode.edit) {
      return _ChurchEditView(repo: widget.repo, initial: _editing, onDone: _backToList);
    }
    return _ListView(repo: widget.repo, onEdit: _openEdit);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRIESTS TAB
// ════════════════════════════════════════════════════════════════════════════

class _PriestsTab extends StatefulWidget {
  const _PriestsTab({required this.churchesRepo, required this.priestsRepo});
  final ChurchesRepository churchesRepo;
  final PriestsRepository priestsRepo;

  @override
  State<_PriestsTab> createState() => _PriestsTabState();
}

class _PriestsTabState extends State<_PriestsTab> {
  _ScreenMode _mode = _ScreenMode.list;
  PriestModel? _editing;

  void _openEdit(PriestModel? priest) =>
      setState(() { _editing = priest; _mode = _ScreenMode.edit; });

  void _backToList() =>
      setState(() { _editing = null; _mode = _ScreenMode.list; });

  @override
  Widget build(BuildContext context) {
    // Churches are only needed to power the "pick an existing church" list
    // in the priest form — a priest never writes to a church document.
    return StreamBuilder<List<ChurchModel>>(
      stream: widget.churchesRepo.watchAll(),
      builder: (context, churchSnap) {
        final churches = churchSnap.data ?? [];

        if (_mode == _ScreenMode.edit) {
          return _PriestEditView(
            repo: widget.priestsRepo,
            churches: churches,
            initial: _editing,
            onDone: _backToList,
          );
        }
        return _PriestListView(repo: widget.priestsRepo, onEdit: _openEdit);
      },
    );
  }
}

// ── Priests list ──────────────────────────────────────────────────────────────

class _PriestListView extends StatefulWidget {
  const _PriestListView({required this.repo, required this.onEdit});
  final PriestsRepository repo;
  final void Function(PriestModel?) onEdit;

  @override
  State<_PriestListView> createState() => _PriestListViewState();
}

class _PriestListViewState extends State<_PriestListView> {
  String _search = '';
  String? _deleteConfirmId;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;

    return StreamBuilder<List<PriestModel>>(
      stream: widget.repo.watchAll(),
      builder: (context, snap) {
        final priests = (snap.data ?? []).where((p) {
          final q = _search.toLowerCase();
          return q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.nameAr.contains(q) ||
              p.churchName.toLowerCase().contains(q);
        }).toList();
        final loading = snap.connectionState == ConnectionState.waiting;

        return Column(children: [
          _Toolbar(
            title: l.priests,
            count: priests.length,
            onSearch: (q) => setState(() => _search = q),
            onAdd: () => widget.onEdit(null),
          ),
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(color: ac.gold, strokeWidth: 2),
                  )
                : priests.isEmpty
                    ? _PriestsEmptyState(onAdd: () => widget.onEdit(null))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: priests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = priests[i];
                          return _PriestCard(
                            priest: p,
                            confirmingDelete: _deleteConfirmId == p.id,
                            onEdit: () => widget.onEdit(p),
                            onDeleteTap: () => setState(() => _deleteConfirmId = p.id),
                            onDeleteConfirm: () async {
                              await widget.repo.delete(p.id);
                              setState(() => _deleteConfirmId = null);
                            },
                            onDeleteCancel: () => setState(() => _deleteConfirmId = null),
                          );
                        },
                      ),
          ),
        ]);
      },
    );
  }
}

class _PriestCard extends StatelessWidget {
  const _PriestCard({
    required this.priest,
    required this.confirmingDelete,
    required this.onEdit,
    required this.onDeleteTap,
    required this.onDeleteConfirm,
    required this.onDeleteCancel,
  });

  final PriestModel priest;
  final bool confirmingDelete;
  final VoidCallback onEdit;
  final VoidCallback onDeleteTap;
  final VoidCallback onDeleteConfirm;
  final VoidCallback onDeleteCancel;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: _kRadius,
        border: Border.all(
          color: confirmingDelete ? ac.maroon.withValues(alpha: 0.6) : ac.tealMid.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: confirmingDelete
          ? _DeleteConfirmRow(
              message: l.deletePriestConfirmMsg,
              onConfirm: onDeleteConfirm,
              onCancel: onDeleteCancel,
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ac.bgMid,
                    border: Border.all(color: ac.goldBorder, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: priest.imageUrl.isNotEmpty
                      ? Image.network(
                          priest.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.person_outline, color: ac.textSecondary),
                        )
                      : Icon(Icons.person_outline, color: ac.textSecondary, size: 22),
                ),
                const SizedBox(width: 12),

                // Name + church + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        priest.name,
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (priest.nameAr.isNotEmpty)
                        Text(
                          priest.nameAr,
                          style: TextStyle(
                            color: ac.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Scheherazade',
                          ),
                        ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.church_outlined, color: ac.gold, size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            priest.churchName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: ac.gold, fontSize: 11),
                          ),
                        ),
                      ]),
                      if (priest.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          priest.phone,
                          style: TextStyle(color: ac.textSecondary, fontSize: 11),
                        ),
                      ],
                      if (!priest.isLinkedToChurch) ...[
                        const SizedBox(height: 4),
                        _Chip(label: l.unlinkedChurch, color: ac.textSecondary),
                      ],
                    ],
                  ),
                ),

                Column(mainAxisSize: MainAxisSize.min, children: [
                  _IconBtn(icon: Icons.edit_outlined, color: ac.gold, onTap: onEdit),
                  const SizedBox(height: 4),
                  _IconBtn(icon: Icons.delete_outline, color: ac.maroonMid, onTap: onDeleteTap),
                ]),
              ]),
            ),
    );
  }
}

class _PriestsEmptyState extends StatelessWidget {
  const _PriestsEmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.church_outlined, color: ac.goldBorder, size: 40),
          const SizedBox(height: 12),
          Text(l.noPriestsYet, style: TextStyle(color: ac.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: ac.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ac.gold.withValues(alpha: 0.4), width: 0.5),
              ),
              child: Text(l.addPriest, style: TextStyle(color: ac.gold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Priest edit form ─────────────────────────────────────────────────────────

class _PriestEditView extends StatefulWidget {
  const _PriestEditView({
    required this.repo,
    required this.churches,
    required this.initial,
    required this.onDone,
  });

  final PriestsRepository repo;
  final List<ChurchModel> churches;
  final PriestModel? initial;
  final VoidCallback onDone;

  @override
  State<_PriestEditView> createState() => _PriestEditViewState();
}

class _PriestEditViewState extends State<_PriestEditView> {
  final _formKey = GlobalKey<FormState>();
  final _cloudinary = sl<CloudinaryDataSource>();

  final _name = TextEditingController();
  final _nameAr = TextEditingController();
  final _phone = TextEditingController();
  final _churchName = TextEditingController();
  String? _churchId;

  String _imageUrl = '';
  File? _imgFile;
  Uint8List? _imgBytes;
  bool _uploading = false;
  double _progress = 0;

  bool _saving = false;
  String _saveError = '';

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      _name.text = p.name;
      _nameAr.text = p.nameAr;
      _phone.text = p.phone;
      _churchName.text = p.churchName;
      _churchId = p.churchId;
      _imageUrl = p.imageUrl;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAr.dispose();
    _phone.dispose();
    _churchName.dispose();
    super.dispose();
  }

  // ── Image pick + upload ───────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _imgFile = kIsWeb ? null : File(img.path);
      _imgBytes = bytes;
      _imageUrl = '';
    });
    await _uploadImage();
  }

  Future<void> _uploadImage() async {
    if (_imgFile == null && _imgBytes == null) return;
    setState(() { _uploading = true; _progress = 0; });
    try {
      final res = kIsWeb
          ? await _cloudinary.uploadCoverImageBytes(
              bytes: _imgBytes!,
              fileName: 'priest_${DateTime.now().millisecondsSinceEpoch}',
              folder: 'Ekklisia/priests',
              onProgress: (p) => setState(() => _progress = p))
          : await _cloudinary.uploadCoverImage(
              imageFile: _imgFile!,
              folder: 'Ekklisia/priests',
              onProgress: (p) => setState(() => _progress = p));
      setState(() => _imageUrl = res.secureUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() { _uploading = false; });
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = ''; });
    try {
      final priest = PriestModel(
        id: widget.initial?.id ?? '',
        name: _name.text.trim(),
        nameAr: _nameAr.text.trim(),
        phone: _phone.text.trim(),
        churchId: _churchId,
        churchName: _churchName.text.trim(),
        imageUrl: _imageUrl,
      );
      await widget.repo.save(priest);
      widget.onDone();
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    final isNew = widget.initial == null;

    return Column(children: [
      // ── Header bar ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: ac.bgDeep,
          border: Border(bottom: ac.borderSide),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: widget.onDone,
            child: Icon(Icons.arrow_back_ios_new, color: ac.gold, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isNew ? l.addPriest : l.editPriest,
              style: TextStyle(color: ac.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _saving ? ac.bgMid : ac.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ac.gold.withValues(alpha: 0.4), width: 0.5),
              ),
              child: _saving
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(color: ac.gold, strokeWidth: 2),
                    )
                  : Text(
                      l.save,
                      style: TextStyle(color: ac.gold, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ]),
      ),

      if (_saveError.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ac.maroon.withValues(alpha: 0.15),
            borderRadius: _kRadius,
            border: Border.all(color: ac.maroon.withValues(alpha: 0.4)),
          ),
          child: Text(_saveError, style: TextStyle(color: ac.maroonMid, fontSize: 12)),
        ),

      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              _FormCard(
                title: 'Ιερέας',
                titleAr: 'الكاهن',
                child: Column(children: [
                  _Field(ctrl: _name, label: l.priestName, required: true),
                  const SizedBox(height: 10),
                  _Field(ctrl: _nameAr, label: l.priestNameAr, arabic: true),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _phone,
                    label: l.priestPhone,
                    hint: '+30 210 0000000',
                    keyboardType: TextInputType.phone,
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              _FormCard(
                title: 'Εκκλησία',
                titleAr: 'الكنيسة',
                child: _ChurchPickerField(
                  nameCtrl: _churchName,
                  churches: widget.churches,
                  onChurchIdChanged: (id) => _churchId = id,
                ),
              ),
              const SizedBox(height: 12),

              _FormCard(
                title: 'Φωτογραφία',
                titleAr: 'الصورة',
                child: _PriestImagePicker(
                  imageUrl: _imageUrl,
                  localBytes: _imgBytes,
                  uploading: _uploading,
                  progress: _progress,
                  onPick: _pickImage,
                  ac: ac,
                  l: l,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ── Church picker (used inside the priest form) ─────────────────────────────
//
// A plain text field the admin can either type into directly (free text —
// no backing church record) or fill via the list icon, which opens a
// searchable sheet of already-registered churches.

class _ChurchPickerField extends StatefulWidget {
  const _ChurchPickerField({
    required this.nameCtrl,
    required this.churches,
    required this.onChurchIdChanged,
  });

  final TextEditingController nameCtrl;
  final List<ChurchModel> churches;
  final ValueChanged<String?> onChurchIdChanged;

  @override
  State<_ChurchPickerField> createState() => _ChurchPickerFieldState();
}

class _ChurchPickerFieldState extends State<_ChurchPickerField> {
  Future<void> _openPicker() async {
    // .adminL10nOnce (not .adminL10n) — this runs from an IconButton
    // callback, not a build() method, and Provider's `watch` (which
    // .adminL10n uses) asserts if called outside the widget tree's build
    // phase.
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10nOnce;
    String search = '';

    final selected = await showModalBottomSheet<ChurchModel>(
      context: context,
      backgroundColor: ac.bgElevated,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = widget.churches.where((c) {
            final q = search.toLowerCase();
            return q.isEmpty ||
                c.nameEn.toLowerCase().contains(q) ||
                c.nameAr.contains(q);
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      autofocus: true,
                      style: TextStyle(color: ac.textPrimary, fontSize: 13),
                      decoration: ac.inputDeco('${l.search} ${l.churches}…'),
                      onChanged: (v) => setSheetState(() => search = v),
                    ),
                  ),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l.noChurches,
                                style: TextStyle(color: ac.textSecondary, fontSize: 13)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                title: Text(c.nameEn, style: TextStyle(color: ac.textPrimary)),
                                subtitle: Text(c.nameAr,
                                    style: TextStyle(color: ac.textSecondary, fontFamily: 'Scheherazade')),
                                onTap: () => Navigator.of(ctx).pop(c),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (selected != null) {
      // Order matters: setting .text first fires onChanged (which clears
      // churchId as "manual typing"), then we set the real id afterward so
      // it sticks.
      widget.nameCtrl.text = selected.nameEn;
      widget.onChurchIdChanged(selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.nameCtrl,
          style: TextStyle(color: ac.textPrimary, fontSize: 13),
          decoration: ac.inputDeco(l.priestChurchField).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(Icons.list_alt_outlined, color: ac.gold, size: 18),
                  onPressed: _openPicker,
                  tooltip: l.churches,
                ),
              ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Υποχρεωτικό' : null,
          onChanged: (_) => widget.onChurchIdChanged(null),
        ),
        const SizedBox(height: 4),
        Text(l.churchPickerHint, style: TextStyle(color: ac.textSecondary, fontSize: 10)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CHURCHES LIST VIEW
// ════════════════════════════════════════════════════════════════════════════

class _ListView extends StatefulWidget {
  const _ListView({required this.repo, required this.onEdit});
  final ChurchesRepository repo;
  final void Function(ChurchModel?) onEdit;

  @override
  State<_ListView> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  String _search = '';
  String? _deleteConfirmId;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;

    return StreamBuilder<List<ChurchModel>>(
      stream: widget.repo.watchAll(),
      builder: (context, snap) {
        final churches = (snap.data ?? []).where((c) {
          final q = _search.toLowerCase();
          return q.isEmpty ||
              c.nameEn.toLowerCase().contains(q) ||
              c.nameAr.contains(q);
        }).toList();
        final loading =
            snap.connectionState == ConnectionState.waiting;

        return Column(children: [
          // ── Toolbar ───────────────────────────────────────────────────
          _Toolbar(
            title: l.churches,
            count: churches.length,
            onSearch: (q) => setState(() => _search = q),
            onAdd: () => widget.onEdit(null),
          ),

          // ── Bishop section ────────────────────────────────────────────
          _BishopAdminCard(repo: sl<BishopRepository>()),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: ac.gold,
                      strokeWidth: 2,
                    ),
                  )
                : churches.isEmpty
                    ? _EmptyState(onAdd: () => widget.onEdit(null))
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: churches.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = churches[i];
                          return _ChurchCard(
                            church: c,
                            confirmingDelete: _deleteConfirmId == c.id,
                            onEdit: () => widget.onEdit(c),
                            onToggle: () => widget.repo
                                .togglePublished(c.id, !c.isPublished),
                            onDeleteTap: () =>
                                setState(() => _deleteConfirmId = c.id),
                            onDeleteConfirm: () async {
                              await widget.repo.delete(c.id);
                              setState(() => _deleteConfirmId = null);
                            },
                            onDeleteCancel: () =>
                                setState(() => _deleteConfirmId = null),
                          );
                        },
                      ),
          ),
        ]);
      },
    );
  }
}

// ── Church card ───────────────────────────────────────────────────────────────

class _ChurchCard extends StatelessWidget {
  const _ChurchCard({
    required this.church,
    required this.confirmingDelete,
    required this.onEdit,
    required this.onToggle,
    required this.onDeleteTap,
    required this.onDeleteConfirm,
    required this.onDeleteCancel,
  });

  final ChurchModel church;
  final bool confirmingDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDeleteTap;
  final VoidCallback onDeleteConfirm;
  final VoidCallback onDeleteCancel;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: _kRadius,
        border: Border.all(
          color: confirmingDelete
              ? ac.maroon.withValues(alpha: 0.6)
              : ac.goldBorder,
          width: 0.5,
        ),
      ),
      child: confirmingDelete
          ? _DeleteConfirmRow(
              message: l.deleteChurch,
              onConfirm: onDeleteConfirm,
              onCancel: onDeleteCancel,
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                // Church icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ac.bgMid,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: ac.goldBorder, width: 0.5),
                  ),
                  child: Center(
                    child: Text('☩',
                        style: TextStyle(
                            color: ac.gold, fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),

                // Names + maps chip
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        church.nameEn,
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        church.nameAr,
                        style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Scheherazade',
                        ),
                      ),
                      if (church.mapsUrl.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Row(children: [
                          _Chip(label: '📍 maps', color: ac.gold),
                        ]),
                      ],
                    ],
                  ),
                ),

                // Status + actions
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onToggle,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: church.isPublished
                              ? ac.tealMid
                                  .withValues(alpha: 0.15)
                              : ac.bgMid,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: church.isPublished
                                ? ac.tealMid
                                : ac.goldBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          church.isPublished ? 'ΕΝΕΡΓΟ' : 'ΠΡΌΧΕΙΡΟ',
                          style: TextStyle(
                            color: church.isPublished
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
                          onTap: onEdit),
                      SizedBox(width: 4),
                      _IconBtn(
                          icon: Icons.delete_outline,
                          color: ac.maroonMid,
                          onTap: onDeleteTap),
                    ]),
                  ],
                ),
              ]),
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CHURCH EDIT VIEW
// ════════════════════════════════════════════════════════════════════════════
//
// Church-only fields — no priest data lives on the church document anymore,
// so this can never accidentally touch priests.

class _ChurchEditView extends StatefulWidget {
  const _ChurchEditView({
    required this.repo,
    required this.initial,
    required this.onDone,
  });
  final ChurchesRepository repo;
  final ChurchModel? initial;
  final VoidCallback onDone;

  @override
  State<_ChurchEditView> createState() => _ChurchEditViewState();
}

class _ChurchEditViewState extends State<_ChurchEditView> {
  final _formKey = GlobalKey<FormState>();

  final _nameEn  = TextEditingController();
  final _nameAr  = TextEditingController();
  final _mapsUrl = TextEditingController();
  bool _published = true;

  bool   _saving    = false;
  String _saveError = '';

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    if (c != null) {
      _nameEn.text   = c.nameEn;
      _nameAr.text   = c.nameAr;
      _mapsUrl.text  = c.mapsUrl;
      _published     = c.isPublished;
    }
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _mapsUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = ''; });
    try {
      final church = ChurchModel(
        id:          widget.initial?.id ?? '',
        nameEn:      _nameEn.text.trim(),
        nameAr:      _nameAr.text.trim(),
        mapsUrl:     _mapsUrl.text.trim(),
        isPublished: _published,
      );

      await widget.repo.save(church);
      widget.onDone();
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    final isNew = widget.initial == null;

    return Column(children: [
      // ── Header bar ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: ac.bgDeep,
          border: Border(bottom: ac.borderSide),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: widget.onDone,
            child: Icon(Icons.arrow_back_ios_new,
                color: ac.gold, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNew ? l.addChurch : l.editChurch,
                  style: TextStyle(
                    color: ac.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isNew)
                  Text(
                    widget.initial!.nameAr,
                    style: TextStyle(
                      color: ac.textSecondary,
                      fontFamily: 'Scheherazade',
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          // Save button
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _saving
                    ? ac.bgMid
                    : ac.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: ac.gold.withValues(alpha: 0.4),
                    width: 0.5),
              ),
              child: _saving
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: ac.gold, strokeWidth: 2),
                    )
                  : Text(
                      isNew ? 'Δημιουργία' : 'Ενημέρωση',
                      style: TextStyle(
                        color: ac.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ]),
      ),

      // ── Error banner ──────────────────────────────────────────────────
      if (_saveError.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ac.maroon.withValues(alpha: 0.15),
            borderRadius: _kRadius,
            border: Border.all(
                color: ac.maroon.withValues(alpha: 0.4)),
          ),
          child: Text(_saveError,
              style: TextStyle(
                  color: ac.maroonMid, fontSize: 12)),
        ),

      // ── Form ──────────────────────────────────────────────────────────
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [

              // ── Church names ───────────────────────────────────────
              _FormCard(
                title: 'Εκκλησία',
                titleAr: 'الكنيسة',
                child: Column(children: [
                  _Field(
                    ctrl: _nameEn,
                    label: l.churchNameEn,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _nameAr,
                    label: l.churchNameAr,
                    required: true,
                    arabic: true,
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Google Maps URL ────────────────────────────────────
              _FormCard(
                title: 'Google Maps',
                titleAr: 'خرائط Google',
                child: _Field(
                  ctrl: _mapsUrl,
                  label: l.mapsLink,
                  hint: 'https://maps.google.com/…',
                ),
              ),
              const SizedBox(height: 12),

              // ── Publish ────────────────────────────────────────────
              _FormCard(
                title: 'Ορατότητα',
                titleAr: 'الظهور',
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _published
                          ? 'Δημοσιευμένο — ορατό σε όλους'
                          : 'Πρόχειρο — ορατό μόνο σε διαχειριστές',
                      style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Switch(
                    value: _published,
                    onChanged: (v) => setState(() => _published = v),
                    activeColor: ac.tealMid,
                    inactiveThumbColor: ac.goldDim,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ── Priest image picker widget ────────────────────────────────────────────────
// (also used by the bishop card, which shares the same pick/preview/upload UI)

class _PriestImagePicker extends StatelessWidget {
  const _PriestImagePicker({
    required this.imageUrl,
    required this.localBytes,
    required this.uploading,
    required this.progress,
    required this.onPick,
    required this.ac,
    required this.l,
    this.label,
  });

  final String      imageUrl;
  final Uint8List?  localBytes;
  final bool        uploading;
  final double      progress;
  final VoidCallback onPick;
  final AdminC      ac;
  final AdminL10n   l;
  /// Override the field label. Defaults to l.priestImage.
  final String?     label;

  @override
  Widget build(BuildContext context) {
    final hasImage = localBytes != null || imageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label ?? l.priestImage,
          style: TextStyle(
              color: ac.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),

        // Preview + button row
        Row(children: [
          // Image preview circle
          GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ac.bgMid,
                border: Border.all(color: ac.goldBorder, width: 0.8),
              ),
              clipBehavior: Clip.antiAlias,
              child: uploading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(ac.gold),
                        ),
                      ),
                    )
                  : hasImage
                      ? _ImagePreview(
                          bytes: localBytes,
                          url: imageUrl,
                        )
                      : Icon(Icons.person_outline,
                          color: ac.textSecondary, size: 28),
            ),
          ),
          const SizedBox(width: 12),

          // Upload / change button
          Expanded(
            child: GestureDetector(
              onTap: uploading ? null : onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ac.bgMid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ac.goldBorder, width: 0.5),
                ),
                child: Row(children: [
                  Icon(
                    uploading
                        ? Icons.cloud_upload_outlined
                        : hasImage
                            ? Icons.edit_outlined
                            : Icons.upload_outlined,
                    color: uploading ? ac.tealMid : ac.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uploading
                          ? 'Uploading… ${(progress * 100).toStringAsFixed(0)}%'
                          : hasImage
                              ? 'Change image'
                              : 'Upload photo',
                      style: TextStyle(
                          color: uploading ? ac.tealMid : ac.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),

        // URL hint (shown once uploaded)
        if (imageUrl.isNotEmpty && !uploading) ...[
          const SizedBox(height: 4),
          Text(
            imageUrl,
            style: TextStyle(
                color: ac.textSecondary.withValues(alpha: 0.7),
                fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// Renders either local bytes or a network image
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.bytes, required this.url});
  final Uint8List? bytes;
  final String    url;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity);
    }
    if (url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.broken_image_outlined, color: Colors.white38, size: 24));
    }
    return const SizedBox.shrink();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED FORM HELPERS
// ════════════════════════════════════════════════════════════════════════════

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
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: _kRadius,
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              Text(
                title,
                style: TextStyle(
                  color: ac.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 8),
              Text(
                titleAr,
                style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 11,
                  fontFamily: 'Scheherazade',
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
            child: Divider(
                height: 1,
                color: ac.goldBorder.withValues(alpha: 0.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.required = false,
    this.arabic = false,
    this.keyboardType,
  });

  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool required;
  final bool arabic;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return TextFormField(
      controller: ctrl,
      maxLines: 1,
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      keyboardType: keyboardType,
      style: TextStyle(
        color: ac.textPrimary,
        fontSize: 13,
        fontFamily: arabic ? 'Scheherazade' : null,
      ),
      decoration: ac.inputDeco(hint ?? label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Υποχρεωτικό' : null
          : null,
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _Toolbar extends StatefulWidget {
  const _Toolbar({
    required this.title,
    required this.count,
    required this.onSearch,
    required this.onAdd,
  });
  final String title;
  final int count;
  final void Function(String) onSearch;
  final VoidCallback onAdd;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  bool _searching = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        border: Border(bottom: ac.borderSide),
      ),
      child: Row(children: [
        Expanded(
          child: _searching
              ? TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(
                      color: ac.textPrimary, fontSize: 13),
                  decoration: ac.inputDeco(
                      '${l.search} ${widget.title}…'),
                  onChanged: widget.onSearch,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        textDirection: l.dir,
                        style: TextStyle(
                          fontFamily: l.fontFam,
                          color: ac.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(
                      '${widget.count}',
                      style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(width: 8),
        _IconBtn(
          icon: _searching ? Icons.close : Icons.search,
          color: ac.textSecondary,
          onTap: () {
            setState(() => _searching = !_searching);
            if (!_searching) {
              _ctrl.clear();
              widget.onSearch('');
            }
          },
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: widget.onAdd,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ac.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: ac.gold.withValues(alpha: 0.4),
                  width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.add, color: ac.gold, size: 14),
              SizedBox(width: 4),
              Text(l.add,
                  textDirection: l.dir,
                  style: TextStyle(
                      fontFamily: l.fontFam,
                      color: ac.gold,
                      fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
              color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600)),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('☩',
                style: TextStyle(
                    color: ac.goldBorder, fontSize: 40)),
            SizedBox(height: 12),
            Text('Δεν έχουν προστεθεί εκκλησίες',
                style: TextStyle(
                    color: ac.textSecondary, fontSize: 14)),
            SizedBox(height: 4),
            Text('لا توجد كنائس حتى الآن',
                style: TextStyle(
                    color: ac.textSecondary,
                    fontFamily: 'Scheherazade',
                    fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: ac.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: ac.gold.withValues(alpha: 0.4),
                      width: 0.5),
                ),
                child: Text('Προσθήκη Πρώτης Εκκλησίας',
                    style: TextStyle(
                        color: ac.gold, fontSize: 13)),
              ),
            ),
          ],
        ),
      );
  }
}

class _DeleteConfirmRow extends StatelessWidget {
  const _DeleteConfirmRow({
    required this.onConfirm,
    required this.onCancel,
    this.message,
  });
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded,
            color: ac.maroonMid, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(message ?? 'Διαγραφή;',
              style: TextStyle(
                  color: ac.textPrimary, fontSize: 13)),
        ),
        TextButton(
          onPressed: onCancel,
          child: Text('Ακύρωση',
              style: TextStyle(color: ac.textSecondary)),
        ),
        SizedBox(width: 4),
        TextButton(
          onPressed: onConfirm,
          child: Text('Διαγραφή',
              style: TextStyle(color: ac.maroonMid)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BISHOP ADMIN CARD
// ════════════════════════════════════════════════════════════════════════════
// Shows the current bishop titles + photo, with an edit button.
// Saves directly to config/bishop via BishopRepository.

class _BishopAdminCard extends StatefulWidget {
  const _BishopAdminCard({required this.repo});
  final BishopRepository repo;

  @override
  State<_BishopAdminCard> createState() => _BishopAdminCardState();
}

class _BishopAdminCardState extends State<_BishopAdminCard> {
  final _cloudinary = sl<CloudinaryDataSource>();

  bool   _editing   = false;
  bool   _saving    = false;
  bool   _uploading = false;
  double _progress  = 0;

  final _titleEl = TextEditingController();
  final _titleAr = TextEditingController();
  String     _imageUrl = '';
  File?      _imgFile;
  Uint8List? _imgBytes;

  @override
  void dispose() {
    _titleEl.dispose();
    _titleAr.dispose();
    super.dispose();
  }

  // ── Image pick + upload ─────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _imgFile  = kIsWeb ? null : File(img.path);
      _imgBytes = bytes;
      _imageUrl = '';
    });
    await _uploadImage();
  }

  Future<void> _uploadImage() async {
    if (_imgFile == null && _imgBytes == null) return;
    setState(() { _uploading = true; _progress = 0; });
    try {
      final res = kIsWeb
          ? await _cloudinary.uploadCoverImageBytes(
              bytes: _imgBytes!,
              fileName: 'bishop_${DateTime.now().millisecondsSinceEpoch}',
              folder: 'Ekklisia/bishop',
              onProgress: (p) => setState(() => _progress = p))
          : await _cloudinary.uploadCoverImage(
              imageFile: _imgFile!,
              folder: 'Ekklisia/bishop',
              onProgress: (p) => setState(() => _progress = p));
      setState(() => _imageUrl = res.secureUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      setState(() { _uploading = false; });
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repo.save(BishopModel(
        titleEl:  _titleEl.text.trim(),
        titleAr:  _titleAr.text.trim(),
        imageUrl: _imageUrl,
      ));
      setState(() => _editing = false);
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l  = context.adminL10n;

    return StreamBuilder<BishopModel?>(
      stream: widget.repo.watch(),
      builder: (context, snap) {
        final bishop = snap.data;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            color: ac.bgElevated,
            borderRadius: _kRadius,
            border: Border.all(color: ac.gold.withValues(alpha: 0.35), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(children: [
                  Text(
                    l.bishop,
                    style: TextStyle(
                      color: ac.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Επίσκοπος',
                    style: TextStyle(color: ac.textSecondary, fontSize: 11),
                  ),
                  const Spacer(),
                  if (!_editing)
                    GestureDetector(
                      onTap: () {
                        _titleEl.text = bishop?.titleEl ?? '';
                        _titleAr.text = bishop?.titleAr ?? '';
                        _imageUrl     = bishop?.imageUrl ?? '';
                        _imgFile      = null;
                        _imgBytes     = null;
                        setState(() => _editing = true);
                      },
                      child: Icon(Icons.edit_outlined, color: ac.gold, size: 16),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                child: Divider(
                    height: 1,
                    color: ac.goldBorder.withValues(alpha: 0.5)),
              ),

              // ── View mode ──────────────────────────────────────────
              if (!_editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: bishop == null || bishop.isEmpty
                      ? Text(
                          'Δεν έχουν οριστεί στοιχεία  —  لم تُحدَّد بيانات',
                          style: TextStyle(color: ac.textSecondary, fontSize: 12),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (bishop.imageUrl.isNotEmpty) ...[
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ac.goldBorder, width: 0.8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  bishop.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.person_outline,
                                      color: ac.textSecondary, size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (bishop.titleEl.isNotEmpty)
                                    Text(bishop.titleEl,
                                        style: TextStyle(
                                          color: ac.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  if (bishop.titleAr.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(bishop.titleAr,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: ac.tealMid,
                                          fontFamily: 'Scheherazade',
                                          fontSize: 13,
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

              // ── Edit mode ──────────────────────────────────────────
              if (_editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(children: [
                    _PriestImagePicker(
                      imageUrl:   _imageUrl,
                      localBytes: _imgBytes,
                      uploading:  _uploading,
                      progress:   _progress,
                      onPick:     _pickImage,
                      ac:         ac,
                      l:          l,
                      label:      l.bishopImage,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _titleEl,
                      label: l.bishopTitleEl,
                      hint: 'Ο Σεβασμιώτατος Επίσκοπος…',
                    ),
                    const SizedBox(height: 8),
                    _Field(
                      ctrl: _titleAr,
                      label: l.bishopTitleAr,
                      hint: 'سيدنا الأنبا…',
                      arabic: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editing = false),
                          child: Text('Ακύρωση',
                              style: TextStyle(color: ac.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: ac.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: ac.gold.withValues(alpha: 0.4),
                                  width: 0.5),
                            ),
                            child: _saving
                                ? SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        color: ac.gold, strokeWidth: 2))
                                : Text(l.saveBishop,
                                    style: TextStyle(
                                        color: ac.gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}
