// lib/features/bookmarks/bookmarks_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bookmarks & Highlights — placeholder while full implementation is pending.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../core/theme/brightness_colors.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final gold = Theme.of(context).primaryColor;

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: bgDeep,
            automaticallyImplyLeading: false,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: BrightnessColors.headerGradient(brightness),
                  border: Border(
                    bottom: BorderSide(color: goldBorder, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            Text('✦',
                                style:
                                    TextStyle(color: goldDim, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(
                              isGreek ? 'ΣΕΛΙΔΟΔΕΙΚΤΕΣ' : 'الإشارات المرجعية',
                              style: TextStyle(
                                fontFamily: isGreek ? null : 'Scheherazade',
                                color: goldLight,
                                fontSize: isGreek ? 18 : 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: isGreek ? 2.0 : 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'BOOKMARKS & HIGHLIGHTS',
                              style: TextStyle(
                                color: goldDim,
                                fontSize: 8,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 0.5, color: goldBorder),
            ),
          ),

          // ── Empty state ───────────────────────────────────────────────
          SliverFillRemaining(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgMid,
                    border: Border.all(color: goldBorder, width: 0.5),
                  ),
                  child: Icon(
                    Icons.bookmarks_outlined,
                    size: 36,
                    color: goldDim,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isGreek ? 'Δεν υπάρχουν σελιδοδείκτες' : 'لا توجد إشارات مرجعية',
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textSecondary,
                    fontSize: isGreek ? 15 : 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGreek
                      ? 'Προσθέστε σελιδοδείκτες κατά την ανάγνωση'
                      : 'أضف إشارات مرجعية أثناء القراءة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textSecondary.withOpacity(0.6),
                    fontSize: isGreek ? 12 : 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGreek ? 'Coming soon' : 'قريباً',
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: gold,
                    fontSize: 12,
                    letterSpacing: 1.0,
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
