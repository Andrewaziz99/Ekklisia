// lib/admin/components/cms_sidebar.dart
// ─────────────────────────────────────────────────────────────────────────────
// Enhanced sidebar with CMS navigation sections
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../cms_router.dart';

class CMSSidebar extends StatelessWidget {
  const CMSSidebar({
    super.key,
    required this.currentPath,
    this.isDrawer = false,
  });

  final String currentPath;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: EkklisiaColors.bgDeep,
        border: Border(
          right: BorderSide(
            color: EkklisiaColors.goldBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: EkklisiaColors.goldBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        EkklisiaColors.bronze,
                        EkklisiaColors.maroon,
                      ],
                    ),
                    border: Border.all(
                      color: EkklisiaColors.goldBorder,
                      width: 0.8,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '✦',
                      style: TextStyle(
                        color: EkklisiaColors.goldLight,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ekklisia',
                        style: TextStyle(
                          color: EkklisiaColors.goldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'CMS',
                        style: TextStyle(
                          color: EkklisiaColors.goldDim,
                          fontSize: 8,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content sections ──────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _SidebarSection(
                  title: 'Content Management',
                  titleAr: 'إدارة المحتوى',
                  items: cmsNavItems,
                  currentPath: currentPath,
                  onItemTap: (path) {
                    if (isDrawer) Navigator.pop(context);
                    context.go(path);
                  },
                ),
                const SizedBox(height: 4),
                _buildDivider(),
                const SizedBox(height: 8),
                _SidebarAction(
                  icon: Icons.people_outline,
                  labelEn: 'Users',
                  labelAr: 'المستخدمون',
                  isActive: currentPath.startsWith('/admin/users'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/users');
                  },
                ),
                _SidebarAction(
                  icon: Icons.notifications_outlined,
                  labelEn: 'Notifications',
                  labelAr: 'الإشعارات',
                  isActive: currentPath.startsWith('/admin/notify'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/notifications');
                  },
                ),
              ],
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: EkklisiaColors.goldBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: EkklisiaColors.goldSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: EkklisiaColors.goldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 12,
                        color: EkklisiaColors.gold,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Admin Access',
                        style: TextStyle(
                          color: EkklisiaColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: EkklisiaColors.goldBorder.withOpacity(0.3),
        height: 1,
        thickness: 0.5,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SIDEBAR SECTION
// ════════════════════════════════════════════════════════════════════════════
class _SidebarSection extends StatelessWidget {
  const _SidebarSection({
    required this.title,
    required this.titleAr,
    required this.items,
    required this.currentPath,
    required this.onItemTap,
  });

  final String title;
  final String titleAr;
  final List<CMSNavItem> items;
  final String currentPath;
  final Function(String path) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: EkklisiaColors.goldLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text(
                titleAr,
                style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  color: EkklisiaColors.goldDim,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _SidebarItem(
          item: item,
          isActive: currentPath.startsWith(item.path),
          onTap: () => onItemTap(item.path),
        )),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SIDEBAR ITEM
// ════════════════════════════════════════════════════════════════════════════
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final CMSNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? EkklisiaColors.goldSubtle : Colors.transparent,
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
                  color: isActive ? EkklisiaColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 18,
                  color: isActive
                      ? EkklisiaColors.gold
                      : EkklisiaColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.labelEn,
                        style: TextStyle(
                          color: isActive
                              ? EkklisiaColors.goldLight
                              : EkklisiaColors.textSecondary,
                          fontSize: 12,
                          fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        item.labelAr,
                        style: const TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkklisiaColors.textSecondary,
                          fontSize: 9,
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

// ════════════════════════════════════════════════════════════════════════════
// SIDEBAR ACTION BUTTON
// ════════════════════════════════════════════════════════════════════════════
class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    required this.icon,
    required this.labelEn,
    required this.labelAr,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String labelEn;
  final String labelAr;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? EkklisiaColors.goldSubtle : Colors.transparent,
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
                  color: isActive ? EkklisiaColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive
                      ? EkklisiaColors.gold
                      : EkklisiaColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelEn,
                        style: TextStyle(
                          color: isActive
                              ? EkklisiaColors.goldLight
                              : EkklisiaColors.textSecondary,
                          fontSize: 12,
                          fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        labelAr,
                        style: const TextStyle(
                          fontFamily: 'Scheherazade',
                          color: EkklisiaColors.textSecondary,
                          fontSize: 9,
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