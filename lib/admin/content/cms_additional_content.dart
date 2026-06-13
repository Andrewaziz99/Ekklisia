// lib/admin/content/cms_additional_content.dart
// ─────────────────────────────────────────────────────────────────────────────
// CMS screens for Prayers, Liturgies, Saints, and Calendar Events
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../core/utils/text_normalizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/content_models.dart';
import '../../features/auth/auth_cubit.dart';
import '../components/admin_data_table.dart';
import '../components/content_form.dart';

// ════════════════════════════════════════════════════════════════════════════
// PRAYERS MANAGEMENT SCREEN
// ════════════════════════════════════════════════════════════════════════════
class PrayersManagerScreen extends StatefulWidget {
  const PrayersManagerScreen({super.key});

  @override
  State<PrayersManagerScreen> createState() => _PrayersManagerScreenState();
}

class _PrayersManagerScreenState extends State<PrayersManagerScreen> {
  final _fb = FirebaseFirestore.instance;
  List<PrayerModel> _prayers = [];
  String _searchQuery = '';
  PrayerModel? _editingItem;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return _editingItem != null ? _buildForm() : _buildTable();
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _fb
          .collection(AppConstants.prayersCollection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        _prayers = docs
            .map((d) => PrayerModel.fromFirestore(d))
            .where((p) =>
        TextNormalizer.anyContains([p.titleAr, p.titleEn], _searchQuery))
            .toList();

        return AdminDataTable<PrayerModel>(
          title: 'Prayers',
          items: _prayers,
          columns: ['Title (EN)', 'Title (AR)', 'Occasion', 'Status'],
          rowBuilder: (prayer, idx) => [
            Text(prayer.titleEn,
                style: const TextStyle(
                  color: EkklisiaColors.textPrimary,
                  fontSize: 12,
                )),
            Text(prayer.titleAr,
                style: const TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'Scheherazade',
                )),
            Text(prayer.occasion ?? 'General',
                style: const TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 11,
                )),
            _StatusBadge(prayer.isPublished),
          ],
          onSearch: (q) => setState(() => _searchQuery = q),
          onAdd: () => setState(() => _editingItem = PrayerModel(
            id: '',
            titleAr: '',
            titleEn: '',
            isPublished: true,
            createdAt: DateTime.now(),
            createdBy: '',
          )),
          onEdit: (item) => setState(() => _editingItem = item),
          onDelete: (id) => _deletePrayer(id),
          isLoading: snap.connectionState == ConnectionState.waiting,
          emptyMessage: 'No prayers added yet',
        );
      },
    );
  }

  Widget _buildForm() {
    final item = _editingItem!;
    return ContentForm(
      title: item.id.isEmpty ? 'Add Prayer' : 'Edit Prayer',
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
          key: 'occasion',
          labelEn: 'Occasion',
          labelAr: 'المناسبة',
          hintEn: 'e.g., Morning, Evening, Feast',
          value: item.occasion,
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
      onSubmit: (data) => _savePrayer(data),
      onCancel: () => setState(() => _editingItem = null),
      submitLabel: item.id.isEmpty ? 'Create' : 'Update',
      isLoading: _isLoading,
    );
  }

  Future<void> _savePrayer(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final item = _editingItem!;
      final userId = context.read<AuthCubit>().state.user?.uid ?? '';

      final prayer = PrayerModel(
        id: item.id,
        titleEn: data['titleEn'],
        titleAr: data['titleAr'],
        occasion: data['occasion'],
        textAr: data['textAr'],
        textCoptic: data['textCoptic'],
        isPublished: data['isPublished'] ?? true,
        createdAt: item.createdAt,
        createdBy: item.createdBy.isEmpty ? userId : item.createdBy,
      );

      if (item.id.isEmpty) {
        await _fb
            .collection(AppConstants.prayersCollection)
            .add(prayer.toFirestore());
      } else {
        await _fb
            .collection(AppConstants.prayersCollection)
            .doc(item.id)
            .update(prayer.toFirestore());
      }

      setState(() => _editingItem = null);
      _showSnackBar('Prayer saved successfully');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePrayer(String id) async {
    try {
      await _fb.collection(AppConstants.prayersCollection).doc(id).delete();
      _showSnackBar('Prayer deleted');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? EkklisiaColors.maroon : EkklisiaColors.gold,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LITURGIES MANAGEMENT SCREEN
// ════════════════════════════════════════════════════════════════════════════
class LiturgiesManagerScreen extends StatefulWidget {
  const LiturgiesManagerScreen({super.key});

  @override
  State<LiturgiesManagerScreen> createState() => _LiturgiesManagerScreenState();
}

class _LiturgiesManagerScreenState extends State<LiturgiesManagerScreen> {
  final _fb = FirebaseFirestore.instance;
  List<LiturgyModel> _liturgies = [];
  String _searchQuery = '';
  LiturgyModel? _editingItem;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return _editingItem != null ? _buildForm() : _buildTable();
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _fb
          .collection(AppConstants.liturgiesCollection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        _liturgies = docs
            .map((d) => LiturgyModel.fromFirestore(d))
            .where((l) =>
        TextNormalizer.anyContains([l.titleAr, l.titleEn], _searchQuery))
            .toList();

        return AdminDataTable<LiturgyModel>(
          title: 'Liturgies',
          items: _liturgies,
          columns: ['Title', 'Type', 'Season', 'Status'],
          rowBuilder: (liturgy, idx) => [
            Text(liturgy.titleEn,
                style: const TextStyle(
                  color: EkklisiaColors.textPrimary,
                  fontSize: 12,
                )),
            Text(liturgy.liturgyType ?? 'General',
                style: const TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 11,
                )),
            Text(liturgy.season ?? 'Regular',
                style: const TextStyle(
                  color: EkklisiaColors.textSecondary,
                  fontSize: 11,
                )),
            _StatusBadge(liturgy.isPublished),
          ],
          onSearch: (q) => setState(() => _searchQuery = q),
          onAdd: () => setState(() => _editingItem = LiturgyModel(
            id: '',
            titleAr: '',
            titleEn: '',
            isPublished: true,
            createdAt: DateTime.now(),
            createdBy: '',
          )),
          onEdit: (item) => setState(() => _editingItem = item),
          onDelete: (id) => _deleteLiturgy(id),
          isLoading: snap.connectionState == ConnectionState.waiting,
          emptyMessage: 'No liturgies added yet',
        );
      },
    );
  }

  Widget _buildForm() {
    final item = _editingItem!;
    return ContentForm(
      title: item.id.isEmpty ? 'Add Liturgy' : 'Edit Liturgy',
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
          key: 'liturgyType',
          labelEn: 'Liturgy Type',
          labelAr: 'نوع الخدمة',
          hintEn: 'e.g., Liturgy of St. Basil',
          value: item.liturgyType,
        ),
        FormFieldConfig(
          key: 'season',
          labelEn: 'Season',
          labelAr: 'الموسم',
          hintEn: 'e.g., Resurrection, Nativity',
          value: item.season,
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
        FormFieldConfig(
          key: 'textAr',
          labelEn: 'Arabic Text',
          labelAr: 'النص بالعربية',
          multiline: true,
          minLines: 5,
          maxLines: 10,
          value: item.textAr,
        ),
      ],
      onSubmit: (data) => _saveLiturgy(data),
      onCancel: () => setState(() => _editingItem = null),
      submitLabel: item.id.isEmpty ? 'Create' : 'Update',
      isLoading: _isLoading,
    );
  }

  Future<void> _saveLiturgy(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final item = _editingItem!;
      final userId = context.read<AuthCubit>().state.user?.uid ?? '';

      final liturgy = LiturgyModel(
        id: item.id,
        titleEn: data['titleEn'],
        titleAr: data['titleAr'],
        liturgyType: data['liturgyType'],
        season: data['season'],
        descriptionEn: data['descriptionEn'],
        textAr: data['textAr'],
        isPublished: data['isPublished'] ?? true,
        createdAt: item.createdAt,
        createdBy: item.createdBy.isEmpty ? userId : item.createdBy,
      );

      if (item.id.isEmpty) {
        await _fb
            .collection(AppConstants.liturgiesCollection)
            .add(liturgy.toFirestore());
      } else {
        await _fb
            .collection(AppConstants.liturgiesCollection)
            .doc(item.id)
            .update(liturgy.toFirestore());
      }

      setState(() => _editingItem = null);
      _showSnackBar('Liturgy saved successfully');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLiturgy(String id) async {
    try {
      await _fb.collection(AppConstants.liturgiesCollection).doc(id).delete();
      _showSnackBar('Liturgy deleted');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? EkklisiaColors.maroon : EkklisiaColors.gold,
      duration: const Duration(seconds: 2),
    ));
  }
}

// SaintsManagerScreen has been moved to lib/admin/content/saints_manager.dart
// (supports cover image, PDF, audio, and video via Cloudinary).

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.isPublished);
  final bool isPublished;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (isPublished ? EkklisiaColors.tealMid : EkklisiaColors.goldDim)
          .withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color:
        (isPublished ? EkklisiaColors.tealMid : EkklisiaColors.goldDim)
            .withValues(alpha: 0.4),
        width: 0.5,
      ),
    ),
    child: Text(
      isPublished ? 'Published' : 'Draft',
      style: TextStyle(
        color: isPublished ? EkklisiaColors.tealMid : EkklisiaColors.goldDim,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}