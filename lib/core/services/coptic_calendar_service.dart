// lib/core/services/coptic_calendar_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Pure-Dart Coptic calendar service — no internet required.
//
// Features:
//  • Gregorian ↔ Coptic date conversion (Julian Day Number method)
//  • Coptic Easter calculation (Alexandrian computus via Julian calendar)
//  • Liturgical season detection (Great Lent, Holy 50 Days, fasts, etc.)
//  • Fixed Coptic feast days per month/day
//  • Monthly recurring feasts (Virgin Mary, Archangel Michael, Gabriel)
// ─────────────────────────────────────────────────────────────────────────────

/// A date in the Coptic (Alexandrian) calendar.
class CopticDate {
  const CopticDate({required this.year, required this.month, required this.day});

  final int year;   // Coptic AM year
  final int month;  // 1–12 = Toot…Misra, 13 = Nasie
  final int day;    // 1–30 (1–5 or 1–6 for Nasie)

  @override
  String toString() =>
      '${CopticCalendarService.dayName(day)} ${CopticCalendarService.monthNameAr(month)} $year';
}

/// A feast or commemoration on a given Coptic day.
class CopticFeast {
  const CopticFeast({
    required this.nameAr,
    required this.nameEn,
    this.isMajor = false,
  });

  final String nameAr;
  final String nameEn;
  final bool isMajor; // true = highlighted in gold
}

/// Liturgical season data.
class CopticSeason {
  const CopticSeason({
    required this.nameAr,
    required this.nameEn,
    required this.nameEl,
    required this.colorHex,
    this.isFast = false,
  });

  final String nameAr;
  final String nameEn;
  final String nameEl; // Greek name
  final int colorHex; // ARGB hex, e.g. 0xFF2A4A7A
  final bool isFast;
}

// ─────────────────────────────────────────────────────────────────────────────

abstract class CopticCalendarService {
  // ── Month names ───────────────────────────────────────────────────────────

  static const List<String> _monthsAr = [
    'توت', 'بابه', 'هاتور', 'كيهك', 'طوبه', 'أمشير',
    'برمهات', 'برموده', 'بشنس', 'بؤونة', 'أبيب', 'مسرى', 'نسيء',
  ];

  static const List<String> _monthsEn = [
    'Toot', 'Baba', 'Hatour', 'Kiahk', 'Touba', 'Amshir',
    'Baramhat', 'Baramoudah', 'Bashans', 'Baouna', 'Abib', 'Misra', 'Nasie',
  ];

  static const List<String> _monthsEl = [
    'Θωθ', 'Βαβέ', 'Χατώρ', 'Χοιάκ', 'Τωβή', 'Αμσίρ',
    'Βαρεμχάτ', 'Βαρμούδα', 'Βαχώνς', 'Παώνι', 'Επήφ', 'Μεσωρή', 'Νεσί',
  ];

  static String monthNameAr(int month) => _monthsAr[month - 1];
  static String monthNameEn(int month) => _monthsEn[month - 1];
  static String monthNameEl(int month) => _monthsEl[month - 1];

  /// Ordinal day label e.g. "7".
  static String dayName(int day) => '$day';

  // ── Coptic year rules ─────────────────────────────────────────────────────

  /// A Coptic year is a leap year when divisible by 4.
  static bool isLeapYear(int copticYear) => copticYear % 4 == 0;

  /// Days in a Coptic month (30 for months 1–12; 5 or 6 for Nasie).
  static int daysInMonth(int month, int year) {
    if (month == 13) return isLeapYear(year) ? 6 : 5;
    return 30;
  }

  // ── JDN helpers ──────────────────────────────────────────────────────────

  static const int _copticEpoch = 1825030; // JDN of 1 Toot 1 AM

  /// Gregorian date → Julian Day Number.
  static int _toJDN(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        (153 * mm + 2) ~/ 5 +
        365 * yy +
        yy ~/ 4 -
        yy ~/ 100 +
        yy ~/ 400 -
        32045;
  }

  /// Julian Day Number → Gregorian date.
  static DateTime _jdnToGregorian(int jdn) {
    final a = jdn + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - 146097 * b ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * d ~/ 4;
    final mm = (5 * e + 2) ~/ 153;
    return DateTime(
      100 * b + d - 4800 + mm ~/ 10,
      mm + 3 - 12 * (mm ~/ 10),
      e - (153 * mm + 2) ~/ 5 + 1,
    );
  }

  // ── Conversion ────────────────────────────────────────────────────────────

  /// Convert a Gregorian [DateTime] to a [CopticDate].
  static CopticDate fromGregorian(DateTime date) {
    final jdn = _toJDN(date.year, date.month, date.day);
    final d = jdn - _copticEpoch;
    final rawYear = (4 * d + 3) ~/ 1461;
    final dayOfYear = d - (365 * rawYear + rawYear ~/ 4);
    return CopticDate(
      year: rawYear + 1,
      month: dayOfYear ~/ 30 + 1,
      day: dayOfYear % 30 + 1,
    );
  }

  /// Convert a Coptic date to a Gregorian [DateTime].
  static DateTime toGregorian(int year, int month, int day) {
    final y = year - 1; // rawYear (0-indexed)
    final jdn = _copticEpoch + 365 * y + y ~/ 4 + 30 * (month - 1) + day - 1;
    return _jdnToGregorian(jdn);
  }

  /// Gregorian weekday of Coptic day 1 of the given month/year.
  /// Returns 0=Sunday … 6=Saturday.
  static int firstWeekdayOfMonth(int copticYear, int copticMonth) {
    final greg = toGregorian(copticYear, copticMonth, 1);
    return greg.weekday % 7; // Dart: Mon=1…Sun=7 → Sun=0…Sat=6
  }

  // ── Easter ────────────────────────────────────────────────────────────────

  /// Calculates Coptic Easter for the given Coptic year.
  /// Returns the Gregorian [DateTime] of Easter Sunday.
  ///
  /// Method: Julian Easter (Meeus algorithm) + 13 days to convert to Gregorian.
  static DateTime copticEaster(int copticYear) {
    // Easter always falls in the Gregorian year = copticYear + 284
    final y = copticYear + 284;
    final a = y % 4;
    final b = y % 7;
    final c = y % 19;
    final d = (19 * c + 15) % 30;
    final e = (2 * a + 4 * b - d + 34) % 7;
    final sum = d + e + 114;
    final julianMonth = sum ~/ 31;       // 3=March, 4=April
    final julianDay = sum % 31 + 1;
    // Convert Julian → Gregorian (+13 days, valid 1900–2099)
    final julian = DateTime(y, julianMonth, julianDay);
    return julian.add(const Duration(days: 13));
  }

  // ── Liturgical season ─────────────────────────────────────────────────────

  /// Returns the current [CopticSeason] for the given Gregorian date.
  static CopticSeason getLiturgicalSeason(DateTime date) {
    final coptic = fromGregorian(date);
    final easter = copticEaster(coptic.year);

    final d = DateTime(date.year, date.month, date.day);
    final easterDay = DateTime(easter.year, easter.month, easter.day);
    final diff = d.difference(easterDay).inDays;

    // ── Easter-relative windows ───────────────────────────────────────────
    // Holy Fifty Days (Pentecost period)
    if (diff >= 0 && diff < 50) {
      return const CopticSeason(
        nameAr: 'الخمسون المقدسة',
        nameEn: 'Holy Fifty Days',
        nameEl: 'Άγια Πεντηκοστή',
        colorHex: 0xFF1A5A7A,
      );
    }
    // Holy Week (last 7 days of Great Lent)
    if (diff >= -7 && diff < 0) {
      return const CopticSeason(
        nameAr: 'الأسبوع المقدس',
        nameEn: 'Holy Week',
        nameEl: 'Αγία Εβδομάδα',
        colorHex: 0xFF6B1A1A,
        isFast: true,
      );
    }
    // Great Lent (55 days before Easter, ends Holy Saturday)
    if (diff >= -55 && diff < -7) {
      return const CopticSeason(
        nameAr: 'الصوم الكبير',
        nameEn: 'Great Lent',
        nameEl: 'Μεγάλη Τεσσαρακοστή',
        colorHex: 0xFF5A1A6B,
        isFast: true,
      );
    }

    // Fast of Nineveh (3 days, starts 21 days before Great Lent)
    final lentStart = easterDay.subtract(const Duration(days: 55));
    final ninevehStart = lentStart.subtract(const Duration(days: 21));
    final ninevehEnd = ninevehStart.add(const Duration(days: 2));
    if (!d.isBefore(ninevehStart) && !d.isAfter(ninevehEnd)) {
      return const CopticSeason(
        nameAr: 'صوم نينوى',
        nameEn: 'Fast of Nineveh',
        nameEl: 'Νηστεία Νινευή',
        colorHex: 0xFF3A5A2A,
        isFast: true,
      );
    }

    // Apostles' Fast (day after Pentecost → 5 Abib)
    final pentecost = easterDay.add(const Duration(days: 49));
    final abib5 = toGregorian(coptic.year, 11, 5);
    if (d.isAfter(pentecost) && !d.isAfter(abib5)) {
      return const CopticSeason(
        nameAr: 'صوم الرسل',
        nameEn: "Apostles' Fast",
        nameEl: 'Νηστεία Αποστόλων',
        colorHex: 0xFF2A5A3A,
        isFast: true,
      );
    }

    // Fast of the Virgin (1–15 August Gregorian = 24 Abib – 7 Misra)
    if (date.month == 8 && date.day >= 1 && date.day <= 15) {
      return const CopticSeason(
        nameAr: 'صوم العذراء',
        nameEn: 'Fast of the Virgin',
        nameEl: 'Νηστεία Θεοτόκου',
        colorHex: 0xFF6A2A7A,
        isFast: true,
      );
    }

    // Advent / Kiahk Fast (25 November – 6 January)
    final isAdvent = (date.month == 11 && date.day >= 25) ||
        date.month == 12 ||
        (date.month == 1 && date.day <= 6);
    if (isAdvent) {
      return const CopticSeason(
        nameAr: 'صوم الميلاد (كيهك)',
        nameEn: 'Advent — Kiahk Fast',
        nameEl: 'Νηστεία Χριστουγέννων (Χοιάκ)',
        colorHex: 0xFF1A2A6A,
        isFast: true,
      );
    }

    // Ordinary time
    return const CopticSeason(
      nameAr: 'الوقت العادي',
      nameEn: 'Ordinary Time',
      nameEl: 'Κοινός Χρόνος',
      colorHex: 0xFF2A3A4A,
    );
  }

  // ── Feasts ────────────────────────────────────────────────────────────────

  /// Returns all feasts celebrated on a given Coptic [month] and [day].
  /// Includes monthly recurring feasts and fixed annual feasts.
  static List<CopticFeast> getFeastsForDay(int month, int day) {
    final feasts = <CopticFeast>[];

    // ── Monthly recurring feasts ──────────────────────────────────────────
    if (day == 21) {
      feasts.add(const CopticFeast(
        nameAr: 'عيد السيدة العذراء مريم (الشهري)',
        nameEn: 'Monthly Feast of the Virgin Mary',
        isMajor: true,
      ));
    }
    if (day == 12) {
      feasts.add(const CopticFeast(
        nameAr: 'عيد الملاك ميخائيل (الشهري)',
        nameEn: 'Monthly Feast of Archangel Michael',
      ));
    }
    if (day == 22) {
      feasts.add(const CopticFeast(
        nameAr: 'عيد الملاك جبرائيل (الشهري)',
        nameEn: 'Monthly Feast of Archangel Gabriel',
      ));
    }

    // ── Fixed annual feasts ───────────────────────────────────────────────
    final key = (month, day);
    final fixed = _fixedFeasts[key];
    if (fixed != null) feasts.addAll(fixed);

    return feasts;
  }

  // ── Fixed feast data ──────────────────────────────────────────────────────

  static final Map<(int, int), List<CopticFeast>> _fixedFeasts = {
    // ── Toot (1) ──────────────────────────────────────────────────────────
    (1, 1): [const CopticFeast(
      nameAr: 'عيد النيروز — رأس السنة القبطية',
      nameEn: 'Nayrouz — Coptic New Year',
      isMajor: true,
    )],
    (1, 17): [const CopticFeast(
      nameAr: 'عيد الصليب المقدس',
      nameEn: 'Feast of the Holy Cross',
      isMajor: true,
    )],
    (1, 26): [const CopticFeast(
      nameAr: 'تذكار الرسول يوحنا الحبيب الإنجيلي',
      nameEn: 'Commemoration of St. John the Beloved',
    )],

    // ── Baba (2) ──────────────────────────────────────────────────────────
    (2, 1): [const CopticFeast(
      nameAr: 'تذكار ميلاد السيدة العذراء مريم',
      nameEn: 'Nativity of the Virgin Mary',
      isMajor: true,
    )],
    (2, 3): [const CopticFeast(
      nameAr: 'تذكار القديس ديونيسيوس الإسكندري',
      nameEn: 'St. Dionysius of Alexandria',
    )],
    (2, 22): [const CopticFeast(
      nameAr: 'تذكار الشهيدة مارينا',
      nameEn: 'St. Marina the Martyr',
    )],

    // ── Hatour (3) ────────────────────────────────────────────────────────
    (3, 8): [const CopticFeast(
      nameAr: 'عيد رئاسة الملاك جبرائيل',
      nameEn: 'Feast of Archangel Gabriel',
      isMajor: true,
    )],
    (3, 14): [const CopticFeast(
      nameAr: 'تذكار الرسول فيلبس',
      nameEn: 'St. Philip the Apostle',
    )],
    (3, 15): [const CopticFeast(
      nameAr: 'تقدمة السيد المسيح للهيكل',
      nameEn: 'Presentation of the Lord at the Temple',
      isMajor: true,
    )],
    (3, 29): [const CopticFeast(
      nameAr: 'تذكار القديسة كاترين',
      nameEn: 'St. Catherine of Alexandria',
    )],

    // ── Kiahk (4) ─────────────────────────────────────────────────────────
    (4, 29): [const CopticFeast(
      nameAr: 'عيد الميلاد المجيد',
      nameEn: 'Coptic Christmas',
      isMajor: true,
    )],

    // ── Touba (5) ─────────────────────────────────────────────────────────
    (5, 11): [const CopticFeast(
      nameAr: 'عيد الغطاس المجيد (الإبيفانيا)',
      nameEn: 'Feast of the Epiphany — Theophany',
      isMajor: true,
    )],
    (5, 24): [const CopticFeast(
      nameAr: 'تذكار الرسول تيموثاوس',
      nameEn: 'St. Timothy the Apostle',
    )],
    (5, 27): [const CopticFeast(
      nameAr: 'عيد الأسرة المقدسة في مصر',
      nameEn: 'Commemoration of the Holy Family in Egypt',
      isMajor: true,
    )],

    // ── Amshir (6) ────────────────────────────────────────────────────────
    (6, 16): [const CopticFeast(
      nameAr: 'عيد ميلاد القديسة ديميانة',
      nameEn: 'St. Damiana',
      isMajor: false,
    )],
    (6, 29): [const CopticFeast(
      nameAr: 'رقاد البابا كيرلس السادس',
      nameEn: 'Repose of Pope Kyrillos VI',
    )],

    // ── Baramhat (7) ──────────────────────────────────────────────────────
    (7, 8): [const CopticFeast(
      nameAr: 'عيد الشهيد أبيفانيوس',
      nameEn: 'St. Epiphanius the Martyr',
    )],
    (7, 29): [const CopticFeast(
      nameAr: 'عيد رئاسة الملاك ميخائيل',
      nameEn: 'Feast of Archangel Michael',
      isMajor: true,
    )],

    // ── Baramoudah (8) ────────────────────────────────────────────────────
    (8, 23): [const CopticFeast(
      nameAr: 'عيد الشهيد مارجرجس',
      nameEn: 'Feast of St. George the Martyr',
      isMajor: true,
    )],
    (8, 24): [const CopticFeast(
      nameAr: 'عيد البشير القديس مرقس الرسول',
      nameEn: 'Feast of St. Mark the Evangelist',
      isMajor: true,
    )],
    (8, 28): [const CopticFeast(
      nameAr: 'تذكار الرسول يعقوب بن زبدي',
      nameEn: 'St. James, son of Zebedee',
    )],

    // ── Bashans (9) ───────────────────────────────────────────────────────
    (9, 1): [const CopticFeast(
      nameAr: 'تذكار القديسة إيرين الشهيدة',
      nameEn: 'St. Irene the Martyr',
    )],
    (9, 8): [const CopticFeast(
      nameAr: 'ظهور الملاك ميخائيل في إكمياء',
      nameEn: 'Apparition of Archangel Michael at Chonae',
      isMajor: true,
    )],
    (9, 24): [const CopticFeast(
      nameAr: 'دخول السيد المسيح أرض مصر مع العائلة المقدسة',
      nameEn: 'Entry of the Holy Family into Egypt',
      isMajor: true,
    )],

    // ── Baouna (10) ───────────────────────────────────────────────────────
    (10, 5): [const CopticFeast(
      nameAr: 'عيد الرسولين بطرس وبولس',
      nameEn: 'Feast of Sts. Peter and Paul',
      isMajor: true,
    )],
    (10, 13): [const CopticFeast(
      nameAr: 'تذكار الشهيد يوحنا المعمدان',
      nameEn: 'St. John the Baptist — Martyrdom',
    )],

    // ── Abib (11) ─────────────────────────────────────────────────────────
    (11, 15): [const CopticFeast(
      nameAr: 'تذكار مريم المجدلية',
      nameEn: 'Commemoration of St. Mary Magdalene',
    )],
    (11, 20): [const CopticFeast(
      nameAr: 'تذكار النبي إيليا',
      nameEn: 'Commemoration of Prophet Elijah',
      isMajor: true,
    )],
    (11, 27): [const CopticFeast(
      nameAr: 'تذكار الشهيد أبوسيفين',
      nameEn: 'St. Mercurius (Abu Seifein)',
    )],

    // ── Misra (12) ────────────────────────────────────────────────────────
    (12, 13): [const CopticFeast(
      nameAr: 'عيد التجلي المجيد',
      nameEn: 'Feast of the Transfiguration',
      isMajor: true,
    )],
    (12, 16): [const CopticFeast(
      nameAr: 'عيد رقاد السيدة العذراء مريم',
      nameEn: 'Dormition of the Virgin Mary',
      isMajor: true,
    )],
    (12, 30): [const CopticFeast(
      nameAr: 'تذكار القديس يوحنا الصائم',
      nameEn: 'St. John the Faster',
    )],
  };
}
