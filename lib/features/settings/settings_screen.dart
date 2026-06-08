// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../core/theme/colors.dart';
import '../../../services/settings_service.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'cubit/settings_cubit.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsCubit   _cubit = sl<SettingsCubit>();
  final SettingsService _svc   = sl<SettingsService>();

  late FontScale    _fontScale;
  late AppLanguage  _language;
  late AppThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _fontScale = _svc.fontScale;
    _language  = _svc.language;
    _themeMode = _svc.themeMode;
  }

  void _setFontScale(FontScale fs) async {
    setState(() => _fontScale = fs);
    await _cubit.setFontScale(fs);
  }

  void _setLanguage(AppLanguage lang) async {
    setState(() => _language = lang);
    await _cubit.setLanguage(lang);
  }

  void _setThemeMode(AppThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _cubit.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        const _SettingsAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _ProfileCard(),
              const SizedBox(height: 28),

              const _SectionLabel('حجم الخط', 'Font Size'),
              const SizedBox(height: 10),
              _FontSizeCard(current: _fontScale, onChanged: _setFontScale),
              const SizedBox(height: 28),

              const _SectionLabel('لغة العرض', 'Display Language'),
              const SizedBox(height: 10),
              _LanguageCard(current: _language, onChanged: _setLanguage),
              const SizedBox(height: 28),

              const _SectionLabel('المظهر', 'Appearance'),
              const SizedBox(height: 10),
              _ThemeModeCard(current: _themeMode, onChanged: _setThemeMode),
              const SizedBox(height: 28),

              const _SectionLabel('الحساب', 'Account'),
              const SizedBox(height: 10),
              const _SignOutCard(),
              const SizedBox(height: 32),

              const _Footer(),
            ]),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR
// ═══════════════════════════════════════════════════════════════════════════
class _SettingsAppBar extends StatelessWidget {
  const _SettingsAppBar();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgDeep     = BrightnessColors.bgDeep(brightness);
    final goldDim    = BrightnessColors.goldDim(brightness);
    final goldLight  = BrightnessColors.goldLight(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: bgDeep,
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: BrightnessColors.headerGradient(brightness),
            border: Border(
              bottom: BorderSide(color: goldBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✦',
                          style: TextStyle(color: goldDim, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        'الإعدادات',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: goldLight,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: goldDim,
                          fontSize: 9,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE CARD
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgMid         = BrightnessColors.bgMid(brightness);
    final bgElevated    = BrightnessColors.bgElevated(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final goldSubtle    = BrightnessColors.goldSubtle(brightness);
    final gold          = BrightnessColors.gold(brightness);
    final textPrimary   = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final user   = auth.user;
        final method = auth.signInMethod;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgMid, bgElevated],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: goldBorder, width: 0.6),
          ),
          child: Row(
            children: [
              _Avatar(
                photoUrl: user?.photoUrl ?? '',
                initials: user?.initials ?? '؟',
                isAdmin:  auth.isAdmin,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user?.displayName.isNotEmpty == true) ...[
                      Text(
                        user!.displayName,
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      auth.isAnonymous
                          ? 'ضيف — قراءة فقط'
                          : (user?.email ?? ''),
                      style: TextStyle(color: textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (auth.isAdmin)
                          _Chip('Admin', gold),
                        if (auth.isAnonymous)
                          _Chip('Guest', textSecondary)
                        else
                          _Chip('Reader', BrightnessColors.tealMid(brightness)),
                        _MethodChip(method),
                      ],
                    ),
                  ],
                ),
              ),
              if (auth.isAdmin) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.go(Routes.adminDashboard),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: goldSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: goldBorder),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 20,
                      color: gold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FONT SIZE CARD
// ═══════════════════════════════════════════════════════════════════════════
class _FontSizeCard extends StatelessWidget {
  const _FontSizeCard({required this.current, required this.onChanged});
  final FontScale               current;
  final ValueChanged<FontScale> onChanged;

  static const Map<FontScale, double> _tileSizes = {
    FontScale.small:      14,
    FontScale.medium:     18,
    FontScale.large:      24,
    FontScale.extraLarge: 30,
  };

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgPrimary     = BrightnessColors.bgPrimary(brightness);
    final bgParchment   = BrightnessColors.bgParchment(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final goldSubtle    = BrightnessColors.goldSubtle(brightness);
    final goldLight     = BrightnessColors.goldLight(brightness);
    final gold          = BrightnessColors.gold(brightness);
    final textPrimary   = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    final double previewSize = (_tileSizes[current] ?? 18) * 0.95;

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'اختر الحجم المناسب',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Container(
                    key: ValueKey(current),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: goldSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: goldBorder, width: 0.5),
                    ),
                    child: Text(
                      current.label,
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color: gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Four size tiles
            Row(
              children: FontScale.values.map((fs) {
                final isActive = current == fs;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: fs != FontScale.values.first ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => onChanged(fs),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isActive ? goldSubtle : bgPrimary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? gold : goldBorder,
                            width: isActive ? 1.5 : 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'أ',
                              textScaleFactor: 1,
                              style: TextStyle(
                                fontFamily: 'Scheherazade',
                                color: isActive ? goldLight : textSecondary,
                                fontSize: _tileSizes[fs],
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            if (isActive)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: gold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Live preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgParchment.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: goldBorder.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color: textPrimary,
                      fontSize: previewSize,
                      height: 1.7,
                    ),
                    child: Text(
                      'أبانا الذي في السماوات، ليتقدس اسمك',
                      textAlign: TextAlign.center,
                      textScaleFactor: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: previewSize * 0.72,
                      height: 1.5,
                    ),
                    child: Text(
                      'Our Father who art in heaven, hallowed be thy name',
                      textAlign: TextAlign.center,
                      textScaleFactor: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 11, color: textSecondary),
                const SizedBox(width: 5),
                Text(
                  'يُطبَّق الحجم على كامل النصوص في التطبيق',
                  textScaleFactor: 1,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LANGUAGE CARD
// ═══════════════════════════════════════════════════════════════════════════
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.current, required this.onChanged});
  final AppLanguage               current;
  final ValueChanged<AppLanguage> onChanged;

  static const Map<AppLanguage, String?> _fontFamilies = {
    AppLanguage.arabic: 'Scheherazade',
    AppLanguage.greek:  'GFSDidot',
  };

  static const Map<AppLanguage, String> _nativeNames = {
    AppLanguage.arabic: 'العربية',
    AppLanguage.greek:  'Ελληνικά',
  };

  static const Map<AppLanguage, String> _subtitles = {
    AppLanguage.arabic: 'Arabic',
    AppLanguage.greek:  'Greek',
  };

  static const Map<AppLanguage, String> _samples = {
    AppLanguage.arabic: 'الكتاب المقدس',
    AppLanguage.greek:  'Ἁγία Γραφή',
  };

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgPrimary     = BrightnessColors.bgPrimary(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final goldSubtle    = BrightnessColors.goldSubtle(brightness);
    final goldLight     = BrightnessColors.goldLight(brightness);
    final gold          = BrightnessColors.gold(brightness);
    final textPrimary   = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return _Card(
      child: Column(
        children: AppLanguage.values.asMap().entries.map((entry) {
          final idx      = entry.key;
          final lang     = entry.value;
          final isActive = current == lang;
          final isLast   = idx == AppLanguage.values.length - 1;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                color: isActive ? goldSubtle : Colors.transparent,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(lang),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? gold.withValues(alpha: 0.15)
                                  : bgPrimary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: goldBorder
                                    .withValues(alpha: isActive ? 1.0 : 0.5),
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Text(lang.flagEmoji,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nativeNames[lang] ?? lang.label,
                                  textScaleFactor: 1,
                                  style: TextStyle(
                                    fontFamily: _fontFamilies[lang],
                                    color: isActive ? goldLight : textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      _subtitles[lang] ?? '',
                                      textScaleFactor: 1,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '· ${_samples[lang] ?? ''}',
                                      textScaleFactor: 1,
                                      style: TextStyle(
                                        fontFamily: _fontFamilies[lang],
                                        color: isActive
                                            ? gold.withValues(alpha: 0.7)
                                            : textSecondary
                                                .withValues(alpha: 0.55),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isActive
                                ? Icon(Icons.check_circle,
                                    size: 22,
                                    color: gold,
                                    key: const ValueKey('on'))
                                : Icon(Icons.radio_button_unchecked,
                                    size: 22,
                                    color: goldBorder,
                                    key: const ValueKey('off')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.4,
                  color: goldBorder,
                  indent: 70,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME MODE CARD
// ═══════════════════════════════════════════════════════════════════════════
class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({required this.current, required this.onChanged});
  final AppThemeMode               current;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            _ThemeModeTile(
              labelAr: 'فاتح',
              labelEn: 'Light',
              icon: Icons.wb_sunny_outlined,
              isActive: current == AppThemeMode.light,
              onTap: () => onChanged(AppThemeMode.light),
            ),
            const SizedBox(width: 10),
            _ThemeModeTile(
              labelAr: 'داكن',
              labelEn: 'Dark',
              icon: Icons.nights_stay_outlined,
              isActive: current == AppThemeMode.dark,
              onTap: () => onChanged(AppThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String   labelAr, labelEn;
  final IconData icon;
  final bool     isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgPrimary     = BrightnessColors.bgPrimary(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final goldSubtle    = BrightnessColors.goldSubtle(brightness);
    final goldLight     = BrightnessColors.goldLight(brightness);
    final gold          = BrightnessColors.gold(brightness);
    final textPrimary   = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? goldSubtle : bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? gold : goldBorder,
              width: isActive ? 1.2 : 0.6,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: isActive ? gold : textSecondary),
              const SizedBox(height: 6),
              Text(
                labelAr,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: isActive ? goldLight : textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                labelEn,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SIGN-OUT CARD
// ═══════════════════════════════════════════════════════════════════════════
class _SignOutCard extends StatefulWidget {
  const _SignOutCard();

  @override
  State<_SignOutCard> createState() => _SignOutCardState();
}

class _SignOutCardState extends State<_SignOutCard> {
  bool _loading = false;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const _ConfirmDialog(
        icon: Icons.logout_outlined,
        title: 'تسجيل الخروج',
        body: 'هل تريد تسجيل الخروج من التطبيق؟',
        confirmLabel: 'خروج',
        isDestructive: true,
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    await context.read<AuthCubit>().signOut();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final maroonColor   = BrightnessColors.maroon(brightness);
    final maroonMid     = brightness == Brightness.dark
        ? EkklisiaColors.darkMaroonMid
        : EkklisiaColors.lightMaroonMid;
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return _Card(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loading ? null : _signOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: maroonColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: maroonColor.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: _loading
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(maroonMid),
                            ),
                          ),
                        )
                      : Icon(Icons.logout_outlined,
                          size: 18, color: maroonMid),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: maroonMid,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: maroonMid.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIRMATION DIALOG
// ═══════════════════════════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.isDestructive = false,
  });

  final IconData icon;
  final String   title, body, confirmLabel;
  final bool     isDestructive;

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgMid         = BrightnessColors.bgMid(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final textPrimary   = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final accentColor   = isDestructive
        ? BrightnessColors.maroon(brightness)
        : BrightnessColors.gold(brightness);

    return Dialog(
      backgroundColor: bgMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: goldBorder, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.12),
                border: Border.all(
                    color: accentColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, size: 24, color: accentColor),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.6,
                )),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: BorderSide(color: goldBorder, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إلغاء',
                      style: TextStyle(
                          fontFamily: 'Scheherazade', fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(confirmLabel,
                      style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final goldDim       = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Column(
      children: [
        Text('✦  ✦  ✦',
            style: TextStyle(
                color: goldDim, fontSize: 9, letterSpacing: 8)),
        const SizedBox(height: 6),
        Text('الكنيسة القبطية الأرثوذكسية',
            style: TextStyle(
                fontFamily: 'Scheherazade',
                color: textSecondary,
                fontSize: 11)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED PRIMITIVES
// ═══════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.ar, this.en);
  final String ar, en;

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final gold          = BrightnessColors.gold(brightness);
    final textPrimary   = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(ar,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(width: 8),
        Text(en,
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
              letterSpacing: 0.8,
            )),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgMid      = BrightnessColors.bgMid(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return Container(
      decoration: BoxDecoration(
        color: bgMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: child,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          )),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip(this.method);
  final SignInMethod method;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    switch (method) {
      case SignInMethod.google:
        return const _Chip('Google', Color(0xFF4285F4));
      case SignInMethod.email:
        return _Chip(
          'Email',
          brightness == Brightness.dark
              ? EkklisiaColors.darkOcean
              : EkklisiaColors.lightOcean,
        );
      case SignInMethod.anonymous:
      case SignInMethod.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.initials,
    required this.isAdmin,
  });
  final String photoUrl, initials;
  final bool   isAdmin;

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final bgElevated    = BrightnessColors.bgElevated(brightness);
    final gold          = BrightnessColors.gold(brightness);
    final goldBorder    = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isAdmin ? gold : goldBorder,
          width: isAdmin ? 2.0 : 0.8,
        ),
      ),
      child: ClipOval(
        child: photoUrl.isNotEmpty
            ? Image.network(photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _fallback(bgElevated, isAdmin ? gold : textSecondary))
            : _fallback(bgElevated, isAdmin ? gold : textSecondary),
      ),
    );
  }

  Widget _fallback(Color bg, Color textColor) => Container(
        color: bg,
        child: Center(
          child: Text(initials,
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              )),
        ),
      );
}
