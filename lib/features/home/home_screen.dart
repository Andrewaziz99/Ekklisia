// lib/features/home/screens/home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 1 home shell.
// Provides a bottom navigation bar ready for future tabs.
// Currently only the Library tab is active.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../books/screens/books_home.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Future tabs (Phase 2+) are placeholder widgets for now
  static const _tabs = <Widget>[
    BooksHomeScreen(),
    _PlaceholderTab(icon: Icons.calendar_month_outlined, label: 'التقويم'),
    _PlaceholderTab(icon: Icons.music_note_outlined,     label: 'التسابيح'),
    _PlaceholderTab(icon: Icons.settings_outlined,       label: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style to match the deep header
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          EkkleiciaColors.bgDeep,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: EkkleiciaColors.bgDeep,
    ));

    return Scaffold(
      backgroundColor: EkkleiciaColors.bgPrimary,
      // Admin entry FAB — only visible to admin users
      floatingActionButton: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, auth) => auth.isAdmin
            ? FloatingActionButton.small(
                onPressed: () => context.go(Routes.adminDashboard),
                backgroundColor: EkkleiciaColors.bgElevated,
                shape: const CircleBorder(),
                elevation: 4,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: EkkleiciaColors.goldBorder, width: 1),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 18,
                    color: EkkleiciaColors.gold,
                  ),
                ),
              )
            : FloatingActionButton.small(
          onPressed: () => context.go(Routes.login),
          backgroundColor: EkkleiciaColors.bgElevated,
          shape: const CircleBorder(),
          elevation: 4,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: EkkleiciaColors.goldBorder, width: 1),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              size: 18,
              color: EkkleiciaColors.gold,
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _EkkleiciaBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _EkkleiciaBottomNav extends StatelessWidget {
  const _EkkleiciaBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: EkkleiciaColors.bottomNavGradient,
        border: Border(
          top: BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon:     Icons.library_books_outlined,
                activeIcon: Icons.library_books,
                label:    'المكتبة',
                isActive: selectedIndex == 0,
                onTap:    () => onTap(0),
              ),
              _NavItem(
                icon:     Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label:    'التقويم',
                isActive: selectedIndex == 1,
                onTap:    () => onTap(1),
                isComingSoon: true,
              ),
              // Centre ornamental button
              _CentreButton(onTap: () => onTap(0)),
              _NavItem(
                icon:     Icons.music_note_outlined,
                activeIcon: Icons.music_note,
                label:    'التسابيح',
                isActive: selectedIndex == 2,
                onTap:    () => onTap(2),
                isComingSoon: true,
              ),
              _NavItem(
                icon:     Icons.settings_outlined,
                activeIcon: Icons.settings,
                label:    'الإعدادات',
                isActive: selectedIndex == 3,
                onTap:    () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isComingSoon = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isComingSoon
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$label — قريباً',
                    style: const TextStyle(fontFamily: 'Scheherazade', color: EkkleiciaColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: EkkleiciaColors.bgElevated,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                        color: EkkleiciaColors.goldBorder, width: 0.5),
                  ),
                ),
              )
          : onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive
                  ? EkkleiciaColors.gold
                  : EkkleiciaColors.textSecondary
                      .withValues(alpha: isComingSoon ? 0.4 : 1.0),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize: 10,
                color: isActive
                    ? EkkleiciaColors.gold
                    : EkkleiciaColors.textSecondary
                        .withValues(alpha: isComingSoon ? 0.4 : 1.0),
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular gold centre button — navigates to library
class _CentreButton extends StatelessWidget {
  const _CentreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [EkkleiciaColors.bronze, EkkleiciaColors.maroon],
          ),
          border: Border.all(
              color: EkkleiciaColors.goldBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: EkkleiciaColors.gold.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '✦',
            style: TextStyle(
              color: EkkleiciaColors.goldLight,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Placeholder tab (Phase 2+ features) ──────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EkkleiciaColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: EkkleiciaColors.goldBorder, width: 0.5),
                color: EkkleiciaColors.bgMid,
              ),
              child:
                  Icon(icon, size: 40, color: EkkleiciaColors.goldDim),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Scheherazade',
                color: EkkleiciaColors.textSecondary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'قريباً',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: EkkleiciaColors.gold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
