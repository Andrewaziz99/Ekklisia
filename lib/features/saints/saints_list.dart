// lib/features/saints/saints_list.dart
// ─────────────────────────────────────────────────────────────────────────────
// User-facing Saints list screen.
// Shows a searchable grid of saint cards. Tapping opens SaintDetailScreen.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/brightness_colors.dart';
import '../../core/theme/colors.dart';
import '../../data/models/saint_model.dart';
import '../../data/repositories/saints_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/cached_image.dart';
import 'saint_detail.dart';
import 'saints_cubit.dart';

class SaintsListScreen extends StatelessWidget {
  const SaintsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SaintsCubit(sl<SaintsRepository>())..load(),
      child: const _SaintsListView(),
    );
  }
}

class _SaintsListView extends StatefulWidget {
  const _SaintsListView();

  @override
  State<_SaintsListView> createState() => _SaintsListViewState();
}

class _SaintsListViewState extends State<_SaintsListView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );

    return Scaffold(
      backgroundColor: BrightnessColors.bgDeep(brightness),
      body: SafeArea(
        child: Column(children: [
          // ── Header ───────────────────────────────────────────────────────
          _Header(onSearch: (q) => setState(() => _query = q)),

          // ── Grid ─────────────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<SaintsCubit, SaintsState>(
              builder: (context, state) {
                final br = Theme.of(context).brightness;

                if (state is SaintsLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: BrightnessColors.gold(br), strokeWidth: 2),
                  );
                }
                if (state is SaintsError) {
                  return Center(
                    child: Text(state.message,
                        style: TextStyle(
                            color: BrightnessColors.maroon(br), fontSize: 13)),
                  );
                }
                if (state is SaintsLoaded) {
                  final saints = _filter(state.saints);
                  if (saints.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('✦',
                              style: TextStyle(
                                  color: BrightnessColors.goldBorder(br),
                                  fontSize: 36)),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? (isGreek ? 'Δεν βρέθηκαν αγίοι' : 'لا يوجد قديسون')
                                : (isGreek
                                    ? 'Δεν βρέθηκαν αποτελέσματα για "$_query"'
                                    : 'لا توجد نتائج لـ "$_query"'),
                            style: TextStyle(
                                color: BrightnessColors.textSecondary(br),
                                fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: saints.length,
                    itemBuilder: (_, i) => _SaintCard(saint: saints[i]),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ]),
      ),
    );
  }

  List<SaintModel> _filter(List<SaintModel> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((s) =>
            s.nameEn.toLowerCase().contains(q) || s.nameAr.contains(q))
        .toList();
  }
}

// ── Header with search ────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  const _Header({required this.onSearch});
  final void Function(String) onSearch;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _searching = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgDeep      = BrightnessColors.bgDeep(brightness);
    final bgMid       = BrightnessColors.bgMid(brightness);
    final gold        = BrightnessColors.gold(brightness);
    final goldBorder  = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: bgDeep,
        border: Border(
            bottom: BorderSide(color: goldBorder, width: 0.5)),
      ),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: gold, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _searching
              ? TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isGreek ? 'Αναζήτηση...' : 'بحث...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: bgMid,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: goldBorder, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: goldBorder, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: gold, width: 1),
                    ),
                  ),
                  onChanged: widget.onSearch,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isGreek ? 'Άγιοι' : 'القديسون',
                        style: TextStyle(
                          color: textPrimary,
                          fontFamily: isGreek ? null : 'Scheherazade',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(
                        isGreek ? 'القديسون' : 'Άγιοι',
                        style: TextStyle(
                          color: textSecondary,
                          fontFamily: isGreek ? 'Scheherazade' : null,
                          fontSize: 14,
                        )),
                  ],
                ),
        ),
        IconButton(
          icon: Icon(
            _searching ? Icons.close : Icons.search,
            color: gold,
          ),
          onPressed: () {
            setState(() => _searching = !_searching);
            if (!_searching) {
              _ctrl.clear();
              widget.onSearch('');
            }
          },
        ),
      ]),
    );
  }
}

// ── Saint card ────────────────────────────────────────────────────────────────

class _SaintCard extends StatelessWidget {
  const _SaintCard({required this.saint});
  final SaintModel saint;

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgElevated  = BrightnessColors.bgElevated(brightness);
    final bgMid       = BrightnessColors.bgMid(brightness);
    final gold        = BrightnessColors.gold(brightness);
    final goldBorder  = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SaintDetailScreen(saint: saint),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9)),
                child: saint.hasImage
                    ? CachedImage(
                        url: saint.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: _placeholder(bgMid, goldBorder),
                      )
                    : _placeholder(bgMid, goldBorder),
              ),
            ),

            // Name
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                saint.nameAr,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontFamily: 'Scheherazade',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Text(
                saint.nameEn,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textSecondary, fontSize: 10),
              ),
            ),

            // Feast date chip
            if (saint.feastDate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: gold.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Text(
                      saint.feastDate!,
                      style: TextStyle(
                        color: gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // Media indicator dots
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (saint.hasPdf)
                    _MediaDot(
                        color: EkklisiaColors.bronze,
                        icon: Icons.picture_as_pdf_outlined),
                  if (saint.hasAudio) ...[
                    if (saint.hasPdf) const SizedBox(width: 4),
                    _MediaDot(
                        color: BrightnessColors.tealMid(brightness),
                        icon: Icons.headphones_outlined),
                  ],
                  if (saint.hasVideo) ...[
                    if (saint.hasPdf || saint.hasAudio)
                      const SizedBox(width: 4),
                    _MediaDot(
                        color: BrightnessColors.plum(brightness),
                        icon: Icons.play_circle_outline),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color bg, Color border) => Container(
    color: bg,
    child: Center(
      child: Text('✦',
          style: TextStyle(color: border, fontSize: 28)),
    ),
  );
}

class _MediaDot extends StatelessWidget {
  const _MediaDot({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
    ),
    child: Icon(icon, color: color, size: 10),
  );
}
