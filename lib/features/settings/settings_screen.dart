// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../services/settings_service.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'cubit/settings_cubit.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN  — StatefulWidget, owns local state, no BlocBuilder needed
// ═══════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsCubit _cubit   = sl<SettingsCubit>();
  final SettingsService _svc   = sl<SettingsService>();

  late FontScale   _fontScale;
  late AppLanguage _language;

  @override
  void initState() {
    super.initState();
    // Seed from the persisted service so we always start from saved values
    _fontScale = _svc.fontScale;
    _language  = _svc.language;
  }

  // ── Setters — update local state immediately, then persist ───────────────

  void _setFontScale(FontScale fs) async {
    setState(() => _fontScale = fs);
    try {
      await _cubit.setFontScale(fs);  // persists + emits cubit state
      debugPrint('✓ Font scale changed to: ${fs.label}');
    } catch (e) {
      debugPrint('✗ Font scale error: $e');
    }
  }

  void _setLanguage(AppLanguage lang) async {
    setState(() => _language = lang);
    try {
      await _cubit.setLanguage(lang);  // persists + emits cubit state
      debugPrint('✓ Language changed to: ${lang.label}');
    } catch (e) {
      debugPrint('✗ Language error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        _SettingsAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Profile ──────────────────────────────────────────────
              _ProfileCard(),
              const SizedBox(height: 28),

              // ── Font Size ────────────────────────────────────────────
              _SectionLabel('حجم الخط', 'Font Size'),
              const SizedBox(height: 10),
              _FontSizeCard(
                current: _fontScale,
                onChanged: _setFontScale,
              ),
              const SizedBox(height: 28),

              // ── Language ─────────────────────────────────────────────
              _SectionLabel('لغة العرض', 'Display Language'),
              const SizedBox(height: 10),
              _LanguageCard(
                current: _language,
                onChanged: _setLanguage,
              ),
              const SizedBox(height: 28),

              // ── Sign Out ─────────────────────────────────────────────
              _SectionLabel('الحساب', 'Account'),
              const SizedBox(height: 10),
              _SignOutCard(),
              const SizedBox(height: 32),

              // ── Footer ───────────────────────────────────────────────
              _Footer(),
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
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: EkkleiciaColors.bgDeep,
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: EkkleiciaColors.headerGradient,
            border: Border(
              bottom: BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✦',
                          style: TextStyle(
                              color: EkkleiciaColors.goldDim, fontSize: 11)),
                      SizedBox(height: 4),
                      Text(
                        'الإعدادات',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkkleiciaColors.goldLight,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: EkkleiciaColors.goldDim,
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
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final user   = auth.user;
        final method = auth.signInMethod;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [EkkleiciaColors.bgMid, EkkleiciaColors.bgElevated],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.6),
          ),
          child: Row(
            children: [
              _Avatar(
                photoUrl: user?.photoUrl ?? '',
                initials: user?.initials ?? '؟',
                isAdmin: auth.isAdmin,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user?.displayName.isNotEmpty == true) ...[
                      Text(
                        user!.displayName,
                        style: const TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkkleiciaColors.textPrimary,
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
                      style: const TextStyle(
                          color: EkkleiciaColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (auth.isAdmin)
                          _Chip('Admin', EkkleiciaColors.gold),
                        if (auth.isAnonymous)
                          _Chip('Guest', EkkleiciaColors.textSecondary)
                        else
                          _Chip('Reader', EkkleiciaColors.tealMid),
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
                      color: EkkleiciaColors.goldSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EkkleiciaColors.goldBorder),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 20,
                      color: EkkleiciaColors.gold,
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
  final FontScale             current;
  final ValueChanged<FontScale> onChanged;

  static const Map<FontScale, double> _tileSizes = {
    FontScale.small:      14,
    FontScale.medium:     18,
    FontScale.large:      24,
    FontScale.extraLarge: 30,
  };

  @override
  Widget build(BuildContext context) {
    final double previewSize = (_tileSizes[current] ?? 18) * 0.95;

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'اختر الحجم المناسب',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkkleiciaColors.textSecondary,
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
                      color: EkkleiciaColors.goldSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: EkkleiciaColors.goldBorder, width: 0.5),
                    ),
                    child: Text(
                      current.label,
                      style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        color: EkkleiciaColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Four tiles ───────────────────────────────────────────────
            Row(
              children: FontScale.values.map((fs) {
                final isActive = current == fs;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: fs != FontScale.values.first ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => onChanged(fs),   // ← calls setState above
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isActive
                              ? EkkleiciaColors.goldSubtle
                              : EkkleiciaColors.bgPrimary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? EkkleiciaColors.gold
                                : EkkleiciaColors.goldBorder,
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
                                color: isActive
                                    ? EkkleiciaColors.goldLight
                                    : EkkleiciaColors.textSecondary,
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
                                decoration: const BoxDecoration(
                                  color: EkkleiciaColors.gold,
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

            // ── Live preview ─────────────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Scheherazade',
                color: EkkleiciaColors.textPrimary,
                fontSize: previewSize,
                height: 1.7,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color:
                  EkkleiciaColors.bgParchment.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: EkkleiciaColors.goldBorder.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'أبانا الذي في السماوات، ليتقدس اسمك',
                      textAlign: TextAlign.center,
                      textScaleFactor: 1,
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color: EkkleiciaColors.textPrimary,
                        fontSize: previewSize,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Our Father who art in heaven, hallowed be thy name',
                      textAlign: TextAlign.center,
                      textScaleFactor: 1,
                      style: TextStyle(
                        color: EkkleiciaColors.textSecondary,
                        fontSize: previewSize * 0.72,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Note ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.info_outline,
                    size: 11, color: EkkleiciaColors.textSecondary),
                SizedBox(width: 5),
                Text(
                  'يُطبَّق الحجم على كامل النصوص في التطبيق',
                  textScaleFactor: 1,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: EkkleiciaColors.textSecondary,
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
    AppLanguage.arabic:  'Scheherazade',
    AppLanguage.coptic:  'CopticFont',
    AppLanguage.greek:   'GFSDidot',
    AppLanguage.english: null,
  };

  static const Map<AppLanguage, String> _nativeNames = {
    AppLanguage.arabic:  'العربية',
    AppLanguage.coptic:  'ⲙⲉⲧⲣⲉⲙⲛ̀ⲭⲏⲙⲓ',
    AppLanguage.greek:   'Ελληνικά',
    AppLanguage.english: 'English',
  };

  static const Map<AppLanguage, String> _subtitles = {
    AppLanguage.arabic:  'Arabic',
    AppLanguage.coptic:  'Coptic',
    AppLanguage.greek:   'Greek',
    AppLanguage.english: 'English',
  };

  static const Map<AppLanguage, String> _samples = {
    AppLanguage.arabic:  'الكتاب المقدس',
    AppLanguage.coptic:  'ⲡⲓⲃⲓⲃⲗⲟⲥ',
    AppLanguage.greek:   'Ἁγία Γραφή',
    AppLanguage.english: 'Holy Scripture',
  };

  @override
  Widget build(BuildContext context) {
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
                color: isActive
                    ? EkkleiciaColors.goldSubtle
                    : Colors.transparent,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(lang),   // ← calls setState above
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Flag badge
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? EkkleiciaColors.gold.withValues(alpha: 0.15)
                                  : EkkleiciaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: EkkleiciaColors.goldBorder
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

                          // Names + sample
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nativeNames[lang] ?? lang.label,
                                  textScaleFactor: 1,
                                  style: TextStyle(
                                    fontFamily: _fontFamilies[lang],
                                    color: isActive
                                        ? EkkleiciaColors.goldLight
                                        : EkkleiciaColors.textPrimary,
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
                                      style: const TextStyle(
                                        color: EkkleiciaColors.textSecondary,
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
                                            ? EkkleiciaColors.gold
                                            .withValues(alpha: 0.7)
                                            : EkkleiciaColors.textSecondary
                                            .withValues(alpha: 0.55),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Check indicator
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isActive
                                ? const Icon(Icons.check_circle,
                                size: 22,
                                color: EkkleiciaColors.gold,
                                key: ValueKey('on'))
                                : const Icon(Icons.radio_button_unchecked,
                                size: 22,
                                color: EkkleiciaColors.goldBorder,
                                key: ValueKey('off')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 0.4,
                  color: EkkleiciaColors.goldBorder,
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
// SIGN-OUT CARD  — preserved exactly as original
// ═══════════════════════════════════════════════════════════════════════════
class _SignOutCard extends StatefulWidget {
  @override
  State<_SignOutCard> createState() => _SignOutCardState();
}

class _SignOutCardState extends State<_SignOutCard> {
  bool _loading = false;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _ConfirmDialog(
        icon: Icons.logout_outlined,
        iconColor: EkkleiciaColors.maroonMid,
        title: 'تسجيل الخروج',
        body: 'هل تريد تسجيل الخروج من التطبيق؟',
        confirmLabel: 'خروج',
        confirmColor: EkkleiciaColors.maroon,
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loading = true);
    await context.read<AuthCubit>().signOut();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loading ? null : _signOut,
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: EkkleiciaColors.maroon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: EkkleiciaColors.maroon.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: _loading
                      ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            EkkleiciaColors.maroonMid),
                      ),
                    ),
                  )
                      : const Icon(Icons.logout_outlined,
                      size: 18, color: EkkleiciaColors.maroonMid),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkkleiciaColors.maroonMid,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: EkkleiciaColors.textSecondary,
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
                  color: EkkleiciaColors.maroonMid.withValues(alpha: 0.5),
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
    required this.iconColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final IconData icon;
  final Color    iconColor;
  final String   title, body, confirmLabel;
  final Color    confirmColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EkkleiciaColors.bgMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
            color: EkkleiciaColors.goldBorder, width: 0.5),
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
                color: iconColor.withValues(alpha: 0.12),
                border: Border.all(
                    color: iconColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color: EkkleiciaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color: EkkleiciaColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                )),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EkkleiciaColors.textSecondary,
                    side: const BorderSide(
                        color: EkkleiciaColors.goldBorder, width: 0.5),
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
                    backgroundColor: confirmColor,
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
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('✦  ✦  ✦',
            style: TextStyle(
                color: EkkleiciaColors.goldDim,
                fontSize: 9,
                letterSpacing: 8)),
        SizedBox(height: 6),
        Text('الكنيسة القبطية الأرثوذكسية',
            style: TextStyle(
                fontFamily: 'Scheherazade',
                color: EkkleiciaColors.textSecondary,
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
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: EkkleiciaColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(ar,
            style: const TextStyle(
              fontFamily: 'Scheherazade',
              color: EkkleiciaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(width: 8),
        Text(en,
            style: const TextStyle(
              color: EkkleiciaColors.textSecondary,
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
    return Container(
      decoration: BoxDecoration(
        color: EkkleiciaColors.bgMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
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
    switch (method) {
      case SignInMethod.google:
        return _Chip('Google', const Color(0xFF4285F4));
      case SignInMethod.email:
        return _Chip('Email', EkkleiciaColors.ocean);
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
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isAdmin ? EkkleiciaColors.gold : EkkleiciaColors.goldBorder,
          width: isAdmin ? 2.0 : 0.8,
        ),
      ),
      child: ClipOval(
        child: photoUrl.isNotEmpty
            ? Image.network(photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    color: EkkleiciaColors.bgElevated,
    child: Center(
      child: Text(initials,
          style: TextStyle(
            fontFamily: 'Scheherazade',
            color: isAdmin
                ? EkkleiciaColors.gold
                : EkkleiciaColors.textSecondary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          )),
    ),
  );
}