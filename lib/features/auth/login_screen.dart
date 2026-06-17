// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/brightness_colors.dart';
import '../../../core/theme/colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_logo.dart';
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
    final brightness = Theme.of(context).brightness;
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Scheherazade', fontSize: 14),
          textAlign: TextAlign.center),
      backgroundColor: bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: goldBorder, width: 0.5)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final bgDeep = BrightnessColors.bgDeep(brightness);

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
        backgroundColor: bgDeep,
        body: Stack(
          children: [
            // Background texture
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg1.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.18),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgDeep,
                      bgDeep.withOpacity(0.75),
                      BrightnessColors.bgPrimary(brightness),
                    ],
                    stops: const [0.0, 0.4, 1.0],
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
                            _buildGoogleButton(),
                            const SizedBox(height: 12),
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
        const AppLogo(size: 80, contained: true),
        const SizedBox(height: 20),
        Text('إكليسيا',
            style: TextStyle(
              fontFamily:  'Scheherazade',
              color:       BrightnessColors.goldLight(Theme.of(context).brightness),
              fontSize:    34,
              fontWeight:  FontWeight.w700,
              letterSpacing: 2,
            )),
        const SizedBox(height: 4),
        Text('Ekklisia  ·  ADMIN',
            style: TextStyle(
              color:       BrightnessColors.goldDim(Theme.of(context).brightness),
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
        final brightness = Theme.of(context).brightness;
        final gold = Theme.of(context).primaryColor;
        final goldDim = BrightnessColors.goldDim(brightness);
        final goldBorder = BrightnessColors.goldBorder(brightness);
        final textPrimary = BrightnessColors.textPrimary(brightness);
        final bgMid = BrightnessColors.bgMid(brightness);
        final bgDeep = BrightnessColors.bgDeep(brightness);

        return Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:  bgMid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: goldBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(width: 3, height: 18,
                      decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Text('تسجيل الدخول',
                      style: TextStyle(
                          fontFamily: 'Scheherazade',
                          color:      textPrimary,
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
                  style: TextStyle(
                      color: textPrimary, fontSize: 14),
                  decoration: _inputDec(
                    hint:   'admin@Ekklisia.app',
                    prefix: Icon(Icons.email_outlined,
                        size: 18, color: goldDim),
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
                  style: TextStyle(
                      color: textPrimary, fontSize: 14),
                  decoration: _inputDec(
                    hint:   '••••••••',
                    prefix: Icon(Icons.lock_outline,
                        size: 18, color: goldDim),
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: goldDim,
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
                        color:  _resetSent ? Colors.green : goldDim,
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
                      backgroundColor: gold,
                      foregroundColor: bgDeep,
                      padding:         const EdgeInsets.symmetric(vertical: 14),
                      shape:           RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor:
                      goldDim.withOpacity(0.5),
                    ),
                    child: state.isLoading
                        ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(bgDeep),
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
    final brightness = Theme.of(context).brightness;
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Row(children: [
      Expanded(child: Container(height: 0.5,
          color: goldBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('أو', style: TextStyle(
            fontFamily: 'Scheherazade',
            color: textSecondary, fontSize: 12)),
      ),
      Expanded(child: Container(height: 0.5,
          color: goldBorder)),
    ]);
  }

  // ── Google Sign-In button ─────────────────────────────────────────────

  Widget _buildGoogleButton() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: state.isLoading
              ? null
              : () async {
                  print('[LoginScreen] Google Sign-In button pressed');
                  try {
                    print('[LoginScreen] Attempting to sign in with Google...');
                    await context.read<AuthCubit>().signInWithGoogle();
                    print('[LoginScreen] Google Sign-In successful');
                  } on UnimplementedError catch (e) {
                    print('[LoginScreen] Google Sign-In not implemented: ${e.toString()}');
                    if (mounted) {
                      _showSnack('دخول Google غير مُفعّل حالياً. يرجى تكوين البيانات الأساسية.');
                    }
                  } catch (e) {
                    print('[LoginScreen] Google Sign-In error: ${e.runtimeType} - ${e.toString()}');
                    if (mounted) {
                      _showSnack('خطأ في دخول Google: ${e.toString()}');
                    }
                  }
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: BrightnessColors.textSecondary(Theme.of(context).brightness),
            side: BorderSide(
                color: BrightnessColors.goldBorder(Theme.of(context).brightness), width: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login, size: 16),
              const SizedBox(width: 8),
              const Text('دخول عبر Google',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize: 14,
                  )),
            ],
          ),
        ),)
      );
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
            foregroundColor: BrightnessColors.textSecondary(Theme.of(context).brightness),
            side: BorderSide(
                color: BrightnessColors.goldBorder(Theme.of(context).brightness), width: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('تصفّح كضيف (قراءة فقط)',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize: 14,
              )),
        ),)
      );
  }

  Widget _buildFooter() {
    final brightness = Theme.of(context).brightness;
    final goldDim = BrightnessColors.goldDim(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);

    return Column(children: [
      Text('✦  ✦  ✦',
          style: TextStyle(
              color: goldDim, fontSize: 9, letterSpacing: 8)),
      const SizedBox(height: 8),
      Text('الكنيسة القبطية الأرثوذكسية',
          style: TextStyle(
              fontFamily: 'Scheherazade',
              color: textSecondary,
              fontSize: 11)),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  InputDecoration _inputDec({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final gold = Theme.of(context).primaryColor;

    return InputDecoration(
      hintText:       hint,
      hintStyle:      TextStyle(
          color: textSecondary, fontSize: 13),
      prefixIcon:     prefix,
      suffixIcon:     suffix,
      filled:         true,
      fillColor:      bgElevated,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      enabledBorder:  OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(
            color: goldBorder, width: 0.5),
      ),
      focusedBorder:  OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(
            color: gold, width: 1.5),
      ),
      errorBorder:    OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle:     const TextStyle(
          fontFamily: 'Scheherazade', fontSize: 12),
    );
  }

  List<Widget> _corners() {
    final goldDim = BrightnessColors.goldDim(Theme.of(context).brightness);
    final s = TextStyle(color: goldDim, fontSize: 14);
    return [
      Positioned(top: 20, left: 16, child: Text('❖', style: s)),
      Positioned(top: 20, right: 16, child: Text('❖', style: s)),
      Positioned(bottom: 20, left: 16, child: Text('❖', style: s)),
      Positioned(bottom: 20, right: 16, child: Text('❖', style: s)),
    ];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontFamily:  'Scheherazade',
        color:       BrightnessColors.textSecondary(Theme.of(context).brightness),
        fontSize:    12,
        fontWeight:  FontWeight.w600,
        letterSpacing: 0.5,
      ));
}

