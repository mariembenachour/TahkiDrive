import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/admin_service.dart';
import 'AdminDashboardPage.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with TickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late AnimationController _entryController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  // ── palette (same as driver LoginPage) ──────────────────────────────────
  static const _neonPurple      = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPurpleDark  = Color(0xFF4A148C);
  static const _neonPink        = Color(0xFFFF00E5);
  static const _darkBg          = Color(0xFF050510);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _floatController = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _entryController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _entryController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AdminService.loginAdmin(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── background identical to driver login ────────────────────────────────
  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _darkBg),
        // radial glow top-centre
        Positioned(
          top: -100, left: -100, right: -100,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _neonPurple.withOpacity(0.25),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
          ),
        ),
        // radial glow bottom
        Positioned(
          bottom: -120, left: -80, right: -80,
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _neonPink.withOpacity(0.12),
                  Colors.transparent,
                ],
                radius: 0.7,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _darkBg.withOpacity(0.2),
                _darkBg.withOpacity(0.75),
                _darkBg.withOpacity(0.98),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _floatingParticle(int index) {
    final random = index * 137.5;
    final size   = 2.0 + (index % 3) * 1.5;
    final colors = [
      _neonPurple.withOpacity(0.6),
      _neonPurpleLight.withOpacity(0.5),
      _neonPink.withOpacity(0.4),
      Colors.white.withOpacity(0.3),
    ];
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, child) {
        final t = _floatController.value;
        final x = cos(random + t * 2 * pi) * 50 + (index % 2 == 0 ? -30 : 250);
        final y = sin(random + t * pi)      * 80 + 100 + index * 120;
        final opacity = 0.3 + sin(t * pi + index) * 0.3;
        return Positioned(
          left: x, top: y,
          child: Opacity(
            opacity: opacity.clamp(0.1, 0.8),
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[index % colors.length],
                boxShadow: [BoxShadow(
                  color: colors[index % colors.length].withOpacity(0.8),
                  blurRadius: 6, spreadRadius: 1,
                )],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) => Transform.scale(
        scale: 1 + _pulseController.value * 0.05, child: child,
      ),
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _floatController.value * -6), child: child,
        ),
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_neonPurple, _neonPurpleLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: _neonPurple.withOpacity(0.5),
                  blurRadius: 20, spreadRadius: 3, offset: const Offset(0, 6)),
              BoxShadow(color: _neonPurpleLight.withOpacity(0.4),
                  blurRadius: 30, spreadRadius: 5, offset: const Offset(0, 10)),
            ],
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: Colors.white, size: 36),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_neonPurpleLight, _neonPurple, Colors.white],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: const Text(
        'TAHKIDRIVE',
        style: TextStyle(
          color: Colors.white, fontSize: 22,
          fontWeight: FontWeight.w900, letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Opacity(
        opacity: 0.5 + _glowController.value * 0.3, child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: _neonPurple.withOpacity(0.4), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'PANNEAU ADMINISTRATION',
          style: TextStyle(
            color: Colors.white70, fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500,
    ),
  );

  Widget _buildField({
    required TextEditingController ctrl,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: _neonPurple.withOpacity(0.05 + _glowController.value * 0.05),
            blurRadius: 10 + _glowController.value * 10, spreadRadius: 1,
          )],
        ),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _neonPurple.withOpacity(0.2), width: 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.02),
              Colors.transparent,
            ],
          ),
        ),
        child: TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
            prefixIcon: Icon(icon, color: _neonPurple.withOpacity(0.6), size: 18),
            suffixIcon: suffix,
            filled: false,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _neonPurpleLight, width: 2)),
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 10, height: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withOpacity(0.4 + _glowController.value * 0.4),
              blurRadius: 20 + _glowController.value * 15, spreadRadius: 3,
            ),
            BoxShadow(
              color: _neonPurpleLight.withOpacity(0.3),
              blurRadius: 30, spreadRadius: 5,
            ),
          ],
        ),
        child: child,
      ),
      child: Container(
        width: double.infinity, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_neonPurple, _neonPurpleDark],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _neonPurpleLight.withOpacity(0.5), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _login,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withOpacity(0.2),
            child: Center(
              child: _loading
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                'CONNEXION',
                style: TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withOpacity(0.15 + _glowController.value * 0.15),
              blurRadius: 30 + _glowController.value * 20, spreadRadius: 5,
            ),
            BoxShadow(
              color: _neonPurpleLight.withOpacity(0.1 + _glowController.value * 0.1),
              blurRadius: 50 + _glowController.value * 30, spreadRadius: 10,
            ),
          ],
        ),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _neonPurpleLight.withOpacity(0.4), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              _neonPurple.withOpacity(0.12),
              _neonPurpleDark.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Email administrateur'),
            const SizedBox(height: 6),
            _buildField(
              ctrl: _emailCtrl,
              icon: Icons.alternate_email_rounded,
              hint: 'admin@tahkidrive.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
              v == null || !v.contains('@') ? 'Email invalide' : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('Mot de passe'),
            const SizedBox(height: 6),
            _buildField(
              ctrl: _passCtrl,
              icon: Icons.lock_outline_rounded,
              hint: '••••••••',
              obscure: _obscure,
              suffix: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _obscure ? Colors.transparent : _neonPurple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: _obscure ? Colors.white30 : _neonPurpleLight,
                    size: 16,
                  ),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),

            // Error banner
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 20),
            _buildLoginButton(),
            const SizedBox(height: 16),

            // Divider label
            Center(
              child: Text(
                'Accès restreint — administrateurs seulement',
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          ...List.generate(6, (i) => _floatingParticle(i)),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _entryController,
                      builder: (context, child) => FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entryController,
                          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3), end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
                          )),
                          child: child,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 60),
                            _buildLogo(),
                            const SizedBox(height: 20),
                            _buildTitle(),
                            const SizedBox(height: 6),
                            _buildSubtitle(),
                            const SizedBox(height: 35),
                            _buildGlassCard(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
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