// lib/admin/utils/drive_link_field.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared "Upload File / Google Drive" widgets, extracted from the Books
// upload flow (lib/admin/books/upload_book_screen.dart) so every CMS section
// that accepts a PDF can offer the same Google Drive link option with
// identical look, validation and behaviour.
//
//   SourceToggleTabs   — the two-tab "Upload File" / "Google Drive" switch.
//   DriveLinkInputCard — the URL text field + live validation + preview.
//
// Pair with driveShareLinkToDirectUrl() from drive_link_utils.dart to convert
// the pasted share link into the direct-download URL that gets stored.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import 'admin_colors.dart';
import 'drive_link_utils.dart';

// ── Source toggle tabs ────────────────────────────────────────────────────────

class SourceToggleTabs extends StatelessWidget {
  const SourceToggleTabs({
    super.key,
    required this.useDriveUrl,
    required this.onChanged,
    this.fileLabel = 'Upload File',
    this.fileLabelAr = 'رفع ملف',
  });

  final bool useDriveUrl;
  final ValueChanged<bool> onChanged;
  final String fileLabel;
  final String fileLabelAr;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Container(
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.goldBorder, width: 0.5),
      ),
      child: Row(children: [
        Expanded(child: _ToggleTab(
          label: fileLabel,
          labelAr: fileLabelAr,
          icon: Icons.upload_file_outlined,
          selected: !useDriveUrl,
          onTap: () => onChanged(false),
        )),
        Container(width: 0.5, height: 44, color: ac.goldBorder),
        Expanded(child: _ToggleTab(
          label: 'Google Drive',
          labelAr: 'Google Drive',
          icon: Icons.link_outlined,
          selected: useDriveUrl,
          onTap: () => onChanged(true),
        )),
      ]),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.labelAr,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String labelAr;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? ac.goldSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: selected ? ac.gold : ac.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? ac.goldLight : ac.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Drive URL input card ──────────────────────────────────────────────────────

class DriveLinkInputCard extends StatelessWidget {
  const DriveLinkInputCard({
    super.key,
    required this.controller,
    required this.onChanged,
    this.error,
    this.onClear,
    this.hint = 'https://drive.google.com/file/d/…/view',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? error;
  final VoidCallback? onClear;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    final directUrl = driveShareLinkToDirectUrl(controller.text);
    final hasDriveUrl = directUrl != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDriveUrl ? ac.tealMid : ac.goldBorder,
          width: hasDriveUrl ? 1.5 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.drive_folder_upload_outlined, color: ac.gold, size: 18),
          const SizedBox(width: 8),
          Text('Google Drive Link',
              style: TextStyle(
                  color: ac.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          if (hasDriveUrl)
            Icon(Icons.check_circle_outline, color: ac.tealMid, size: 16),
        ]),
        const SizedBox(height: 4),
        Text(
          'Paste a "Anyone with link" sharing URL — no size limit',
          style: TextStyle(color: ac.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          style: TextStyle(color: ac.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: ac.textSecondary, fontSize: 12),
            errorText: error,
            prefixIcon: Icon(Icons.link, color: ac.goldDim, size: 18),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 16, color: ac.textSecondary),
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: ac.bgMid,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ac.goldBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ac.gold, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.2),
            ),
          ),
          onChanged: onChanged,
        ),
        if (hasDriveUrl) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: EkklisiaColors.tealDark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              Icon(Icons.check, color: ac.tealMid, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  directUrl,
                  style: TextStyle(color: ac.tealMid, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
