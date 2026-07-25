// lib/admin/content/churches_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin CMS — Churches manager.
//
// Two modes:
//   • list  — table of all churches with publish toggle + edit / delete
//   • edit  — form: nameAr, nameEn, mapsUrl, dynamic priests list
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
import '../../data/repositories/bishop_repository.dart';
import '../../data/repositories/churches_repository.dart';
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
  final _repo = sl<ChurchesRepository>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              _ChurchesTab(repo: _repo),
              // Priests tab
              _PriestsTab(repo: _repo),
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
      return _EditView(repo: widget.repo, initial: _editing, onDone: _backToList, showPriestSection: false);
    }
    return _ListView(repo: widget.repo, onEdit: _openEdit);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRIESTS TAB
// ════════════════════════════════════════════════════════════════════════════

class _PriestsTab extends StatefulWidget {
  const _PriestsTab({required this.repo});
  final ChurchesRepository repo;

  @override
  State<_PriestsTab> createState() => _PriestTabState();
}

class _PriestTabState extends State<_PriestsTab> {
  String _search = '';
  ChurchModel? _selectedChurch;
  ChurchModel? _editingPriest;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;

    return StreamBuilder<List<ChurchModel>>(
      stream: widget.repo.watchAll(),
      builder: (context, snap) {
        final churches = snap.data ?? [];
        final filteredChurches = churches.where((c) {
          final q = _search.toLowerCase();
          return q.isEmpty ||
              c.nameEn.toLowerCase().contains(q) ||
              c.nameAr.contains(q);
        }).toList();

        return Column(
          children: [
            // ── Search toolbar ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: ac.bgDeep,
                border: Border(bottom: ac.borderSide),
              ),
              child: TextField(
                onChanged: (q) => setState(() => _search = q),
                style: TextStyle(color: ac.textPrimary, fontSize: 13),
                decoration: ac.inputDeco('${l.search} ${l.churches}…'),
              ),
            ),

            // ── Churches list with priest management ──────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: filteredChurches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final church = filteredChurches[i];
                  return _ChurchPriestsCard(
                    church: church,
                    repo: widget.repo,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIST VIEW
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

                // Names + priest count + maps chip
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
                      SizedBox(height: 4),
                      Row(children: [
                        if (church.priests.isNotEmpty)
                          _Chip(
                            label: '${church.priests.length} κ.',
                            color: ac.tealMid,
                          ),
                        if (church.priests.isNotEmpty)
                          SizedBox(width: 4),
                        if (church.mapsUrl.isNotEmpty)
                          _Chip(
                            label: '📍 maps',
                            color: ac.gold,
                          ),
                      ]),
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
// EDIT VIEW
// ════════════════════════════════════════════════════════════════════════════

class _EditView extends StatefulWidget {
  const _EditView({
    required this.repo,
    required this.initial,
    required this.onDone,
    this.showPriestSection = true,
  });
  final ChurchesRepository repo;
  final ChurchModel? initial;
  final VoidCallback onDone;
  final bool showPriestSection;

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  final _formKey = GlobalKey<FormState>();

  // ── Church fields ─────────────────────────────────────────────────────────
  final _nameEn  = TextEditingController();
  final _nameAr  = TextEditingController();
  final _mapsUrl = TextEditingController();
  bool _published = true;

  // ── Priests (dynamic list of row controllers) ─────────────────────────────
  final List<_PriestRow> _priests = [];

  // ── Save state ────────────────────────────────────────────────────────────
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
      for (final p in c.priests) {
        _priests.add(_PriestRow(
          nameEn:   TextEditingController(text: p.nameEn),
          nameAr:   TextEditingController(text: p.nameAr),
          phone:    TextEditingController(text: p.phone),
          imageUrl: TextEditingController(text: p.imageUrl),
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _mapsUrl.dispose();
    for (final r in _priests) {
      r.nameEn.dispose();
      r.nameAr.dispose();
      r.phone.dispose();
      r.imageUrl.dispose();
    }
    super.dispose();
  }

  void _addPriest() {
    setState(() {
      _priests.add(_PriestRow(
        nameEn:   TextEditingController(),
        nameAr:   TextEditingController(),
        phone:    TextEditingController(),
        imageUrl: TextEditingController(),
      ));
    });
  }

  void _removePriest(int i) {
    setState(() {
      _priests[i].nameEn.dispose();
      _priests[i].nameAr.dispose();
      _priests[i].phone.dispose();
      _priests[i].imageUrl.dispose();
      _priests.removeAt(i);
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = ''; });
    try {
      final priests = _priests.map((r) => PriestModel(
        nameEn:   r.nameEn.text.trim(),
        nameAr:   r.nameAr.text.trim(),
        phone:    r.phone.text.trim(),
        imageUrl: r.imageUrl.text.trim(),
      )).toList();

      final church = ChurchModel(
        id:          widget.initial?.id ?? '',
        nameEn:      _nameEn.text.trim(),
        nameAr:      _nameAr.text.trim(),
        mapsUrl:     _mapsUrl.text.trim(),
        isPublished: _published,
        priests:     priests,
      );

      await widget.repo.save(church);
      widget.onDone();
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      setState(() => _saving = false);
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

              // ── Priests ────────────────────────────────────────────
              if (widget.showPriestSection)
              _FormCard(
                title: 'Ιερείς',
                titleAr: 'الكهنة',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_priests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Δεν έχουν προστεθεί ιερείς  —  لا يوجد كهنة',
                          style: TextStyle(
                            color: ac.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Priest rows
                    for (int i = 0; i < _priests.length; i++) ...[
                      _PriestFormRow(
                        row: _priests[i],
                        index: i,
                        l: l,
                        onRemove: () => _removePriest(i),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Add priest button
                    GestureDetector(
                      onTap: _addPriest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: ac.bgMid,
                          borderRadius: _kRadius,
                          border: Border.all(
                              color: ac.goldBorder, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_outlined,
                                color: ac.tealMid, size: 16),
                            SizedBox(width: 6),
                            Text(
                              l.addPriest,
                              style: TextStyle(
                                color: ac.tealMid,
                                fontFamily: l.fontFam,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

// ── Priest form row ───────────────────────────────────────────────────────────

class _PriestRow {
  _PriestRow({
    required this.nameEn,
    required this.nameAr,
    required this.phone,
    required this.imageUrl,
  });
  final TextEditingController nameEn;
  final TextEditingController nameAr;
  final TextEditingController phone;
  final TextEditingController imageUrl;
}

class _PriestFormRow extends StatefulWidget {
  const _PriestFormRow({
    required this.row,
    required this.index,
    required this.l,
    required this.onRemove,
  });

  final _PriestRow row;
  final int index;
  final AdminL10n l;
  final VoidCallback onRemove;

  @override
  State<_PriestFormRow> createState() => _PriestFormRowState();
}

class _PriestFormRowState extends State<_PriestFormRow> {
  final _cloudinary = sl<CloudinaryDataSource>();

  File?      _imgFile;
  Uint8List? _imgBytes;
  bool       _uploading = false;
  double     _progress  = 0;

  // ── Image pick + upload ───────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _imgFile  = kIsWeb ? null : File(img.path);
      _imgBytes = bytes;
      widget.row.imageUrl.clear();
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
      setState(() => widget.row.imageUrl.text = res.secureUrl);
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac  = AdminC(Theme.of(context).brightness);
    final l   = widget.l;
    final row = widget.row;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        borderRadius: _kRadius,
        border: Border.all(
            color: ac.tealMid.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ac.tealMid.withValues(alpha: 0.12),
              border: Border.all(
                  color: ac.tealMid.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Center(
              child: Text(
                '${widget.index + 1}',
                style: TextStyle(
                    color: ac.tealMid,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.priests,
              style: TextStyle(
                  color: ac.tealMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: widget.onRemove,
            child: Icon(Icons.close, color: ac.maroonMid, size: 16),
          ),
        ]),
        const SizedBox(height: 10),

        // ── Text fields ──────────────────────────────────────────────────────
        _Field(ctrl: row.nameEn, label: l.priestNameEn, required: true),
        const SizedBox(height: 8),
        _Field(ctrl: row.nameAr, label: l.priestNameAr, required: true, arabic: true),
        const SizedBox(height: 8),
        _Field(ctrl: row.phone, label: l.priestPhone,
            hint: '+30 210 0000000', keyboardType: TextInputType.phone),
        const SizedBox(height: 10),

        // ── Image picker ─────────────────────────────────────────────────────
        _PriestImagePicker(
          imageUrl:   row.imageUrl.text,
          localBytes: _imgBytes,
          uploading:  _uploading,
          progress:   _progress,
          onPick:     _pickImage,
          ac:         ac,
          l:          l,
        ),
      ]),
    );
  }
}

// ── Priest image picker widget ────────────────────────────────────────────────

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
                      '${l.search} ${l.churches}…'),
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
  const _DeleteConfirmRow(
      {required this.onConfirm, required this.onCancel});
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

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
          child: Text('Διαγραφή αυτής της εκκλησίας;',
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
// ══════════════════════════════════════════════════════════════════// Shows the current bishop titles + photo, with an edit button.
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

// ════════════════════════════════════════════════════════════════════════════
// CHURCH PRIESTS CARD (for Priests Tab)
// ════════════════════════════════════════════════════════════════════════════

class _ChurchPriestsCard extends StatefulWidget {
  const _ChurchPriestsCard({
    required this.church,
    required this.repo,
  });

  final ChurchModel church;
  final ChurchesRepository repo;

  @override
  State<_ChurchPriestsCard> createState() => _ChurchPriestsCardState();
}

class _ChurchPriestsCardState extends State<_ChurchPriestsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final l = context.adminL10n;
    final church = widget.church;

    return Container(
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: _kRadius,
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        children: [
          // ── Church header ──────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Church icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ac.bgMid,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: ac.goldBorder, width: 0.5),
                      ),
                      child: Center(
                        child: Text('☩',
                            style: TextStyle(
                                color: ac.gold, fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Church names + priest count
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
                          SizedBox(height: 4),
                          _Chip(
                            label:
                                '${church.priests.length} ${l.priests}',
                            color: ac.tealMid,
                          ),
                        ],
                      ),
                    ),

                    // Expand/collapse icon
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: ac.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Priests list (when expanded) ────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: ac.goldBorder),
            if (church.priests.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Δεν υπάρχουν ιερείς  —  لا يوجد كهنة',
                  style: TextStyle(
                    color: ac.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(
                    church.priests.length,
                    (index) {
                      final priest = church.priests[index];
                      return Column(
                        children: [
                          _PriestItemRow(
                            priest: priest,
                            index: index,
                            ac: ac,
                            onEdit: () {
                              // TODO: Open priest edit for this church
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Edit ${priest.nameEn} - TODO implementation'),
                                ),
                              );
                            },
                          ),
                          if (index < church.priests.length - 1)
                            const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _PriestItemRow extends StatelessWidget {
  const _PriestItemRow({
    required this.priest,
    required this.index,
    required this.ac,
    required this.onEdit,
  });

  final PriestModel priest;
  final int index;
  final AdminC ac;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ac.tealMid.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          // Priest number badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ac.tealMid.withValues(alpha: 0.12),
              border:
                  Border.all(color: ac.tealMid.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: ac.tealMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Priest image + names + phone
          if (priest.imageUrl.isNotEmpty)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ac.goldBorder, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                priest.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person_outline, color: ac.textSecondary),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ac.bgElevated,
                border: Border.all(color: ac.goldBorder, width: 0.5),
              ),
              child: Icon(Icons.person_outline,
                  color: ac.textSecondary, size: 20),
            ),
          const SizedBox(width: 10),

          // Priest info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priest.nameEn,
                  style: TextStyle(
                    color: ac.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (priest.nameAr.isNotEmpty)
                  Text(
                    priest.nameAr,
                    style: TextStyle(
                      color: ac.textSecondary,
                      fontFamily: 'Scheherazade',
                      fontSize: 11,
                    ),
                  ),
                if (priest.phone.isNotEmpty)
                  Text(
                    priest.phone,
                    style: TextStyle(
                      color: ac.gold,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),

          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: Icon(Icons.edit_outlined, color: ac.gold, size: 16),
          ),
        ],
      ),
    );
  }
}
