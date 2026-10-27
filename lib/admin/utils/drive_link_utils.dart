// lib/admin/utils/drive_link_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared helper for admin CMS screens that let an admin paste a Google Drive
// "Anyone with the link" sharing URL instead of uploading a PDF (or other
// file) directly. Extracted from the Books upload flow
// (lib/admin/books/upload_book_screen.dart) so every other CMS section can
// reuse the exact same parsing/validation logic.
//
// resolveDriveUrl() is the read-side counterpart: drive.google.com sends no
// CORS headers, which breaks Flutter Web (CachedNetworkImage / CachedPdfViewer
// both do a real fetch()). It rewrites any Drive URL — old or new, already
// stored in Firestore or freshly pasted — to go through the drive-proxy
// Supabase edge function instead, which fetches server-side and re-serves
// with Access-Control-Allow-Origin set. Apply it at render time, not at save
// time, so every already-published record is fixed automatically with no
// data migration. See supabase/functions/drive-proxy/index.ts.
// ─────────────────────────────────────────────────────────────────────────────

import '../../core/constants/app_constants.dart';

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

/// Rewrites a Google Drive URL so it's actually fetchable from Flutter Web.
///
/// Safe to call on *any* URL — non-Drive URLs (Cloudinary, etc.) are
/// returned unchanged, so this can wrap every url passed to CachedImage /
/// CachedPdfViewer unconditionally. Extracts the file ID regardless of which
/// Drive URL shape it was given (share link, "open?id=", or an
/// already-converted "uc?export=download") and points it at the drive-proxy
/// edge function instead of drive.google.com directly.
String resolveDriveUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty || !looksLikeDriveLink(trimmed)) return url;

  final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(trimmed) ??
      RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  final id = idMatch?.group(1);

  // Unrecognised Drive URL shape — nothing we can extract an ID from, so
  // hand back the original rather than send the proxy a request we already
  // know it will reject. It will fail the same way it does today.
  if (id == null) return url;

  return '${AppConstants.driveProxyUrl}?id=$id';
}
