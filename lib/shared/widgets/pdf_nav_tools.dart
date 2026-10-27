// lib/shared/widgets/pdf_nav_tools.dart
// ─────────────────────────────────────────────────────────────────────────────
// Two small, reusable UI helpers shared by every PDF reader screen
// (Agbeya, generic PDF content, books):
//   • showPdfGoToPageDialog — type a page number, jump straight to it.
//   • showPdfSearchSheet    — full-text search; results list pages, tap to
//     jump. No in-page highlighting (pages are flat bitmaps — see
//     CachedPdfViewer / pdf_text_search.dart).
// Both operate on the same PdfScrollController each screen already gets via
// CachedPdfViewer.onControllerReady.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import 'cached_pdf_viewer.dart';

const _kGold = Color(0xFFC9A84C);
const _kNavy = Color(0xFF1B2A4A);

// ── Go to page ──────────────────────────────────────────────────────────────

Future<void> showPdfGoToPageDialog(
  BuildContext context, {
  required PdfScrollController controller,
  required int totalPages,
  required int currentPage,
  bool isGreek = false,
}) {
  // Dialog content is its own StatefulWidget so the TextEditingController's
  // lifecycle is owned by the element that uses it (created in initState,
  // disposed in dispose()). Previously the controller was created/disposed
  // here in this function, right after `await showDialog(...)` returned —
  // but that Future completes as soon as Navigator.pop() is *called*, not
  // once the dialog's exit transition finishes removing it from the tree.
  // If anything triggered a rebuild of the still-animating-out dialog in
  // that window, TextFormField would try to use the already-disposed
  // controller and crash ("used after being disposed").
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _GoToPageDialog(
      controller: controller,
      totalPages: totalPages,
      currentPage: currentPage,
      isGreek: isGreek,
    ),
  );
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({
    required this.controller,
    required this.totalPages,
    required this.currentPage,
    required this.isGreek,
  });

  final PdfScrollController controller;
  final int totalPages;
  final int currentPage;
  final bool isGreek;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _textCtrl =
      TextEditingController(text: '${widget.currentPage}');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final page = int.parse(_textCtrl.text.trim());
    widget.controller.animateToPage(page);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = widget.isGreek;
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF14213A)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _kGold.withValues(alpha: 0.3), width: 0.8),
      ),
      title: Text(
        isGreek ? 'Μετάβαση σε σελίδα' : 'الانتقال إلى صفحة',
        textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
        style: TextStyle(
          fontFamily: isGreek ? null : 'Scheherazade',
          fontSize: 17,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _textCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '1 – ${widget.totalPages}',
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kGold, width: 1.5),
            ),
          ),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) {
              return isGreek ? 'Μη έγκυρος αριθμός' : 'رقم غير صالح';
            }
            if (n < 1 || n > widget.totalPages) {
              return isGreek
                  ? 'Μεταξύ 1 και ${widget.totalPages}'
                  : 'بين 1 و ${widget.totalPages}';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isGreek ? 'Άκυρο' : 'إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kGold),
          onPressed: _submit,
          child: Text(
            isGreek ? 'Μετάβαση' : 'انتقال',
            style: const TextStyle(color: _kNavy, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ── Search ──────────────────────────────────────────────────────────────────

Future<void> showPdfSearchSheet(
  BuildContext context, {
  required PdfScrollController controller,
  bool isGreek = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PdfSearchSheet(controller: controller, isGreek: isGreek),
  );
}

class _PdfSearchSheet extends StatefulWidget {
  const _PdfSearchSheet({required this.controller, required this.isGreek});
  final PdfScrollController controller;
  final bool isGreek;

  @override
  State<_PdfSearchSheet> createState() => _PdfSearchSheetState();
}

class _PdfSearchSheetState extends State<_PdfSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<PdfSearchMatch> _results = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searched = true;
    });
    final results = await widget.controller.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isGreek = widget.isGreek;
    final sheetBg = brightness == Brightness.dark
        ? const Color(0xFF0E1A2E)
        : const Color(0xFF1B2A4A);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _kGold.withValues(alpha: 0.25), width: 0.8),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.search, color: _kGold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: isGreek ? 'Αναζήτηση στο κείμενο...' : 'ابحث في النص...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontFamily: isGreek ? null : 'Scheherazade',
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: _runSearch,
                      ),
                    ),
                    if (_searching)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_kGold),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Divider(color: _kGold.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 6),
                Flexible(
                  child: _buildResults(isGreek),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(bool isGreek) {
    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          isGreek
              ? 'Πληκτρολογήστε μια λέξη και πατήστε Enter'
              : 'اكتب كلمة واضغط Enter للبحث',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
        ),
      );
    }
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: SizedBox.shrink(),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          isGreek ? 'Δεν βρέθηκαν αποτελέσματα' : 'لا توجد نتائج',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          Divider(color: _kGold.withValues(alpha: 0.08), height: 1),
      itemBuilder: (context, i) {
        final m = _results[i];
        return ListTile(
          dense: true,
          leading: Icon(Icons.description_outlined, color: _kGold.withValues(alpha: 0.7), size: 18),
          title: Text(
            isGreek ? 'Σελίδα ${m.pageNumber}' : 'صفحة ${m.pageNumber}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          trailing: Text(
            isGreek
                ? '${m.count} αποτ.'
                : '${m.count} نتيجة',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
          onTap: () {
            widget.controller.goToSearchResult(i);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
