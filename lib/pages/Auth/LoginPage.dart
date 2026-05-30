import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import '../../services/auth_service.dart';
import 'ScanQrPage.dart';
import '../Main_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;

  late AnimationController _entryController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

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

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
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
      final data = await AuthService.loginDriver(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      final cin = data['cin']?.toString() ?? await AuthService.getCin() ?? '';
      if (cin.isNotEmpty) await NotificationService.init(cin);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      setState(() {
        final msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('401') || msg.contains('incorrect')) {
          _error = 'Email ou mot de passe incorrect';
        } else if (msg.contains('403') || msg.contains('validation')) {
          _error = 'Compte en attente de validation admin';
        } else {
          _error = msg;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════
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
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 40,
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _entryController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entryController,
                          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 60.h),
                          _buildLogo3D(),
                          SizedBox(height: 20.h),
                          _buildTitle(),
                          SizedBox(height: 6.h),
                          _buildSubtitle(),
                          SizedBox(height: 35.h),
                          _buildGlassCard(),
                          SizedBox(height: 20.h),
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
    );
  }

  // ════════════════════════════════════════════════════════
  // BACKGROUND
  // ════════════════════════════════════════════════════════
  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('images/bg cars.jpg', fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _darkBg.withOpacity(0.4),
                _darkBg.withOpacity(0.8),
                _darkBg.withOpacity(0.98),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Colors.transparent, _darkBg.withOpacity(0.6)],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // PARTICLES
  // ════════════════════════════════════════════════════════
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
        final t       = _floatController.value;
        final x       = cos(random + t * 2 * pi) * 50 + (index % 2 == 0 ? -30 : 250);
        final y       = sin(random + t * pi) * 80 + 100 + index * 120;
        final opacity = 0.3 + sin(t * pi + index) * 0.3;
        return Positioned(
          left: x,
          top:  y,
          child: Opacity(
            opacity: opacity.clamp(0.1, 0.8),
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[index % colors.length],
                boxShadow: [
                  BoxShadow(
                    color: colors[index % colors.length].withOpacity(0.8),
                    blurRadius: 6, spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════
  // LOGO
  // ════════════════════════════════════════════════════════
  Widget _buildLogo3D() {
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
          width: 70.w, height: 70.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_neonPurple, _neonPurpleLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: _neonPurple.withOpacity(0.5), blurRadius: 20, spreadRadius: 3, offset: const Offset(0, 6)),
              BoxShadow(color: _neonPurpleLight.withOpacity(0.4), blurRadius: 30, spreadRadius: 5, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipOval(
            child: Image.asset('images/logo.png', fit: BoxFit.cover, width: 70.w, height: 70.h),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // TITLE / SUBTITLE
  // ════════════════════════════════════════════════════════
  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [_neonPurpleLight, _neonPurple, Colors.white.withOpacity(0.9)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: Text(
        'TAHKIDRIVE',
        style: TextStyle(
          color: Colors.white, fontSize: 22.sp,
          fontWeight: FontWeight.w900, letterSpacing: 4.w,
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          border: Border.all(color: _neonPurple.withOpacity(0.4), width: 1.w),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          'CONNEXION',
          style: TextStyle(
            color: Colors.white70, fontSize: 10.sp,
            fontWeight: FontWeight.w600, letterSpacing: 2.w,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // GLASS CARD
  // ════════════════════════════════════════════════════════
  Widget _buildGlassCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
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
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: _neonPurpleLight.withOpacity(0.4), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
            _buildLabel('Email'),
            SizedBox(height: 6.h),
            _buildFuturisticField(
              controller: _emailCtrl,
              icon: Icons.alternate_email_rounded,
              hint: 'chauffeur@gmail.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                return null;
              },
            ),
            SizedBox(height: 16.h),
            _buildLabel('Mot de passe'),
            SizedBox(height: 6.h),
            _buildFuturisticField(
              controller: _passCtrl,
              icon: Icons.lock_outline_rounded,
              hint: '••••••••',
              obscure: _obscure,
              suffix: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: _obscure ? Colors.transparent : _neonPurple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: _obscure ? Colors.white30 : _neonPurpleLight,
                    size: 16.w,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                return null;
              },
            ),
            SizedBox(height: 20.h),
            _buildNeonButton(),

            // ── Erreur serveur ──────────────────────────────
            if (_error != null) ...[
              SizedBox(height: 12.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.4), width: 1.w,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 18.w),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 16.h),

            // ── Séparateur ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, _neonPurple.withOpacity(0.3)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OU',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10.sp, fontWeight: FontWeight.w600, letterSpacing: 2.w,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_neonPurple.withOpacity(0.3), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),
            _buildQrButton(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // WIDGETS HELPERS
  // ════════════════════════════════════════════════════════
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 12.sp, fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildFuturisticField({
    required TextEditingController controller,
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
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withOpacity(0.05 + _glowController.value * 0.05),
              blurRadius: 10 + _glowController.value * 10, spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _neonPurple.withOpacity(0.2), width: 1.w),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.02),
              Colors.transparent,
            ],
          ),
        ),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13.sp),
            prefixIcon: Icon(icon, color: _neonPurple.withOpacity(0.6), size: 18.w),
            suffixIcon: suffix,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: _neonPurpleLight, width: 2.w),
            ),
            errorStyle: TextStyle(color: Colors.redAccent, fontSize: 11.sp),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
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
        width: double.infinity,
        height: 46.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_neonPurple, _neonPurpleDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _neonPurpleLight.withOpacity(0.5), width: 1.w),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _login,
            borderRadius: BorderRadius.circular(14.r),
            splashColor: Colors.white.withOpacity(0.2),
            child: Center(
              child: _loading
                  ? SizedBox(
                width: 20.w, height: 20.h,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
              )
                  : Text(
                'Connexion',
                style: TextStyle(
                  color: Colors.white, fontSize: 14.sp,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5.w,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrButton() {
    return Container(
      width: double.infinity,
      height: 44.h,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _neonPurple.withOpacity(0.4), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanQrPage()),
          ),
          borderRadius: BorderRadius.circular(14.r),
          splashColor: _neonPurple.withOpacity(0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded,
                  color: _neonPurpleLight.withOpacity(0.9), size: 18.w),
              SizedBox(width: 8.w),
              Text(
                'Inscription par QR',
                style: TextStyle(
                  color: _neonPurpleLight.withOpacity(0.95),
                  fontSize: 13.sp, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
