// lib/admin/content/home_layout_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Home Screen.
// Lets an admin customise the app's home screen without a new release:
//   • Header banner image
//   • Content Library tiles — Arabic / Greek name + cover image per tile
//   • Section titles — home headers, side-drawer entries, bottom-nav tabs
//
// Everything lives in config/home_layout (HomeLayoutRepository); the
// "Art Works" drawer entry keeps using category_labels/artworks
// (CategoryLabelRepository) since its list screen already reads from there.
// Blank fields fall back to the built-in defaults shown as hints.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../data/models/category_label_model.dart';
import '../../data/models/home_layout_model.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/repositories/category_label_repository.dart';
import '../../data/repositories/home_layout_repository.dart';
import '../../features/home/home_layout_defaults.dart';
import '../../shared/widgets/cached_image.dart';
import '../utils/admin_colors.dart';

const _kBannerKey = '__banner__';

class HomeLayoutManagerScreen extends StatefulWidget {
  const HomeLayoutManagerScreen({super.key});

  @override
  State<HomeLayoutManagerScreen> createState() =>
      _HomeLayoutManagerScreenState();
}

class _HomeLayoutManagerScreenState extends State<HomeLayoutManagerScreen> {
  final _repo = sl<HomeLayoutRepository>();
  final _labelRepo = sl<CategoryLabelRepository>();

  // Bilingual text controllers, keyed by tile / section key.
  final Map<String, TextEditingController> _ar = {};
  final Map<String, TextEditingController> _el = {};

  // Current image URLs (tile key → url, plus _kBannerKey for the banner).
  final Map<String, String> _images = {};

  // In-flight uploads (key → 0..1 progress).
  final Map<String, double> _uploading = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String _message = '';
  bool _messageIsError = false;

  List<String> get _allTextKeys => [
        ...homeTileDefs.map((d) => d.key),
        ...homeSectionDefs.map((d) => d.key),
        PdfCategory.artworks,
      ];

  @override
  void initState() {
    super.initState();
    for (final k in _allTextKeys) {
      _ar[k] = TextEditingController()..addListener(_markDirty);
      _el[k] = TextEditingController()..addListener(_markDirty);
    }
    _load();
  }

  void _markDirty() {
    if (!_loading && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetch(),
        _labelRepo.fetch(PdfCategory.artworks),
      ]);
      final layout = results[0] as HomeLayoutModel;
      final art = results[1] as CategoryLabel?;
      if (!mounted) return;

      for (final d in homeTileDefs) {
        final o = layout.tile(d.key);
        _ar[d.key]!.text = o.labelAr;
        _el[d.key]!.text = o.labelEl;
        if (o.imageUrl.isNotEmpty) _images[d.key] = o.imageUrl;
      }
      for (final d in homeSectionDefs) {
        final o = layout.section(d.key);
        _ar[d.key]!.text = o.labelAr;
        _el[d.key]!.text = o.labelEl;
      }
      _ar[PdfCategory.artworks]!.text = art?.labelAr ?? '';
      _el[PdfCategory.artworks]!.text = art?.labelEl ?? '';
      if (layout.bannerUrl.isNotEmpty) _images[_kBannerKey] = layout.bannerUrl;

      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Failed to load: $e';
        _messageIsError = true;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [..._ar.values, ..._el.values]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Image pick + upload ──────────────────────────────────────────────────

  Future<void> _pickImage(String key) async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: key == _kBannerKey ? 1600 : 800,
      maxHeight: key == _kBannerKey ? 900 : 800,
      imageQuality: 85,
    );
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final sizeMb = bytes.lengthInBytes / (1024 * 1024);
    if (sizeMb > AppConstants.maxImageSizeMb) {
      _showMessage(
        'Image is ${sizeMb.toStringAsFixed(1)} MB — maximum allowed size is '
        '${AppConstants.maxImageSizeMb.toInt()} MB.',
        error: true,
      );
      return;
    }

    setState(() => _uploading[key] = 0);
    try {
      final url = await _repo.uploadImage(
        bytes: bytes,
        fileName: img.name,
        onProgress: (p) {
          if (mounted) setState(() => _uploading[key] = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _images[key] = url;
        _uploading.remove(key);
        _dirty = true;
      });
      _showMessage('Image uploaded — press Save to publish it.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading.remove(key));
      _showMessage('Upload failed: $e', error: true);
    }
  }

  void _resetImage(String key) => setState(() {
        _images.remove(key);
        _dirty = true;
      });

  // ── Save ─────────────────────────────────────────────────────────────────

  HomeItemOverride _overrideFor(String key) => HomeItemOverride(
        labelAr:  _ar[key]!.text.trim(),
        labelEl:  _el[key]!.text.trim(),
        imageUrl: _images[key] ?? '',
      );

  Future<void> _save() async {
    if (_uploading.isNotEmpty) {
      _showMessage('Wait for the image upload to finish.', error: true);
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final layout = HomeLayoutModel(
        bannerUrl: _images[_kBannerKey] ?? '',
        tiles: {for (final d in homeTileDefs) d.key: _overrideFor(d.key)},
        sections: {
          for (final d in homeSectionDefs)
            d.key: HomeItemOverride(
              labelAr: _ar[d.key]!.text.trim(),
              labelEl: _el[d.key]!.text.trim(),
            ),
        },
      );
      await Future.wait([
        _repo.save(layout),
        _labelRepo.save(CategoryLabel(
          category: PdfCategory.artworks,
          labelAr:  _ar[PdfCategory.artworks]!.text.trim(),
          labelEl:  _el[PdfCategory.artworks]!.text.trim(),
        )),
      ]);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _showMessage('Saved — the app updates instantly.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Failed: $e', error: true);
    }
  }

  void _showMessage(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _messageIsError = error;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);

    return Scaffold(
      backgroundColor: ac.bgPrimary,
      appBar: AppBar(
        backgroundColor: ac.bgDeep,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home Screen',
                style: TextStyle(
                    color: ac.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            Text('الشاشة الرئيسية • Αρχική Οθόνη',
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary,
                    fontSize: 11)),
          ],
        ),
        actions: [
          if (_saving)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _loading ? null : _save,
              icon: Icon(
                _dirty ? Icons.save : Icons.save_outlined,
                color: ac.gold,
                size: 18,
              ),
              label: Text(_dirty ? 'Save *' : 'Save',
                  style:
                      TextStyle(color: ac.gold, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                strokeWidth: 2,
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_message.isNotEmpty) _messageBanner(),
                    Text(
                      'Leave a field empty to keep the built-in text (shown '
                      'in grey). Changes go live for all users when you '
                      'press Save.',
                      style: TextStyle(color: ac.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    // ── Header banner ───────────────────────────────────
                    _FormCard(
                      label: 'Header banner • صورة الغلاف',
                      child: _bannerEditor(ac),
                    ),
                    const SizedBox(height: 16),

                    // ── Tiles ───────────────────────────────────────────
                    _FormCard(
                      label: 'Content Library tiles • أقسام المكتبة',
                      child: Column(
                        children: [
                          for (var i = 0; i < homeTileDefs.length; i++) ...[
                            if (i > 0)
                              Divider(color: ac.goldBorder, height: 24),
                            _tileEditor(ac, homeTileDefs[i]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Section titles ──────────────────────────────────
                    _sectionGroupCard(
                      ac,
                      'Home section titles • عناوين الأقسام',
                      HomeSectionGroup.home,
                    ),
                    const SizedBox(height: 16),
                    _sectionGroupCard(
                      ac,
                      'Side menu • القائمة الجانبية',
                      HomeSectionGroup.drawer,
                      extra: _BilingualFields(
                        arCtrl: _ar[PdfCategory.artworks]!,
                        elCtrl: _el[PdfCategory.artworks]!,
                        defaultAr: PdfCategory.labelAr[PdfCategory.artworks]!,
                        defaultEl: PdfCategory.labelEl[PdfCategory.artworks]!,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionGroupCard(
                      ac,
                      'Bottom navigation tabs • أزرار التنقل السفلية',
                      HomeSectionGroup.bottomNav,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _messageBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _messageIsError
              ? const Color(0xFF8C2B2B).withValues(alpha: 0.12)
              : const Color(0xFF2E7D52).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_message,
            style: TextStyle(
              color: _messageIsError
                  ? const Color(0xFFE57373)
                  : const Color(0xFF3A8C5A),
              fontSize: 12,
            )),
      );

  Widget _bannerEditor(AdminC ac) {
    final url = _images[_kBannerKey] ?? '';
    const fallback = Image(
      image: AssetImage('assets/images/Banner.png'),
      fit: BoxFit.cover,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url.isEmpty)
                  fallback
                else
                  CachedImage(
                    url: url,
                    fit: BoxFit.cover,
                    errorWidget: fallback,
                  ),
                if (_uploading.containsKey(_kBannerKey))
                  _UploadOverlay(progress: _uploading[_kBannerKey]!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ImageButtons(
          hasCustom: url.isNotEmpty,
          busy: _uploading.containsKey(_kBannerKey),
          onPick: () => _pickImage(_kBannerKey),
          onReset: () => _resetImage(_kBannerKey),
        ),
      ],
    );
  }

  Widget _tileEditor(AdminC ac, HomeTileDef d) {
    final url = _images[d.key] ?? '';
    final busy = _uploading.containsKey(d.key);

    Widget defaultArt() => d.asset.isEmpty
        ? Container(
            color: d.bgColor,
            child: Icon(Icons.calendar_month, color: ac.gold, size: 30),
          )
        : Image.asset(d.asset, fit: BoxFit.cover);

    final thumb = SizedBox(
      width: 84,
      height: 84,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: d.bgColor),
            if (url.isEmpty)
              defaultArt()
            else
              CachedImage(
                url: url,
                fit: BoxFit.cover,
                errorWidget: defaultArt(),
              ),
            if (busy) _UploadOverlay(progress: _uploading[d.key]!),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            thumb,
            const SizedBox(height: 6),
            if (d.allowImage)
              SizedBox(
                width: 84,
                child: _ImageButtons(
                  compact: true,
                  hasCustom: url.isNotEmpty,
                  busy: busy,
                  onPick: () => _pickImage(d.key),
                  onReset: () => _resetImage(d.key),
                ),
              )
            else
              SizedBox(
                width: 84,
                child: Text(
                  'Shows today’s date',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ac.textSecondary, fontSize: 9),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _BilingualFields(
            arCtrl: _ar[d.key]!,
            elCtrl: _el[d.key]!,
            defaultAr: d.defaultLabel(AppL10n.ar),
            defaultEl: d.defaultLabel(AppL10n.el),
          ),
        ),
      ],
    );
  }

  Widget _sectionGroupCard(
    AdminC ac,
    String title,
    HomeSectionGroup group, {
    Widget? extra,
  }) {
    final defs = homeSectionDefs.where((d) => d.group == group).toList();
    final children = <Widget>[
      for (final d in defs)
        _BilingualFields(
          arCtrl: _ar[d.key]!,
          elCtrl: _el[d.key]!,
          defaultAr: d.defaultLabel(AppL10n.ar),
          defaultEl: d.defaultLabel(AppL10n.el),
        ),
      ?extra,
    ];
    return _FormCard(
      label: title,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ── Bilingual name fields (Arabic + Greek) ───────────────────────────────────

class _BilingualFields extends StatelessWidget {
  const _BilingualFields({
    required this.arCtrl,
    required this.elCtrl,
    required this.defaultAr,
    required this.defaultEl,
  });

  final TextEditingController arCtrl;
  final TextEditingController elCtrl;
  final String defaultAr;
  final String defaultEl;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final ar = _Field(
      controller: arCtrl,
      label: 'Arabic • عربي',
      hint: defaultAr,
      rtl: true,
    );
    final el = _Field(
      controller: elCtrl,
      label: 'Greek • Ελληνικά',
      hint: defaultEl,
    );
    final fields = LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 520
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ar),
                const SizedBox(width: 12),
                Expanded(child: el),
              ],
            )
          : Column(children: [ar, const SizedBox(height: 10), el]),
    );
    // Header naming the item by its built-in name, so it stays identifiable
    // after the admin has typed over the hints.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$defaultAr  •  $defaultEl',
          style: TextStyle(
            color: ac.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Scheherazade',
          ),
        ),
        const SizedBox(height: 6),
        fields,
      ],
    );
  }
}

// ── Change / reset image buttons ─────────────────────────────────────────────

class _ImageButtons extends StatelessWidget {
  const _ImageButtons({
    required this.hasCustom,
    required this.busy,
    required this.onPick,
    required this.onReset,
    this.compact = false,
  });

  final bool hasCustom;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onReset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final style = TextStyle(color: ac.gold, fontSize: compact ? 10 : 12);
    final change = TextButton(
      onPressed: busy ? null : onPick,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('Change image', style: style),
    );
    final reset = TextButton(
      onPressed: busy ? null : onReset,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('Use default',
          style: style.copyWith(color: ac.textSecondary)),
    );
    return compact
        ? Column(children: [change, if (hasCustom) reset])
        : Wrap(spacing: 8, children: [change, if (hasCustom) reset]);
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            value: progress > 0 && progress < 1 ? progress : null,
            strokeWidth: 2.5,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C)),
          ),
        ),
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
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
    this.rtl = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool rtl;

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
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            color: ac.textPrimary,
            fontSize: rtl ? 16 : 14,
            fontFamily: rtl ? 'Scheherazade' : 'GFSDidot',
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintTextDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            hintStyle: TextStyle(
              color: ac.textSecondary.withValues(alpha: 0.5),
              fontSize: 13,
              fontFamily: rtl ? 'Scheherazade' : 'GFSDidot',
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, _) => v.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Use default',
                      icon: Icon(Icons.close,
                          size: 16, color: ac.textSecondary),
                      onPressed: controller.clear,
                    ),
            ),
            filled: true,
            fillColor: ac.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ac.gold, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
