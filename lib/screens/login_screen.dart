// lib/screens/login_screen.dart
// PREMIUM v4 — Ultra-premium login with water animation, glassmorphism,
// brand identity, and smooth micro-interactions

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import '../core/utils.dart';
import '../core/constants.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool _isLogin      = true;
  bool _obscurePass  = true;
  bool _rememberMe   = false;

  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _cardSlide;
  late AnimationController _bgCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000))
      ..repeat();

    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context); // cache before async gap
    auth.clearError();

    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    bool ok;
    if (_isLogin) {
      ok = await auth.login(email, pass);
    } else {
      ok = await auth.register(email, pass);
      if (ok && mounted) {
        // Update display name if provided
        if (_nameCtrl.text.trim().isNotEmpty) {
          try {
            await auth.currentUser?.updateDisplayName(_nameCtrl.text.trim());
          } catch (_) {}
        }
        if (!mounted) return;
        AppUtils.showSnack(context, '✅ Account created! Please verify your email.');
        setState(() => _isLogin = true);
        _passCtrl.clear();
        return;
      }
    }

    if (ok && mounted) {
      navigator.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (_) => false,
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      AppUtils.showSnack(context, 'Enter your email first, then tap Forgot Password.', isError: true);
      return;
    }
    final auth = context.read<AuthService>();
    final ok   = await auth.sendPasswordReset(email);
    if (mounted) {
      AppUtils.showSnack(
        context,
        ok ? '📧 Password reset email sent. Check your inbox.' : 'Failed to send reset email.',
        isError: !ok,
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _passCtrl.clear();
    });
    context.read<AuthService>().clearError();
    _entryCtrl.forward(from: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: Stack(
        children: [
          // ── Animated deep-ocean background ─────────────
          _OceanBackground(bgCtrl: _bgCtrl),

          // ── Wave decoration at top ──────────────────────
          _WaveDecoration(waveCtrl: _waveCtrl, screenHeight: size.height),

          // ── Main content ────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: FadeTransition(
                  opacity: _entryFade,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Brand header ─────────────────
                        _BrandHeader(pulseCtrl: _pulseCtrl),
                        const SizedBox(height: 32),

                        // ── Premium form card ────────────
                        _PremiumFormCard(
                          isLogin: _isLogin,
                          emailCtrl: _emailCtrl,
                          passCtrl: _passCtrl,
                          nameCtrl: _nameCtrl,
                          formKey: _formKey,
                          obscurePass: _obscurePass,
                          rememberMe: _rememberMe,
                          onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                          onToggleRemember: (v) => setState(() => _rememberMe = v ?? false),
                          onForgotPassword: _forgotPassword,
                          onSubmit: _submit,
                        ),

                        const SizedBox(height: 20),

                        // ── Toggle register/login ────────
                        _ToggleRow(isLogin: _isLogin, onToggle: _toggleMode),

                        const SizedBox(height: 24),

                        // ── Footer ───────────────────────
                        _Footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ocean animated background ───────────────────────────────
class _OceanBackground extends StatelessWidget {
  final AnimationController bgCtrl;
  const _OceanBackground({required this.bgCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final t = bgCtrl.value;
        return Stack(
          children: [
            // Deep ocean gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020B18),
                    Color(0xFF041225),
                    Color(0xFF061830),
                    Color(0xFF020B18),
                  ],
                  stops: [0, 0.3, 0.7, 1],
                ),
              ),
            ),
            // Animated orb 1 — ocean blue
            Positioned(
              left: -80 + 60 * math.sin(t * 2 * math.pi),
              top: -80 + 50 * math.cos(t * 2 * math.pi),
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.16),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            // Orb 2 — cyan
            Positioned(
              right: -100 + 40 * math.cos(t * 2 * math.pi + 1.5),
              bottom: 100 + 60 * math.sin(t * 2 * math.pi + 1.5),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF06B6D4).withValues(alpha: 0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            // Orb 3 — small accent
            Positioned(
              left: 80 + 30 * math.sin(t * 2 * math.pi + 3),
              bottom: -60 + 40 * math.cos(t * 2 * math.pi + 3),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            // Dot grid
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          ],
        );
      },
    );
  }
}

// ── Wave decoration ─────────────────────────────────────────
class _WaveDecoration extends StatelessWidget {
  final AnimationController waveCtrl;
  final double screenHeight;
  const _WaveDecoration({required this.waveCtrl, required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: waveCtrl,
      builder: (_, __) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: screenHeight * 0.28,
          child: CustomPaint(
            painter: _WavePainter(progress: waveCtrl.value),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final paint2 = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.6);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.6 +
          math.sin((x / size.width * 2 * math.pi) + progress * 2 * math.pi) *
              size.height * 0.1;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.7 +
          math.sin((x / size.width * 2 * math.pi) + progress * 2 * math.pi + 1.0) *
              size.height * 0.08;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.progress != progress;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Brand header ────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _BrandHeader({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final pulse = 0.9 + 0.1 * pulseCtrl.value;
        return Column(
          children: [
            // Logo container with pulse glow
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF1E4B8A), Color(0xFF0D2952)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.3 + 0.2 * pulseCtrl.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.25 + 0.15 * pulseCtrl.value),
                      blurRadius: 30 + 10 * pulseCtrl.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.water_drop_rounded, color: Color(0xFF38BDF8), size: 42),
              ),
            ),
            const SizedBox(height: 16),

            // App name
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF7DD3FC), Color(0xFF0EA5E9)],
              ).createShader(bounds),
              child: const Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Brand name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.7 + 0.3 * pulseCtrl.value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    AppConstants.brandName,
                    style: TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Premium form card ───────────────────────────────────────
class _PremiumFormCard extends StatelessWidget {
  final bool isLogin;
  final TextEditingController emailCtrl, passCtrl, nameCtrl;
  final GlobalKey<FormState> formKey;
  final bool obscurePass, rememberMe;
  final VoidCallback onToggleObscure, onForgotPassword, onSubmit;
  final void Function(bool?) onToggleRemember;

  const _PremiumFormCard({
    required this.isLogin,
    required this.emailCtrl,
    required this.passCtrl,
    required this.nameCtrl,
    required this.formKey,
    required this.obscurePass,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x22103070), Color(0x151A3B6E)],
        ),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                      ),
                    ),
                    child: Icon(
                      isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLogin ? 'Welcome Back' : 'Create Account',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isLogin ? 'Sign in to your account' : 'Join Smart IoT Interface',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Container(height: 1, color: const Color(0xFF0EA5E9).withValues(alpha: 0.12)),
              const SizedBox(height: 22),

              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Display name (register only)
                    if (!isLogin) ...[
                      _LoginField(
                        controller: nameCtrl,
                        label: 'Display Name',
                        hint: 'Your full name',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Email
                    _LoginField(
                      controller: emailCtrl,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w{2,}$').hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password
                    _LoginField(
                      controller: passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: obscurePass,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => onSubmit(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 19,
                        ),
                        onPressed: onToggleObscure,
                      ),
                      validator: (v) => AuthService.validatePassword(v, isLogin: isLogin),
                    ),

                    const SizedBox(height: 12),

                    // Remember me + forgot password
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => onToggleRemember(!rememberMe),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: rememberMe
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                  color: rememberMe
                                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.2)
                                      : Colors.transparent,
                                ),
                                child: rememberMe
                                    ? const Icon(Icons.check_rounded, size: 13, color: Color(0xFF0EA5E9))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remember me',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (isLogin)
                          GestureDetector(
                            onTap: onForgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Error
                    Consumer<AuthService>(
                      builder: (_, auth, __) {
                        if (auth.errorMessage == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.errorMessage!,
                                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Submit button
                    Consumer<AuthService>(
                      builder: (_, auth, __) => SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: isLogin ? 'Sign In' : 'Create Account',
                          icon: isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                          isLoading: auth.isLoading,
                          onPressed: auth.isLoading ? null : onSubmit,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle row ───────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;
  const _ToggleRow({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? "Don't have an account? " : 'Already have an account? ',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
        ),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
            ),
            child: Text(
              isLogin ? 'Register' : 'Sign In',
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Footer ──────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterDot(),
            const SizedBox(width: 8),
            Text(
              '${AppConstants.brandName}  ·  Secure & Encrypted',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 11, letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            _FooterDot(),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'v${AppConstants.appVersion}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.12), fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }
}

class _FooterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
      ),
    );
  }
}

// ── Premium input field for login ───────────────────────────
class _LoginField extends StatefulWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _LoginField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _focused
              ? [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -2)]
              : null,
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              child: Icon(
                widget.icon,
                color: _focused ? const Color(0xFF38BDF8) : Colors.white38,
                size: 20,
              ),
            ),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: _focused
                ? const Color(0xFF0EA5E9).withValues(alpha: 0.08)
                : const Color(0xFF0D1F3C).withValues(alpha: 0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
            ),
            labelStyle: TextStyle(
              color: _focused ? const Color(0xFF38BDF8) : Colors.white38,
              fontSize: 14,
            ),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.18), fontSize: 13),
            errorStyle: const TextStyle(color: AppTheme.danger, fontSize: 12),
          ),
          validator: widget.validator,
        ),
      ),
    );
  }
}
