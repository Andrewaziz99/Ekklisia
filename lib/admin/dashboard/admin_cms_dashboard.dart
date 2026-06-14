// lib/admin/dashboard/admin_cms_dashboard.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin dashboard with CMS statistics and quick actions
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/constants/app_constants.dart';
import '../cms_router.dart';

class AdminCMSDashboard extends StatefulWidget {
  const AdminCMSDashboard({super.key});

  @override
  State<AdminCMSDashboard> createState() => _AdminCMSDashboardState();
}

class _AdminCMSDashboardState extends State<AdminCMSDashboard> {
  final _fb = FirebaseFirestore.instance;

  Future<int> _getCollectionCount(String collection) async {
    try {
      final snap = await _fb.collection(collection).count().get();
      return snap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome header ──────────────────────────────────────────────
            Text(
              'Πίνακας CMS',
              style: EkklisiaTheme.bodyMedium(Theme.of(context).brightness),
            ),
            const SizedBox(height: 8),
            Text(
              'Διαχείριση περιεχομένου σε όλες τις ενότητες',
              style: EkklisiaTheme.bodySmall(Theme.of(context).brightness),
            ),
            const SizedBox(height: 32),

            // ── Stats grid ──────────────────────────────────────────────────
            GridView.count(
              crossAxisCount: _getGridColumns(context),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Βίβλοι',
                  icon: Icons.book_outlined,
                  collection: AppConstants.biblesCollection,
                  onTap: () => context.go(CMSRouter.bibles),
                ),
                _StatCard(
                  title: 'Ύμνοι',
                  icon: Icons.music_note_outlined,
                  collection: AppConstants.hymnsCollection,
                  onTap: () => context.go(CMSRouter.hymns),
                ),
                _StatCard(
                  title: 'Προσευχές',
                  icon: Icons.favorite_outline,
                  collection: AppConstants.prayersCollection,
                  onTap: () => context.go(CMSRouter.prayers),
                ),
                _StatCard(
                  title: 'Λειτουργίες',
                  icon: Icons.church_outlined,
                  collection: AppConstants.liturgiesCollection,
                  onTap: () => context.go(CMSRouter.liturgies),
                ),
                _StatCard(
                  title: 'Άγιοι',
                  icon: Icons.person_outline,
                  collection: AppConstants.saintsCollection,
                  onTap: () => context.go(CMSRouter.saints),
                ),
                _StatCard(
                  title: 'Χρήστες',
                  icon: Icons.people_outline,
                  collection: AppConstants.usersCollection,
                  onTap: () => context.go('/admin/users'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Quick actions ───────────────────────────────────────────────
            _buildQuickActions(context),

            const SizedBox(height: 32),

            // ── Recent activity ─────────────────────────────────────────────
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 3;
    if (width > 768) return 2;
    return 1;
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Γρήγορες Ενέργειες',
          style: EkklisiaTheme.headingMedium(Theme.of(context).brightness),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionButton(
              label: 'Προσθήκη Βίβλου',
              icon: Icons.menu_book_outlined,
              color: EkklisiaColors.tealMid,
              onPressed: () => context.go(CMSRouter.bibles),
            ),
            _QuickActionButton(
              label: 'Προσθήκη Ύμνου',
              icon: Icons.add_box_outlined,
              color: EkklisiaColors.plum,
              onPressed: () => context.go(CMSRouter.hymns),
            ),
            _QuickActionButton(
              label: 'Προσθήκη Προσευχής',
              icon: Icons.add_location_outlined,
              color: EkklisiaColors.maroon,
              onPressed: () => context.go(CMSRouter.prayers),
            ),
            _QuickActionButton(
              label: 'Προσθήκη Αγίου',
              icon: Icons.person_add_outlined,
              color: EkklisiaColors.bronze,
              onPressed: () => context.go(CMSRouter.saints),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Κατάσταση Συστήματος',
          style: EkklisiaTheme.headingMedium(Theme.of(context).brightness),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EkklisiaColors.bgMid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EkklisiaColors.goldBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: EkklisiaColors.tealMid,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Σύνδεση Βάσης Δεδομένων',
                      style: TextStyle(
                        color: EkklisiaColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Το Firestore είναι συνδεδεμένο και συγχρονισμένο',
                      style: TextStyle(
                        color: EkklisiaColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EkklisiaColors.tealMid.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: EkklisiaColors.tealMid.withOpacity(0.4),
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  'Ενεργό',
                  style: TextStyle(
                    color: EkklisiaColors.tealMid,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STAT CARD
// ════════════════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.collection,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: EkklisiaColors.bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EkklisiaColors.goldBorder,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: EkklisiaColors.goldSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: EkklisiaColors.goldBorder,
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                color: EkklisiaColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: EkklisiaColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _getCount(),
              builder: (context, snap) {
                if (snap.hasData) {
                  return Text(
                    '${snap.data} στοιχεία',
                    style: const TextStyle(
                      color: EkklisiaColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }
                return const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(
                      EkklisiaColors.gold,
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Διαχείριση',
                  style: TextStyle(
                    color: EkklisiaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_outlined,
                  size: 14,
                  color: EkklisiaColors.goldDim,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUICK ACTION BUTTON
// ════════════════════════════════════════════════════════════════════════════
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}