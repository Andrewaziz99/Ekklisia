// lib/admin/content/social_links_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin — Social Links.
// Lets an admin set the Facebook / YouTube / Viber URLs shown as icon
// buttons at the bottom of the home screen drawer. Single doc:
// config/social_links (see SocialLinksRepository).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/models/social_links_model.dart';
import '../../data/repositories/social_links_repository.dart';
import '../utils/admin_colors.dart';

class SocialLinksManagerScreen extends StatefulWidget {
  const SocialLinksManagerScreen({super.key});

  @override
  State<SocialLinksManagerScreen> createState() =>
      _SocialLinksManagerScreenState();
}

class _SocialLinksManagerScreenState extends State<SocialLinksManagerScreen> {
  final _repo = sl<SocialLinksRepository>();

  late final TextEditingController _facebookCtrl;
  late final TextEditingController _youtubeCtrl;
  late final TextEditingController _viberCtrl;

  bool _loading = true;
  bool _saving = false;
  String _saveMessage = '';

  @override
  void initState() {
    super.initState();
    _facebookCtrl = TextEditingController();
    _youtubeCtrl  = TextEditingController();
    _viberCtrl    = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final links = await _repo.fetch();
    if (!mounted) return;
    setState(() {
      _facebookCtrl.text = links.facebookUrl;
      _youtubeCtrl.text  = links.youtubeUrl;
      _viberCtrl.text    = links.viberUrl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _facebookCtrl.dispose();
    _youtubeCtrl.dispose();
    _viberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saveMessage = ''; });
    try {
      await _repo.save(SocialLinksModel(
        facebookUrl: _facebookCtrl.text.trim(),
        youtubeUrl:  _youtubeCtrl.text.trim(),
        viberUrl:    _viberCtrl.text.trim(),
      ));
      if (!mounted) return;
      setState(() { _saving = false; _saveMessage = 'Saved.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveMessage = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);

    return Scaffold(
      backgroundColor: ac.bgPrimary,
      appBar: AppBar(
        backgroundColor: ac.bgDeep,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Social Links',
                style: TextStyle(
                    color: ac.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            Text('روابط التواصل الاجتماعي • Σύνδεσμοι Social Media',
                style: TextStyle(
                    fontFamily: 'Scheherazade',
                    color: ac.textSecondary,
                    fontSize: 11)),
          ],
        ),
        actions: [
          if (_saving)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                      color: ac.gold, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ac.gold),
                strokeWidth: 2,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_saveMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _saveMessage.startsWith('Failed')
                          ? const Color(0xFF8C2B2B).withValues(alpha: 0.12)
                          : const Color(0xFF2E7D52).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_saveMessage,
                        style: TextStyle(
                          color: _saveMessage.startsWith('Failed')
                              ? const Color(0xFFE57373)
                              : const Color(0xFF3A8C5A),
                          fontSize: 12,
                        )),
                  ),
                _FormCard(
                  label: 'Bottom-of-drawer icons',
                  child: Column(
                    children: [
                      _Field(
                        controller: _facebookCtrl,
                        label: 'Facebook URL',
                        hint: 'https://facebook.com/yourpage',
                        icon: Icons.facebook,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _youtubeCtrl,
                        label: 'YouTube URL',
                        hint: 'https://youtube.com/@yourchannel',
                        icon: Icons.smart_display_outlined,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _viberCtrl,
                        label: 'Viber URL',
                        hint: 'https://invite.viber.com/?g=...',
                        icon: Icons.chat_bubble_outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Leave a field empty to hide that icon in the app drawer.',
                  style: TextStyle(color: ac.textSecondary, fontSize: 11),
                ),
              ],
            ),
    );
  }
}

// ── Form card container ───────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: ac.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: ac.gold,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: ac.textSecondary, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.url,
          style: TextStyle(color: ac.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: ac.textSecondary)
                : null,
            hintText: hint,
            hintStyle: TextStyle(
              color: ac.textSecondary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            filled: true,
            fillColor: ac.bgPrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ac.gold, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
