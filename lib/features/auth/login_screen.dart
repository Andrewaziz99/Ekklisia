// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/router/app_router.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _obscure      = true;
  bool  _resetSent    = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fade;
  late final Animation<Offset>    _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signInWithEmail(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('أدخل بريدك الإلكتروني أولاً');
      return;
    }
    final ok = await context.read<AuthCubit>().sendPasswordReset(email);
    setState(() => _resetSent = ok);
    _showSnack(ok ? 'تم إرسال رابط إعادة تعيين كلمة المرور' : 'تعذّر الإرسال');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Scheherazade', fontSize: 14),
          textAlign: TextAlign.center),
      backgroundColor: EkkleiciaColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isAdmin) {
          context.go(Routes.adminDashboard);
        } else if (state.isAuthenticated) {
          context.go(Routes.home);
        } else if (state.status == AuthStatus.error) {
          _showSnack(state.errorMessage ?? 'حدث خطأ');
        }
      },
      child: Scaffold(
        backgroundColor: EkkleiciaColors.bgDeep,
        body: Stack(
          children: [
            // Background texture
            Positioned.fill(
              child: Image.asset(
                'assets/images/ekklicia_background.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.18),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EkkleiciaColors.bgDeep,
                      Color(0xFF0A1520),
                      EkkleiciaColors.bgPrimary,
                    ],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Corner ornaments
            ..._corners(),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLogo(),
                            const SizedBox(height: 40),
                            _buildForm(),
                            const SizedBox(height: 20),
                            _buildDivider(),
                            const SizedBox(height: 16),
                            _buildAnonymousButton(),
                            const SizedBox(height: 32),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [
              Color(0xFF2A1A10),
              EkkleiciaColors.bgDeep,
            ]),
            border: Border.all(color: EkkleiciaColors.goldBorder, width: 1),
            boxShadow: [
              BoxShadow(
                  color: EkkleiciaColors.gold.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: 4),
            ],
          ),
          child: CustomPaint(painter: _CrossPainter()),
        ),
        const SizedBox(height: 20),
        const Text('إكليسيا',
            style: TextStyle(
              fontFamily:  'Scheherazade',
              color:       EkkleiciaColors.goldLight,
              fontSize:    34,
              fontWeight:  FontWeight.w700,
              letterSpacing: 2,
            )),
        const SizedBox(height: 4),
        const Text('EKKLICIA  ·  ADMIN',
            style: TextStyle(
              color:       EkkleiciaColors.goldDim,
              fontSize:    10,
              letterSpacing: 5,
            )),
      ],
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:  EkkleiciaColors.bgMid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(width: 3, height: 18,
                      decoration: BoxDecoration(
                          color: EkkleiciaColors.gold,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Text('تسجيل الدخول',
                      style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color:      EkkleiciaColors.textPrimary,
                          fontSize:   18,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 24),

                // Email
                _Label('البريد الإلكتروني'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:   _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  textAlign:    TextAlign.left,
                  style: const TextStyle(
                      color: EkkleiciaColors.textPrimary, fontSize: 14),
                  decoration: _inputDec(
                    hint:   'admin@ekklicia.app',
                    prefix: const Icon(Icons.email_outlined,
                        size: 18, color: EkkleiciaColors.goldDim),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                _Label('كلمة المرور'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:  _passwordCtrl,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  textAlign:   TextAlign.left,
                  style: const TextStyle(
                      color: EkkleiciaColors.textPrimary, fontSize: 14),
                  decoration: _inputDec(
                    hint:   '••••••••',
                    prefix: const Icon(Icons.lock_outline,
                        size: 18, color: EkkleiciaColors.goldDim),
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: EkkleiciaColors.goldDim,
                      ),
                    ),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'مطلوب';
                    if (v.length < 6) return 'على الأقل ٦ أحرف';
                    return null;
                  },
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: Text(
                      _resetSent ? '✓ تم الإرسال' : 'نسيت كلمة المرور؟',
                      style: TextStyle(
                        fontFamily: 'Scheherazade',
                        color:  _resetSent
                            ? EkkleiciaColors.tealMid
                            : EkkleiciaColors.goldDim,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EkkleiciaColors.gold,
                      foregroundColor: EkkleiciaColors.bgDeep,
                      padding:         const EdgeInsets.symmetric(vertical: 14),
                      shape:           RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor:
                      EkkleiciaColors.goldDim.withOpacity(0.5),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              EkkleiciaColors.bgDeep),
                        ))
                        : const Text('دخول',
                        style: TextStyle(
                          fontFamily: 'Scheherazade',
                          fontSize:   18,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Container(height: 0.5,
          color: EkkleiciaColors.goldBorder)),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('أو', style: TextStyle(
            fontFamily: 'Scheherazade',
            color: EkkleiciaColors.textSecondary, fontSize: 12)),
      ),
      Expanded(child: Container(height: 0.5,
          color: EkkleiciaColors.goldBorder)),
    ]);
  }

  // ── Anonymous button ──────────────────────────────────────────────────

  Widget _buildAnonymousButton() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: state.isLoading
              ? null
              : () => context.read<AuthCubit>().signInAnonymously(),
          style: OutlinedButton.styleFrom(
            foregroundColor: EkkleiciaColors.textSecondary,
            side: const BorderSide(
                color: EkkleiciaColors.goldBorder, width: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('تصفّح كضيف (قراءة فقط)',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize: 14,
              )),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(children: [
      Text('✦  ✦  ✦',
          style: TextStyle(
              color: EkkleiciaColors.goldDim, fontSize: 9, letterSpacing: 8)),
      SizedBox(height: 8),
      Text('الكنيسة القبطية الأرثوذكسية',
          style: TextStyle(
              fontFamily: 'Scheherazade',
              color: EkkleiciaColors.textSecondary,
              fontSize: 11)),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  InputDecoration _inputDec({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText:       hint,
        hintStyle:      const TextStyle(
            color: EkkleiciaColors.textSecondary, fontSize: 13),
        prefixIcon:     prefix,
        suffixIcon:     suffix,
        filled:         true,
        fillColor:      EkkleiciaColors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        enabledBorder:  OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(
              color: EkkleiciaColors.goldBorder, width: 0.5),
        ),
        focusedBorder:  OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(
              color: EkkleiciaColors.gold, width: 1.5),
        ),
        errorBorder:    OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle:     const TextStyle(
            fontFamily: 'Scheherazade', fontSize: 12),
      );

  List<Widget> _corners() {
    const s = TextStyle(color: EkkleiciaColors.goldDim, fontSize: 14);
    return [
      const Positioned(top: 20, left: 16, child: Text('❖', style: s)),
      const Positioned(top: 20, right: 16, child: Text('❖', style: s)),
      const Positioned(bottom: 20, left: 16, child: Text('❖', style: s)),
      const Positioned(bottom: 20, right: 16, child: Text('❖', style: s)),
    ];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontFamily:  'Scheherazade',
        color:       EkkleiciaColors.textSecondary,
        fontSize:    12,
        fontWeight:  FontWeight.w600,
        letterSpacing: 0.5,
      ));
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = EkkleiciaColors.gold
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap   = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const arm = 22.0;
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), paint);
    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), paint);
    for (final p in [
      Offset(cx, cy - arm), Offset(cx, cy + arm),
      Offset(cx - arm, cy), Offset(cx + arm, cy),
    ]) {
      canvas.drawCircle(p, 3,
          Paint()..color = EkkleiciaColors.gold..style = PaintingStyle.fill);
    }
    canvas.drawCircle(Offset(cx, cy), 4,
        Paint()..color = EkkleiciaColors.gold..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()
          ..color       = EkkleiciaColors.goldBorder
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.8);
  }
  @override
  bool shouldRepaint(_) => false;
}