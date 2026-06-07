// lib/admin/admin_shell.dart
// ─────────────────────────────────────────────────────────────────────────────
// Responsive admin shell.
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
import '../core/theme/colors.dart';
import '../core/router/app_router.dart';
import '../features/auth/auth_cubit.dart';
import '../features/auth/auth_state.dart';

// ════════════════════════════════════════════════════════════════════════════
// DATA
// ════════════════════════════════════════════════════════════════════════════

class _NavItem {
  const _NavItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.labelAr,
    required this.labelEn,
  });
  final String   path;
  final IconData icon;
  final IconData activeIcon;
  final String   labelAr;
  final String   labelEn;
}

// Quick Actions — appear in bottom nav on mobile
const _quickActions = <_NavItem>[
  _NavItem(
    path: Routes.adminDashboard,
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    labelAr: 'الرئيسية',
    labelEn: 'Dashboard',
  ),
  _NavItem(
    path: Routes.adminUpload,
    icon: Icons.upload_file_outlined,
    activeIcon: Icons.upload_file,
    labelAr: 'رفع كتاب',
    labelEn: 'Upload',
  ),
  _NavItem(
    path: Routes.adminNotify,
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    labelAr: 'الإشعارات',
    labelEn: 'Notify',
  ),
  _NavItem(
    path: Routes.adminUsers,
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    labelAr: 'المستخدمون',
    labelEn: 'Users',
  ),
];

// CMS items — live in drawer on mobile, sidebar section on wide
const _cmsItems = <_NavItem>[
  _NavItem(
    path: Routes.adminCmsBibles,
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    labelAr: 'الكتاب المقدس',
    labelEn: 'Bible',
  ),
  _NavItem(
    path: Routes.adminCmsHymns,
    icon: Icons.music_note_outlined,
    activeIcon: Icons.music_note,
    labelAr: 'التسابيح',
    labelEn: 'Hymns',
  ),
  _NavItem(
    path: Routes.adminCmsPrayers,
    icon: Icons.favorite_outline,
    activeIcon: Icons.favorite,
    labelAr: 'الصلوات',
    labelEn: 'Prayers',
  ),
  _NavItem(
    path: Routes.adminCmsLiturgies,
    icon: Icons.church_outlined,
    activeIcon: Icons.church,
    labelAr: 'القداسات',
    labelEn: 'Liturgies',
  ),
  _NavItem(
    path: Routes.adminCmsSaints,
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    labelAr: 'القديسون',
    labelEn: 'Saints',
  ),
  _NavItem(
    path: Routes.adminCmsDailyVerse,
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
    labelAr: 'آية اليوم',
    labelEn: 'Daily Verse',
  ),
  _NavItem(
    path: Routes.adminCmsAgbeya,
    icon: Icons.access_time_outlined,
    activeIcon: Icons.access_time,
    labelAr: 'الأجبية',
    labelEn: 'Agbeya',
  ),
];

// ════════════════════════════════════════════════════════════════════════════
// SHELL
// ════════════════════════════════════════════════════════════════════════════

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      backgroundColor: EkklisiaColors.bgPrimary,
      drawer: wide ? null : _CmsDrawer(currentPath: currentPath),
      body: wide ? _wideLayout() : _narrowLayout(context),
    );
  }

  Widget _wideLayout() {
    return Row(children: [
      _WideSidebar(currentPath: currentPath),
      Expanded(child: child),
    ]);
  }

  Widget _narrowLayout(BuildContext context) {
    return Column(children: [
      _MobileTopBar(currentPath: currentPath),
      Expanded(child: child),
      _MobileBottomNav(currentPath: currentPath),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDE SIDEBAR  (tablet / desktop)
// ════════════════════════════════════════════════════════════════════════════

class _WideSidebar extends StatelessWidget {
  const _WideSidebar({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: EkklisiaColors.bgDeep,
        border: Border(
          right: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5),
        ),
      ),
      child: Column(children: [
        // ── Logo ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5)),
          ),
          child: Row(children: [
            _CrossCircle(size: 36),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ekklisia', style: TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              Text('ADMIN', style: TextStyle(
                  color: EkklisiaColors.goldDim, fontSize: 9, letterSpacing: 3)),
            ]),
          ]),
        ),

        // ── Nav items ─────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              // Dashboard
              ..._quickActions.take(1).map((item) => _SidebarTile(
                    item: item,
                    active: currentPath.startsWith(item.path),
                    onTap: () => context.go(item.path),
                  )),

              // Quick Actions section
              _SectionLabel(label: 'QUICK ACTIONS'),
              ..._quickActions.skip(1).map((item) => _SidebarTile(
                    item: item,
                    active: currentPath.startsWith(item.path),
                    onTap: () => context.go(item.path),
                  )),

              // CMS section
              _SectionLabel(label: 'CONTENT'),
              ..._cmsItems.map((item) => _SidebarTile(
                    item: item,
                    active: currentPath.startsWith(item.path),
                    onTap: () => context.go(item.path),
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
    return Drawer(
      backgroundColor: EkklisiaColors.bgDeep,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5)),
          ),
          child: Row(children: [
            _CrossCircle(size: 32),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Content', style: TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              Text('CMS MANAGER', style: TextStyle(
                  color: EkklisiaColors.goldDim, fontSize: 8, letterSpacing: 3)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close,
                  color: EkklisiaColors.textSecondary, size: 20),
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
                item: item,
                active: active,
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.path);
                },
              );
            }).toList(),
          ),
        ),

        // Footer
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

  String _titleFor(String path) {
    for (final item in [..._quickActions, ..._cmsItems]) {
      if (path.startsWith(item.path)) return item.labelEn;
    }
    return 'Admin';
  }

  String _subtitleFor(String path) {
    for (final item in [..._quickActions, ..._cmsItems]) {
      if (path.startsWith(item.path)) return item.labelAr;
    }
    return 'إكليسيا';
  }

  bool _isCmsPath(String path) =>
      _cmsItems.any((item) => path.startsWith(item.path));

  @override
  Widget build(BuildContext context) {
    final isCms = _isCmsPath(currentPath);
    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: EkklisiaColors.bgDeep,
        border: Border(
            bottom: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5)),
      ),
      child: Row(children: [
        // Menu button — opens CMS drawer
        IconButton(
          icon: Icon(
            isCms ? Icons.menu_book_outlined : Icons.menu,
            color: isCms ? EkklisiaColors.gold : EkklisiaColors.gold,
          ),
          tooltip: 'CMS',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        _CrossCircle(size: 26),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titleFor(currentPath),
                style: const TextStyle(
                    color: EkklisiaColors.goldLight,
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text(_subtitleFor(currentPath),
                style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkklisiaColors.textSecondary, fontSize: 11)),
          ],
        ),
        const Spacer(),
        // CMS badge when on a CMS screen
        if (isCms)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EkklisiaColors.goldSubtle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
            ),
            child: const Text('CMS', style: TextStyle(
                color: EkklisiaColors.gold,
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              context.read<AuthCubit>().signOut();
              context.go(Routes.login);
            },
            child: const Icon(Icons.logout_outlined,
                size: 20, color: EkklisiaColors.textSecondary),
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
    return Container(
      decoration: const BoxDecoration(
        color: EkklisiaColors.bgDeep,
        border: Border(
            top: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
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
                              ? EkklisiaColors.gold
                              : EkklisiaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.labelEn,
                        style: TextStyle(
                          fontSize: 9,
                          color: active
                              ? EkklisiaColors.gold
                              : EkklisiaColors.textSecondary,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
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
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: EkklisiaColors.goldDim,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final _NavItem     item;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? EkklisiaColors.goldSubtle : Colors.transparent,
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
                  color: active ? EkklisiaColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 18,
                color: active
                    ? EkklisiaColors.gold
                    : EkklisiaColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.labelEn,
                        style: TextStyle(
                          color: active
                              ? EkklisiaColors.goldLight
                              : EkklisiaColors.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        )),
                    Text(item.labelAr,
                        style: const TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkklisiaColors.textSecondary,
                          fontSize: 11,
                        )),
                  ],
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
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5)),
          ),
          child: Row(children: [
            _Avatar(initials: user?.initials ?? 'A', size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName.isNotEmpty == true
                        ? user!.displayName
                        : 'Admin',
                    style: const TextStyle(
                        color: EkklisiaColors.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    user?.email ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: EkklisiaColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                context.read<AuthCubit>().signOut();
                context.go(Routes.login);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: EkklisiaColors.bgElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: EkklisiaColors.goldBorder, width: 0.5),
                ),
                child: const Icon(Icons.logout_outlined,
                    size: 14, color: EkklisiaColors.textSecondary),
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
            colors: [EkklisiaColors.bronze, EkklisiaColors.maroon]),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 1),
      ),
      child: Center(
        child: Text('✦',
            style: TextStyle(
                color: EkklisiaColors.goldLight, fontSize: size * 0.42)),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.size = 40});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EkklisiaColors.bgElevated,
        border: Border.all(color: EkklisiaColors.goldBorder, width: 1),
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                color: EkklisiaColors.gold,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
