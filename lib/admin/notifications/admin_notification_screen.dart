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
import '../utils/admin_colors.dart';

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
      final ac = AdminC(Theme.of(context).brightness);
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
    final ac = AdminC(Theme.of(context).brightness);

    return Form(
      key: _formKey,
      child: _AdminCard(
        title: 'Compose Notification',
        titleAr: 'إنشاء إشعار',
        children: [
          // Title field
          _FieldLabel('Notification Title', 'عنوان الإشعار *'),
          SizedBox(height: 6),
          TextFormField(
            controller:  _titleCtrl,
            maxLength:   65,
            style: TextStyle(
                color: ac.textPrimary, fontSize: 14),
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
            style: TextStyle(
                color: ac.textPrimary, fontSize: 14),
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
                dropdownColor: ac.bgElevated,
                style: TextStyle(
                    color: ac.textPrimary, fontSize: 13),
                decoration: _inputDec(hint: 'No deep-link'),
                items: [
                  DropdownMenuItem(value: null,
                      child: Text('No deep-link',
                          style: TextStyle(
                              color: ac.textSecondary))),
                  ...published.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.titleAr,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontFamily: 'Scheherazade',
                              color: ac.textPrimary,
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
                color: ac.goldSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: ac.goldBorder, width: 0.5),
              ),
              child: Row(children: [
                Icon(Icons.link, size: 12,
                    color: ac.gold),
                SizedBox(width: 6),
                Text('Ekklisia://book/${_linkedBook!.id}',
                    style: TextStyle(
                        color: ac.gold, fontSize: 11)),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // Error
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ac.maroon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ac.maroon, width: 0.5),
              ),
              child: Row(children: [
                Icon(Icons.error_outline,
                    color: ac.maroonMid, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(_errorMsg!,
                    style: TextStyle(
                        color: ac.textSecondary,
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
                  ? SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              ac.bgDeep)))
                  : Icon(
                      _sent ? Icons.check_circle_outline
                            : Icons.send_outlined,
                      size: 18,
                      color: ac.bgDeep),
              label: Text(
                _sending ? 'Sending…'
                    : _sent    ? 'Sent!'
                    : 'Send Push Notification',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: ac.bgDeep),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _sent
                    ? ac.tealMid
                    : ac.gold,
                disabledBackgroundColor: _sent
                    ? ac.tealMid
                    : ac.goldDim.withValues(alpha: 0.5),
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
    final ac = AdminC(Theme.of(context).brightness);

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
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('No notifications sent yet',
                  style: TextStyle(
                      color: ac.textSecondary,
                      fontSize: 12))),
            )
          else
            ..._history.asMap().entries.map((e) => Column(children: [
              _HistoryRow(notif: e.value),
              if (e.key < _history.length - 1)
                Divider(height: 16,
                    color: ac.goldBorder,
                    indent: 4, endIndent: 4),
            ])),
        ],
      ),
    ]);
  }

  InputDecoration _inputDec({required String hint, bool counter = false}) {
    final ac = AdminC(Theme.of(context).brightness);
    return InputDecoration(
        hintText:  hint,
        counterText: counter ? null : '',
        hintStyle: TextStyle(
            color: ac.textSecondary, fontSize: 13),
        filled:    true,
        fillColor: ac.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: ac.goldBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: ac.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Colors.redAccent, width: 1.5),
        ),
      );
  }
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ac.bgMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ac.goldBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: ac.gold,
                    borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 8),
            Text(title, style: TextStyle(
                color: ac.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w700)),
            SizedBox(width: 6),
            Text(titleAr, style: TextStyle(
                fontFamily: 'Scheherazade',
                color: ac.textSecondary, fontSize: 12)),
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
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Row(children: [
      Text(label, style: TextStyle(
          color: ac.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      SizedBox(width: 6),
      Text(labelAr, style: TextStyle(
          fontFamily: 'Scheherazade',
          color: ac.textSecondary, fontSize: 11)),
    ]);
  }
}

class _PreviewLabel extends StatelessWidget {
  _PreviewLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Text(label, style: TextStyle(
      color: ac.textSecondary,
      fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600));
  }
}

class _AndroidPreview extends StatelessWidget {
  const _AndroidPreview({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: ac.goldBorder, width: 0.3),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [
              ac.bronze, ac.maroon]),
          ),
          child: Center(child: Text('✦', style: TextStyle(
              color: ac.goldLight, fontSize: 14))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Text('Ekklisia', style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.w600)),
              Text('now', style: TextStyle(
                  color: ac.textSecondary, fontSize: 10)),
            ]),
            SizedBox(height: 2),
            Text(title, style: TextStyle(
                color: ac.textPrimary,
                fontSize: 12, fontWeight: FontWeight.w700)),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: ac.textSecondary, fontSize: 11)),
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
      final ac = AdminC(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ac.goldBorder, width: 0.3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  ac.bronze, ac.maroon]),
              ),
              child: Center(child: Text('✦', style: TextStyle(
                  color: ac.goldLight, fontSize: 8))),
            ),
            const SizedBox(width: 5),
            const Text('Ekklisia', style: TextStyle(
                color: Color(0xAAFFFFFF), fontSize: 10,
                fontWeight: FontWeight.w600)),
          ]),
          const Text('now', style: TextStyle(
              color: Color(0x66FFFFFF), fontSize: 10)),
        ]),
        const SizedBox(height: 5),
        Text(title, style: TextStyle(
            color: Colors.white,
            fontSize: 12, fontWeight: FontWeight.w700)),
        Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Color(0xCCFFFFFF), fontSize: 11)),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.notif});
  final _SentNotif notif;
  @override
  Widget build(BuildContext context) {
    final ac = AdminC(Theme.of(context).brightness);
    return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: ac.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(
              color: ac.goldBorder, width: 0.5),
        ),
        child: Icon(Icons.notifications_none,
            size: 14, color: ac.gold),
      ),
      SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notif.title, style: TextStyle(
              color: ac.textPrimary,
              fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 2),
          Text(notif.body, style: TextStyle(
              color: ac.textSecondary, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 3),
          Text(notif.time, style: TextStyle(
              color: ac.textSecondary, fontSize: 10)),
        ],
      )),
      Text('${notif.count}',
          style: TextStyle(
              color: ac.gold, fontSize: 11,
              fontWeight: FontWeight.w700)),
    ],
  );
  }
}
