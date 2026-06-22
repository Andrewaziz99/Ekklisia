// lib/admin/admin_l10n.dart
// ─────────────────────────────────────────────────────────────────────────────
// Lightweight admin localisation helper.
//
// Usage in any build() method:
//   final l = context.adminL10n;   // auto-watches SettingsCubit → rebuilds
//   Text(l.dashboard)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/settings/cubit/settings_cubit.dart';
import '../services/settings_service.dart';

extension AdminL10nExt on BuildContext {
  /// Reads current language from [SettingsCubit] (auto-watches → rebuilds).
  AdminL10n get adminL10n {
    final lang = watch<SettingsCubit>().state.language;
    return lang == AppLanguage.arabic ? AdminL10n.ar : AdminL10n.el;
  }
}

class AdminL10n {
  const AdminL10n._({required this.isAr});
  final bool isAr;

  static const ar = AdminL10n._(isAr: true);
  static const el = AdminL10n._(isAr: false);

  String _t(String ar, String el) => isAr ? ar : el;

  // ── Text direction / font ─────────────────────────────────────────────────
  TextDirection get dir => isAr ? TextDirection.rtl : TextDirection.ltr;
  String? get fontFam => isAr ? 'Scheherazade' : null;

  // ── Shell navigation ──────────────────────────────────────────────────────
  String get dashboard => _t('الرئيسية', 'Πίνακας');
  String get upload => _t('رفع كتاب', 'Ανέβασμα');
  String get notify => _t('الإشعارات', 'Ειδοποιήσεις');
  String get users => _t('المستخدمون', 'Χρήστες');
  String get bible => _t('الكتاب المقدس', 'Αγία Γραφή');
  String get psalmody => _t('الترانيم', 'Ψαλμωδία');
  String get liturgies => _t('القداسات', 'Λειτουργίες');
  String get readings => _t('القراءات', 'Αναγνώσματα');
  String get hymns => _t('الألحان', 'Ύμνοι');
  String get occasions => _t('مناسبات', 'Ευκαιρίες');
  String get prayers => _t('الصلوات', 'Προσευχές');
  String get saints => _t('القديسون', 'Άγιοι');
  String get dailyVerse => _t('آية اليوم', 'Ημερήσιο Εδάφιο');
  String get agbeya => _t('الأجبية', 'Αγπεγιά');
  String get bookCategories => _t('تصنيفات الكتب', 'Κατηγορίες Βιβλίων');
  String get games => _t('الألعاب', 'Παιχνίδια');

  // ── Shell section headers ─────────────────────────────────────────────────
  String get sectionQuickActions =>
      _t('الإجراءات السريعة', 'ΓΡΗΓΟΡΕΣ ΕΝΕΡΓΕΙΕΣ');
  String get sectionContent => _t('المحتوى', 'ΠΕΡΙΕΧΟΜΕΝΟ');
  String get sectionAdmin => _t('إكليسيا', 'EKKLISIA');

  // ── Dashboard sections ────────────────────────────────────────────────────
  String get overview => _t('نظرة عامة', 'Επισκόπηση');
  String get quickActionsSection => _t('إجراءات سريعة', 'Γρήγορες Ενέργειες');
  String get library => _t('المكتبة', 'Βιβλιοθήκη');
  String get contentManagement =>
      _t('إدارة المحتوى', 'Διαχείριση Περιεχομένου');
  String get recentBooks => _t('المضافة حديثاً', 'Πρόσφατες Προσθήκες');

  // ── Stat cards ────────────────────────────────────────────────────────────
  String get totalBooks => _t('إجمالي الكتب', 'Σύνολο Βιβλίων');
  String get published => _t('منشور', 'Δημοσιευμένα');
  String get drafts => _t('مسودات', 'Πρόχειρα');
  String get categories => _t('الأقسام', 'Κατηγορίες');

  // ── Library mini-stats ────────────────────────────────────────────────────
  String get pdfs => _t('كتب PDF', 'PDF');
  String get videos => _t('فيديو', 'Βίντεο');
  String get audio => _t('صوتي', 'Ήχος');
  String get live => _t('منشور', 'Ζωντανό');

  // ── Library action buttons ────────────────────────────────────────────────
  String get manageLibrary => _t('إدارة المكتبة', 'Διαχείριση Βιβλιοθήκης');
  String get uploadBook => _t('رفع كتاب', 'Ανέβασμα Βιβλίου');
  String get bulkUpload => _t('رفع متعدد', 'Μαζικό Ανέβασμα');

  // ── Quick actions ─────────────────────────────────────────────────────────
  String get sendNotification => _t('إرسال إشعار', 'Αποστολή Ειδοποίησης');
  String get viewApp => _t('عرض التطبيق', 'Προβολή Εφαρμογής');

  // ── CMS shortcuts ─────────────────────────────────────────────────────────
  String get cmsBible => _t('الكتاب المقدس', 'Αγία Γραφή');
  String get cmsHymns => _t('الألحان', 'Ύμνοι');
  String get cmsPrayers => _t('الصلوات', 'Προσευχές');
  String get cmsLiturgies => _t('القداسات', 'Λειτουργίες');
  String get cmsSaints => _t('القديسون', 'Άγιοι');
  String get cmsDailyVerse => _t('آية اليوم', 'Ημερήσιο Εδάφιο');
  String get cmsAgbeya => _t('الأجبية', 'Αγπεγιά');

  // ── Welcome banner ────────────────────────────────────────────────────────
  String welcomeUser(String name) => _t('مرحباً، $name', 'Καλωσόρισες, $name');
  String get adminPanel =>
      _t('إكليسيا — لوحة التحكم', 'Ekklisia — Πίνακας Ελέγχου');

  // ── Status labels ─────────────────────────────────────────────────────────
  String get statusLive => _t('منشور', 'LIVE');
  String get statusDraft => _t('مسودة', 'DRAFT');
  String get recentlyAdded => _t('أضيف مؤخراً', 'Πρόσφατα Προσθήκες');
  String get viewAll => _t('عرض الكل', 'Προβολή Όλων');

  // ── Common actions ────────────────────────────────────────────────────────
  String get add => _t('إضافة', 'Προσθήκη');
  String get save => _t('حفظ', 'Αποθήκευση');
  String get cancel => _t('إلغاء', 'Ακύρωση');
  String get delete => _t('حذف', 'Διαγραφή');
  String get edit => _t('تعديل', 'Επεξεργασία');
  String get search => _t('بحث', 'Αναζήτηση');
  String get bulk => _t('مجمّع', 'Μαζικό');
  String get confirm => _t('تأكيد', 'Επιβεβαίωση');

  // ── Managers ─────────────────────────────────────────────────────────────
  String get manageBooks => _t('إدارة الكتب', 'Διαχείριση Βιβλίων');
  String get manageSaints => _t('إدارة القديسين', 'Διαχείριση Αγίων');
  String get manageChurches => _t('إدارة الكنائس', 'Διαχείριση Εκκλησιών');
  String get churches => _t('الكنائس', 'Εκκλησίες');
  String get addChurch => _t('إضافة كنيسة', 'Προσθήκη Εκκλησίας');
  String get editChurch => _t('تعديل الكنيسة', 'Επεξεργασία Εκκλησίας');
  String get deleteChurch => _t('حذف الكنيسة', 'Διαγραφή Εκκλησίας');
  String get churchNameAr => _t('اسم الكنيسة (عربي)', 'Όνομα Εκκλησίας (Αραβικά)');
  String get churchNameEn => _t('اسم الكنيسة (يوناني)', 'Όνομα Εκκλησίας (Ελληνικά)');
  String get mapsLink => _t('رابط خرائط Google', 'Σύνδεσμος Google Maps');
  String get priests => _t('الكهنة', 'Ιερείς');
  String get addPriest => _t('إضافة كاهن', 'Προσθήκη Ιερέα');
  String get priestNameAr => _t('اسم الكاهن (عربي)', 'Όνομα Ιερέα (Αραβικά)');
  String get priestNameEn => _t('اسم الكاهن (يوناني)', 'Όνομα Ιερέα (Ελληνικά)');
  String get priestPhone => _t('رقم الهاتف', 'Τηλέφωνο');
  String get priestImage => _t('صورة الكاهن', 'Φωτογραφία Ιερέα');
  String get noChurches => _t('لا توجد كنائس', 'Δεν βρέθηκαν εκκλησίες');
  String get cmsChurches => _t('الكنائس', 'Εκκλησίες');
  // ── Bishop ──────────────────────────────────────────────────────────────
  String get bishop => _t('الأسقف', 'Επίσκοπος');
  String get bishopTitleEl => _t('اللقب الرسمي (يوناني)', 'Επίσημος Τίτλος (Ελληνικά)');
  String get bishopTitleAr => _t('اللقب الرسمي (عربي)', 'Επίσημος Τίτλος (Αραβικά)');
  String get bishopImage   => _t('صورة الأسقف', 'Φωτογραφία Επισκόπου');
  String get saveBishop => _t('حفظ بيانات الأسقف', 'Αποθήκευση Επισκόπου');
  String get bulkUploadSaints =>
      _t('رفع مجمّع — القديسون', 'Μαζικό Ανέβασμα — Άγιοι');
  String get bulkUploadBooks =>
      _t('رفع مجمّع — الكتب', 'Μαζικό Ανέβασμα — Βιβλία');
  String get addFiles => _t('إضافة ملفات', 'Προσθήκη Αρχείων');
  String get uploadAll => _t('رفع الكل', 'Ανέβασμα Όλων');
  String get noFilesSelected =>
      _t('لم يتم اختيار ملفات', 'Δεν έχουν επιλεγεί αρχεία');
  String get filenameHint => _t(
    'سيُستخدم اسم الملف كعنوان',
    'Το όνομα αρχείου θα χρησιμοποιηθεί ως τίτλος',
  );

  // ── Upload screen fields ──────────────────────────────────────────────────
  String get titleAr => _t('العنوان (عربي)', 'Τίτλος (Αραβικά)');
  String get titleEl => _t('العنوان (يوناني)', 'Τίτλος (Ελληνικά)');
  String get saintNameAr => _t('اسم القديس (عربي)', 'Όνομα Αγίου (Αραβικά)');
  String get saintNameEl => _t('اسم القديس (يوناني)', 'Όνομα Αγίου (Ελληνικά)');
  String get titleEn => _t('العنوان (إنجليزي)', 'Τίτλος (Αγγλικά)');
  String get video => _t('فيديو', 'Βίντεο');
  String get gallery => _t('المعرض', 'Γκαλερί');
  String get galleryBulkUpload => _t('رفع مجمّع — المعرض', 'Μαζικό Ανέβασμα — Γκαλερί');
  String get elibManager => _t('المكتبة الإلكترونية', 'Ηλεκτρονική Βιβλιοθήκη');
  String get elibBulkUpload => _t('رفع مجمّع — المكتبة', 'Μαζικό Ανέβασμα — Βιβλιοθήκη');
  String get elibVideos => _t('فيديوهات المكتبة', 'Βίντεο Βιβλιοθήκης');
  String get sections => _t('الأقسام', 'Τμήματα');
  String get addSection => _t('إضافة قسم', 'Προσθήκη Τμήματος');
  String get addItem => _t('إضافة عنصر', 'Προσθήκη Στοιχείου');
  String get addUrl => _t('إضافة رابط', 'Προσθήκη URL');
  String get selectSection => _t('اختر قسمًا', 'Επιλογή Τμήματος');
  String uploadAllN(int n) => _t('رفع الكل ($n)', 'Ανέβασμα Όλων ($n)');
  String get defaultCat => _t('الفئة الافتراضية', 'Προεπιλεγμένη Κατηγορία');
  String pendingCount(int n) => _t('في الانتظار ($n)', 'Σε αναμονή ($n)');
  String doneCount(int n) => _t('تم ($n)', 'Ολοκληρωμένα ($n)');
  String failedCount(int n) => _t('فشل ($n)', 'Αποτυχία ($n)');

}
