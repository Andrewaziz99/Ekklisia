// lib/admin/admin_shell.dart
// ─────────────────────────────────────────────────────────────────────────────
// Responsive admin shell — brightness-aware (light / dark).
//
// Mobile (< 720 px):
//   • Bottom nav  → 4 Quick Actions: Dashboard, Upload, Notify, Users
//   • Drawer      → CMS content managers + profile/sign-out
//
// Tablet / Desktop (≥ 720 px):
//   • Persistent sidebar with labelled sections:
//       — Navigation (Dashboard)
//       — Quick Actions (Upload, Notify, Users)
//       — Content Management (Bible, Hymns, Prayers, Liturgies, Saints, Verse)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../core/theme/brightness_colors.dart';
import '../core/theme/colors.dart';
import '../features/auth/auth_cubit.dart';
import '../features/auth/auth_state.dart';
import '../features/settings/cubit/settings_cubit.dart';
import '../features/settings/cubit/settings_state.dart';
import '../services/settings_service.dart';
import 'admin_l10n.dart';

// ════════════════════════════════════════════════════════════════════════════
// DATA
// ════════════════════════════════════════════════════════════════════════════

class _NavItem {
  const _NavItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.labelAr,
    required this.labelEl,
  });
  final String   path;
  final IconData icon;
  final IconData activeIcon;
  final String   labelAr;
  final String   labelEl;

  String labelFor(AppLanguage lang) =>
      lang == AppLanguage.arabic ? labelAr : labelEl;
}

// Quick Actions — appear in bottom nav on mobile
const _quickActions = <_NavItem>[
  _NavItem(
    path:        Routes.adminDashboard,
    icon:        Icons.dashboard_outlined,
    activeIcon:  Icons.dashboard,
    labelAr:     'الرئيسية',
    labelEl:     'Πίνακας',
  ),
  _NavItem(
    path:        Routes.adminUpload,
    icon:        Icons.upload_file_outlined,
    activeIcon:  Icons.upload_file,
    labelAr:     'رفع كتاب',
    labelEl:     'Ανέβασμα',
  ),
  _NavItem(
    path:        Routes.adminNotify,
    icon:        Icons.notifications_outlined,
    activeIcon:  Icons.notifications,
    labelAr:     'الإشعارات',
    labelEl:     'Ειδοποιήσεις',
  ),
  _NavItem(
    path:        Routes.adminUsers,
    icon:        Icons.people_outline,
    activeIcon:  Icons.people,
    labelAr:     'المستخدمون',
    labelEl:     'Χρήστες',
  ),
];

// CMS items — live in drawer on mobile, sidebar section on wide
const _cmsItems = <_NavItem>[
  _NavItem(
    path: Routes.adminCmsBibles,
    icon: Icons.book_outlined, activeIcon: Icons.book,
    labelAr: 'الكتاب المقدس', labelEl: 'Αγία Γραφή',
  ),
  _NavItem(
    path: Routes.adminCmsPsalmody,
    icon: Icons.queue_music_outlined, activeIcon: Icons.queue_music,
    labelAr: 'الترانيم', labelEl: 'Ψαλμωδία',
  ),
  _NavItem(
    path: Routes.adminCmsLiturgies,
    icon: Icons.church_outlined, activeIcon: Icons.church,
    labelAr: 'القداسات', labelEl: 'Λειτουργίες',
  ),
  _NavItem(
    path: Routes.adminCmsReadings,
    icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book,
    labelAr: 'القراءات', labelEl: 'Αναγνώσματα',
  ),
  _NavItem(
    path: Routes.adminCmsHymns,
    icon: Icons.music_note_outlined, activeIcon: Icons.music_note,
    labelAr: 'الألحان', labelEl: 'Ύμνοι',
  ),
  _NavItem(
    path: Routes.adminCmsOccasions,
    icon: Icons.celebration_outlined, activeIcon: Icons.celebration,
    labelAr: 'مناسبات', labelEl: 'Ευκαιρίες',
  ),
  _NavItem(
    path: Routes.adminCmsPrayers,
    icon: Icons.favorite_outline, activeIcon: Icons.favorite,
    labelAr: 'الصلوات', labelEl: 'Προσευχές',
  ),
  _NavItem(
    path: Routes.adminCmsSaints,
    icon: Icons.person_outline, activeIcon: Icons.person,
    labelAr: 'القديسون', labelEl: 'Άγιοι',
  ),
  _NavItem(
    path: Routes.adminCmsDailyVerse,
    icon: Icons.wb_sunny_outlined, activeIcon: Icons.wb_sunny,
    labelAr: 'آية اليوم', labelEl: 'Ημερήσιο Εδάφιο',
  ),
  _NavItem(
    path: Routes.adminCmsAgbeya,
    icon: Icons.access_time_outlined, activeIcon: Icons.access_time,
    labelAr: 'الأجبية', labelEl: 'Αγπεγιά',
  ),
  _NavItem(
    path: Routes.adminCmsCategories,
    icon: Icons.category_outlined, activeIcon: Icons.category,
    labelAr: 'تصنيفات الكتب', labelEl: 'Κατηγορίες Βιβλίων',
  ),
  _NavItem(
    path: Routes.adminCmsGames,
    icon: Icons.gamepad_outlined, activeIcon: Icons.gamepad,
    labelAr: 'الألعاب', labelEl: 'Παιχνίδια',
  ),
  _NavItem(
    path: Routes.adminCmsGallery,
    icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library,
    labelAr: 'معرض الصور', labelEl: 'Gallery',
  ),
  _NavItem(
    path: Routes.adminCmsElib,
    icon: Icons.video_library_outlined, activeIcon: Icons.video_library,
    labelAr: 'المكتبة الالكترونية', labelEl: 'Ηλ. Βιβλιοθήκη',
  ),
];

// ════════════════════════════════════════════════════════════════════════════
// SHELL
// ════════════════════════════════════════════════════════════════════════════

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final b    = Theme.of(context).brightness;
    final wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      backgroundColor: BrightnessColors.bgPrimary(b),
      drawer: wide ? null : _CmsDrawer(currentPath: currentPath),
      body:   wide ? _wideLayout() : _narrowLayout(context),
    );
  }

  Widget _wideLayout() => Row(children: [
    _WideSidebar(currentPath: currentPath),
    Expanded(child: child),
  ]);

  Widget _narrowLayout(BuildContext context) => Column(children: [
    _MobileTopBar(currentPath: currentPath),
    Expanded(child: child),
    _MobileBottomNav(currentPath: currentPath),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// WIDE SIDEBAR  (tablet / desktop)
// ════════════════════════════════════════════════════════════════════════════

class _WideSidebar extends StatelessWidget {
  const _WideSidebar({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final b    = Theme.of(context).brightness;
    final l    = context.adminL10n;
    final lang = context.watch<SettingsCubit>().state.language;

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: BrightnessColors.bgDeep(b),
        border: Border(
          right: BorderSide(color: BrightnessColors.goldBorder(b), width: 0.5),
        ),
      ),
      child: Column(children: [
        // ── Logo ────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: BrightnessColors.goldBorder(b), width: 0.5),
            ),
          ),
          child: Row(children: [
            _CrossCircle(size: 36),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ekklisia', style: TextStyle(
                color: BrightnessColors.goldLight(b), fontSize: 14,
                fontWeight: FontWeight.w700, letterSpacing: 2,
              )),
              Text(l.sectionAdmin, style: TextStyle(
                color: BrightnessColors.goldDim(b), fontSize: 9, letterSpacing: 3,
              )),
            ]),
          ]),
        ),

        // ── Nav items ──────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              // Dashboard
              ..._quickActions.take(1).map((item) => _SidebarTile(
                item: item, lang: lang,
                active: currentPath.startsWith(item.path),
                onTap:  () => context.go(item.path),
              )),

              // Quick Actions section
              _SectionLabel(label: l.sectionQuickActions),
              ..._quickActions.skip(1).map((item) => _SidebarTile(
                item: item, lang: lang,
                active: currentPath.startsWith(item.path),
                onTap:  () => context.go(item.path),
              )),

              // CMS section
              _SectionLabel(label: l.sectionContent),
              ..._cmsItems.map((item) => _SidebarTile(
                item: item, lang: lang,
                active: currentPath.startsWith(item.path),
                onTap:  () => context.go(item.path),
              )),
            ],
          ),
        ),

        _SidebarFooter(),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOBILE DRAWER  (CMS only)
// ════════════════════════════════════════════════════════════════════════════

class _CmsDrawer extends StatelessWidget {
  const _CmsDrawer({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final b    = Theme.of(context).brightness;
    final l    = context.adminL10n;
    final lang = context.watch<SettingsCubit>().state.language;

    return Drawer(
      backgroundColor: BrightnessColors.bgDeep(b),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: BrightnessColors.goldBorder(b), width: 0.5),
            ),
          ),
          child: Row(children: [
            _CrossCircle(size: 32),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.sectionContent, style: TextStyle(
                color: BrightnessColors.goldLight(b), fontSize: 13,
                fontWeight: FontWeight.w700, letterSpacing: 1.5,
              )),
              Text('CMS', style: TextStyle(
                color: BrightnessColors.goldDim(b), fontSize: 8, letterSpacing: 3,
              )),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close,
                  color: BrightnessColors.textSecondary(b), size: 20),
            ),
          ]),
        ),

        // CMS items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: _cmsItems.map((item) {
              final active = currentPath.startsWith(item.path);
              return _SidebarTile(
                item: item, lang: lang, active: active,
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.path);
                },
              );
            }).toList(),
          ),
        ),

        _SidebarFooter(),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOBILE TOP BAR
// ════════════════════════════════════════════════════════════════════════════

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.currentPath});
  final String currentPath;

  bool _isCmsPath(String path) =>
      _cmsItems.any((item) => path.startsWith(item.path));

  @override
  Widget build(BuildContext context) {
    final b     = Theme.of(context).brightness;
    final lang  = context.watch<SettingsCubit>().state.language;
    final isCms = _isCmsPath(currentPath);

    // Find matching nav item for title
    String title = lang == AppLanguage.arabic ? 'إكليسيا' : 'Ekklisia';
    for (final item in [..._quickActions, ..._cmsItems]) {
      if (currentPath.startsWith(item.path)) {
        title = item.labelFor(lang);
        break;
      }
    }

    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: BrightnessColors.bgDeep(b),
        border: Border(
          bottom: BorderSide(color: BrightnessColors.goldBorder(b), width: 0.5),
        ),
      ),
      child: Row(children: [
        // Menu button
        IconButton(
          icon: Icon(
            isCms ? Icons.menu_book_outlined : Icons.menu,
            color: BrightnessColors.gold(b),
          ),
          tooltip: 'CMS',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        _CrossCircle(size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            textDirection: lang == AppLanguage.arabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: TextStyle(
              color:       BrightnessColors.goldLight(b),
              fontSize:    14,
              fontWeight:  FontWeight.w700,
              fontFamily:  lang == AppLanguage.arabic ? 'Scheherazade' : null,
            ),
          ),
        ),
        // CMS badge
        if (isCms)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: BrightnessColors.goldSubtle(b),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
            ),
            child: Text('CMS', style: TextStyle(
              color: BrightnessColors.gold(b), fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.5,
            )),
          ),
        // Language toggle
        const _LangToggle(),
        const SizedBox(width: 8),
        // Logout
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              context.read<AuthCubit>().signOut();
              context.go(Routes.login);
            },
            child: Icon(Icons.logout_outlined,
                size: 20, color: BrightnessColors.textSecondary(b)),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOBILE BOTTOM NAV  (Quick Actions only)
// ════════════════════════════════════════════════════════════════════════════

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final b    = Theme.of(context).brightness;
    final lang = context.watch<SettingsCubit>().state.language;

    return Container(
      decoration: BoxDecoration(
        color: BrightnessColors.bgDeep(b),
        border: Border(
          top: BorderSide(color: BrightnessColors.goldBorder(b), width: 0.5),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: _quickActions.map((item) {
              final active = currentPath.startsWith(item.path);
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          key: ValueKey(active),
                          size: 22,
                          color: active
                              ? BrightnessColors.gold(b)
                              : BrightnessColors.textSecondary(b),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.labelFor(lang),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:   9,
                          fontFamily: lang == AppLanguage.arabic
                              ? 'Scheherazade' : null,
                          color:      active
                              ? BrightnessColors.gold(b)
                              : BrightnessColors.textSecondary(b),
                          fontWeight: active
                              ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LANGUAGE TOGGLE  (AR | EL pill)
// ════════════════════════════════════════════════════════════════════════════

class _LangToggle extends StatelessWidget {
  const _LangToggle();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final current = state.language;
        return Container(
          height: 26,
          decoration: BoxDecoration(
            color: BrightnessColors.bgElevated(b),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: BrightnessColors.goldBorder(b), width: 0.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _LangOption(
              label: 'AR',
              active: current == AppLanguage.arabic,
              onTap: () => context
                  .read<SettingsCubit>()
                  .setLanguage(AppLanguage.arabic),
              leftRounded: true,
            ),
            Container(width: 0.5, color: BrightnessColors.goldBorder(b)),
            _LangOption(
              label: 'EL',
              active: current == AppLanguage.greek,
              onTap: () => context
                  .read<SettingsCubit>()
                  .setLanguage(AppLanguage.greek),
              leftRounded: false,
            ),
          ]),
        );
      },
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.active,
    required this.onTap,
    required this.leftRounded,
  });
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  final bool     leftRounded;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final radius = leftRounded
        ? const BorderRadius.horizontal(left:  Radius.circular(5))
        : const BorderRadius.horizontal(right: Radius.circular(5));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 26,
        decoration: BoxDecoration(
          color: active ? BrightnessColors.goldSubtle(b) : Colors.transparent,
          borderRadius: radius,
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color:      active
                ? BrightnessColors.gold(b)
                : BrightnessColors.textSecondary(b),
            fontSize:   10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.5,
          )),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
      child: Text(label, style: TextStyle(
        color: BrightnessColors.goldDim(b), fontSize: 9,
        fontWeight: FontWeight.w700, letterSpacing: 2,
      )),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.lang,
    required this.active,
    required this.onTap,
  });
  final _NavItem     item;
  final AppLanguage  lang;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b        = Theme.of(context).brightness;
    final label    = item.labelFor(lang);
    final isArabic = lang == AppLanguage.arabic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? BrightnessColors.goldSubtle(b) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: active ? BrightnessColors.gold(b) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 18,
                color: active
                    ? BrightnessColors.gold(b)
                    : BrightnessColors.textSecondary(b),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textDirection: isArabic
                      ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    color: active
                        ? BrightnessColors.goldLight(b)
                        : BrightnessColors.textSecondary(b),
                    fontSize:   13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: isArabic ? 'Scheherazade' : null,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: BrightnessColors.goldBorder(b), width: 0.5),
            ),
          ),
          child: Row(children: [
            _Avatar(initials: user?.initials ?? 'A', size: 34),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName.isNotEmpty == true
                      ? user!.displayName : 'Admin',
                  style: TextStyle(
                    color: BrightnessColors.textPrimary(b), fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrightnessColors.textSecondary(b), fontSize: 10,
                  ),
                ),
              ],
            )),
            const _LangToggle(),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                context.read<AuthCubit>().signOut();
                context.go(Routes.login);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BrightnessColors.bgElevated(b),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: BrightnessColors.goldBorder(b), width: 0.5),
                ),
                child: Icon(Icons.logout_outlined,
                    size: 14, color: BrightnessColors.textSecondary(b)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _CrossCircle extends StatelessWidget {
  const _CrossCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [EkklisiaColors.darkBronze, EkklisiaColors.darkMaroon],
        ),
        border: Border.all(color: EkklisiaColors.darkGoldBorder, width: 1),
      ),
      child: Center(child: Text('✦', style: TextStyle(
        color: EkklisiaColors.darkGoldLight, fontSize: size * 0.42,
      ))),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.size = 40});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BrightnessColors.bgElevated(b),
        border: Border.all(color: BrightnessColors.goldBorder(b), width: 1),
      ),
      child: Center(child: Text(initials, style: TextStyle(
        color: BrightnessColors.gold(b), fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
      ))),
    );
  }
}
