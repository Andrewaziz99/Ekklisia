// lib/admin/content/cms_content_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Master CMS content manager with CRUD for all content types
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../core/utils/text_normalizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/content_models.dart';
import '../../features/auth/auth_cubit.dart';
import '../components/admin_data_table.dart';
import '../components/content_form.dart';
import '../utils/admin_colors.dart';

// ════════════════════════════════════════════════════════════════════════════
// BIBLES MANAGEMENT SCREEN
// ════════════════════════════════════════════════════════════════════════════
class BiblesManagerScreen extends StatefulWidget {
  const BiblesManagerScreen({super.key});

  @override
  State<BiblesManagerScreen> createState() => _BiblesManagerScreenState();
}

class _BiblesManagerScreenState extends State<BiblesManagerScreen> {
  final _fb = FirebaseFirestore.instance;
  List<BibleModel> _bibles = [];
  String _searchQuery = '';
  BibleModel? _editingItem;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return _editingItem != null
        ? _buildForm()
        : _buildTable();
  }

  Widget _buildTable() {
    final ac = AdminC(Theme.of(context).brightness);

    return StreamBuilder<QuerySnapshot>(
      stream: _fb
          .collection(AppConstants.biblesCollection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        _bibles = docs
            .map((d) => BibleModel.fromFirestore(d))
            .where((b) =>
        TextNormalizer.anyContains([b.titleAr, b.titleEn, b.version], _searchQuery))
            .toList();

        return AdminDataTable<BibleModel>(
          title: 'Bibles',
          items: _bibles,
          columns: ['Title', 'Version', 'Language', 'Status'],
          rowBuilder: (bible, idx) => [
            Text(bible.titleEn, style: TextStyle(
              color: ac.textPrimary,
              fontSize: 12,
            )),
            Text(bible.version, style: TextStyle(
              color: ac.textSecondary,
              fontSize: 11,
            )),
            Text(bible.language, style: TextStyle(
              color: ac.textSecondary,
              fontSize: 11,
            )),
            _StatusBadge(bible.isPublished),
          ],
          onSearch: (q) => setState(() => _searchQuery = q),
          onAdd: () => setState(() => _editingItem = BibleModel(
            id: '',
            titleAr: '',
            titleEn: '',
            language: 'en',
            version: '',
            isPublished: true,
            createdAt: DateTime.now(),
            createdBy: '',
          )),
          onEdit: (item) => setState(() => _editingItem = item),
          onDelete: (id) => _deleteBible(id),
          isLoading: snap.connectionState == ConnectionState.waiting,
          emptyMessage: 'No bibles added yet',
        );
      },
    );
  }

  Widget _buildForm() {
    final item = _editingItem!;
    return ContentForm(
      title: item.id.isEmpty ? 'Add Bible' : 'Edit Bible',
      fields: [
        FormFieldConfig(
          key: 'titleAr',
          labelEn: 'Arabic Title',
          labelAr: 'العنوان بالعربية',
          hintEn: 'e.g., الكتاب المقدس',
          required: true,
          value: item.titleAr,
        ),
        FormFieldConfig(
          key: 'titleEn',
          labelEn: 'English Title',
          labelAr: 'العنوان بالإنجليزية',
          hintEn: 'e.g., Holy Bible',
          required: true,
          value: item.titleEn,
        ),
        FormFieldConfig(
          key: 'version',
          labelEn: 'Version',
          labelAr: 'الإصدار',
          hintEn: 'e.g., NRSV, KJV',
          required: true,
          value: item.version,
        ),
        FormFieldConfig(
          key: 'language',
          labelEn: 'Language',
          labelAr: 'اللغة',
          hintEn: 'e.g., en, ar, cop',
          required: true,
          value: item.language,
        ),
        FormFieldConfig(
          key: 'translator',
          labelEn: 'Translator (Optional)',
          labelAr: 'المترجم (اختياري)',
          value: item.translator,
        ),
        FormFieldConfig(
          key: 'descriptionEn',
          labelEn: 'Description',
          labelAr: 'الوصف',
          multiline: true,
          minLines: 3,
          maxLines: 5,
          value: item.descriptionEn,
        ),
      ],
      onSubmit: (data) => _saveBible(data),
      onCancel: () => setState(() => _editingItem = null),
      submitLabel: item.id.isEmpty ? 'Create' : 'Update',
      isLoading: _isLoading,
    );
  }

  Future<void> _saveBible(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final item = _editingItem!;
      final userId = context.read<AuthCubit>().state.user?.uid ?? '';

      final bible = BibleModel(
        id: item.id,
        titleAr: data['titleAr'],
        titleEn: data['titleEn'],
        version: data['version'],
        language: data['language'],
        translator: data['translator'],
        descriptionEn: data['descriptionEn'],
        isPublished: data['isPublished'] ?? true,
        createdAt: item.createdAt,
        createdBy: item.createdBy.isEmpty ? userId : item.createdBy,
      );

      if (item.id.isEmpty) {
        await _fb.collection(AppConstants.biblesCollection).add(bible.toFirestore());
      } else {
        await _fb
            .collection(AppConstants.biblesCollection)
            .doc(item.id)
            .update(bible.toFirestore());
      }

      setState(() => _editingItem = null);
      _showSnackBar('Bible saved successfully');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBible(String id) async {
    try {
      await _fb.collection(AppConstants.biblesCollection).doc(id).delete();
      _showSnackBar('Bible deleted');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    final ac = AdminC(Theme.of(context).brightness);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? ac.maroon : ac.gold,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HYMNS MANAGEMENT SCREEN
// ════════════════════════════════════════════════════════════════════════════
class HymnsManagerScreen extends StatefulWidget {
  const HymnsManagerScreen({super.key});

  @override
  State<HymnsManagerScreen> createState() => _HymnsManagerScreenState();
}

class _HymnsManagerScreenState extends State<HymnsManagerScreen> {
  final _fb = FirebaseFirestore.instance;
  List<HymnModel> _hymns = [];
  String _searchQuery = '';
  HymnModel? _editingItem;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return _editingItem != null ? _buildForm() : _buildTable();
  }

  Widget _buildTable() {
    final ac = AdminC(Theme.of(context).brightness);

    return StreamBuilder<QuerySnapshot>(
      stream: _fb
          .collection(AppConstants.hymnsCollection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        _hymns = docs
            .map((d) => HymnModel.fromFirestore(d))
            .where((h) =>
        TextNormalizer.anyContains([h.titleAr, h.titleEn], _searchQuery))
            .toList();

        return AdminDataTable<HymnModel>(
          title: 'Hymns',
          items: _hymns,
          columns: ['Title (EN)', 'Title (AR)', 'Categories', 'Status'],
          rowBuilder: (hymn, idx) => [
            Text(hymn.titleEn, style: TextStyle(
              color: ac.textPrimary,
              fontSize: 12,
            )),
            Text(hymn.titleAr, style: TextStyle(
              color: ac.textSecondary,
              fontSize: 11,
              fontFamily: 'Scheherazade',
            )),
            Wrap(
              spacing: 4,
              children: hymn.categories
                  .take(2)
                  .map((c) => _CategoryTag(c))
                  .toList(),
            ),
            _StatusBadge(hymn.isPublished),
          ],
          onSearch: (q) => setState(() => _searchQuery = q),
          onAdd: () => setState(() => _editingItem = HymnModel(
            id: '',
            titleAr: '',
            titleEn: '',
            isPublished: true,
            createdAt: DateTime.now(),
            createdBy: '',
          )),
          onEdit: (item) => setState(() => _editingItem = item),
          onDelete: (id) => _deleteHymn(id),
          isLoading: snap.connectionState == ConnectionState.waiting,
          emptyMessage: 'No hymns added yet',
        );
      },
    );
  }

  Widget _buildForm() {
    final item = _editingItem!;
    return ContentForm(
      title: item.id.isEmpty ? 'Add Hymn' : 'Edit Hymn',
      fields: [
        FormFieldConfig(
          key: 'titleEn',
          labelEn: 'English Title',
          labelAr: 'العنوان بالإنجليزية',
          required: true,
          value: item.titleEn,
        ),
        FormFieldConfig(
          key: 'titleAr',
          labelEn: 'Arabic Title',
          labelAr: 'العنوان بالعربية',
          required: true,
          value: item.titleAr,
        ),
        FormFieldConfig(
          key: 'titleCoptic',
          labelEn: 'Coptic Title (Optional)',
          labelAr: 'العنوان بالقبطية',
          value: item.titleCoptic,
        ),
        FormFieldConfig(
          key: 'composer',
          labelEn: 'Composer',
          labelAr: 'الموسيقار',
          value: item.composer,
        ),
        FormFieldConfig(
          key: 'textAr',
          labelEn: 'Arabic Text',
          labelAr: 'النص بالعربية',
          multiline: true,
          minLines: 5,
          maxLines: 10,
          value: item.textAr,
        ),
        FormFieldConfig(
          key: 'textCoptic',
          labelEn: 'Coptic Text (Optional)',
          labelAr: 'النص بالقبطية',
          multiline: true,
          minLines: 3,
          maxLines: 8,
          value: item.textCoptic,
        ),
      ],
      onSubmit: (data) => _saveHymn(data),
      onCancel: () => setState(() => _editingItem = null),
      submitLabel: item.id.isEmpty ? 'Create' : 'Update',
      isLoading: _isLoading,
    );
  }

  Future<void> _saveHymn(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final item = _editingItem!;
      final userId = context.read<AuthCubit>().state.user?.uid ?? '';

      final hymn = HymnModel(
        id: item.id,
        titleEn: data['titleEn'],
        titleAr: data['titleAr'],
        titleCoptic: data['titleCoptic'],
        composer: data['composer'],
        textAr: data['textAr'],
        textCoptic: data['textCoptic'],
        isPublished: data['isPublished'] ?? true,
        createdAt: item.createdAt,
        createdBy: item.createdBy.isEmpty ? userId : item.createdBy,
      );

      if (item.id.isEmpty) {
        await _fb.collection(AppConstants.hymnsCollection).add(hymn.toFirestore());
      } else {
        await _fb
            .collection(AppConstants.hymnsCollection)
            .doc(item.id)
            .update(hymn.toFirestore());
      }

      setState(() => _editingItem = null);
      _showSnackBar('Hymn saved successfully');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHymn(String id) async {
    try {
      await _fb.collection(AppConstants.hymnsCollection).doc(id).delete();
      _showSnackBar('Hymn deleted');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    final ac = AdminC(Theme.of(context).brightness);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? ac.maroon : ac.gold,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.isPublished);
  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (isPublished ? ac.tealMid : ac.goldDim)
          .withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color:
        (isPublished ? ac.tealMid : ac.goldDim)
            .withOpacity(0.4),
        width: 0.5,
      ),
    ),
    child: Text(
      isPublished ? 'Published' : 'Draft',
      style: TextStyle(
        color: isPublished ? ac.tealMid : ac.goldDim,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: ac.goldSubtle,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: ac.goldBorder,
        width: 0.5,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: ac.gold,
        fontSize: 8,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  }
}