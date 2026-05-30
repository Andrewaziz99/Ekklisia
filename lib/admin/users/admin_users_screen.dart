// lib/admin/users/admin_users_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/user_model.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search  = TextEditingController();
  String _filter = 'all'; // all | admin | anon | active

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ───────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: const BoxDecoration(
          color: EkklisiaColors.bgDeep,
          border: Border(
              bottom: BorderSide(
                  color: EkklisiaColors.goldBorder, width: 0.5)),
        ),
        child: Column(children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                color: EkklisiaColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by email or UID…',
              hintStyle: const TextStyle(
                  color: EkklisiaColors.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: EkklisiaColors.goldDim),
              filled:    true,
              fillColor: EkklisiaColors.bgElevated,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: EkklisiaColors.goldBorder, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: EkklisiaColors.gold, width: 1.0),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip('All',   'all'),
              _FilterChip('Admins','admin'),
              _FilterChip('Anonymous', 'anon'),
            ].map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = c.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _filter == c.key
                        ? EkklisiaColors.goldSubtle
                        : EkklisiaColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filter == c.key
                          ? EkklisiaColors.gold
                          : EkklisiaColors.goldBorder,
                      width: _filter == c.key ? 1.0 : 0.5,
                    ),
                  ),
                  child: Text(c.label, style: TextStyle(
                    color: _filter == c.key
                        ? EkklisiaColors.goldLight
                        : EkklisiaColors.textSecondary,
                    fontSize: 12,
                    fontWeight: _filter == c.key
                        ? FontWeight.w600 : FontWeight.w400,
                  )),
                ),
              ),
            )).toList(),
          ),
          )
        ]),
      ),

      // ── User list from Firestore ─────────────────────────────────────
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: sl<FirebaseFirestore>()
              .collection(AppConstants.usersCollection)
              .orderBy('last_seen_at', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                      EkklisiaColors.gold)));
            }
            if (snap.hasError) {
              return Center(child: Text(
                  'Error: ${snap.error}',
                  style: const TextStyle(
                      color: EkklisiaColors.textSecondary)));
            }

            final q = _search.text.toLowerCase();
            final docs = (snap.data?.docs ?? [])
                .map((d) => UserModel.fromFirestore(d))
                .where((u) {
                  // Search filter
                  final matchesSearch = q.isEmpty ||
                      u.email.toLowerCase().contains(q) ||
                      u.uid.toLowerCase().contains(q) ||
                      u.displayName.toLowerCase().contains(q);
                  // Tab filter
                  final matchesTab = _filter == 'all' ||
                      (_filter == 'admin' && u.isAdmin) ||
                      (_filter == 'anon'  && u.isAnonymous);
                  return matchesSearch && matchesTab;
                })
                .toList();

            if (docs.isEmpty) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline,
                      size: 48, color: EkklisiaColors.goldDim),
                  const SizedBox(height: 12),
                  Text(
                    _search.text.isNotEmpty
                        ? 'No users match "${_search.text}"'
                        : 'No users yet',
                    style: const TextStyle(
                        color: EkklisiaColors.textSecondary,
                        fontSize: 14),
                  ),
                ],
              ));
            }

            // Summary row
            return Column(children: [
              _SummaryBar(total: docs.length),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _UserCard(user: docs[i]),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: EkklisiaColors.bgPrimary,
    child: Row(children: [
      const Icon(Icons.people, size: 14,
          color: EkklisiaColors.goldDim),
      const SizedBox(width: 6),
      Text('$total user${total != 1 ? 's' : ''} found',
          style: const TextStyle(
              color: EkklisiaColors.textSecondary, fontSize: 12)),
    ]),
  );
}

// ── User card ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: EkklisiaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isAdmin
              ? EkklisiaColors.goldBorder
              : EkklisiaColors.goldBorder.withOpacity(0.5),
          width: user.isAdmin ? 0.8 : 0.4,
        ),
      ),
      child: Row(children: [
        // Avatar
        _Avatar(user: user),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name / email
            if (user.displayName.isNotEmpty)
              Text(user.displayName, style: const TextStyle(
                  color: EkklisiaColors.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w700)),
            Row(children: [
              Expanded(child: Text(
                user.isAnonymous
                    ? 'Anonymous user'
                    : user.email.isNotEmpty
                        ? user.email
                        : 'No email',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: user.isAnonymous
                      ? EkklisiaColors.textSecondary
                      : EkklisiaColors.textPrimary,
                  fontSize: user.displayName.isNotEmpty ? 11 : 13,
                  fontStyle: user.isAnonymous
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              )),
            ]),
            const SizedBox(height: 4),
            // UID chip (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: user.uid));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('UID copied'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '${user.uid.substring(0, 8)}…',
                  style: const TextStyle(
                      color: EkklisiaColors.textSecondary,
                      fontSize: 10, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 10,
                    color: EkklisiaColors.goldDim),
              ]),
            ),
          ],
        )),

        // Badges
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (user.isAdmin) _Badge('ADMIN', EkklisiaColors.gold),
            if (user.isAnonymous)
              _Badge('ANON', EkklisiaColors.textSecondary),
            if (user.fcmToken.isNotEmpty) ...[
              const SizedBox(height: 4),
              _Badge('FCM ✓', EkklisiaColors.tealMid),
            ],
            if (user.lastSeenAt != null) ...[
              const SizedBox(height: 6),
              Text(_relativeTime(user.lastSeenAt!),
                  style: const TextStyle(
                      color: EkklisiaColors.textSecondary,
                      fontSize: 9)),
            ],
          ],
        ),
      ]),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inHours  < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays   < 1) return '${diff.inHours}h ago';
    if (diff.inDays   < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final UserModel user;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user.isAdmin
            ? EkklisiaColors.goldSubtle
            : EkklisiaColors.bgElevated,
        border: Border.all(
          color: user.isAdmin
              ? EkklisiaColors.gold
              : EkklisiaColors.goldBorder,
          width: user.isAdmin ? 1.5 : 0.5,
        ),
      ),
      child: Center(child: Text(
        user.isAnonymous ? '?' : user.initials,
        style: TextStyle(
          color: user.isAdmin
              ? EkklisiaColors.gold
              : EkklisiaColors.textSecondary,
          fontSize: 14, fontWeight: FontWeight.w700,
        ),
      )),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.4), width: 0.5),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 9,
        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );
}

class _FilterChip {
  const _FilterChip(this.label, this.key);
  final String label;
  final String key;
}
