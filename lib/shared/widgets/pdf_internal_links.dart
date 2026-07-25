// lib/shared/widgets/pdf_internal_links.dart
// ─────────────────────────────────────────────────────────────────────────────
// Parses a PDF's internal ("jump to page X") link annotations so
// CachedPdfViewer can overlay tappable regions on top of its rendered page
// images. pdfx (the engine actually used for rendering) has no annotation
// API, so this uses syncfusion_flutter_pdf purely to read link geometry —
// nothing here is rendered by Syncfusion, it only supplies coordinates.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// One internal link found on a source page.
class PdfInternalLink {
  const PdfInternalLink({required this.bounds, required this.targetPage});

  /// Clickable rectangle in PDF point space (top-left origin), matching the
  /// page's own [PdfPageLinks.sizePt] — not yet scaled to screen pixels.
  final Rect bounds;

  /// 1-indexed destination page.
  final int targetPage;
}

/// Links found on one page, plus that page's own size in points — needed to
/// scale [PdfInternalLink.bounds] to whatever size the page ends up
/// rendered at on screen.
class PdfPageLinks {
  const PdfPageLinks({required this.sizePt, required this.links});

  final Size sizePt;
  final List<PdfInternalLink> links;
}

/// Reads [bytes] and returns internal document links keyed by 1-indexed
/// source page number. Runs synchronously — call via [compute] to keep it
/// off the UI thread for large files.
///
/// External (URI) links are intentionally skipped: this only powers
/// in-document navigation (tables of contents, cross-references, etc.),
/// which is the kind of link that silently did nothing before.
Map<int, PdfPageLinks> extractInternalPdfLinks(Uint8List bytes) {
  final result = <int, PdfPageLinks>{};
  sf.PdfDocument? doc;
  try {
    doc = sf.PdfDocument(inputBytes: bytes);
    for (int i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final pageLinks = <PdfInternalLink>[];
      for (int a = 0; a < page.annotations.count; a++) {
        final annot = page.annotations[a];
        if (annot is! sf.PdfDocumentLinkAnnotation) continue;
        final destPage = annot.destination?.page;
        if (destPage == null) continue;
        final targetIndex = doc.pages.indexOf(destPage);
        if (targetIndex < 0) continue;
        pageLinks.add(
          PdfInternalLink(bounds: annot.bounds, targetPage: targetIndex + 1),
        );
      }
      if (pageLinks.isNotEmpty) {
        result[i + 1] = PdfPageLinks(sizePt: page.size, links: pageLinks);
      }
    }
  } catch (_) {
    // Malformed/encrypted/odd PDFs: fall back to no links rather than
    // taking down the viewer — pdfx still renders the page images fine.
    return {};
  } finally {
    doc?.dispose();
  }
  return result;
}
