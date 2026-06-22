// lib/admin/electronic_library/elib_manager_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Electronic Library Manager.
//
// Two-panel layout:
//   Left / top:  Section list  (create / delete / reorder)
//   Right / bottom: Items in selected section (add URL | bulk upload | delete)
//
// On narrow screens: sections at top, items below.
// On wide screens: split left/right.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/service_locator.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../data/models/elib_item_model.dart';
import '../../data/models/elib_section_model.dart';
import '../../data/repositories/elib_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../admin_l10n.dart';
import '../utils/admin_colors.dart';

class ElibManagerScreen extends StatefulWidget {
  const ElibManagerScreen({super.key});

  @override
  State<ElibManagerScreen> createState() => _ElibManagerScreenState();
}

class _ElibManagerScreenState extends State<ElibManagerScreen> {
  final _repo = sl<ElibRepository>();

  List<ElibSectionModel> _sections = [];
  String? _selectedSectionId;
  bool _sectionsLoading = true;

  @override
  void initState() {
    super.initState();
    _repo.watchSections().listen(
      (sections) => setState(() {
        _sections = sections;
        _sectionsLoading = false;
        if (_selectedSectionId == null && sections.isNotEmpty) {
          _selectedSectionId = sections.first.id;
        }
      }),
    );
  }

  ElibSectionModel? get _selectedSection =>
      _sections.where((s) => s.id == _selectedSectionId).firstOrNull;

  /// Safe l10n getter for use in callbacks (uses read, not watch).
  AdminL10n get _l {
    final lang = context.read<SettingsCubit>().state.language;
    return lang == AppLanguage.arabic ? AdminL10n.ar : AdminL10n.el;
  }

  // ── Section CRUD ──────────────────────────────────────────────────────────

  Future<void> _createSection() async {
    final l = _l;
    final arCtrl = TextEditingController();
    final elCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.addSection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: arCtrl,
              decoration: InputDecoration(labelText: l.titleAr),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: elCtrl,
              decoration: InputDecoration(labelText: l.titleEl),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l.save),
          ),
        ],
      ),
    );

    if (result == true && arCtrl.text.isNotEmpty) {
      final section = ElibSectionModel(
        id: '',
        titleAr: arCtrl.text.trim(),
        titleEl: elCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      final saved = await _repo.saveSection(section);
      setState(() => _selectedSectionId = saved.id);
    }
  }

  Future<void> _deleteSection(ElibSectionModel section) async {
    final l = _l;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.delete),
        content: Text(section.titleAr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.deleteSection(section.id);
      if (_selectedSectionId == section.id) {
        setState(() => _selectedSectionId = _sections.firstOrNull?.id);
      }
    }
  }

  // ── Item CRUD ─────────────────────────────────────────────────────────────

  Future<void> _addItemByUrl() async {
    if (_selectedSectionId == null) return;
    final l = _l;
    final arCtrl = TextEditingController();
    final elCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    ElibMediaType mediaType = ElibMediaType.video;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          title: Text(l.addItem),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: arCtrl,
                  decoration: InputDecoration(labelText: l.titleAr),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: elCtrl,
                  decoration: InputDecoration(labelText: l.titleEl),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'URL'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(l.video),
                      selected: mediaType == ElibMediaType.video,
                      onSelected: (_) =>
                          setDlgState(() => mediaType = ElibMediaType.video),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(l.audio),
                      selected: mediaType == ElibMediaType.audio,
                      onSelected: (_) =>
                          setDlgState(() => mediaType = ElibMediaType.audio),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );

    if (result == true && urlCtrl.text.isNotEmpty) {
      final item = ElibItemModel(
        id: '',
        sectionId: _selectedSectionId!,
        titleAr: arCtrl.text.trim(),
        titleEl: elCtrl.text.trim(),
        mediaUrl: urlCtrl.text.trim(),
        mediaType: mediaType,
        isPublished: true,
        createdAt: DateTime.now(),
      );
      await _repo.saveItem(item);
    }
  }

  Future<void> _deleteItem(ElibItemModel item) async {
    final l = _l;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.delete),
        content: Text(item.titleAr.isNotEmpty ? item.titleAr : item.titleEl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await _repo.deleteItem(item.id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );
    final l = _l;
    final wide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      body: Column(
        children: [
          // ── Top toolbar ───────────────────────────────────────────────
          _TopBar(
            title: l.elibManager,
            isGreek: isGreek,
            l: l,
            onBulk: _selectedSectionId == null
                ? null
                : () => context.push(
                      Routes.adminCmsElibBulk,
                      extra: _selectedSectionId,
                    ),
          ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      SizedBox(
                        width: 260,
                        child: _SectionPanel(
                          sections: _sections,
                          loading: _sectionsLoading,
                          selectedId: _selectedSectionId,
                          isGreek: isGreek,
                          l: l,
                          onSelect: (id) => setState(() => _selectedSectionId = id),
                          onAdd: _createSection,
                          onDelete: _deleteSection,
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFF2A3A50)),
                      Expanded(
                        child: _selectedSectionId == null
                            ? _NoSection(l: l)
                            : _ItemsPanel(
                                sectionId: _selectedSectionId!,
                                section: _selectedSection,
                                repo: _repo,
                                isGreek: isGreek,
                                l: l,
                                onAddUrl: _addItemByUrl,
                                onDelete: _deleteItem,
                              ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: _SectionPanel(
                          sections: _sections,
                          loading: _sectionsLoading,
                          selectedId: _selectedSectionId,
                          isGreek: isGreek,
                          l: l,
                          onSelect: (id) => setState(() => _selectedSectionId = id),
                          onAdd: _createSection,
                          onDelete: _deleteSection,
                          horizontal: true,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF2A3A50)),
                      Expanded(
                        child: _selectedSectionId == null
                            ? _NoSection(l: l)
                            : _ItemsPanel(
                                sectionId: _selectedSectionId!,
                                section: _selectedSection,
                                repo: _repo,
                                isGreek: isGreek,
                                l: l,
                                onAddUrl: _addItemByUrl,
                                onDelete: _deleteItem,
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isGreek,
    required this.l,
    required this.onBulk,
  });

  final String title;
  final bool isGreek;
  final AdminL10n l;
  final VoidCallback? onBulk;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
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
                fontSize: isGreek ? 18 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onBulk != null)
            FilledButton.icon(
              onPressed: onBulk,
              icon: Icon(Icons.upload_file, size: 16),
              label: Text(l.bulk),
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

// ── Section panel ─────────────────────────────────────────────────────────────

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.sections,
    required this.loading,
    required this.selectedId,
    required this.isGreek,
    required this.l,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
    this.horizontal = false,
  });

  final List<ElibSectionModel> sections;
  final bool loading;
  final String? selectedId;
  final bool isGreek;
  final AdminL10n l;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ElibSectionModel> onDelete;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    if (horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Text(
                  l.sections,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: onAdd,
                  child: Icon(Icons.add_circle_outline, color: ac.gold, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: sections.length,
              itemBuilder: (_, i) {
                final s = sections[i];
                final selected = s.id == selectedId;
                final title = (isGreek && s.titleEl.isNotEmpty) ? s.titleEl : s.titleAr;
                return GestureDetector(
                  onTap: () => onSelect(s.id),
                  onLongPress: () => onDelete(s),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? ac.gold.withValues(alpha: 0.15)
                          : Color(0xFF162535),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? ac.gold : Color(0xFF2A3A50),
                      ),
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: selected ? ac.gold : Colors.white70,
                        fontSize: isGreek ? 12 : 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Vertical list (wide layout)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Text(
                l.sections,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Icon(Icons.add, color: ac.gold, size: 20),
              ),
            ],
          ),
        ),
        if (loading)
          Expanded(child: Center(child: CircularProgressIndicator(color: ac.gold, strokeWidth: 2)))
        else
          Expanded(
            child: ListView.builder(
              itemCount: sections.length,
              itemBuilder: (_, i) {
                final s = sections[i];
                final selected = s.id == selectedId;
                final title = (isGreek && s.titleEl.isNotEmpty) ? s.titleEl : s.titleAr;
                return ListTile(
                  selected: selected,
                  selectedTileColor: ac.gold.withValues(alpha: 0.1),
                  selectedColor: ac.gold,
                  title: Text(
                    title,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: selected ? ac.gold : Colors.white70,
                      fontSize: isGreek ? 13 : 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  onTap: () => onSelect(s.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    onPressed: () => onDelete(s),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Items panel ───────────────────────────────────────────────────────────────

class _ItemsPanel extends StatefulWidget {
  const _ItemsPanel({
    required this.sectionId,
    required this.section,
    required this.repo,
    required this.isGreek,
    required this.l,
    required this.onAddUrl,
    required this.onDelete,
  });

  final String sectionId;
  final ElibSectionModel? section;
  final ElibRepository repo;
  final bool isGreek;
  final AdminL10n l;
  final VoidCallback onAddUrl;
  final ValueChanged<ElibItemModel> onDelete;

  @override
  State<_ItemsPanel> createState() => _ItemsPanelState();
}

class _ItemsPanelState extends State<_ItemsPanel> {
  // Local optimistic copy for smooth drag animation.
  List<ElibItemModel>? _localItems;

  void _onReorder(int oldIndex, int newIndex) {
    if (_localItems == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _localItems!.removeAt(oldIndex);
      _localItems!.insert(newIndex, item);
    });
    // Persist order in the background.
    widget.repo.reorderItems(_localItems!.map((e) => e.id).toList());
  }

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final sectionTitle = widget.section == null
        ? ''
        : (widget.isGreek && widget.section!.titleEl.isNotEmpty
            ? widget.section!.titleEl
            : widget.section!.titleAr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section items header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Color(0xFF0D1B2A)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  style: TextStyle(
                    fontFamily: widget.isGreek ? null : 'Scheherazade',
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: widget.isGreek ? 14 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onAddUrl,
                icon: Icon(Icons.link, size: 15),
                label: Text(widget.l.addUrl),
                style: TextButton.styleFrom(foregroundColor: ac.gold),
              ),
            ],
          ),
        ),
        // Items list
        Expanded(
          child: StreamBuilder<List<ElibItemModel>>(
            stream: widget.repo.watchItemsBySection(widget.sectionId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  _localItems == null) {
                return Center(
                  child: CircularProgressIndicator(
                    color: ac.gold, strokeWidth: 2),
                );
              }
              // Sync local copy from stream only when not dragging.
              final streamItems = snap.data ?? [];
              if (_localItems == null ||
                  streamItems.length != _localItems!.length) {
                // Use post-frame callback to avoid setState during build.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _localItems = List.from(streamItems));
                });
              }
              final items = _localItems ?? streamItems;

              if (items.isEmpty) {
                return Center(
                  child: Text(
                    widget.l.noFilesSelected,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(12),
                onReorder: _onReorder,
                itemCount: items.length,
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  child: child,
                ),
                itemBuilder: (ctx, i) => _ItemTile(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  isGreek: widget.isGreek,
                  l: widget.l,
                  onDelete: () => widget.onDelete(items[i]),
                  onTogglePublish: (val) =>
                      widget.repo.setItemPublished(items[i].id, published: val),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.isGreek,
    required this.l,
    required this.onDelete,
    required this.onTogglePublish,
  });

  final ElibItemModel item;
  final bool isGreek;
  final AdminL10n l;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePublish;

  bool get _isYouTube =>
      item.mediaUrl.contains('youtube.com') ||
      item.mediaUrl.contains('youtu.be');

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final title = (isGreek && item.titleEl.isNotEmpty) ? item.titleEl : item.titleAr;
    final isVideo = item.mediaType == ElibMediaType.video;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF162535),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3A50)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isVideo ? Colors.blue : ac.gold).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isYouTube
                  ? Icons.smart_display_outlined
                  : (isVideo ? Icons.videocam_outlined : Icons.audiotrack_outlined),
              color: isVideo ? Colors.blue : ac.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : '—',
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: isGreek ? 12 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.mediaUrl,
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Play / open
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white38),
            onPressed: () async {
              final uri = Uri.tryParse(item.mediaUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          // Publish toggle
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: item.isPublished,
              onChanged: onTogglePublish,
              activeColor: ac.gold,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── No section selected ───────────────────────────────────────────────────────

class _NoSection extends StatelessWidget {
  const _NoSection({required this.l});
  final AdminL10n l;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Center(
      child: Text(
        l.selectSection,
        style: TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }
}
