// lib/admin/gallery/gallery_manager_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Gallery Manager.
// Shows a grid of all uploaded gallery images.
// Toolbar has: title | "Add Image" (single) | "Bulk Upload" button.
// Each card: image + title + publish toggle + delete.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/service_locator.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/brightness_colors.dart';
import '../../core/theme/colors.dart';
import '../../data/models/gallery_item_model.dart';
import '../../data/repositories/gallery_repository.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/cached_image.dart';
import '../admin_l10n.dart';

class GalleryManagerScreen extends StatefulWidget {
  const GalleryManagerScreen({super.key});

  @override
  State<GalleryManagerScreen> createState() => _GalleryManagerScreenState();
}

class _GalleryManagerScreenState extends State<GalleryManagerScreen> {
  final _repo = sl<GalleryRepository>();
  List<GalleryItemModel> _items = [];
  bool _loading = true;
  String? _error;

  /// Safe l10n getter for callbacks (uses read, not watch).
  AdminL10n get _l {
    final lang = context.read<SettingsCubit>().state.language;
    return lang == AppLanguage.arabic ? AdminL10n.ar : AdminL10n.el;
  }

  @override
  void initState() {
    super.initState();
    _repo.watchAll().listen(
      (items) => setState(() { _items = items; _loading = false; }),
      onError: (e) => setState(() { _error = e.toString(); _loading = false; }),
    );
  }

  Future<void> _addSingle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // Show dialog to enter titles
    final titles = await _showTitleDialog(stem: _stem(file.name));
    if (titles == null) return;

    final uid = context.read<AuthCubit>().state.user?.uid ?? '';

    try {
      if (kIsWeb && file.bytes != null) {
        await _repo.uploadAndSaveBytes(
          bytes: file.bytes!,
          fileName: file.name,
          titleAr: titles.$1,
          titleEl: titles.$2,
          createdBy: uid,
        );
      } else if (!kIsWeb && file.path != null) {
        await _repo.uploadAndSave(
          imageFile: File(file.path!),
          titleAr: titles.$1,
          titleEl: titles.$2,
          createdBy: uid,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<(String, String)?> _showTitleDialog({String stem = ''}) async {
    final arCtrl = TextEditingController(text: stem);
    final elCtrl = TextEditingController(text: stem);
    final l = _l;

    return showDialog<(String, String)>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.add),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, (arCtrl.text, elCtrl.text)),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(GalleryItemModel item) async {
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
    if (confirmed == true) await _repo.delete(item.id);
  }

  String _stem(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? name : name.substring(0, i);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.adminL10n;
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );

    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      body: Column(
        children: [
          // ── Toolbar ──────────────────────────────────────────────────────
          _Toolbar(
            title: l.gallery,
            isGreek: isGreek,
            onAdd: _addSingle,
            onBulk: () => context.push(Routes.adminCmsGalleryBulk),
          ),
          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: BrightnessColors.gold(brightness)))
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: BrightnessColors.maroon(brightness))))
                    : _items.isEmpty
                        ? _EmptyState(l: l)
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) => _ImageCard(
                              item: _items[i],
                              isGreek: isGreek,
                              brightness: brightness,
                              onDelete: () => _delete(_items[i]),
                              onTogglePublish: (val) => _repo.setPublished(
                                _items[i].id,
                                published: val,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.isGreek,
    required this.onAdd,
    required this.onBulk,
  });

  final String title;
  final bool isGreek;
  final VoidCallback onAdd;
  final VoidCallback onBulk;

  @override
  Widget build(BuildContext context) {
    final l = context.adminL10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
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
                color: EkklisiaColors.gold,
                fontSize: isGreek ? 18 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onBulk,
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(l.bulk),
            style: OutlinedButton.styleFrom(
              foregroundColor: EkklisiaColors.gold,
              side: const BorderSide(color: EkklisiaColors.gold),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_photo_alternate, size: 16),
            label: Text(l.add),
            style: FilledButton.styleFrom(
              backgroundColor: EkklisiaColors.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image card ────────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.item,
    required this.isGreek,
    required this.brightness,
    required this.onDelete,
    required this.onTogglePublish,
  });

  final GalleryItemModel item;
  final bool isGreek;
  final Brightness brightness;
  final VoidCallback onDelete;
  final ValueChanged<bool> onTogglePublish;

  @override
  Widget build(BuildContext context) {
    final title = (isGreek && item.titleEl.isNotEmpty) ? item.titleEl : item.titleAr;
    final bgCard = brightness == Brightness.dark
        ? const Color(0xFF162535)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3A50), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: CachedImage(
                url: item.imageUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: const Color(0xFF1B2A4A),
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Colors.white24, size: 32),
                  ),
                ),
              ),
            ),
          ),
          // Title + controls
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF1B2A4A),
                    fontSize: isGreek ? 11 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    // Publish toggle
                    Transform.scale(
                      scale: 0.75,
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: item.isPublished,
                        onChanged: onTogglePublish,
                        activeColor: EkklisiaColors.gold,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    // Delete
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AdminL10n l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            l.noFilesSelected,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
