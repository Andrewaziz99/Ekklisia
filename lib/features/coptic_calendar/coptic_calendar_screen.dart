// lib/features/coptic_calendar/coptic_calendar_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Coptic Calendar Screen
//
// Layout:
//   • Today card — Coptic date + liturgical season badge
//   • Month navigation — ← month year →
//   • Weekday headers — Sun…Sat
//   • 30-day grid — each cell shows day number + feast dots
//   • Tap a day → bottom sheet with feast details
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/coptic_calendar_service.dart';
import '../../core/theme/brightness_colors.dart';
import '../../core/theme/colors.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';

class CopticCalendarScreen extends StatefulWidget {
  const CopticCalendarScreen({super.key});

  @override
  State<CopticCalendarScreen> createState() => _CopticCalendarScreenState();
}

class _CopticCalendarScreenState extends State<CopticCalendarScreen> {
  late CopticDate _today;
  late int _viewYear;
  late int _viewMonth;

  @override
  void initState() {
    super.initState();
    _today = CopticCalendarService.fromGregorian(DateTime.now());
    _viewYear = _today.year;
    _viewMonth = _today.month;
  }

  void _prevMonth() => setState(() {
        if (_viewMonth == 1) {
          _viewMonth = 13;
          _viewYear--;
        } else {
          _viewMonth--;
        }
      });

  void _nextMonth() => setState(() {
        if (_viewMonth == 13) {
          _viewMonth = 1;
          _viewYear++;
        } else {
          _viewMonth++;
        }
      });

  void _goToToday() => setState(() {
        _viewYear = _today.year;
        _viewMonth = _today.month;
      });

  bool get _isCurrentMonth =>
      _viewYear == _today.year && _viewMonth == _today.month;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );

    final season = CopticCalendarService.getLiturgicalSeason(DateTime.now());

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: gold, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isGreek ? 'Κοπτικό Ημερολόγιο' : 'التقويم القبطي',
          style: TextStyle(
            fontFamily: isGreek ? null : 'Scheherazade',
            color: gold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!_isCurrentMonth)
            TextButton(
              onPressed: _goToToday,
              child: Text(
                isGreek ? 'Σήμερα' : 'اليوم',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: gold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: goldBorder),
        ),
      ),
      body: Column(
        children: [
          // ── Today banner ──────────────────────────────────────────────────
          _TodayBanner(
            today: _today,
            season: season,
            brightness: brightness,
            isGreek: isGreek,
          ),

          // ── Month navigation ──────────────────────────────────────────────
          _MonthNav(
            year: _viewYear,
            month: _viewMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
            brightness: brightness,
            isGreek: isGreek,
          ),

          // ── Weekday headers ───────────────────────────────────────────────
          _WeekdayHeaders(
            textSecondary: textSecondary,
            gold: gold,
            isGreek: isGreek,
          ),

          Container(height: 0.5, color: goldBorder),

          // ── Day grid ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: _DayGrid(
                viewYear: _viewYear,
                viewMonth: _viewMonth,
                today: _today,
                brightness: brightness,
                bgMid: bgMid,
                gold: gold,
                goldBorder: goldBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onDayTap: (day) => _showDaySheet(context, day, isGreek),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDaySheet(BuildContext context, int day, bool isGreek) {
    final feasts = CopticCalendarService.getFeastsForDay(_viewMonth, day);
    final brightness = Theme.of(context).brightness;
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    final greg = CopticCalendarService.toGregorian(_viewYear, _viewMonth, day);

    final weekdaysAr = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final weekdaysEl = ['Κυριακή', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο'];
    final weekday = isGreek
        ? weekdaysEl[greg.weekday % 7]
        : weekdaysAr[greg.weekday % 7];

    final monthName = isGreek
        ? CopticCalendarService.monthNameEl(_viewMonth)
        : CopticCalendarService.monthNameAr(_viewMonth);

    final isToday =
        _viewYear == _today.year && _viewMonth == _today.month && day == _today.day;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bgMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: goldBorder, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: goldBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Day header
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isToday
                        ? gold.withValues(alpha: 0.15)
                        : bgDeep.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday ? gold : goldBorder,
                      width: isToday ? 1.5 : 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isToday ? gold : textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGreek
                          ? '$weekday, $day $monthName'
                          : '$weekday، $day $monthName',
                      style: TextStyle(
                        fontFamily: isGreek ? null : 'Scheherazade',
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$day ${CopticCalendarService.monthNameEl(_viewMonth)} $_viewYear AM',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    Text(
                      isGreek
                          ? '${greg.day}/${greg.month}/${greg.year} μ.Χ.'
                          : '${greg.day}/${greg.month}/${greg.year} م',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (feasts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  isGreek
                      ? 'Δεν υπάρχουν εορτές για αυτή την ημέρα'
                      : 'لا توجد أعياد مسجلة لهذا اليوم',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
            else ...[
              Text(
                isGreek ? 'Εορτές της ημέρας' : 'أعياد اليوم',
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              ...feasts.map((f) => _FeastRow(
                    feast: f,
                    gold: gold,
                    goldBorder: goldBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    bgDeep: bgDeep,
                    isGreek: isGreek,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Today banner ──────────────────────────────────────────────────────────────

class _TodayBanner extends StatelessWidget {
  const _TodayBanner({
    required this.today,
    required this.season,
    required this.brightness,
    required this.isGreek,
  });

  final CopticDate today;
  final CopticSeason season;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final bgMid = BrightnessColors.bgMid(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final seasonColor = Color(season.colorHex);

    final monthName = isGreek
        ? CopticCalendarService.monthNameEl(today.month)
        : CopticCalendarService.monthNameAr(today.month);
    final seasonName = isGreek ? season.nameEl : season.nameAr;
    final yearSuffix = isGreek ? 'Α.Μ.' : 'ش';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Day number circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: gold, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${today.day}',
                style: TextStyle(
                  color: gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${today.day} $monthName ${today.year} $yearSuffix',
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${today.day} ${CopticCalendarService.monthNameEl(today.month)} ${today.year} AM',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                // Season badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: seasonColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: seasonColor.withValues(alpha: 0.4), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (season.isFast)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.water_drop_outlined,
                              color: seasonColor, size: 11),
                        ),
                      Text(
                        seasonName,
                        style: TextStyle(
                          fontFamily: isGreek ? null : 'Scheherazade',
                          color: seasonColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Cross ornament
          Text(
            '☩',
            style: TextStyle(
              color: gold.withValues(alpha: 0.3),
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month navigation ──────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.brightness,
    required this.isGreek,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Brightness brightness;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final gold = BrightnessColors.gold(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);

    final primaryName = isGreek
        ? CopticCalendarService.monthNameEl(month)
        : CopticCalendarService.monthNameAr(month);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: Icon(Icons.chevron_left, color: gold, size: 26),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  primaryName,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${CopticCalendarService.monthNameEl(month)}  $year AM',
                  style: TextStyle(
                    color: goldBorder,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, color: gold, size: 26),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ── Weekday headers ───────────────────────────────────────────────────────────

class _WeekdayHeaders extends StatelessWidget {
  const _WeekdayHeaders({
    required this.textSecondary,
    required this.gold,
    required this.isGreek,
  });

  final Color textSecondary;
  final Color gold;
  final bool isGreek;

  static const _labelsAr = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمس', 'جمع', 'سبت'];
  static const _labelsEl = ['Κυρ', 'Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ'];

  @override
  Widget build(BuildContext context) {
    final labels = isGreek ? _labelsEl : _labelsAr;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final isSunday = e.key == 0;
          return Expanded(
            child: Text(
              e.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: isSunday ? gold.withValues(alpha: 0.7) : textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Day grid ──────────────────────────────────────────────────────────────────

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.viewYear,
    required this.viewMonth,
    required this.today,
    required this.brightness,
    required this.bgMid,
    required this.gold,
    required this.goldBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.onDayTap,
  });

  final int viewYear;
  final int viewMonth;
  final CopticDate today;
  final Brightness brightness;
  final Color bgMid;
  final Color gold;
  final Color goldBorder;
  final Color textPrimary;
  final Color textSecondary;
  final void Function(int day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final totalDays = CopticCalendarService.daysInMonth(viewMonth, viewYear);
    final startWeekday = CopticCalendarService.firstWeekdayOfMonth(viewYear, viewMonth);

    final cells = startWeekday + totalDays;
    final rows = (cells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final day = cellIndex - startWeekday + 1;

            if (day < 1 || day > totalDays) {
              return const Expanded(child: SizedBox(height: 52));
            }

            final isToday = viewYear == today.year &&
                viewMonth == today.month &&
                day == today.day;

            final feasts =
                CopticCalendarService.getFeastsForDay(viewMonth, day);
            final hasMajorFeast = feasts.any((f) => f.isMajor);
            final hasFeast = feasts.isNotEmpty;
            final isSunday = col == 0;

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayTap(day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  height: 52,
                  decoration: BoxDecoration(
                    color: isToday
                        ? gold.withValues(alpha: 0.12)
                        : bgMid.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday ? gold : goldBorder.withValues(alpha: 0.4),
                      width: isToday ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isToday
                              ? gold
                              : isSunday
                                  ? gold.withValues(alpha: 0.75)
                                  : textPrimary,
                          fontSize: 15,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w500,
                        ),
                      ),
                      if (hasFeast) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: hasMajorFeast
                                    ? gold
                                    : EkklisiaColors.tealMid
                                        .withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ── Feast row in bottom sheet ─────────────────────────────────────────────────

class _FeastRow extends StatelessWidget {
  const _FeastRow({
    required this.feast,
    required this.gold,
    required this.goldBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.bgDeep,
    required this.isGreek,
  });

  final CopticFeast feast;
  final Color gold;
  final Color goldBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color bgDeep;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final accentColor = feast.isMajor ? gold : EkklisiaColors.tealMid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: accentColor.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 10),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGreek ? feast.nameEn : feast.nameAr,
                  textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: isGreek ? null : 'Scheherazade',
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight:
                        feast.isMajor ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (!isGreek) ...[
                  const SizedBox(height: 2),
                  Text(
                    feast.nameEn,
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (feast.isMajor)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(Icons.star_rounded, color: gold, size: 14),
            ),
        ],
      ),
    );
  }
}
