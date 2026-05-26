// lib/admin/notifications/admin_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/colors.dart';
import '../../core/di/service_locator.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/books_repository.dart';
import '../../features/books/cubit/books_cubit.dart';
import '../../features/books/cubit/books_state.dart';
import '../../services/notification_service.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});
  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  BookModel? _linkedBook;
  bool       _sending  = false;
  bool       _sent     = false;
  String?    _errorMsg;

  // Simulated sent history
  final List<_SentNotif> _history = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _sending = true; _errorMsg = null; });

    try {
      final tokens = await sl<BooksRepository>().fetchAllFcmTokens();

      // Build a synthetic BookModel if a book is linked
      final targetBook = _linkedBook ?? BookModel(
        id:          '',
        titleAr:     _titleCtrl.text.trim(),
        category:    'other',
        pdfUrl:      '',
        addedByUid:  '',
        createdAt:   DateTime.now(),
        updatedAt:   DateTime.now(),
        descriptionAr: _bodyCtrl.text.trim(),
      );

      await sl<NotificationService>().sendNewBookNotification(
        book:  targetBook,
        fcmTokens: tokens,
        topic: AppConstants.newBooksTopic,
        title: _titleCtrl.text.trim(),
        body:  _bodyCtrl.text.trim(),
      );

      setState(() {
        _sending = false;
        _sent    = true;
        _history.insert(0, _SentNotif(
          _titleCtrl.text.trim(),
          _bodyCtrl.text.trim(),
          'Just now',
          tokens.length,
        ));
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _sent = false;
          _titleCtrl.clear();
          _bodyCtrl.clear();
          _linkedBook = null;
        });
      }
    } catch (e) {
      setState(() {
        _sending  = false;
        _errorMsg = 'Failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Layout: composer + preview side by side on wide screens ───
        LayoutBuilder(builder: (_, constraints) {
          final wide = constraints.maxWidth > 600;
          final children = [
            _buildComposer(),
            const SizedBox(width: 20, height: 20),
            _buildPreviewAndHistory(),
          ];
          return wide
              ? IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: children[0]),
                    children[1],
                    Expanded(flex: 2, child: children[2]),
                  ]))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children);
        }),
      ]),
    );
  }

  // ── Composer ────────────────────────────────────────────────────────────

  Widget _buildComposer() {
    return Form(
      key: _formKey,
      child: _AdminCard(
        title: 'Compose Notification',
        titleAr: 'إنشاء إشعار',
        children: [
          // Title field
          _FieldLabel('Notification Title', 'عنوان الإشعار *'),
          const SizedBox(height: 6),
          TextFormField(
            controller:  _titleCtrl,
            maxLength:   65,
            style: const TextStyle(
                color: EkkleiciaColors.textPrimary, fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: _inputDec(hint: 'New book added…', counter: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // Body field
          _FieldLabel('Body', 'نص الإشعار *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _bodyCtrl,
            maxLines:   3,
            maxLength:  150,
            style: const TextStyle(
                color: EkkleiciaColors.textPrimary, fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: _inputDec(hint: 'A new book has been added…', counter: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Link to book
          _FieldLabel('Link to Book', 'ربط بكتاب (اختياري)'),
          const SizedBox(height: 6),
          BlocBuilder<BooksCubit, BooksState>(
            builder: (context, state) {
              final published =
                  state.books.where((b) => b.isPublished).toList();
              return DropdownButtonFormField<BookModel?>(
                initialValue: _linkedBook,
                dropdownColor: EkkleiciaColors.bgElevated,
                style: const TextStyle(
                    color: EkkleiciaColors.textPrimary, fontSize: 13),
                decoration: _inputDec(hint: 'No deep-link'),
                items: [
                  const DropdownMenuItem(value: null,
                      child: Text('No deep-link',
                          style: TextStyle(
                              color: EkkleiciaColors.textSecondary))),
                  ...published.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.titleAr,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              fontFamily: 'Scheherazade',
                              color: EkkleiciaColors.textPrimary,
                              fontSize: 14)))),
                ],
                onChanged: (v) => setState(() => _linkedBook = v),
              );
            },
          ),

          if (_linkedBook != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EkkleiciaColors.goldSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: EkkleiciaColors.goldBorder, width: 0.5),
              ),
              child: Row(children: [
                const Icon(Icons.link, size: 12,
                    color: EkkleiciaColors.gold),
                const SizedBox(width: 6),
                Text('ekklicia://book/${_linkedBook!.id}',
                    style: const TextStyle(
                        color: EkkleiciaColors.gold, fontSize: 11)),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // Error
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EkkleiciaColors.maroon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: EkkleiciaColors.maroon, width: 0.5),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: EkkleiciaColors.maroonMid, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMsg!,
                    style: const TextStyle(
                        color: EkkleiciaColors.textSecondary,
                        fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_sending || _sent) ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              EkkleiciaColors.bgDeep)))
                  : Icon(
                      _sent ? Icons.check_circle_outline
                            : Icons.send_outlined,
                      size: 18,
                      color: EkkleiciaColors.bgDeep),
              label: Text(
                _sending ? 'Sending…'
                    : _sent    ? 'Sent!'
                    : 'Send Push Notification',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: EkkleiciaColors.bgDeep),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _sent
                    ? EkkleiciaColors.tealMid
                    : EkkleiciaColors.gold,
                disabledBackgroundColor: _sent
                    ? EkkleiciaColors.tealMid
                    : EkkleiciaColors.goldDim.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview + History ────────────────────────────────────────────────────

  Widget _buildPreviewAndHistory() {
    final previewTitle = _titleCtrl.text.isNotEmpty
        ? _titleCtrl.text
        : 'Notification Title';
    final previewBody = _bodyCtrl.text.isNotEmpty
        ? _bodyCtrl.text
        : 'Notification body will appear here…';

    return Column(children: [

      // Live preview
      _AdminCard(
        title: 'Preview',
        titleAr: 'معاينة',
        children: [
          // Android preview
          _PreviewLabel('Android'),
          const SizedBox(height: 6),
          _AndroidPreview(title: previewTitle, body: previewBody),
          const SizedBox(height: 12),

          // iOS preview
          _PreviewLabel('iOS'),
          const SizedBox(height: 6),
          _IosPreview(title: previewTitle, body: previewBody),
        ],
      ),

      const SizedBox(height: 16),

      // History
      _AdminCard(
        title: 'Sent History',
        titleAr: 'السجل',
        children: [
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('No notifications sent yet',
                  style: TextStyle(
                      color: EkkleiciaColors.textSecondary,
                      fontSize: 12))),
            )
          else
            ..._history.asMap().entries.map((e) => Column(children: [
              _HistoryRow(notif: e.value),
              if (e.key < _history.length - 1)
                const Divider(height: 16,
                    color: EkkleiciaColors.goldBorder,
                    indent: 4, endIndent: 4),
            ])),
        ],
      ),
    ]);
  }

  InputDecoration _inputDec({String hint = '', bool counter = false}) =>
      InputDecoration(
        hintText:  hint,
        counterText: counter ? null : '',
        hintStyle: const TextStyle(
            color: EkkleiciaColors.textSecondary, fontSize: 13),
        filled:    true,
        fillColor: EkkleiciaColors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: EkkleiciaColors.goldBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: EkkleiciaColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: Colors.redAccent, width: 1.5),
        ),
      );
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SentNotif {
  _SentNotif(this.title, this.body, this.time, this.count);
  final String title;
  final String body;
  final String time;
  final int    count;
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.titleAr,
    required this.children,
  });
  final String       title;
  final String       titleAr;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EkkleiciaColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: EkkleiciaColors.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: EkkleiciaColors.gold,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
                color: EkkleiciaColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text(titleAr, style: const TextStyle(
                fontFamily: 'Scheherazade',
                color: EkkleiciaColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, this.labelAr);
  final String label;
  final String labelAr;
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
        color: EkkleiciaColors.textSecondary,
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
    const SizedBox(width: 6),
    Text(labelAr, style: const TextStyle(
        fontFamily: 'Scheherazade',
        color: EkkleiciaColors.textSecondary, fontSize: 11)),
  ]);
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(
      color: EkkleiciaColors.textSecondary,
      fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600));
}

class _AndroidPreview extends StatelessWidget {
  const _AndroidPreview({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EkkleiciaColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: EkkleiciaColors.goldBorder, width: 0.3),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(
            gradient: RadialGradient(colors: [
              EkkleiciaColors.bronze, EkkleiciaColors.maroon]),
          ),
          child: const Center(child: Text('✦', style: TextStyle(
              color: EkkleiciaColors.goldLight, fontSize: 14))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Ekklicia', style: TextStyle(
                  color: EkkleiciaColors.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.w600)),
              const Text('now', style: TextStyle(
                  color: EkkleiciaColors.textSecondary, fontSize: 10)),
            ]),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(
                color: EkkleiciaColors.textPrimary,
                fontSize: 12, fontWeight: FontWeight.w700)),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: EkkleiciaColors.textSecondary, fontSize: 11)),
          ],
        )),
      ]),
    );
  }
}

class _IosPreview extends StatelessWidget {
  const _IosPreview({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: EkkleiciaColors.goldBorder, width: 0.3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 18, height: 18,
              decoration: const BoxDecoration(
                gradient: RadialGradient(colors: [
                  EkkleiciaColors.bronze, EkkleiciaColors.maroon]),
              ),
              child: const Center(child: Text('✦', style: TextStyle(
                  color: EkkleiciaColors.goldLight, fontSize: 8))),
            ),
            const SizedBox(width: 5),
            const Text('EKKLICIA', style: TextStyle(
                color: Color(0xAAFFFFFF), fontSize: 10,
                fontWeight: FontWeight.w600)),
          ]),
          const Text('now', style: TextStyle(
              color: Color(0x66FFFFFF), fontSize: 10)),
        ]),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(
            color: Colors.white,
            fontSize: 12, fontWeight: FontWeight.w700)),
        Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Color(0xCCFFFFFF), fontSize: 11)),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.notif});
  final _SentNotif notif;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: EkkleiciaColors.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(
              color: EkkleiciaColors.goldBorder, width: 0.5),
        ),
        child: const Icon(Icons.notifications_none,
            size: 14, color: EkkleiciaColors.gold),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notif.title, style: const TextStyle(
              color: EkkleiciaColors.textPrimary,
              fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(notif.body, style: const TextStyle(
              color: EkkleiciaColors.textSecondary, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(notif.time, style: const TextStyle(
              color: EkkleiciaColors.textSecondary, fontSize: 10)),
        ],
      )),
      Text('${notif.count}',
          style: const TextStyle(
              color: EkkleiciaColors.gold, fontSize: 11,
              fontWeight: FontWeight.w700)),
    ],
  );
}
