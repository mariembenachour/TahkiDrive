import 'dart:convert';
import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tahki_drive1/services/theme_service.dart';
import 'package:tahki_drive1/services/language_service.dart';
import 'VerifyEmailPage.dart';
import 'SetupProfilePage.dart';
import '../../services/auth_service.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage>
    with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────
  final _deviceQrCtrl = TextEditingController();
  final _camQrCtrl    = TextEditingController();
  final _vendorQrCtrl = TextEditingController();
  final _cinCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool  _loading = false;
  bool  _obscure = true;
  bool  _hasCam  = false;
  String? _error;

  // ── Animations ──────────────────────────────────────────────
  late AnimationController _entryController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  // ── Couleurs Néon (identiques à LoginPage) ──────────────────
  static const _neonPurple      = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPurpleDark  = Color(0xFF4A148C);
  static const _neonPink        = Color(0xFFFF00E5);
  static const _darkBg          = Color(0xFF050510);
  static const _orange          = Color(0xFFFF9800);
  static const _blue            = Color(0xFF2196F3);

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
    _deviceQrCtrl.dispose();
    _camQrCtrl.dispose();
    _vendorQrCtrl.dispose();
    _cinCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _entryController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ── Submit (inchangé) ───────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      String deviceQrData = _deviceQrCtrl.text.trim();
      String vendorQrData = _vendorQrCtrl.text.trim();

      if (!deviceQrData.startsWith('{')) {
        deviceQrData = jsonEncode({'type': 'device', 'serial': deviceQrData});
      }
      if (!vendorQrData.startsWith('{')) {
        vendorQrData = jsonEncode({'type': 'vendor', 'token': vendorQrData});
      }

      String? camQrData;
      if (_hasCam && _camQrCtrl.text.trim().isNotEmpty) {
        camQrData = _camQrCtrl.text.trim();
        if (!camQrData.startsWith('{')) {
          camQrData = jsonEncode({'type': 'device', 'serial': camQrData});
        }
      }

      final cin = _cinCtrl.text.trim();

      final result = await AuthService.scanRegister(
        cin:          cin,
        deviceQrData: deviceQrData,
        vendorQrData: vendorQrData,
        email:        _emailCtrl.text.trim(),
        password:     _passCtrl.text,
        camQrData:    camQrData,
      );

      final setupToken = result['setup_token']?.toString() ?? '';
      if (setupToken.isEmpty) throw Exception('Token manquant');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailPage(setupToken: setupToken, cin: cin)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Scanner QR (inchangé) ───────────────────────────────────
  Future<void> _scanQr(TextEditingController ctrl) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (result != null && mounted) {
      setState(() => ctrl.text = result);
    }
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond animé
          _buildBackground(),
          ...List.generate(6, (i) => _floatingParticle(i)),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header avec retour
                      _buildHeader(),
                      const SizedBox(height: 30),

                      // Logo animé
                      Center(child: _buildLogo3D()),
                      const SizedBox(height: 16),
                      Center(child: _buildTitle()),
                      const SizedBox(height: 4),
                      Center(child: _buildSubtitle()),
                      const SizedBox(height: 40),

                      // ── Étape 1 — Boitier GPS ─────────────────
                      _buildStepTitle(0, 'boitier gps'.tr(), 'scan boitier desc'.tr(), _blue),
                      const SizedBox(height: 12),
                      _buildFuturisticQrField(
                        controller: _deviceQrCtrl,
                        label: 'qr boitier'.tr(),
                        color: _blue,
                        icon: Icons.router_rounded,
                        validator: (v) => v == null || v.isEmpty ? 'requis'.tr() : null,
                      ),
                      const SizedBox(height: 12),

                      // Toggle caméra
                      _buildCamToggle(),

                      // Champ caméra (si activé)
                      if (_hasCam) ...[
                        const SizedBox(height: 16),
                        _buildStepTitle(null, 'camera'.tr(), 'scan camera desc'.tr(), _orange),
                        const SizedBox(height: 10),
                        _buildFuturisticQrField(
                          controller: _camQrCtrl,
                          label: 'qr camera'.tr(),
                          color: _orange,
                          icon: Icons.videocam_rounded,
                          validator: null,
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Étape 2 — QR Revendeur ────────────────
                      _buildStepTitle(1, 'qr revendeur'.tr(), 'scan revendeur desc'.tr(), _neonPurple),
                      const SizedBox(height: 12),
                      _buildFuturisticQrField(
                        controller: _vendorQrCtrl,
                        label: 'qr revendeur label'.tr(),
                        color: _neonPurple,
                        icon: Icons.qr_code_2_rounded,
                        validator: (v) => v == null || v.isEmpty ? 'requis'.tr() : null,
                      ),
                      const SizedBox(height: 32),

                      // ── Étape 3 — Compte ──────────────────────
                      _buildStepTitle(2, 'creer compte'.tr(), 'compte desc'.tr(), _neonPurple),
                      const SizedBox(height: 12),

                      _buildFuturisticField(
                        controller: _cinCtrl,
                        label: 'numero cin'.tr(),
                        icon: Icons.credit_card_outlined,
                        validator: (v) => v == null || v.trim().isEmpty ? 'cin requis'.tr() : null,
                      ),
                      const SizedBox(height: 12),
                      _buildFuturisticField(
                        controller: _emailCtrl,
                        label: 'email'.tr(),
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') ? 'email invalide'.tr() : null,
                      ),
                      const SizedBox(height: 12),
                      _buildFuturisticField(
                        controller: _passCtrl,
                        label: 'mot de passe'.tr(),
                        icon: Icons.lock_outline_rounded,
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
                        validator: (v) => v == null || v.length < 4 ? 'mdp court'.tr() : null,
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildError(_error!),
                      ],

                      const SizedBox(height: 32),

                      // Bouton principal néon
                      _buildNeonButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS STYLISÉS (style LoginPage)
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: _neonPurple.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'inscription'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Tu peux remettre ton image de fond ici si tu veux
        // Image.asset('images/bg cars.jpg', fit: BoxFit.cover),
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
          child: const Icon(
            Icons.person_add_rounded,
            color: Colors.white,
            size: 32,
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
          'inscription titre'.tr().toUpperCase(),
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

  Widget _buildStepTitle(int? step, String title, String sub, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${'etape'.tr()} ${step + 1}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (step != null) const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildCamToggle() {
    return GestureDetector(
      onTap: () => setState(() => _hasCam = !_hasCam),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _hasCam
              ? _orange.withOpacity(0.1)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasCam
                ? _orange.withOpacity(0.5)
                : _neonPurple.withOpacity(0.2),
            width: 1.5,
          ),
          gradient: _hasCam
              ? null
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.videocam_rounded,
              color: _hasCam ? _orange : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _hasCam
                    ? 'camera activee'.tr()
                    : 'ajouter camera'.tr(),
                style: TextStyle(
                  color: _hasCam ? _orange : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _hasCam
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                key: ValueKey(_hasCam),
                color: _hasCam ? _orange : Colors.white24,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Champ QR avec style futuriste ───────────────────────────
  Widget _buildFuturisticQrField({
    required TextEditingController controller,
    required String label,
    required Color color,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildFuturisticField(
            controller: controller,
            label: label,
            icon: icon,
            color: color,
            validator: validator,
          ),
        ),
        const SizedBox(width: 10),
        // Bouton scanner avec glow
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3 + _glowController.value * 0.3),
                    blurRadius: 15 + _glowController.value * 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _scanQr(controller),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Champ texte futuriste (style LoginPage) ─────────────────
  Widget _buildFuturisticField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? color,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final fieldColor = color ?? _neonPurple;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: fieldColor.withOpacity(0.05 + _glowController.value * 0.05),
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
            color: fieldColor.withOpacity(0.2),
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
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              color: fieldColor.withOpacity(0.6),
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
              borderSide: BorderSide(
                color: fieldColor.withOpacity(0.8),
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

  // ── Bouton principal néon ───────────────────────────────────
  Widget _buildNeonButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_neonPurple, _neonPurpleDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _neonPurpleLight.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _submit,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.2),
            child: Center(
              child: _loading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'continuer'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page scanner QR caméra (inchangée) ────────────────────────────────────────

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('scanner qr'.tr(), style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7226FF), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'centrer qr'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
