// lib/features/pdf_content/pdf_content_list_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// User-facing screen: list of PDF items for a content category
// (Psalmody, Liturgies, Readings, Hymns, Occasions).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/cached_image.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/artwork_section_model.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/repositories/artwork_section_repository.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/pdf_content_repository.dart';
import '../../data/repositories/section_description_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import 'generic_pdf_viewer_screen.dart';

class PdfContentListScreen extends StatefulWidget {
  const PdfContentListScreen({
    super.key,
    required this.category,
    required this.labelAr,
    required this.labelEl,
  });

  final String category;
  final String labelAr;
  final String labelEl;

  @override
  State<PdfContentListScreen> createState() => _PdfContentListScreenState();
}

class _PdfContentListScreenState extends State<PdfContentListScreen> {
  late final Stream<List<PdfContent>> _stream;
  late final Stream<SectionDescription?> _sectionStream;

  @override
  void initState() {
    super.initState();
    _stream = sl<PdfContentRepository>().watchVisible(widget.category);
    _sectionStream =
        sl<SectionDescriptionRepository>().watch(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l = context.l10n;
    final isGreek = !l.isAr;

    return Scaffold(
      backgroundColor: BrightnessColors.bgDeep(brightness),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, brightness, isGreek),
          SliverToBoxAdapter(
            child: StreamBuilder<SectionDescription?>(
              stream: _sectionStream,
              builder: (context, snap) {
                final section = snap.data;
                if (section == null || section.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _SectionDescriptionCard(
                  section: section,
                  brightness: brightness,
                  isGreek: isGreek,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<PdfContent>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _ShimmerList(brightness: brightness);
                }
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: l.loadingError,
                    onRetry: () => setState(() {}),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return _EmptyView(isGreek: isGreek);
                }
                // Art Works items open a cover + description detail view
                // instead of a PDF, and are grouped into admin-editable
                // sections (see ArtworkSectionRepository) rather than shown
                // as a single flat list.
                if (widget.category == PdfCategory.artworks) {
                  return _GroupedArtworkBody(
                    items: items,
                    brightness: brightness,
                    isGreek: isGreek,
                  );
                }
                // The theses tab is the one category split into two
                // sections on open (Masters / Doctoral) rather than shown
                // as a single flat list — everything else is unaffected.
                if (widget.category == PdfCategory.theses) {
                  return _GroupedThesesBody(
                    items: items,
                    brightness: brightness,
                    isGreek: isGreek,
                  );
                }
                return _ItemList(
                  items: items,
                  brightness: brightness,
                  isGreek: isGreek,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    Brightness brightness,
    bool isGreek,
  ) {
    final l = context.l10n;
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final bgDeep = BrightnessColors.bgDeep(brightness);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: bgDeep,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: goldLight, size: 18),
        onPressed: () => Navigator.pop(context),
        tooltip: l.back,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: BrightnessColors.headerGradient(brightness),
            border: Border(
              bottom: BorderSide(color: goldBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✦',
                    style: TextStyle(color: goldDim, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGreek ? widget.labelEl : widget.labelAr,
                    style: TextStyle(
                      fontFamily: isGreek ? null : 'Scheherazade',
                      color: goldLight,
                      fontSize: isGreek ? 20 : 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: isGreek ? 2.0 : 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.librarySubtitle,
                    style: TextStyle(
                      color: goldDim,
                      fontSize: 9,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 0.5,
          color: goldBorder,
        ),
      ),
    );
  }
}

// ── Section description card ────────────────────────────────────────────────
// Constant card at the top of the screen — describes the whole category
// (e.g. Art Works), not a single item. Editable from the admin CMS via
// SectionDescriptionRepository. Shows Arabic + Greek body text plus a row of
// "available at" buttons that open their linked URL.

class _SectionDescriptionCard extends StatelessWidget {
  const _SectionDescriptionCard({
    required this.section,
    required this.brightness,
    required this.isGreek,
  });

  final SectionDescription section;
  final Brightness brightness;
  final bool isGreek;

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = BrightnessColors.gold(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (section.descriptionAr.isNotEmpty)
              Text(
                section.descriptionAr,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            if (section.descriptionAr.isNotEmpty &&
                section.descriptionEl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: goldBorder, height: 1),
              ),
            if (section.descriptionEl.isNotEmpty)
              Text(
                section.descriptionEl,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            if (section.hasLinks) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment:
                    isGreek ? WrapAlignment.start : WrapAlignment.end,
                children: section.links
                    .where((l) => l.url.isNotEmpty)
                    .map((l) => OutlinedButton.icon(
                          onPressed: () => _openLink(l.url),
                          icon: Icon(Icons.open_in_new, size: 14, color: gold),
                          label: Text(
                            l.labelFor(isGreek ? 'el' : 'ar'),
                            style: TextStyle(
                              fontFamily: isGreek ? null : 'Scheherazade',
                              fontSize: 13,
                              color: gold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: gold, width: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Item List ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.brightness,
    required this.isGreek,
  });

  final List<PdfContent> items;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ItemCard(
        item: items[i],
        brightness: brightness,
        isGreek: isGreek,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GenericPdfViewerScreen(
              url:         items[i].pdfUrl,
              titleAr:     items[i].titleAr,
              titleEl:     items[i].titleEl,
              contentId:   items[i].id,
              category:    items[i].category,
              audioTracks: items[i].audioTracks,
              videoUrl:    items[i].videoUrl,
              coverUrl:    items[i].coverUrl,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Grouped Art Works body — admin-editable sections ────────────────────────
// Splits artwork items by the admin-managed [ArtworkSection] they were
// assigned (see ArtworkSectionRepository / ArtworkSectionManagerScreen).
// Items with no section (or a section that no longer exists) fall into a
// trailing "Other" bucket instead of disappearing, mirroring the theses
// category's "unspecified" fallback. When no sections have been created yet,
// this renders as one plain grid — identical to the pre-sections behavior.

class _GroupedArtworkBody extends StatelessWidget {
  const _GroupedArtworkBody({
    required this.items,
    required this.brightness,
    required this.isGreek,
  });

  final List<PdfContent> items;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ArtworkSection>>(
      stream: sl<ArtworkSectionRepository>().watchSections(),
      builder: (context, snap) {
        final sections = snap.data ?? const <ArtworkSection>[];

        // No sections defined — keep the original flat-grid behavior.
        if (sections.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _ArtworkGrid(
              items: items,
              brightness: brightness,
              isGreek: isGreek,
            ),
          );
        }

        final sectionIds = sections.map((s) => s.id).toSet();
        final grouped = <String, List<PdfContent>>{
          for (final s in sections) s.id: [],
        };
        final other = <PdfContent>[];
        for (final item in items) {
          if (sectionIds.contains(item.sectionId)) {
            grouped[item.sectionId]!.add(item);
          } else {
            other.add(item);
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in sections)
                if (grouped[section.id]!.isNotEmpty) ...[
                  _SectionHeader(
                    label: isGreek ? section.nameFor('el') : section.nameAr,
                    brightness: brightness,
                    isGreek: isGreek,
                  ),
                  const SizedBox(height: 10),
                  _ArtworkGrid(
                    items: grouped[section.id]!,
                    brightness: brightness,
                    isGreek: isGreek,
                  ),
                  const SizedBox(height: 20),
                ],
              if (other.isNotEmpty) ...[
                _SectionHeader(
                  label: isGreek ? 'Λοιπά' : 'أخرى',
                  brightness: brightness,
                  isGreek: isGreek,
                ),
                const SizedBox(height: 10),
                _ArtworkGrid(
                  items: other,
                  brightness: brightness,
                  isGreek: isGreek,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Art Works grid ────────────────────────────────────────────────────────────
// Showcase cards — cover image on top, name below. Unlike every other
// PdfContent category there is no PDF to open; tapping a card instead shows
// the cover image plus the item's bilingual description.

class _ArtworkGrid extends StatelessWidget {
  const _ArtworkGrid({
    required this.items,
    required this.brightness,
    required this.isGreek,
  });

  final List<PdfContent> items;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ArtworkCard(
        item: items[i],
        brightness: brightness,
        isGreek: isGreek,
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({
    required this.item,
    required this.brightness,
    required this.isGreek,
  });

  final PdfContent item;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ArtworkDetailScreen(item: item, isGreek: isGreek),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Hero(
                tag: 'artwork_${item.id}',
                child: item.coverUrl.isNotEmpty
                    ? CachedImage(
                        url: item.coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: bgElevated,
                          child: Icon(Icons.palette_outlined,
                              color: goldBorder, size: 32),
                        ),
                      )
                    : Container(
                        color: bgElevated,
                        child: Icon(Icons.palette_outlined,
                            color: goldBorder, size: 32),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    item.titleAr,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (item.titleEl.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.titleEl,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Art Work detail ───────────────────────────────────────────────────────────
// Opened by tapping an artwork card: full cover image plus the item's
// bilingual description (Arabic + Greek) — there is no PDF to open for this
// category.

class _ArtworkDetailScreen extends StatelessWidget {
  const _ArtworkDetailScreen({required this.item, required this.isGreek});

  final PdfContent item;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: bgDeep,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgDeep.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: goldBorder, width: 0.5),
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 16, color: goldLight),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'artwork_${item.id}',
                child: item.coverUrl.isNotEmpty
                    ? CachedImage(url: item.coverUrl, fit: BoxFit.cover)
                    : Container(
                        color: bgElevated,
                        child: Icon(Icons.palette_outlined,
                            color: goldBorder, size: 56),
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.titleAr,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  if (item.titleEl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.titleEl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (item.hasDescription) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child:
                                Container(height: 0.5, color: goldBorder)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('✦',
                              style: TextStyle(
                                  color: goldBorder, fontSize: 12)),
                        ),
                        Expanded(
                            child:
                                Container(height: 0.5, color: goldBorder)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (item.descriptionAr.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgMid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: goldBorder, width: 0.5),
                        ),
                        child: Text(
                          item.descriptionAr,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Scheherazade',
                            color: textPrimary,
                            fontSize: 16,
                            height: 1.8,
                          ),
                        ),
                      ),
                    if (item.descriptionAr.isNotEmpty &&
                        item.descriptionEl.isNotEmpty)
                      const SizedBox(height: 14),
                    if (item.descriptionEl.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgMid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: goldBorder, width: 0.5),
                        ),
                        child: Text(
                          item.descriptionEl,
                          textAlign: TextAlign.left,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 15,
                            height: 1.7,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grouped theses body — Masters / Doctoral sections ───────────────────────────
// Items uploaded before the level field existed (or left unset by mistake)
// fall into a third "unspecified" section instead of silently disappearing.

class _GroupedThesesBody extends StatelessWidget {
  const _GroupedThesesBody({
    required this.items,
    required this.brightness,
    required this.isGreek,
  });

  final List<PdfContent> items;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final masters =
        items.where((i) => i.level == ThesisLevel.masters).toList();
    final doctoral =
        items.where((i) => i.level == ThesisLevel.doctoral).toList();
    final other = items
        .where((i) =>
            i.level != ThesisLevel.masters && i.level != ThesisLevel.doctoral)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (masters.isNotEmpty) ...[
            _SectionHeader(
                label: l.masterTheses, brightness: brightness, isGreek: isGreek),
            const SizedBox(height: 10),
            _ItemList(items: masters, brightness: brightness, isGreek: isGreek),
            const SizedBox(height: 20),
          ],
          if (doctoral.isNotEmpty) ...[
            _SectionHeader(
                label: l.doctoralTheses, brightness: brightness, isGreek: isGreek),
            const SizedBox(height: 10),
            _ItemList(items: doctoral, brightness: brightness, isGreek: isGreek),
            const SizedBox(height: 20),
          ],
          if (other.isNotEmpty) ...[
            _SectionHeader(
                label: l.unspecifiedTheses, brightness: brightness, isGreek: isGreek),
            const SizedBox(height: 10),
            _ItemList(items: other, brightness: brightness, isGreek: isGreek),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.brightness,
    required this.isGreek,
  });

  final String label;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Row(
      textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: goldLight,
            fontSize: isGreek ? 14 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: goldBorder, height: 1)),
      ],
    );
  }
}

// ── Item Card ─────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.brightness,
    required this.isGreek,
    required this.onTap,
  });

  final PdfContent item;
  final Brightness brightness;
  final bool isGreek;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // ── Cover thumbnail ──────────────────────────────────────────
            _CoverThumbnail(
              coverUrl: item.coverUrl,
              titleAr: item.titleAr,
              bgElevated: bgElevated,
              goldBorder: goldBorder,
            ),
            const SizedBox(width: 12),

            // ── Title block ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: isGreek
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    item.titleAr,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  if (item.titleEl.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.titleEl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Audio badge (when tracks available) ──────────────────────
            if (item.hasAudio)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color:        gold.withOpacity(0.12),
                  shape:        BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.35), width: 0.8),
                ),
                child: Icon(Icons.music_note,
                    size: 12, color: gold.withOpacity(0.8)),
              ),

            // ── Bookmark toggle ────────────────────────────────────────────
            _BookmarkToggle(item: item, gold: gold),

            // ── Chevron ──────────────────────────────────────────────────
            Icon(Icons.chevron_right, color: gold.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Bookmark toggle (whole-item) ─────────────────────────────────────────────
// Tapping does NOT open the item (wrapped so its own GestureDetector eats
// the tap before it reaches the card's onTap).

class _BookmarkToggle extends StatelessWidget {
  const _BookmarkToggle({required this.item, required this.gold});

  final PdfContent item;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final repo = sl<BookmarkRepository>();
    return StreamBuilder<bool>(
      stream: repo.watchIsContentBookmarked(contentId: item.id),
      builder: (context, snap) {
        final isBookmarked = snap.data ?? false;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            try {
              await repo.toggleContentBookmark(
                contentId: item.id,
                category:  item.category,
                titleAr:   item.titleAr,
                titleEl:   item.titleEl,
                coverUrl:  item.coverUrl,
                pdfUrl:    item.pdfUrl,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('تعذّر حفظ الإشارة المرجعية: $e'),
                  backgroundColor: Colors.red.shade800,
                ));
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: isBookmarked ? gold : gold.withOpacity(0.4),
            ),
          ),
        );
      },
    );
  }
}

// ── Cover Thumbnail ───────────────────────────────────────────────────────────

class _CoverThumbnail extends StatelessWidget {
  const _CoverThumbnail({
    required this.coverUrl,
    required this.titleAr,
    required this.bgElevated,
    required this.goldBorder,
  });

  final String coverUrl;
  final String titleAr;
  final Color bgElevated;
  final Color goldBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: goldBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CachedImage(
          url: coverUrl,
          fit: BoxFit.cover,
          errorWidget: _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    final firstChar = titleAr.isNotEmpty ? titleAr[0] : '✦';
    return Container(
      color: bgElevated,
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            fontFamily: 'Scheherazade',
            color: Color(0xFFC8A84B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Placeholder ───────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList({required this.brightness});
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _ShimmerCard(brightness: brightness),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.brightness});
  final Brightness brightness;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(widget.brightness);
    final bgElevated = BrightnessColors.bgElevated(widget.brightness);
    final goldBorder = BrightnessColors.goldBorder(widget.brightness);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 52,
              height: 56,
              decoration: BoxDecoration(
                color: bgElevated.withOpacity(_anim.value),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(width: 12),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: bgElevated.withOpacity(_anim.value),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.55,
                    alignment: Alignment.centerRight,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: bgElevated.withOpacity(_anim.value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty View ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 56, color: goldDim),
              const SizedBox(height: 16),
              Text(
                isGreek ? 'Δεν βρέθηκαν αρχεία' : 'لا يوجد محتوى متاح',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: textSecondary,
                  fontSize: isGreek ? 15 : 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isGreek
                    ? 'Ελέγξτε ξανά αργότερα'
                    : 'تحقق مرة أخرى لاحقاً',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: textSecondary.withOpacity(0.6),
                  fontSize: isGreek ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final goldDim = BrightnessColors.goldDim(brightness);

    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: goldDim,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.l10n.retry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC8A84B),
                  side: const BorderSide(color: Color(0xFFC8A84B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
