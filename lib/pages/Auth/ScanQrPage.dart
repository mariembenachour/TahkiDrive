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
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


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

      print('>>> RESULT: $result');

      // ── Gérer les erreurs backend ──
      final status = result['status']?.toString() ?? '';
      if (status == 'already_linked') {
        setState(() => _error = 'Ce véhicule est déjà associé à un compte');
        return;
      }
      if (status == 'error') {
        setState(() => _error = result['message']?.toString() ?? 'Erreur inconnue');
        return;
      }

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
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
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
                      SizedBox(height: 30.h),

                      // Logo animé
                      Center(child: _buildLogo3D()),
                      SizedBox(height: 16.h),
                      Center(child: _buildTitle()),
                      SizedBox(height: 4.h),
                      Center(child: _buildSubtitle()),
                      SizedBox(height: 40.h),

                      // ── Étape 1 — Boitier GPS ─────────────────
                      _buildStepTitle(0, 'boitier gps'.tr(), 'scan boitier desc'.tr(), _blue),
                      SizedBox(height: 12.h),
                      _buildFuturisticQrField(
                        controller: _deviceQrCtrl,
                        label: 'qr boitier'.tr(),
                        color: _blue,
                        icon: Icons.router_rounded,
                        validator: (v) => v == null || v.isEmpty ? 'requis'.tr() : null,
                      ),
                      SizedBox(height: 12.h),

                      // Toggle caméra
                      _buildCamToggle(),

                      // Champ caméra (si activé)
                      if (_hasCam) ...[
                        SizedBox(height: 16.h),
                        _buildStepTitle(null, 'camera'.tr(), 'scan camera desc'.tr(), _orange),
                        SizedBox(height: 10.h),
                        _buildFuturisticQrField(
                          controller: _camQrCtrl,
                          label: 'qr camera'.tr(),
                          color: _orange,
                          icon: Icons.videocam_rounded,
                          validator: null,
                        ),
                      ],

                      SizedBox(height: 32.h),

                      // ── Étape 2 — QR Revendeur ────────────────
                      _buildStepTitle(1, 'qr revendeur'.tr(), 'scan revendeur desc'.tr(), _neonPurple),
                      SizedBox(height: 12.h),
                      _buildFuturisticQrField(
                        controller: _vendorQrCtrl,
                        label: 'qr revendeur label'.tr(),
                        color: _neonPurple,
                        icon: Icons.qr_code_2_rounded,
                        validator: (v) => v == null || v.isEmpty ? 'requis'.tr() : null,
                      ),
                      SizedBox(height: 32.h),

                      // ── Étape 3 — Compte ──────────────────────
                      _buildStepTitle(2, 'creer compte'.tr(), 'compte desc'.tr(), _neonPurple),
                      SizedBox(height: 12.h),

                      _buildFuturisticField(
                        controller: _cinCtrl,
                        label: 'numero cin'.tr(),
                        icon: Icons.credit_card_outlined,
                        validator: (v) => v == null || v.trim().isEmpty ? 'cin requis'.tr() : null,
                      ),
                      SizedBox(height: 12.h),
                      _buildFuturisticField(
                        controller: _emailCtrl,
                        label: 'email'.tr(),
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') ? 'email invalide'.tr() : null,
                      ),
                      SizedBox(height: 12.h),
                      _buildFuturisticField(
                        controller: _passCtrl,
                        label: 'mot de passe'.tr(),
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: _obscure
                                  ? Colors.transparent
                                  : _neonPurple.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: _obscure ? Colors.white30 : _neonPurpleLight,
                              size: 16.w,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 4 ? 'mdp court'.tr() : null,
                      ),

                      if (_error != null) ...[
                        SizedBox(height: 16.h),
                        _buildError(_error!),
                      ],

                      SizedBox(height: 32.h),

                      // Bouton principal néon
                      _buildNeonButton(),
                      SizedBox(height: 40.h),
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
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: _neonPurple.withOpacity(0.3),
                width: 1.w,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18.w,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Text(
          'inscription'.tr(),
          style:  TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
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
          width: 70.w,
          height: 70.h,
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
          child:  Icon(
            Icons.person_add_rounded,
            color: Colors.white,
            size: 32.w,
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
      child:  Text(
        'TAHKIDRIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.w,
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: _neonPurple.withOpacity(0.4),
            width: 1.w,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          'inscription titre'.tr().toUpperCase(),
          style:  TextStyle(
            color: Colors.white70,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.w,
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
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.w,
              ),
            ),
            child: Text(
              '${'etape'.tr()} ${step + 1}',
              style: TextStyle(
                color: color,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (step != null) SizedBox(height: 8.h),
        Text(
          title,
          style:  TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13.sp,
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _hasCam
              ? _orange.withOpacity(0.1)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14.r),
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
              size: 20.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _hasCam
                    ? 'camera activee'.tr()
                    : 'ajouter camera'.tr(),
                style: TextStyle(
                  color: _hasCam ? _orange : Colors.white54,
                  fontSize: 13.sp,
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
                size: 22.w,
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
        SizedBox(width: 10.w),
        // Bouton scanner avec glow
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
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
              width: 54.w,
              height: 54.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.w,
                ),
              ),
              child:  Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 26.w,
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
            borderRadius: BorderRadius.circular(14.r),
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
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: fieldColor.withOpacity(0.2),
            width: 1.w,
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
          style:  TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13.sp,
            ),
            prefixIcon: Icon(
              icon,
              color: fieldColor.withOpacity(0.6),
              size: 18.w,
            ),
            suffixIcon: suffix,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: fieldColor.withOpacity(0.8),
                width: 2.w,
              ),
            ),
            errorStyle:  TextStyle(
              color: Colors.redAccent,
              fontSize: 10.sp,
              height: 0.5,
            ),
            contentPadding: EdgeInsets.symmetric(
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
            borderRadius: BorderRadius.circular(16.r),
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
        height: 54.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_neonPurple, _neonPurpleDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _neonPurpleLight.withOpacity(0.5),
            width: 1.w,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _submit,
            borderRadius: BorderRadius.circular(16.r),
            splashColor: Colors.white.withOpacity(0.2),
            child: Center(
              child: _loading
                  ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.w,
                ),
              )
                  : Text(
                'continuer'.tr(),
                style:  TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5.w,
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
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1.w,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              msg,
              style:  TextStyle(
                color: Colors.redAccent,
                fontSize: 13.sp,
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
              width: 250.w,
              height: 250.h,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7226FF), width: 2),
                borderRadius: BorderRadius.circular(16.r),
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
