// lib/admin/users/admin_users_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin screen for managing app users.
//
// Actions per user:
//   • Promote to admin / Demote from admin  (requires confirmation)
//   • Deactivate / Reactivate               (soft-disable, requires confirmation)
//   • Delete user record                    (hard-delete, requires double confirmation)
//
// Rules:
//   • Cannot modify your own account from this screen.
//   • Anonymous users cannot be promoted to admin.
//   • All destructive actions show a confirmation dialog before executing.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/text_normalizer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/colors.dart';
import '../../data/models/user_model.dart';
import '../../services/auth_service.dart';
import '../utils/admin_colors.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search  = TextEditingController();
  String _filter = 'all'; // all | admin | anon | inactive

  final _auth    = sl<AuthService>();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleAdmin(UserModel u) async {
    final promote = !u.isAdmin;
    final confirmed = await _confirm(
      context,
      title: promote ? 'Promote to admin?' : 'Demote from admin?',
      body: promote
          ? '${_name(u)} will gain full access to all content, users, and notifications.'
          : '${_name(u)} will lose admin access immediately.',
      confirmLabel: promote ? 'Promote' : 'Demote',
      destructive: !promote,
    );
    if (confirmed != true) return;
    try {
      await _auth.setAdminStatus(u.uid, isAdmin: promote);
      _snack(promote ? '${_name(u)} promoted to admin' : '${_name(u)} demoted');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _toggleActive(UserModel u) async {
    final deactivate = u.isActive;
    final confirmed = await _confirm(
      context,
      title: deactivate ? 'Deactivate account?' : 'Reactivate account?',
      body: deactivate
          ? '${_name(u)} will be marked inactive. They will still appear in this list.'
          : '${_name(u)} will be marked active again.',
      confirmLabel: deactivate ? 'Deactivate' : 'Reactivate',
      destructive: deactivate,
    );
    if (confirmed != true) return;
    try {
      await _auth.setActiveStatus(u.uid, isActive: !deactivate);
      _snack(deactivate ? '${_name(u)} deactivated' : '${_name(u)} reactivated');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _deleteUser(UserModel u) async {
    // First confirmation
    final first = await _confirm(
      context,
      title: 'Delete user record?',
      body: 'This removes ${_name(u)} from Firestore. It does not delete their Firebase Auth account.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (first != true) return;

    // Second confirmation — extra safety
    final second = await _confirm(
      context,
      title: 'Are you sure?',
      body: 'This action cannot be undone. The record for ${_name(u)} will be permanently deleted.',
      confirmLabel: 'Delete permanently',
      destructive: true,
    );
    if (second != true) return;

    try {
      await _auth.deleteUserRecord(u.uid);
      _snack('${_name(u)} deleted');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _name(UserModel u) =>
      u.displayName.isNotEmpty ? u.displayName : u.email.isNotEmpty ? u.email : 'User';

  void _snack(String msg, {bool error = false}) {
    final ac = AdminC(Theme.of(context).brightness);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.redAccent : ac.bgElevated,
    ));
  }

  Future<bool?> _confirm(
    BuildContext ctx, {
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    final ac = AdminC(Theme.of(context).brightness);
    return showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: ac.bgElevated,
          title: Text(title,
              style: TextStyle(
                  color: ac.goldLight, fontSize: 15)),
          content: Text(body,
              style: TextStyle(
                  color: ac.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('Cancel',
                  style: TextStyle(color: ac.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                confirmLabel,
                style: TextStyle(
                  color: destructive ? Colors.redAccent : ac.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: ac.bgMid,
          border: Border(
              bottom: BorderSide(color: ac.goldBorder, width: 0.5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.people_outline,
                color: ac.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Users',
                      style: TextStyle(
                          color: ac.goldLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text('Manage accounts, roles & access',
                      style: TextStyle(
                          color: ac.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Search
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
                color: ac.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by name, email or UID…',
              hintStyle: TextStyle(
                  color: ac.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.search,
                  size: 18, color: ac.goldDim),
              filled: true,
              fillColor: ac.bgElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: ac.goldBorder, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: ac.gold, width: 1.0),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All',      'all'),
                _chip('Admins',   'admin'),
                _chip('Anonymous','anon'),
                _chip('Inactive', 'inactive'),
              ].map((w) => Padding(
                padding: const EdgeInsets.only(right: 8), child: w)).toList(),
            ),
          ),
        ]),
      ),

      // ── Stream list ───────────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: sl<FirebaseFirestore>()
              .collection(AppConstants.usersCollection)
              .orderBy('last_seen_at', descending: true)
              .limit(200)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(ac.gold)));
            }
            if (snap.hasError) {
              return Center(
                  child: Text('Error: ${snap.error}',
                      style: TextStyle(
                          color: ac.textSecondary)));
            }

            final docs = (snap.data?.docs ?? [])
                .map((d) => UserModel.fromFirestore(d))
                .where((u) {
                  final matchesSearch = TextNormalizer.anyContains(
                      [u.email, u.uid, u.displayName], _search.text);
                  final matchesTab = _filter == 'all' ||
                      (_filter == 'admin'    && u.isAdmin) ||
                      (_filter == 'anon'     && u.isAnonymous) ||
                      (_filter == 'inactive' && !u.isActive);
                  return matchesSearch && matchesTab;
                })
                .toList();

            if (docs.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline,
                      size: 48, color: ac.goldDim),
                  const SizedBox(height: 12),
                  Text(
                    _search.text.isNotEmpty
                        ? 'No users match "${_search.text}"'
                        : 'No users in this filter',
                    style: TextStyle(
                        color: ac.textSecondary, fontSize: 14),
                  ),
                ]),
              );
            }

            return Column(children: [
              // Summary
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: EkklisiaColors.bgPrimary,
                child: Row(children: [
                  Icon(Icons.people,
                      size: 14, color: ac.goldDim),
                  SizedBox(width: 6),
                  Text('${docs.length} user${docs.length != 1 ? 's' : ''}',
                      style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 12)),
                  Spacer(),
                  Text(
                    '${docs.where((u) => u.isAdmin).length} admin · '
                    '${docs.where((u) => !u.isActive).length} inactive',
                    style: TextStyle(
                        color: ac.textSecondary, fontSize: 11),
                  ),
                ]),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _UserCard(
                    user:         docs[i],
                    myUid:        _myUid,
                    onToggleAdmin:  () => _toggleAdmin(docs[i]),
                    onToggleActive: () => _toggleActive(docs[i]),
                    onDelete:       () => _deleteUser(docs[i]),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _chip(String label, String key) {
    final ac = AdminC(Theme.of(context).brightness);

    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? ac.goldSubtle
              : ac.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? ac.gold : ac.goldBorder,
            width: active ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? ac.goldLight
                : ac.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.myUid,
    required this.onToggleAdmin,
    required this.onToggleActive,
    required this.onDelete,
  });

  final UserModel  user;
  final String     myUid;
  final VoidCallback onToggleAdmin;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  bool get _isSelf => user.uid == myUid;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    final dimmed = !user.isActive;

    return Opacity(
      opacity: dimmed ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ac.bgMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: user.isAdmin
                ? ac.goldBorder
                : ac.goldBorder.withOpacity(0.4),
            width: user.isAdmin ? 0.8 : 0.4,
          ),
        ),
        child: Row(children: [
          _Avatar(user: user),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.displayName.isNotEmpty)
                  Text(user.displayName,
                      style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                Text(
                  user.isAnonymous
                      ? 'Anonymous user'
                      : user.email.isNotEmpty
                          ? user.email
                          : 'No email',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: user.isAnonymous
                        ? ac.textSecondary
                        : ac.textPrimary,
                    fontSize:
                        user.displayName.isNotEmpty ? 11 : 13,
                    fontStyle: user.isAnonymous
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: user.uid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('UID copied'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${user.uid.substring(0, 8)}…',
                      style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.copy,
                        size: 10, color: ac.goldDim),
                  ]),
                ),
                if (user.lastSeenAt != null) ...[
                  SizedBox(height: 2),
                  Text(
                    _relativeTime(user.lastSeenAt!),
                    style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 10),
                  ),
                ],
              ],
            ),
          ),

          // Badges + menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (user.isAdmin)
                  _Badge('ADMIN', ac.gold),
                if (!user.isActive) ...[
                  SizedBox(width: 4),
                  _Badge('INACTIVE', Colors.redAccent),
                ],
                if (user.isAnonymous) ...[
                  SizedBox(width: 4),
                  _Badge('ANON', ac.textSecondary),
                ],
                if (user.fcmToken.isNotEmpty) ...[
                  SizedBox(width: 4),
                  _Badge('FCM', ac.tealMid),
                ],
              ]),
              const SizedBox(height: 6),

              // Action menu (disabled for self)
              if (_isSelf)
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('(you)',
                      style: TextStyle(
                          color: ac.textSecondary,
                          fontSize: 10)),
                )
              else
                _ActionMenu(
                  user:           user,
                  onToggleAdmin:  user.isAnonymous ? null : onToggleAdmin,
                  onToggleActive: onToggleActive,
                  onDelete:       onDelete,
                ),
            ],
          ),
        ]),
      ),
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

// ── Action Menu ───────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.user,
    required this.onToggleAdmin,
    required this.onToggleActive,
    required this.onDelete,
  });

  final UserModel    user;
  final VoidCallback? onToggleAdmin;
  final VoidCallback  onToggleActive;
  final VoidCallback  onDelete;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          size: 18, color: ac.goldDim),
      color: ac.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: ac.goldBorder, width: 0.5),
      ),
      onSelected: (v) {
        if (v == 'admin')  onToggleAdmin?.call();
        if (v == 'active') onToggleActive();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        // Toggle admin
        PopupMenuItem(
          enabled: onToggleAdmin != null,
          value: 'admin',
          child: Row(children: [
            Icon(
              user.isAdmin ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined,
              size: 16,
              color: onToggleAdmin != null
                  ? ac.gold
                  : ac.textSecondary,
            ),
            SizedBox(width: 10),
            Text(
              user.isAdmin ? 'Demote from admin' : 'Promote to admin',
              style: TextStyle(
                color: onToggleAdmin != null
                    ? ac.textPrimary
                    : ac.textSecondary,
                fontSize: 13,
              ),
            ),
          ]),
        ),

        // Toggle active
        PopupMenuItem(
          value: 'active',
          child: Row(children: [
            Icon(
              user.isActive
                  ? Icons.block_outlined
                  : Icons.check_circle_outline,
              size: 16,
              color: user.isActive
                  ? Colors.orangeAccent
                  : ac.tealMid,
            ),
            const SizedBox(width: 10),
            Text(
              user.isActive ? 'Deactivate account' : 'Reactivate account',
              style: TextStyle(
                color: user.isActive
                    ? Colors.orangeAccent
                    : ac.tealMid,
                fontSize: 13,
              ),
            ),
          ]),
        ),

        const PopupMenuDivider(),

        // Delete
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline,
                size: 16, color: Colors.redAccent),
            const SizedBox(width: 10),
            const Text('Delete record',
                style: TextStyle(
                    color: Colors.redAccent, fontSize: 13)),
          ]),
        ),
      ],
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user.isAdmin
            ? ac.goldSubtle
            : ac.bgElevated,
        border: Border.all(
          color: user.isAdmin
              ? ac.gold
              : ac.goldBorder,
          width: user.isAdmin ? 1.5 : 0.5,
        ),
      ),
      child: Center(
        child: Text(
          user.isAnonymous ? '?' : user.initials,
          style: TextStyle(
            color: user.isAdmin
                ? ac.gold
                : ac.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.4), width: 0.5),
    ),
    child: Text(
      label,
      style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5),
    ),
  );
  }
}
