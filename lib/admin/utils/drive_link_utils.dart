// lib/admin/utils/drive_link_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared helper for admin CMS screens that let an admin paste a Google Drive
// "Anyone with the link" sharing URL instead of uploading a PDF (or other
// file) directly. Extracted from the Books upload flow
// (lib/admin/books/upload_book_screen.dart) so every other CMS section can
// reuse the exact same parsing/validation logic.
// ─────────────────────────────────────────────────────────────────────────────

/// Converts a Google Drive sharing link to a direct-download URL.
/// Returns null if [raw] is not a recognisable Drive link.
///
/// Handles:
///   • https://drive.google.com/file/d/<ID>/view?usp=sharing
///   • https://drive.google.com/open?id=<ID>
///   • https://drive.google.com/uc?export=download&id=<ID>  (already direct)
String? driveShareLinkToDirectUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final fileMatch =
      RegExp(r'drive\.google\.com/file/d/([^/?]+)').firstMatch(trimmed);
  if (fileMatch != null) {
    return 'https://drive.google.com/uc?export=download&id=${fileMatch.group(1)}';
  }

  final openMatch =
      RegExp(r'drive\.google\.com/open\?id=([^&]+)').firstMatch(trimmed);
  if (openMatch != null) {
    return 'https://drive.google.com/uc?export=download&id=${openMatch.group(1)}';
  }

  if (trimmed.contains('drive.google.com/uc') &&
      trimmed.contains('export=download')) {
    return trimmed;
  }

  return null;
}

/// True if [raw] looks like any kind of drive.google.com URL at all — used to
/// decide whether to show a "not a valid Drive link" error vs. silently
/// treating the text as a non-Drive URL (e.g. a Cloudinary link).
bool looksLikeDriveLink(String raw) => raw.trim().contains('drive.google.com');
