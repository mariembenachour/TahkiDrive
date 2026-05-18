import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tahki_drive1/services/theme_service.dart';
import 'package:tahki_drive1/services/language_service.dart';
import '../../services/auth_service.dart';
import 'ScanQrPage.dart';
import '../Main_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late AnimationController _entryController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  // Animation pour le menu popup
  AnimationController? _menuController;
  Animation<double>? _menuScaleAnimation;
  Animation<double>? _menuFadeAnimation;
  OverlayEntry? _menuOverlay;

  static const _neonPurple = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPurpleDark = Color(0xFF4A148C);
  static const _neonPink = Color(0xFFFF00E5);
  static const _darkBg = Color(0xFF050510);

  final GlobalKey _langButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
    _menuController?.dispose();
    _hideMenu();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.loginDriver(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MainScreen()));
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══ MENU LANGUE AVEC ANIMATION SCALE ═══

  void _toggleLanguageMenu() {
    if (_menuOverlay != null) {
      _hideMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    final renderBox = _langButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _menuScaleAnimation = CurvedAnimation(
      parent: _menuController!,
      curve: Curves.easeOutBack,
    );

    _menuFadeAnimation = CurvedAnimation(
      parent: _menuController!,
      curve: Curves.easeOut,
    );

    _menuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Fond transparent pour fermer au clic
          GestureDetector(
            onTap: _hideMenu,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Menu positionné sous le bouton
          Positioned(
            top: offset.dy + size.height + 8,
            right: MediaQuery.of(context).size.width - offset.dx - size.width,
            child: FadeTransition(
              opacity: _menuFadeAnimation!,
              child: ScaleTransition(
                scale: _menuScaleAnimation!,
                alignment: Alignment.topRight,
                child: _buildMenuContent(),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
    _menuController!.forward();
  }

  void _hideMenu() {
    if (_menuController != null) {
      _menuController!.reverse().then((_) {
        _menuOverlay?.remove();
        _menuOverlay = null;
        _menuController?.dispose();
        _menuController = null;
      });
    }
  }

  Widget _buildMenuContent() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: _darkBg.withOpacity(0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _neonPurple.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _neonPurple.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangItem('fr', '🇫🇷', 'Français'),
            Divider(color: _neonPurple.withOpacity(0.2), height: 1),
            _buildLangItem('ar', '🇹🇳', 'Arabe'),
            Divider(color: _neonPurple.withOpacity(0.2), height: 1),
            _buildLangItem('en', '🇬🇧', 'English'),
          ],
        ),
      ),
    );
  }

  Widget _buildLangItem(String langCode, String flag, String langName) {
    final isSelected = context.locale.languageCode == langCode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _hideMenu();
          await context.setLocale(Locale(langCode));
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${'langue changee'.tr()} ${langName.toUpperCase()}'),
                backgroundColor: _neonPurple,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        splashColor: _neonPurple.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  langName,
                  style: TextStyle(
                    color: isSelected ? _neonPurpleLight : Colors.white,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: _neonPurpleLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _currentLangEmoji() {
    final code = context.locale.languageCode;
    const map = {'fr': '🇫🇷', 'ar': '🇹🇳', 'en': '🇬🇧'};
    return map[code] ?? '🌐';
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

          // ═══ CONTENU PRINCIPAL (scrollable) ═══
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                          const SizedBox(height: 60),
                          _buildLogo3D(),
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

          // ═══ BOUTON LANGUE AVEC MENU SCALE ═══
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              key: _langButtonKey,
              onTap: _toggleLanguageMenu,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _neonPurple.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neonPurple.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    return Transform.scale(
                      scale: 1 + _pulseController.value * 0.05,
                      child: Center(
                        child: Text(
                          _currentLangEmoji(),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'images/bg cars.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
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
              colors: [
                Colors.transparent,
                _darkBg.withOpacity(0.6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _floatingParticle(int index) {
    final random = index * 137.5;
    final size = 2.0 + (index % 3) * 1.5;
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
        final y = sin(random + t * pi) * 80 + 100 + index * 120;
        final opacity = 0.3 + sin(t * pi + index) * 0.3;

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity.clamp(0.1, 0.8),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[index % colors.length],
                boxShadow: [
                  BoxShadow(
                    color: colors[index % colors.length].withOpacity(0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo3D() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final scale = 1 + _pulseController.value * 0.05;
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (_, child) {
          final y = _floatController.value * -6;
          return Transform.translate(offset: Offset(0, y), child: child);
        },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_neonPurple, _neonPurpleLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: _neonPurpleLight.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'images/logo.png',
              fit: BoxFit.cover,
              width: 70,
              height: 70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          _neonPurpleLight,
          _neonPurple,
          Colors.white.withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: const Text(
        'TAHKIDRIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Opacity(
          opacity: 0.5 + _glowController.value * 0.3,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: _neonPurple.withOpacity(0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'connexion titre'.tr(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withOpacity(
                  0.15 + _glowController.value * 0.15,
                ),
                blurRadius: 30 + _glowController.value * 20,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: _neonPurpleLight.withOpacity(
                  0.1 + _glowController.value * 0.1,
                ),
                blurRadius: 50 + _glowController.value * 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _neonPurpleLight.withOpacity(0.4),
            width: 1.5,
          ),
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
            _buildLabel('email'.tr()),
            const SizedBox(height: 6),
            _buildFuturisticField(
              controller: _emailCtrl,
              icon: Icons.alternate_email_rounded,
              hint: 'chauffeur@gmail.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
              v == null || !v.contains('@') ? 'email invalide'.tr() : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('mot de passe'.tr()),
            const SizedBox(height: 6),
            _buildFuturisticField(
              controller: _passCtrl,
              icon: Icons.lock_outline_rounded,
              hint: '••••••••',
              obscure: _obscure,
              suffix: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _obscure
                        ? Colors.transparent
                        : _neonPurple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: _obscure ? Colors.white30 : _neonPurpleLight,
                    size: 16,
                  ),
                ),
              ),
              validator: (v) =>
              v == null || v.length < 4 ? 'mdp court'.tr() : null,
            ),
            const SizedBox(height: 20),
            _buildNeonButton(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _neonPurple.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou'.tr().toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _neonPurple.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQrButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 12,
        fontWeight: FontWeight.w500,
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
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withOpacity(0.05 + _glowController.value * 0.05),
                blurRadius: 10 + _glowController.value * 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _neonPurple.withOpacity(0.2),
            width: 1,
          ),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              color: _neonPurple.withOpacity(0.6),
              size: 18,
            ),
            suffixIcon: suffix,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: _neonPurpleLight,
                width: 2,
              ),
            ),
            errorStyle: const TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              height: 0.5,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withOpacity(
                  0.4 + _glowController.value * 0.4,
                ),
                blurRadius: 20 + _glowController.value * 15,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: _neonPurpleLight.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_neonPurple, _neonPurpleDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _neonPurpleLight.withOpacity(0.5),
            width: 1,
          ),
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'connexion'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
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
      height: 44,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _neonPurple.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanQrPage()),
          ),
          borderRadius: BorderRadius.circular(14),
          splashColor: _neonPurple.withOpacity(0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: _neonPurpleLight.withOpacity(0.9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'inscription qr'.tr(),
                style: TextStyle(
                  color: _neonPurpleLight.withOpacity(0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
