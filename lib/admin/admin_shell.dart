// lib/admin/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/colors.dart';
import '../core/router/app_router.dart';
import '../features/auth/auth_cubit.dart';
import '../features/auth/auth_state.dart';


/// Responsive admin shell.
/// • Tablet / desktop (≥720 px)  → persistent sidebar
/// • Mobile (< 720 px)           → bottom navigation + drawer
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child, required this.currentPath});
  final Widget child;
  final String currentPath;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _drawerOpen = false;

  static const _navItems = <_NavItem>[
    _NavItem(path: Routes.adminDashboard, icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard, labelAr: 'الرئيسية',    labelEn: 'Dashboard'),
    _NavItem(path: Routes.adminUpload,    icon: Icons.upload_file_outlined,
        activeIcon: Icons.upload_file,    labelAr: 'رفع كتاب',  labelEn: 'Upload'),
    _NavItem(path: Routes.adminBooks,     icon: Icons.library_books_outlined,
        activeIcon: Icons.library_books,  labelAr: 'الكتب',     labelEn: 'Books'),
    _NavItem(path: Routes.adminNotify,    icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,  labelAr: 'الإشعارات', labelEn: 'Notify'),
    _NavItem(path: Routes.adminUsers,     icon: Icons.people_outline,
        activeIcon: Icons.people,         labelAr: 'المستخدمون',labelEn: 'Users'),
    // CMS Content Management
    _NavItem(path: Routes.adminCmsBibles,     icon: Icons.book_outlined,
        activeIcon: Icons.book,            labelAr: 'الكتب المقدسة', labelEn: 'Bibles'),
    _NavItem(path: Routes.adminCmsHymns,      icon: Icons.music_note_outlined,
        activeIcon: Icons.music_note,      labelAr: 'التسابيح',  labelEn: 'Hymns'),
    _NavItem(path: Routes.adminCmsPrayers,    icon: Icons.favorite_outline,
        activeIcon: Icons.favorite,        labelAr: 'الصلوات',   labelEn: 'Prayers'),
    _NavItem(path: Routes.adminCmsLiturgies,  icon: Icons.church_outlined,
        activeIcon: Icons.church,          labelAr: 'القداسات',  labelEn: 'Liturgies'),
    _NavItem(path: Routes.adminCmsSaints,     icon: Icons.person_outline,
        activeIcon: Icons.person,          labelAr: 'القديسون',  labelEn: 'Saints'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      backgroundColor: EkkleiciaColors.bgPrimary,
      drawer: wide ? null : _buildDrawer(context),
      body: wide ? _wideLayout(context) : _narrowLayout(context),
    );
  }

  // ── Wide layout: side-by-side ─────────────────────────────────────────

  Widget _wideLayout(BuildContext context) {
    return Row(children: [
      _Sidebar(items: _navItems, currentPath: widget.currentPath),
      Expanded(child: widget.child),
    ]);
  }

  // ── Narrow layout: topbar + body + bottom nav ─────────────────────────

  Widget _narrowLayout(BuildContext context) {
    return Column(children: [
      _MobileTopBar(
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        currentPath: widget.currentPath,
        items: _navItems,
      ),
      Expanded(child: widget.child),
      _BottomAdminNav(items: _navItems, currentPath: widget.currentPath),
    ]);
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: EkkleiciaColors.bgDeep,
      child: _Sidebar(items: _navItems, currentPath: widget.currentPath,
          isDrawer: true),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SIDEBAR
// ════════════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.currentPath,
    this.isDrawer = false,
  });
  final List<_NavItem> items;
  final String currentPath;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: EkkleiciaColors.bgDeep,
        border: Border(
          right: BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5),
        ),
      ),
      child: Column(children: [
        // Logo
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(
                color: EkkleiciaColors.goldBorder, width: 0.5)),
          ),
          child: Row(children: [
            _CrossCircle(size: 36),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EKKLICIA', style: TextStyle(
                  color: EkkleiciaColors.goldLight, fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 2)),
              Text('ADMIN', style: TextStyle(
                  color: EkkleiciaColors.goldDim, fontSize: 9, letterSpacing: 3)),
            ]),
          ]),
        ),

        // Nav items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: items.map((item) {
              final active = currentPath.startsWith(item.path);
              return _SidebarTile(
                  item: item, active: active,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go(item.path);
                  });
            }).toList(),
          ),
        ),

        // Admin profile + sign out
        _SidebarFooter(),
      ]),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item, required this.active, required this.onTap});
  final _NavItem item;
  final bool     active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? EkkleiciaColors.goldSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: active ? EkkleiciaColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(children: [
              Icon(active ? item.activeIcon : item.icon,
                  size: 20,
                  color: active
                      ? EkkleiciaColors.gold
                      : EkkleiciaColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.labelEn, style: TextStyle(
                    color: active
                        ? EkkleiciaColors.goldLight
                        : EkkleiciaColors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
                  )),
                  Text(item.labelAr, style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    color:      EkkleiciaColors.textSecondary,
                    fontSize:   11,
                  )),
                ]),
              ),
              if (item.path == Routes.adminUpload)
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: EkkleiciaColors.gold, shape: BoxShape.circle),
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
                top: BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5)),
          ),
          child: Column(children: [
            Row(children: [
              _Avatar(initials: user?.initials ?? 'A', size: 34),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.displayName.isNotEmpty == true
                      ? user!.displayName : 'Admin',
                      style: const TextStyle(
                          color: EkkleiciaColors.textPrimary,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(user?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: EkkleiciaColors.textSecondary,
                          fontSize: 10)),
                ],
              )),
              GestureDetector(
                onTap: () {
                  context.read<AuthCubit>().signOut();
                  context.go(Routes.login);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EkkleiciaColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: EkkleiciaColors.goldBorder, width: 0.5),
                  ),
                  child: const Icon(Icons.logout_outlined,
                      size: 14, color: EkkleiciaColors.textSecondary),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              decoration: BoxDecoration(
                color: EkkleiciaColors.goldSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: EkkleiciaColors.goldBorder, width: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      size: 12, color: EkkleiciaColors.gold),
                  SizedBox(width: 5),
                  Text('Admin', style: TextStyle(
                    color: EkkleiciaColors.gold,
                    fontSize: 11, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOBILE TOP BAR
// ════════════════════════════════════════════════════════════════════════════
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.onMenuTap,
    required this.currentPath,
    required this.items,
  });
  final VoidCallback   onMenuTap;
  final String         currentPath;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final current = items.firstWhere(
          (i) => currentPath.startsWith(i.path),
      orElse: () => items.first,
    );
    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: EkkleiciaColors.bgDeep,
        border: Border(bottom: BorderSide(
            color: EkkleiciaColors.goldBorder, width: 0.5)),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.menu, color: EkkleiciaColors.gold),
          onPressed: onMenuTap,
        ),
        _CrossCircle(size: 28),
        const SizedBox(width: 8),
        Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(current.labelEn, style: const TextStyle(
                  color: EkkleiciaColors.goldLight,
                  fontSize: 14, fontWeight: FontWeight.w700)),
              Text(current.labelAr, style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color: EkkleiciaColors.textSecondary, fontSize: 11)),
            ]),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              context.read<AuthCubit>().signOut();
              context.go(Routes.login);
            },
            child: const Icon(Icons.logout_outlined,
                size: 20, color: EkkleiciaColors.textSecondary),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOBILE BOTTOM NAV
// ════════════════════════════════════════════════════════════════════════════
class _BottomAdminNav extends StatelessWidget {
  const _BottomAdminNav({
    required this.items, required this.currentPath});
  final List<_NavItem> items;
  final String         currentPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EkkleiciaColors.bgDeep,
        border: Border(
            top: BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: items.map((item) {
              final active = currentPath.startsWith(item.path);
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(active ? item.activeIcon : item.icon,
                          size: 20,
                          color: active
                              ? EkkleiciaColors.gold
                              : EkkleiciaColors.textSecondary),
                      const SizedBox(height: 2),
                      Text(item.labelEn, style: TextStyle(
                        color: active
                            ? EkkleiciaColors.gold
                            : EkkleiciaColors.textSecondary,
                        fontSize: 9,
                        fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
                      )),
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
            colors: [EkkleiciaColors.bronze, EkkleiciaColors.maroon]),
        border: Border.all(color: EkkleiciaColors.goldBorder, width: 1),
      ),
      child: Center(child: Text('✦', style: TextStyle(
          color: EkkleiciaColors.goldLight, fontSize: size * 0.42))),
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
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EkkleiciaColors.bgElevated,
        border: Border.all(color: EkkleiciaColors.goldBorder, width: 1),
      ),
      child: Center(child: Text(initials, style: TextStyle(
          color: EkkleiciaColors.gold,
          fontSize: size * 0.36, fontWeight: FontWeight.w700))),
    );
  }
}

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