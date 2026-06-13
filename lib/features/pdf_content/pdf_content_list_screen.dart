// lib/features/pdf_content/pdf_content_list_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// User-facing screen: list of PDF items for a content category
// (Psalmody, Liturgies, Readings, Hymns, Occasions).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/widgets/cached_image.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/pdf_content_model.dart';
import '../../data/repositories/pdf_content_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _stream = sl<PdfContentRepository>().watchVisible(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Scaffold(
      backgroundColor: BrightnessColors.bgDeep(brightness),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, brightness, isGreek),
          SliverToBoxAdapter(
            child: StreamBuilder<List<PdfContent>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _ShimmerList(brightness: brightness);
                }
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: isGreek
                        ? 'Σφάλμα φόρτωσης'
                        : 'حدث خطأ في تحميل المحتوى',
                    onRetry: () => setState(() {}),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return _EmptyView(isGreek: isGreek);
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
        tooltip: isGreek ? 'Πίσω' : 'رجوع',
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
                    'LIBRARY',
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
              audioTracks: items[i].audioTracks,
            ),
          ),
        ),
      ),
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
                      maxLines: 1,
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

            // ── Chevron ──────────────────────────────────────────────────
            Icon(Icons.chevron_right, color: gold.withOpacity(0.5), size: 20),
          ],
        ),
      ),
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
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Scheherazade'),
                ),
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
