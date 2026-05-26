// lib/admin/cms_router.dart
// ─────────────────────────────────────────────────────────────────────────────
// CMS routing and navigation
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart';
import 'content/cms_content_manager.dart';
import 'content/cms_additional_content.dart';

/// CMS routes configuration
class CMSRouter {
  static const String root = '/admin/cms';
  static const String bibles = '/admin/cms/bibles';
  static const String hymns = '/admin/cms/hymns';
  static const String prayers = '/admin/cms/prayers';
  static const String liturgies = '/admin/cms/liturgies';
  static const String saints = '/admin/cms/saints';
  static const String calendars = '/admin/cms/calendars';
  static const String books = '/admin/cms/books';

  static final routes = [
    GoRoute(
      path: bibles,
      name: 'cms-bibles',
      builder: (context, state) => const BiblesManagerScreen(),
    ),
    GoRoute(
      path: hymns,
      name: 'cms-hymns',
      builder: (context, state) => const HymnsManagerScreen(),
    ),
    GoRoute(
      path: prayers,
      name: 'cms-prayers',
      builder: (context, state) => const PrayersManagerScreen(),
    ),
    GoRoute(
      path: liturgies,
      name: 'cms-liturgies',
      builder: (context, state) => const LiturgiesManagerScreen(),
    ),
    GoRoute(
      path: saints,
      name: 'cms-saints',
      builder: (context, state) => const SaintsManagerScreen(),
    ),
  ];
}

/// CMS nav items for sidebar
class CMSNavItem {
  final String path;
  final String labelEn;
  final String labelAr;
  final IconData icon;
  final IconData activeIcon;

  const CMSNavItem({
    required this.path,
    required this.labelEn,
    required this.labelAr,
    required this.icon,
    required this.activeIcon,
  });
}

final cmsNavItems = <CMSNavItem>[
  CMSNavItem(
    path: CMSRouter.bibles,
    labelEn: 'Bibles',
    labelAr: 'الكتب المقدسة',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
  ),
  CMSNavItem(
    path: CMSRouter.hymns,
    labelEn: 'Hymns',
    labelAr: 'التسابيح',
    icon: Icons.music_note_outlined,
    activeIcon: Icons.music_note,
  ),
  CMSNavItem(
    path: CMSRouter.prayers,
    labelEn: 'Prayers',
    labelAr: 'الصلوات',
    icon: Icons.favorite_outline,
    activeIcon: Icons.favorite,
  ),
  CMSNavItem(
    path: CMSRouter.liturgies,
    labelEn: 'Liturgies',
    labelAr: 'القداسات',
    icon: Icons.church_outlined,
    activeIcon: Icons.church,
  ),
  CMSNavItem(
    path: CMSRouter.saints,
    labelEn: 'Saints',
    labelAr: 'القديسون',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
];