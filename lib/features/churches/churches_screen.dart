// lib/features/churches/churches_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// User-facing Churches screen — two tabs:
//   1. Churches  → bishop card + list of church cards (name + maps button)
//   2. Priests   → flat list of all priests across all churches
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/bishop_model.dart';
import '../../data/models/church_model.dart';
import '../../data/repositories/bishop_repository.dart';
import '../../data/repositories/churches_repository.dart';
import 'churches_cubit.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class ChurchesScreen extends StatelessWidget {
  const ChurchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChurchesCubit(sl<ChurchesRepository>())..load(),
      child: const _ChurchesView(),
    );
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _ChurchesView extends StatefulWidget {
  const _ChurchesView();

  @override
  State<_ChurchesView> createState() => _ChurchesViewState();
}

class _ChurchesViewState extends State<_ChurchesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final l = context.l10n;

    return Scaffold(
      backgroundColor: bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: bgDeep,
                border: Border(
                  bottom: BorderSide(color: goldBorder, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new,
                            color: gold, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.churches,
                              style: TextStyle(
                                color: textPrimary,
                                fontFamily: l.bodyFont,
                                fontSize: l.isAr ? 20 : 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              l.churchesTitleAlt,
                              style: TextStyle(
                                color: textSecondary,
                                fontFamily: l.isAr ? null : 'Scheherazade',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Tab bar ───────────────────────────────────────────
                  TabBar(
                    controller: _tab,
                    labelColor: gold,
                    unselectedLabelColor: textSecondary,
                    indicatorColor: gold,
                    indicatorWeight: 2,
                    labelStyle: TextStyle(
                      fontFamily: l.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontFamily: l.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: l.churches),
                      Tab(text: l.priests),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tab views ─────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<ChurchesCubit, ChurchesState>(
                builder: (context, state) {
                  if (state is ChurchesLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: gold,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (state is ChurchesError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: TextStyle(
                          color: BrightnessColors.maroon(brightness),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  if (state is ChurchesLoaded) {
                    return TabBarView(
                      controller: _tab,
                      children: [
                        _ChurchesTab(churches: state.churches),
                        _PriestsTab(churches: state.churches),
                      ],
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Churches ───────────────────────────────────────────────────────────

class _ChurchesTab extends StatelessWidget {
  const _ChurchesTab({required this.churches});
  final List<ChurchModel> churches;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final l = context.l10n;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: churches.isEmpty ? 2 : churches.length + 1,
      itemBuilder: (_, i) {
        // Slot 0 → bishop card
        if (i == 0) return _BishopCard(repo: sl<BishopRepository>());

        // Empty state
        if (churches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✦', style: TextStyle(color: goldBorder, fontSize: 36)),
                  const SizedBox(height: 12),
                  Text(
                    l.noChurches,
                    style: TextStyle(
                      color: textSecondary,
                      fontFamily: l.bodyFont,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _ChurchCard(church: churches[i - 1]);
      },
    );
  }
}

// ── Tab 2: Priests ────────────────────────────────────────────────────────────

class _PriestsTab extends StatelessWidget {
  const _PriestsTab({required this.churches});
  final List<ChurchModel> churches;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final teal = BrightnessColors.tealMid(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final l = context.l10n;

    // Build a flat list: {priest, churchName}
    final items = <({PriestModel priest, String churchName})>[];
    for (final church in churches) {
      final name = l.isAr ? church.nameAr : church.nameEn;
      for (final p in church.priests) {
        items.add((priest: p, churchName: name));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✦', style: TextStyle(color: goldBorder, fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              l.noPriests,
              style: TextStyle(
                color: textSecondary,
                fontFamily: l.bodyFont,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _PriestListCard(
          priest: item.priest,
          churchName: item.churchName,
          gold: gold,
          teal: teal,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          goldBorder: goldBorder,
          l: l,
        );
      },
    );
  }
}

// ── Bishop card ───────────────────────────────────────────────────────────────

class _BishopCard extends StatelessWidget {
  const _BishopCard({required this.repo});
  final BishopRepository repo;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = BrightnessColors.gold(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final teal = BrightnessColors.tealMid(brightness);
    final l = context.l10n;

    return StreamBuilder<BishopModel?>(
      stream: repo.watch(),
      builder: (context, snap) {
        final bishop = snap.data;
        if (bishop == null || bishop.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: goldBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (bishop.imageUrl.isNotEmpty) ...[
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: goldBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withValues(alpha: 0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    bishop.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person_outline, color: gold, size: 44),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (bishop.titleEl.isNotEmpty)
                Text(
                  bishop.titleEl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontFamily: l.isAr ? null : 'GFSDidot',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              if (bishop.titleEl.isNotEmpty && bishop.titleAr.isNotEmpty)
                const SizedBox(height: 6),
              if (bishop.titleAr.isNotEmpty)
                Text(
                  bishop.titleAr,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: teal,
                    fontFamily: 'Scheherazade',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Church card (Churches tab) ────────────────────────────────────────────────

class _ChurchCard extends StatelessWidget {
  const _ChurchCard({required this.church});
  final ChurchModel church;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final l = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldBorder, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            // ── Cross icon ────────────────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgMid,
                shape: BoxShape.circle,
                border: Border.all(
                  color: gold.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '☩',
                  style: TextStyle(color: gold, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Names ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isAr ? church.nameAr : church.nameEn,
                    textDirection: l.dir,
                    style: TextStyle(
                      color: textPrimary,
                      fontFamily: l.bodyFont,
                      fontSize: l.isAr ? 17 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (church.nameEn.isNotEmpty && church.nameAr.isNotEmpty)
                    Text(
                      l.isAr ? church.nameEn : church.nameAr,
                      style: TextStyle(
                        color: textSecondary,
                        fontFamily: l.isAr ? null : 'Scheherazade',
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // ── Maps button ───────────────────────────────────────────────
            if (church.mapsUrl.isNotEmpty)
              _MapsButton(url: church.mapsUrl, label: l.openMaps),
          ],
        ),
      ),
    );
  }
}

// ── Priest card (Priests tab) ─────────────────────────────────────────────────

class _PriestListCard extends StatelessWidget {
  const _PriestListCard({
    required this.priest,
    required this.churchName,
    required this.gold,
    required this.teal,
    required this.textPrimary,
    required this.textSecondary,
    required this.goldBorder,
    required this.l,
  });

  final PriestModel priest;
  final String churchName;
  final Color gold;
  final Color teal;
  final Color textPrimary;
  final Color textSecondary;
  final Color goldBorder;
  final AppL10n l;

  Future<void> _dial() async {
    final uri = Uri(scheme: 'tel', path: priest.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: teal.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: priest.imageUrl.isNotEmpty
                  ? Image.network(
                      priest.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),
          const SizedBox(width: 12),

          // ── Name + church ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.isAr ? priest.nameAr : priest.nameEn,
                  textDirection: l.dir,
                  style: TextStyle(
                    color: textPrimary,
                    fontFamily: l.bodyFont,
                    fontSize: l.isAr ? 16 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (priest.nameEn.isNotEmpty && priest.nameAr.isNotEmpty)
                  Text(
                    l.isAr ? priest.nameEn : priest.nameAr,
                    style: TextStyle(
                      color: textSecondary,
                      fontFamily: l.isAr ? null : 'Scheherazade',
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.church_outlined, color: gold, size: 11),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        churchName,
                        textDirection: l.dir,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: gold,
                          fontFamily: l.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Call button ───────────────────────────────────────────────
          if (priest.phone.isNotEmpty)
            GestureDetector(
              onTap: _dial,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: teal.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_outlined, color: teal, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        priest.phone,
                        style: TextStyle(
                          color: teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
    color: teal.withValues(alpha: 0.1),
    child: Icon(Icons.person_outlined, color: teal, size: 24),
  );
}

// ── Maps button ───────────────────────────────────────────────────────────────

class _MapsButton extends StatelessWidget {
  const _MapsButton({required this.url, required this.label});
  final String url;
  final String label;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4285F4);
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
