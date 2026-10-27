// lib/core/l10n/app_l10n.dart
// ─────────────────────────────────────────────────────────────────────────────
// App-wide localisation strings — Arabic ↔ Greek.
//
// Usage in any build() method:
//   final l = context.l10n;   // auto-watches SettingsCubit → rebuilds on lang change
//   Text(l.library)
//
// To change a string, edit it here. No need to touch individual screens.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';

// ── Context extension ─────────────────────────────────────────────────────────

extension AppL10nExt on BuildContext {
  /// Reads current language from [SettingsCubit] (auto-watches → rebuilds).
  /// Only call this from a build() method — Provider's `watch` asserts if
  /// called from an event handler or other callback outside the widget
  /// tree's build phase. Use [l10nOnce] there instead.
  AppL10n get l10n {
    final lang = watch<SettingsCubit>().state.language;
    return lang == AppLanguage.arabic ? AppL10n.ar : AppL10n.el;
  }

  /// Same lookup as [l10n] but via `read` instead of `watch` — safe to call
  /// from event handlers, async callbacks, etc. (anywhere outside a build()
  /// method). Doesn't subscribe to rebuilds, which is fine for a one-shot
  /// read like building a dialog's contents or a SnackBar message.
  AppL10n get l10nOnce {
    final lang = read<SettingsCubit>().state.language;
    return lang == AppLanguage.arabic ? AppL10n.ar : AppL10n.el;
  }
}

// ── Main class ────────────────────────────────────────────────────────────────

class AppL10n {
  const AppL10n._({required this.isAr});
  final bool isAr;

  static const ar = AppL10n._(isAr: true);
  static const el = AppL10n._(isAr: false);

  /// Pick [ar] string when Arabic, [el] string when Greek.
  String _t(String ar, String el) => isAr ? ar : el;

  // ── Text direction / font helpers ─────────────────────────────────────────
  TextDirection get dir => isAr ? TextDirection.rtl : TextDirection.ltr;
  String? get bodyFont => isAr ? 'Scheherazade' : 'GFSDidot';
  String? get labelFont => isAr ? 'Scheherazade' : null;

  /// The opposite locale — useful for bilingual widgets that show both labels.
  AppL10n get other => isAr ? AppL10n.el : AppL10n.ar;

  // ══════════════════════════════════════════════════════════════════════════
  // GENERAL / SHARED
  // ══════════════════════════════════════════════════════════════════════════

  String get appName => _t('إكليسيا', 'Εκκλησία');
  String get back => _t('رجوع', 'Πίσω');
  String get retry => _t('إعادة المحاولة', 'Επανάληψη');
  String get search => _t('بحث', 'Αναζήτηση');
  String get seeAll => _t('عرض الكل', 'Δείτε Όλα');
  String get all => _t('الكل', 'ΟΛΑ');
  String get comingSoon => _t('قريباً', 'Σύντομα');
  String get loadingError => _t('حدث خطأ', 'Σφάλμα φόρτωσης');
  String get loadingErrorLong => _t('حدث خطأ أثناء التحميل', 'Σφάλμα φόρτωσης');
  String get next => _t('← التالي', 'Επόμενο →');
  String get previous => _t('السابق', 'Προηγούμενο');
  String get results => _t('النتائج', 'Αποτελέσματα');
  String get video => _t('مشاهدة الفيديو', 'Βίντεο');
  String get readPdf => _t('قراءة PDF', 'Ανάγνωση PDF');
  String get noContent => _t('لا يوجد محتوى', 'Δεν υπάρχουν στοιχεία');
  String get yearSuffix => _t('م', 'Α.D.');

  // ══════════════════════════════════════════════════════════════════════════
  // LANGUAGE SELECTION (onboarding)
  // ══════════════════════════════════════════════════════════════════════════

  String get selectLanguage => _t('اختر اللغة', 'Επιλέξτε γλώσσα');
  String get arabicLanguage => _t('العربية', 'Αραβικά');
  String get arabicSubtitle => _t('Arabic / العربية', 'Arabic / العربية');
  String get greekLanguage => _t('اليونانية', 'Ελληνικά');
  String get greekSubtitle => _t('Greek / Ελληνικά', 'Greek / Ελληνικά');

  // ══════════════════════════════════════════════════════════════════════════
  // HOME SCREEN
  // ══════════════════════════════════════════════════════════════════════════

  String get home => _t('الرئيسية', 'Αρχική');
  String get ekklisiaApp => _t('إكليسيا', 'Εκκλησία');
  String get appLabel => _t('التطبيق', 'Εφαρμογή');

  // Section headers
  String get contentLibrary => _t('مكتبة المحتوى', 'Βιβλιοθήκη');
  String get recentlyAdded => _t('أحدث الإضافات', 'Πρόσφατα προστέθηκε');

  // Category / quick-access grid labels
  String get categoryAgbeya => _t('الأجبية', 'Προσευχές από το');
  String get categoryPsalmody => _t('الترانيم', 'Χριστιανικά Άσματα');
  String get categoryBible => _t('الكتاب المقدس', 'Αγία Γραφή');
  String get categoryLiturgies => _t('القداسات', 'Λειτουργία');
  String get categoryReadings => _t('كتب ليتورجية', 'Λειτουργικά βιβλία');
  String get categoryHymns => _t('الألحان', 'Μεσονυκτική Ακολουθία');
  String get categoryOccasions => _t('أسبوع الآلام', 'Μ. ΕΒΔΟΜΑΔA');
  String get categoryCopticCalendar =>
      _t('التقويم القبطي', 'Κοπτικό Ημερολόγιο');
  String get categoryTheses =>
      _t('رسائل الدكتوراه والماجستير', 'Διδακτορικά και Μεταπτυχιακές Εργασίες');
  // ── Theses sub-sections (inside the category-theses tab) ──────────────────
  String get masterTheses => _t('رسائل الماجستير', 'ΜΕΤΑΠΤΥΧΙΑΚΕΣ ΕΡΓΑΣΙΕΣ');
  String get doctoralTheses => _t('رسائل الدكتوراه', 'ΔΙΔΑΚΤΟΡΙΚΕΣ ΔΙΑΤΡΙΒΕΣ');
  String get unspecifiedTheses => _t('أخرى', 'Άλλα');
  String get categoryChristianBooks => _t('الكتب المسيحية', 'Χριστιανικά Βιβλία');
  String get categoryServiceBooks => _t('كتب الخدمة', 'Βιβλία Διακονίας');

  // Bottom navigation bar
  String get navHome => _t('الرئيسية', 'Αρχική');
  String get navLibrary => _t('المكتبة', 'Βιβλιοθήκη');
  String get navBookmarks => _t('الإشارات', 'Σελιδοδ.');
  String get navSettings => _t('الإعدادات', 'Ρυθμίσεις');

  // End-drawer menu items
  String get adminDashboard => _t('لوحة التحكم', 'Πίνακας Διαχείρισης');

  // ══════════════════════════════════════════════════════════════════════════
  // DAILY VERSE
  // ══════════════════════════════════════════════════════════════════════════

  String get dailyVerseTitle => _t('آية اليوم', 'Το εδάφιο της ημέρας');
  String get dailyVerseTitleUpper => _t('آية اليوم', 'Το εδάφιο της ημέρας');
  String get dailyVerseEmpty => _t('القراءة اليومية', 'Καθημερινός Στίχος');

  // ══════════════════════════════════════════════════════════════════════════
  // BOOKS / LIBRARY
  // ══════════════════════════════════════════════════════════════════════════

  String get library => _t('المكتبة', 'ΒΙΒΛΙΟΘΗΚΗ');
  String get librarySubtitle => _t('LIBRARY', 'ΒΙΒΛΙΟΘΗΚΗ');
  String get downloads => _t('تم التحميل', 'ΛΗΨΕΙΣ');
  String get recent => _t('الأحدث', 'ΠΡΟΣΦΑΤΑ');
  String get gridView => _t('عرض شبكي', 'Προβολή πλέγματος');
  String get listView => _t('عرض قائمة', 'Προβολή λίστας');
  String get searchBook => _t('ابحث عن كتاب…', 'Αναζήτηση βιβλίου…');
  String get noBooksFound => _t('لا توجد كتب', 'Δεν βρέθηκαν βιβλία');

  // ══════════════════════════════════════════════════════════════════════════
  // BIBLE
  // ══════════════════════════════════════════════════════════════════════════

  String get bible => _t('الكتاب المقدس', 'Αγία Γραφή');
  String get bibleSubtitle => _t('HOLY BIBLE', 'Αγία Γραφή');
  String get oldTestament => _t('العهد القديم', 'Παλαιά Διαθήκη');
  String get newTestament => _t('العهد الجديد', 'Καινή Διαθήκη');
  String get selectChapter => _t('اختر الأصحاح', 'Επιλέξτε κεφάλαιο');
  String get searchBible => _t('ابحث عن سفر…', 'Αναζήτηση βιβλίου…');
  String get noBibleBooks => _t('لا توجد أسفار', 'Δεν βρέθηκαν βιβλία');

  // ══════════════════════════════════════════════════════════════════════════
  // AGBEYA (BOOK OF HOURS)
  // ══════════════════════════════════════════════════════════════════════════

  String get agbeya => _t('الأجبية', 'Προσευχές από το');
  String get noHours => _t('لا توجد ساعات بعد', 'Δεν βρέθηκαν ώρες');
  String get pickTrack => _t('اختر التسجيل', 'Επιλογή Κομματιού');
  String get stopPlayback => _t('إيقاف', 'Διακοπή');
  String get trackLabelFallback => _t('تسجيل', 'Κομμάτι');

  // ── PDF reader chrome (Agbeya / Holy Mass / books readers) ────────────────
  String get goToPageTooltip => _t('الانتقال إلى صفحة', 'Μετάβαση σε σελίδα');
  String get readingModeTooltip => _t('وضع القراءة', 'Λειτουργία ανάγνωσης');
  String get noAudioForHour =>
      _t('لا يوجد صوت لهذه الساعة', 'Δεν υπάρχει ήχος για αυτή την ώρα');
  String get pdfLoadError => _t(
    'تعذّر عرض هذه الصفحة، حاول مرة أخرى.',
    'Δεν ήταν δυνατή η προβολή αυτής της σελίδας. Δοκιμάστε ξανά.',
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SAINTS
  // ══════════════════════════════════════════════════════════════════════════

  String get saints => _t('القديسين', 'Άγιοι');

  /// Alternate-language subtitle shown beside the primary title.
  String get saintsTitleAlt => _t('Άγιοι', 'القديسين');
  String get noSaints => _t('لا يوجد قديسين', 'Δεν βρέθηκαν Άγιοι');
  String get searchHint => _t('بحث...', 'Αναζήτηση...');
  String noResultsFor(String q) =>
      _t('لا توجد نتائج لـ "$q"', 'Δεν βρέθηκαν αποτελέσματα για "$q"');
  String get mediaSection => _t('وسائط', 'Μέσα');
  String get playAudio => _t('تشغيل الصوت', 'Αναπαραγωγή Ήχου');
  String get watchVideo => _t('مشاهدة الفيديو', 'Παρακολούθηση Βίντεο');
  String get biography => _t('السيرة  Βιογραφία', 'Βιογραφία  السيرة');
  String get english => _t('إنجليزي', 'Αγγλικά');
  String get feastPrefix => _t('العيد: ', 'Εορτή: ');
  String get patronPrefix => _t('شفيع ', 'Προστάτης ');

  // ══════════════════════════════════════════════════════════════════════════
  // BOOKMARKS
  // ══════════════════════════════════════════════════════════════════════════

  String get bookmarks => _t('الإشارات المرجعية', 'ΣΕΛΙΔΟΔΕΙΚΤΕΣ');
  String get noBookmarks =>
      _t('لا توجد إشارات مرجعية', 'Δεν υπάρχουν σελιδοδείκτες');

  // ══════════════════════════════════════════════════════════════════════════
  // COPTIC CALENDAR
  // ══════════════════════════════════════════════════════════════════════════

  String get copticCalendar => _t('التقويم القبطي', 'Κοπτικό Ημερολόγιο');
  String get today => _t('اليوم', 'Σήμερα');
  String get todayFeasts => _t('أعياد اليوم', 'Εορτές της ημέρας');
  String get copticYearSuffix => _t('ش', 'Α.Μ.');

  // ══════════════════════════════════════════════════════════════════════════
  // CHURCHES
  // ══════════════════════════════════════════════════════════════════════════

  String get churches => _t('الكنائس', 'ΕΚΚΛΗΣΙΕΣ');
  String get churchesTitleAlt => _t('ΕΚΚΛΗΣΙΕΣ', 'الكنائس');
  String get noChurches => _t('لا توجد كنائس', 'Δεν βρέθηκαν εκκλησίες');
  String get openMaps => _t('افتح الخريطة', 'Άνοιγμα χάρτη');
  String get priest => _t('الكاهن', 'Ιερέας');
  String get priests => _t('الكهنة', 'Ιερείς');
  String get noPriests => _t('لا يوجد كهنة', 'Δεν βρέθηκαν ιερείς');
  String get callPhone => _t('اتصال', 'Κλήση');

  // ══════════════════════════════════════════════════════════════════════════
  // GALLERY
  // ══════════════════════════════════════════════════════════════════════════

  String get gallery => _t('معرض الصور', 'Φωτογραφικό Υλικό');
  String get noImages => _t('لا توجد صور', 'Δεν υπάρχουν εικόνες');
  String get saintsPhotos => _t('صور من حياة القديسين', 'Φωτογραφίες Βίοι Αγίων');

  // ══════════════════════════════════════════════════════════════════════════
  // ELECTRONIC LIBRARY (ELIB)
  // ══════════════════════════════════════════════════════════════════════════

  String get elib => _t('المكتبة الالكترونية', 'Ηλεκτρονική Βιβλιοθήκη');
  String get noVideos => _t('لا توجد فيديوهات', 'Δεν υπάρχουν βίντεο');

  // ══════════════════════════════════════════════════════════════════════════
  // GAMES
  // ══════════════════════════════════════════════════════════════════════════

  String get games => _t('الألعاب', 'Παιχνίδια');
  String get correctAnswers => _t('إجابات صحيحة', 'Σωστές απαντήσεις');
  String get playAgain => _t('العب مجددًا', 'Παίξε Ξανά');
  String get changeGame => _t('تغيير اللعبة', 'Αλλαγή Παιχνιδιού');
  String get loadingQuestions =>
      _t('جارٍ تحميل الأسئلة…', 'Φόρτωση ερωτήσεων…');

  // ══════════════════════════════════════════════════════════════════════════
  // SETTINGS SCREEN
  // ══════════════════════════════════════════════════════════════════════════

  String get settings => _t('الإعدادات', 'Ρυθμίσεις');
  String get settingsSubtitle => _t('SETTINGS', 'ΡΥΘΜΙΣΕΙΣ');
  String get language => _t('اللغة', 'Γλώσσα');
  String get theme => _t('المظهر', 'Θέμα');
  String get darkMode => _t('الوضع الداكن', 'Σκοτεινή λειτουργία');
  String get lightMode => _t('الوضع الفاتح', 'Φωτεινή λειτουργία');
  String get offlineMode => _t('وضع عدم الاتصال', 'Λειτουργία εκτός σύνδεσης');
  String get notifications => _t('الإشعارات', 'Ειδοποιήσεις');
  String get signOut => _t('تسجيل الخروج', 'Αποσύνδεση');

  // Section headers
  String get sectionFontSize => _t('حجم الخط', 'Μέγεθος γραμματοσειράς');
  String get sectionLanguage => _t('لغة العرض', 'Γλώσσα εμφάνισης');
  String get sectionAppearance => _t('المظهر', 'Εμφάνιση');
  String get sectionStorage => _t('التخزين', 'Αποθήκευση');
  String get sectionConnection => _t('الاتصال', 'Σύνδεση');
  String get sectionAccount => _t('الحساب', 'Λογαριασμός');

  // Font size card
  String get chooseFontSize =>
      _t('اختر الحجم المناسب', 'Επιλέξτε το κατάλληλο μέγεθος');
  String get fontSizeAppliesEverywhere => _t(
    'يُطبَّق الحجم على كامل النصوص في التطبيق',
    'Το μέγεθος εφαρμόζεται σε όλα τα κείμενα της εφαρμογής',
  );

  // Storage card
  String get cacheLabel => _t('الذاكرة المؤقتة', 'Προσωρινή μνήμη');
  String cacheDescription(String size) => _t(
    'الصور والملفات والصوت المحفوظة • $size',
    'Αποθηκευμένες εικόνες, αρχεία και ήχος • $size',
  );
  String get clearCache => _t('مسح', 'Εκκαθάριση');
  String get cacheCleared =>
      _t('تم مسح الذاكرة المؤقتة', 'Η προσωρινή μνήμη εκκαθαρίστηκε');

  // Sign-out confirmation
  String get confirmSignOutBody => _t(
    'هل تريد تسجيل الخروج من التطبيق؟',
    'Θέλετε να αποσυνδεθείτε από την εφαρμογή;',
  );
  String get confirmSignOutAction => _t('خروج', 'Έξοδος');
  String get cancel => _t('إلغاء', 'Ακύρωση');

  // Profile card
  String get guestReadOnly => _t('ضيف — قراءة فقط', 'Επισκέπτης — μόνο ανάγνωση');

  // Footer
  String get footerChurchName =>
      _t('الكنيسة القبطية الأرثوذكسية', 'Κοπτική Ορθόδοξη Εκκλησία');

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH SCREENS
  // ══════════════════════════════════════════════════════════════════════════

  String get signIn => _t('تسجيل الدخول', 'Σύνδεση');
  String get email => _t('البريد الإلكتروني', 'Email');
  String get password => _t('كلمة المرور', 'Κωδικός');
  String get forgotPassword => _t('نسيت كلمة المرور؟', 'Ξέχασα τον κωδικό');
  String get continueGuest => _t('تصفح كزائر', 'Συνέχεια ως επισκέπτης');
  String get signInGoogle => _t('الدخول بـ Google', 'Σύνδεση με Google');
  String get resetSent => _t(
    'تم إرسال رابط إعادة تعيين كلمة المرور',
    'Στάλθηκε σύνδεσμος επαναφοράς',
  );
  String get resetFailed => _t('تعذّر الإرسال', 'Η αποστολή απέτυχε');
  String get enterEmailFirst =>
      _t('أدخل بريدك الإلكتروني أولاً', 'Εισάγετε πρώτα το email σας');
}
