// lib/features/home/home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// App shell with a clean 4-tab bottom navigation:
//   0 → Home dashboard  (HomeTabScreen)
//   1 → Library         (BooksHomeScreen)
//   2 → Bookmarks       (BookmarksScreen)
//   3 → Settings        (SettingsScreen)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/brightness_colors.dart';
import '../../features/agbeya/cubit/audio_player_cubit.dart';
import '../../features/agbeya/cubit/audio_player_state.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/auth/auth_state.dart';
import '../../features/bookmarks/bookmarks_screen.dart';
import '../../features/books/screens/books_home.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../features/settings/settings_screen.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/audio_player_bar.dart';
import 'home_tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _goToLibrary() => setState(() => _selectedIndex = 1);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Keep system UI in sync with theme
    final isDark = brightness == Brightness.dark;
    final navBgColor = BrightnessColors.bgDeep(brightness);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: navBgColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: navBgColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    final tabs = <Widget>[
      HomeTabScreen(onGoToLibrary: _goToLibrary),
      const BooksHomeScreen(),
      const BookmarksScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: BrightnessColors.bgDeep(brightness),
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent mini player — visible whenever a track is loaded
          BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
            builder: (ctx, state) => state.hasTrack
                ? const AudioPlayerBar()
                : const SizedBox.shrink(),
          ),
          _EkklisiaBottomNav(
            selectedIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _EkklisiaBottomNav extends StatelessWidget {
  const _EkklisiaBottomNav({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = Theme.of(context).primaryColor;
    final goldDim = BrightnessColors.goldDim(brightness);

    final lang = context.select<SettingsCubit, AppLanguage>(
      (c) => c.state.language,
    );
    final isGreek = lang == AppLanguage.greek;

    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        arLabel: 'الرئيسية',
        elLabel: 'Αρχική',
        isActive: selectedIndex == 0,
        onTap: () => onTap(0),
      ),
      _NavItem(
        icon: Icons.library_books_outlined,
        activeIcon: Icons.library_books,
        arLabel: 'المكتبة',
        elLabel: 'Βιβλιοθήκη',
        isActive: selectedIndex == 1,
        onTap: () => onTap(1),
      ),
      _NavItem(
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks,
        arLabel: 'الإشارات',
        elLabel: 'Σελιδοδ.',
        isActive: selectedIndex == 2,
        onTap: () => onTap(2),
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        arLabel: 'الإعدادات',
        elLabel: 'Ρυθμίσεις',
        isActive: selectedIndex == 3,
        onTap: () => onTap(3),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgDeep,
        border: Border(top: BorderSide(color: goldBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: items.map((item) {
              final isActive = item.isActive;
              return Expanded(
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          key: ValueKey(isActive),
                          size: 22,
                          color: isActive ? gold : goldDim,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isGreek ? item.elLabel : item.arLabel,
                        style: TextStyle(
                          fontFamily: isGreek ? null : 'Scheherazade',
                          fontSize: isGreek ? 9 : 10,
                          color: isActive ? gold : goldDim,
                          fontWeight: isActive
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

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.arLabel,
    required this.elLabel,
    required this.isActive,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String arLabel;
  final String elLabel;
  final bool isActive;
  final VoidCallback onTap;
}
