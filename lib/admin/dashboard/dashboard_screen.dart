// lib/admin/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/app_router.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/auth/auth_state.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, booksState) {
        final books     = booksState.books;
        final published = books.where((b) => b.isPublished).length;
        final drafts    = books.length - published;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeBanner(),
              const SizedBox(height: 20),

              // ── Stat cards ─────────────────────────────────────────
              _sectionLabel('Overview'),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _StatCard(
                    label: 'Total Books',
                    labelAr: 'إجمالي الكتب',
                    value: books.length.toString(),
                    icon: Icons.library_books,
                    color: EkklisiaColors.gold,
                  ),
                  _StatCard(
                    label: 'Published',
                    labelAr: 'منشور',
                    value: published.toString(),
                    icon: Icons.check_circle_outline,
                    color: EkklisiaColors.tealMid,
                  ),
                  _StatCard(
                    label: 'Drafts',
                    labelAr: 'مسودات',
                    value: drafts.toString(),
                    icon: Icons.edit_note_outlined,
                    color: EkklisiaColors.textSecondary,
                  ),
                  _StatCard(
                    label: 'Categories',
                    labelAr: 'الأقسام',
                    value: books
                        .map((b) => b.category)
                        .toSet()
                        .length
                        .toString(),
                    icon: Icons.category_outlined,
                    color: EkklisiaColors.goldLight,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Quick actions ──────────────────────────────────────
              _sectionLabel('Quick Actions'),
              const SizedBox(height: 12),
              _QuickActions(),
              const SizedBox(height: 24),

              // ── CMS shortcuts ──────────────────────────────────────
              _sectionLabel('Content Management'),
              const SizedBox(height: 12),
              _CmsShortcuts(),
              const SizedBox(height: 24),

              // ── Recent books ───────────────────────────────────────
              if (books.isNotEmpty) ...[
                _sectionLabel('Recent Books'),
                const SizedBox(height: 12),
                _RecentBooks(books: books.take(5).toList()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
        color:       EkklisiaColors.textSecondary,
        fontSize:    11,
        fontWeight:  FontWeight.w600,
        letterSpacing: 1.5,
      ));
}

// ── Welcome Banner ────────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final name = state.user?.displayName.isNotEmpty == true
            ? state.user!.displayName
            : state.user?.email.split('@').first ?? 'Admin';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [EkklisiaColors.bgMid, EkklisiaColors.bgElevated],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً، $name',
                    style: const TextStyle(
                      fontFamily: 'Scheherazade',
                      color:      EkklisiaColors.goldLight,
                      fontSize:   20,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                const Text('إكليسيا — لوحة التحكم',
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      color:      EkklisiaColors.textSecondary,
                      fontSize:   13,
                    )),
                const SizedBox(height: 10),
                Row(children: [
                  // Admin badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: EkklisiaColors.goldSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: EkklisiaColors.goldBorder, width: 0.5),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 12, color: EkklisiaColors.gold),
                      SizedBox(width: 5),
                      Text('Admin', style: TextStyle(
                        color:      EkklisiaColors.gold,
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      )),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  // ← View App button
                  GestureDetector(
                    onTap: () => context.go(Routes.home),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: EkklisiaColors.tealDark.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: EkklisiaColors.tealMid.withOpacity(0.4),
                            width: 0.5),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.home_outlined,
                            size: 12, color: EkklisiaColors.tealMid),
                        SizedBox(width: 5),
                        Text('View App', style: TextStyle(
                          color:      EkklisiaColors.tealMid,
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )),
                      ]),
                    ),
                  ),
                ]),
              ],
            )),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                    colors: [EkklisiaColors.bronze, EkklisiaColors.maroon]),
                border: Border.all(
                    color: EkklisiaColors.goldBorder, width: 1.5),
              ),
              child: const Center(child: Text('✦', style: TextStyle(
                  color: EkklisiaColors.goldLight, fontSize: 24))),
            ),
          ]),
        );
      },
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.labelAr,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String   label;
  final String   labelAr;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: EkklisiaColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ),
            Icon(icon, size: 16, color: color),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(
                color:      color,
                fontSize:   26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
          ),
          const SizedBox(height: 2),
          Text(labelAr,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color:      EkklisiaColors.textSecondary,
                  fontSize:   11)),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: _ActionButton(
            label: 'Upload Book',
            labelAr: 'رفع كتاب',
            icon: Icons.upload_file,
            color: EkklisiaColors.gold,
            onTap: () => context.go(Routes.adminUpload),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Send Notification',
            labelAr: 'إرسال إشعار',
            icon: Icons.notifications_active_outlined,
            color: EkklisiaColors.maroonMid,
            onTap: () => context.go(Routes.adminNotify),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Users',
            labelAr: 'المستخدمون',
            icon: Icons.people_outline,
            color: EkklisiaColors.tealMid,
            onTap: () => context.go(Routes.adminUsers),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      // ── View App — full-width, prominent ──────────────────────────────
      Material(
        color: EkklisiaColors.tealDark.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(Routes.home),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: EkklisiaColors.tealMid.withOpacity(0.35), width: 0.8),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: EkklisiaColors.tealDark.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: EkklisiaColors.tealMid.withOpacity(0.4),
                      width: 0.8),
                ),
                child: const Icon(Icons.home_outlined,
                    color: EkklisiaColors.tealMid, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('View App',
                        style: TextStyle(
                            color: EkklisiaColors.tealMid,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text('عرض التطبيق',
                        style: TextStyle(
                            fontFamily: 'Scheherazade',
                            color: EkklisiaColors.textSecondary,
                            fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: EkklisiaColors.tealMid, size: 14),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── CMS Shortcuts ─────────────────────────────────────────────────────────────

class _CmsShortcuts extends StatelessWidget {
  static final _items = [
    (label: 'Bible', labelAr: 'الكتاب المقدس', icon: Icons.book_outlined,
      color: EkklisiaColors.gold, path: Routes.adminCmsBibles),
    (label: 'Hymns', labelAr: 'التسابيح', icon: Icons.music_note_outlined,
      color: EkklisiaColors.tealDark, path: Routes.adminCmsHymns),
    (label: 'Prayers', labelAr: 'الصلوات', icon: Icons.favorite_outline,
      color: EkklisiaColors.maroonMid, path: Routes.adminCmsPrayers),
    (label: 'Liturgies', labelAr: 'القداسات', icon: Icons.church_outlined,
      color: EkklisiaColors.bronze, path: Routes.adminCmsLiturgies),
    (label: 'Saints', labelAr: 'القديسون', icon: Icons.person_outline,
      color: EkklisiaColors.plum, path: Routes.adminCmsSaints),
    (label: 'Daily Verse', labelAr: 'آية اليوم', icon: Icons.menu_book_outlined,
      color: EkklisiaColors.tealMid, path: Routes.adminCmsDailyVerse),
    (label: 'Agbeya', labelAr: 'الأجبية', icon: Icons.access_time_outlined,
      color: EkklisiaColors.maroon, path: Routes.adminCmsAgbeya),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: _items.map((item) {
        return Material(
          color: item.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.go(item.path),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: item.color.withOpacity(0.25), width: 0.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(item.icon, color: item.color, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                        color: item.color,
                        fontSize: 11, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.labelAr,
                    style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        color: EkklisiaColors.textSecondary,
                        fontSize: 10),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.labelAr,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String   label;
  final String   labelAr;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(labelAr,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Scheherazade',
                      color: EkklisiaColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent Books list ─────────────────────────────────────────────────────────

class _RecentBooks extends StatelessWidget {
  const _RecentBooks({required this.books});
  final List books;

  static const _catColors = {
    'bible': EkklisiaColors.maroon, 'prayers': EkklisiaColors.maroonMid,
    'liturgy': EkklisiaColors.bronze, 'hymns': EkklisiaColors.tealDark,
    'saints': EkklisiaColors.plum, 'fathers': EkklisiaColors.forest,
    'commentaries': EkklisiaColors.ocean, 'studies': EkklisiaColors.ocean,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EkklisiaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EkklisiaColors.goldBorder, width: 0.5),
      ),
      child: Column(children: [
        for (int i = 0; i < books.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              // Cover thumb
              Container(
                width: 36, height: 50,
                decoration: BoxDecoration(
                  color: (_catColors[books[i].category] ??
                      EkklisiaColors.bgElevated)
                      .withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: EkklisiaColors.goldBorder, width: 0.5),
                ),
                child: Center(child: Text(
                    books[i].titleAr.isNotEmpty
                        ? books[i].titleAr.substring(0,
                        books[i].titleAr.length > 1 ? 2 : 1)
                        : '؟',
                    style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        color: EkklisiaColors.textCream,
                        fontSize: 11))),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(books[i].titleAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkklisiaColors.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_catColors[books[i].category] ??
                            EkklisiaColors.bgElevated)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(books[i].category, style: const TextStyle(
                          color: EkklisiaColors.textSecondary,
                          fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    Text(books[i].formattedSize, style: const TextStyle(
                        color: EkklisiaColors.textSecondary, fontSize: 10)),
                  ]),
                ],
              )),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: books[i].isPublished
                      ? EkklisiaColors.tealMid.withOpacity(0.15)
                      : EkklisiaColors.bgElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: books[i].isPublished
                        ? EkklisiaColors.tealMid.withOpacity(0.4)
                        : EkklisiaColors.goldBorder,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  books[i].isPublished ? 'LIVE' : 'DRAFT',
                  style: TextStyle(
                    color: books[i].isPublished
                        ? EkklisiaColors.tealMid
                        : EkklisiaColors.textSecondary,
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ]),
          ),
          if (i < books.length - 1)
            const Divider(height: 1, color: EkklisiaColors.goldBorder,
                indent: 14, endIndent: 14),
        ],
      ]),
    );
  }
}