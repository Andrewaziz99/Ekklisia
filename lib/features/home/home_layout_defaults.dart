// lib/features/home/home_layout_defaults.dart
// ─────────────────────────────────────────────────────────────────────────────
// Single source of truth for everything the admin can rename / re-image on
// the home screen, together with its compiled-in default. Used by both the
// app (home_tab_screen.dart, home_screen.dart) and the admin editor
// (admin/content/home_layout_manager.dart), so adding a tile or a section
// here makes it editable automatically.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../core/l10n/app_l10n.dart';
import '../../data/models/pdf_content_model.dart';

// ── Keys (Firestore map keys — never rename, only add) ──────────────────────

abstract class HomeTileKeys {
  static const agbeya         = 'agbeya';
  static const psalmody       = PdfCategory.psalmody;
  static const bible          = 'bible';
  static const liturgy        = PdfCategory.liturgy;
  static const readings       = PdfCategory.readings;
  static const hymns          = PdfCategory.hymns;
  static const occasions      = PdfCategory.occasions;
  static const copticCalendar = 'coptic_calendar';
  static const theses         = PdfCategory.theses;
  static const christianBooks = PdfCategory.christianBooks;
  static const serviceBooks   = PdfCategory.serviceBooks;
}

abstract class HomeSectionKeys {
  // Home body
  static const contentLibrary = 'content_library';
  static const recentlyAdded  = 'recently_added';
  static const dailyVerse     = 'daily_verse';
  // Side drawer
  static const drawerSaints       = 'drawer_saints';
  static const drawerChurches     = 'drawer_churches';
  static const drawerGames        = 'drawer_games';
  static const drawerGallery      = 'drawer_gallery';
  static const drawerSaintsPhotos = 'drawer_saints_photos';
  static const drawerElib         = 'drawer_elib';
  // Bottom navigation
  static const navHome      = 'nav_home';
  static const navLibrary   = 'nav_library';
  static const navBookmarks = 'nav_bookmarks';
  static const navSettings  = 'nav_settings';
}

// ── Tile definitions (order == grid order) ──────────────────────────────────

class HomeTileDef {
  const HomeTileDef({
    required this.key,
    required this.asset,
    required this.bgColor,
    required this.defaultLabel,
    this.pdfCategory,
    this.allowImage = true,
  });

  final String key;

  /// Default tile artwork. Empty for tiles that render live content.
  final String asset;
  final Color bgColor;
  final String Function(AppL10n l) defaultLabel;

  /// Non-null for tiles that open a PdfContentListScreen.
  final String? pdfCategory;

  /// False for the Coptic calendar tile, which shows today's date instead
  /// of an image.
  final bool allowImage;
}

final List<HomeTileDef> homeTileDefs = [
  HomeTileDef(
    key: HomeTileKeys.agbeya,
    asset: 'assets/images/icons/agbeya.jpg',
    bgColor: const Color(0xFF1B2A4A),
    defaultLabel: (l) => l.categoryAgbeya,
  ),
  HomeTileDef(
    key: HomeTileKeys.psalmody,
    asset: 'assets/images/icons/psalmody.jpg',
    bgColor: const Color(0xFF2A1A38),
    defaultLabel: (l) => l.categoryPsalmody,
    pdfCategory: PdfCategory.psalmody,
  ),
  HomeTileDef(
    key: HomeTileKeys.bible,
    asset: 'assets/images/icons/bible.jpg',
    bgColor: const Color(0xFF1A2C1A),
    defaultLabel: (l) => l.categoryBible,
  ),
  HomeTileDef(
    key: HomeTileKeys.liturgy,
    asset: 'assets/images/icons/liturgies.jpg',
    bgColor: const Color(0xFF2C1A0E),
    defaultLabel: (l) => l.categoryLiturgies,
    pdfCategory: PdfCategory.liturgy,
  ),
  HomeTileDef(
    key: HomeTileKeys.readings,
    asset: 'assets/images/icons/readings.jpg',
    bgColor: const Color(0xFF1B2A4A),
    defaultLabel: (l) => l.categoryReadings,
    pdfCategory: PdfCategory.readings,
  ),
  HomeTileDef(
    key: HomeTileKeys.hymns,
    asset: 'assets/images/icons/hymns.jpg',
    bgColor: const Color(0xFF2A1A38),
    defaultLabel: (l) => l.categoryHymns,
    pdfCategory: PdfCategory.hymns,
  ),
  HomeTileDef(
    key: HomeTileKeys.occasions,
    asset: 'assets/images/icons/Holy_week.jpg',
    bgColor: const Color(0xFF6B1A1A),
    defaultLabel: (l) => l.categoryOccasions,
    pdfCategory: PdfCategory.occasions,
  ),
  HomeTileDef(
    key: HomeTileKeys.copticCalendar,
    asset: '',
    bgColor: const Color(0xFF1A3A2A),
    defaultLabel: (l) => l.categoryCopticCalendar,
    allowImage: false,
  ),
  HomeTileDef(
    key: HomeTileKeys.theses,
    asset: 'assets/images/icons/phD.jpg',
    bgColor: const Color(0xFF3A2A1A),
    defaultLabel: (l) => l.categoryTheses,
    pdfCategory: PdfCategory.theses,
  ),
  HomeTileDef(
    key: HomeTileKeys.christianBooks,
    asset: 'assets/images/icons/coptic_books.jpg',
    bgColor: const Color(0xFF1A2438),
    defaultLabel: (l) => l.categoryChristianBooks,
    pdfCategory: PdfCategory.christianBooks,
  ),
  HomeTileDef(
    key: HomeTileKeys.serviceBooks,
    asset: 'assets/images/icons/service_books.jpg',
    bgColor: const Color(0xFF1E3A28),
    defaultLabel: (l) => l.categoryServiceBooks,
    pdfCategory: PdfCategory.serviceBooks,
  ),
];

// ── Section title definitions (grouped for the admin editor) ────────────────

enum HomeSectionGroup { home, drawer, bottomNav }

class HomeSectionDef {
  const HomeSectionDef({
    required this.key,
    required this.group,
    required this.defaultLabel,
  });

  final String key;
  final HomeSectionGroup group;
  final String Function(AppL10n l) defaultLabel;
}

final List<HomeSectionDef> homeSectionDefs = [
  HomeSectionDef(
    key: HomeSectionKeys.dailyVerse,
    group: HomeSectionGroup.home,
    defaultLabel: (l) => l.dailyVerseTitleUpper,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.contentLibrary,
    group: HomeSectionGroup.home,
    defaultLabel: (l) => l.contentLibrary,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.recentlyAdded,
    group: HomeSectionGroup.home,
    defaultLabel: (l) => l.recentlyAdded,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.drawerSaints,
    group: HomeSectionGroup.drawer,
    defaultLabel: (l) => l.saints,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.drawerChurches,
    group: HomeSectionGroup.drawer,
    defaultLabel: (l) => l.churches,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.drawerGames,
    group: HomeSectionGroup.drawer,
    defaultLabel: (l) => l.games,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.drawerGallery,
    group: HomeSectionGroup.drawer,
    defaultLabel: (l) => l.gallery,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.drawerSaintsPhotos,
    group: HomeSectionGroup.drawer,
    defaultLabel: (l) => l.saintsPhotos,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.drawerElib,
    group: HomeSectionGroup.drawer,
    defaultLabel: (l) => l.elib,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.navHome,
    group: HomeSectionGroup.bottomNav,
    defaultLabel: (l) => l.navHome,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.navLibrary,
    group: HomeSectionGroup.bottomNav,
    defaultLabel: (l) => l.navLibrary,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.navBookmarks,
    group: HomeSectionGroup.bottomNav,
    defaultLabel: (l) => l.navBookmarks,
  ),
  HomeSectionDef(
    key: HomeSectionKeys.navSettings,
    group: HomeSectionGroup.bottomNav,
    defaultLabel: (l) => l.navSettings,
  ),
];
