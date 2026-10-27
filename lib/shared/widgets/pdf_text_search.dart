// lib/shared/widgets/pdf_text_search.dart
// ─────────────────────────────────────────────────────────────────────────────
// Full-text search across a PDF's pages. Runs on a background isolate (see
// [searchPdfText]) using syncfusion_flutter_pdf purely for text extraction —
// nothing here is rendered by Syncfusion; CachedPdfViewer renders the actual
// pages via pdfrx (PDFium-backed). Results only report *which page* matched
// (no in-page highlighting) — pdfrx has its own native text search/highlight
// API (PdfTextSearcher) that a future pass could switch to instead of this
// page-level syncfusion approach.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// One page that contains at least one match for the last search query.
class PdfSearchMatch {
  const PdfSearchMatch({required this.pageNumber, required this.count});

  /// 1-indexed page number.
  final int pageNumber;

  /// Number of matches found on this page.
  final int count;
}

/// Arguments bundle for [searchPdfText] — [compute] only accepts a single
/// message argument.
class PdfSearchArgs {
  const PdfSearchArgs({required this.bytes, required this.query});
  final Uint8List bytes;
  final String query;
}

/// Page batch size for [searchPdfText] — see the comment inside for why the
/// search runs in chunks instead of one call across the whole document.
const int _searchBatchSize = 15;

/// Searches every page of the PDF in [args.bytes] for [args.query]
/// (case-insensitive) and returns one entry per matching page, in page
/// order. Call via `compute(searchPdfText, args)` to keep large documents
/// off the UI thread.
Future<List<PdfSearchMatch>> searchPdfText(PdfSearchArgs args) async {
  final query = args.query.trim();
  if (query.isEmpty) return const [];

  sf.PdfDocument? doc;
  try {
    doc = sf.PdfDocument(inputBytes: args.bytes);
    final extractor = sf.PdfTextExtractor(doc);
    final totalPages = doc.pages.count;
    final counts = <int, int>{};

    // findText() across an entire large document is one long blocking
    // call with no internal yield points. compute() runs this on a real
    // background isolate on native platforms, where that barely matters —
    // but Flutter Web has no true background isolate for compute(), so
    // there this call runs on the main thread and visibly freezes the UI
    // for the whole search. Break it into page batches and yield between
    // them so the engine can still paint frames (spinner, etc.) while a
    // search is in progress.
    for (int start = 0; start < totalPages; start += _searchBatchSize) {
      final end = (start + _searchBatchSize - 1).clamp(0, totalPages - 1);
      // No searchOption → case-insensitive by default (only wholeWords /
      // caseSensitive / both opt INTO case sensitivity in this API).
      final matches = extractor.findText(
        [query],
        startPageIndex: start,
        endPageIndex: end,
      );
      for (final m in matches) {
        final page = m.pageIndex + 1; // 1-indexed
        counts[page] = (counts[page] ?? 0) + 1;
      }
      if (end < totalPages - 1) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final pages = counts.keys.toList()..sort();
    return [
      for (final p in pages) PdfSearchMatch(pageNumber: p, count: counts[p]!),
    ];
  } catch (_) {
    // Malformed/encrypted/odd PDFs — fail closed with no results rather than
    // taking down the viewer.
    return const [];
  } finally {
    doc?.dispose();
  }
}
