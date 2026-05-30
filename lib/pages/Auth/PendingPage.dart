import 'dart:async';
import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/auth_service.dart';
import '../Main_screen.dart';
import 'LoginPage.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class PendingPage extends StatefulWidget {
  final String cin;
  final String setupToken;
  const PendingPage({
    super.key,
    required this.cin,
    required this.setupToken,
  });
  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _entryController;
  Timer? _pollingTimer;
  bool _checking = false;

  // Couleurs Néon (identiques LoginPage)
  static const _neonPurple = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPurpleDark = Color(0xFF4A148C);
  static const _neonPink = Color(0xFFFF00E5);
  static const _darkBg = Color(0xFF050510);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _floatController = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )
      ..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _pollingTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _check());
    _check();
    _entryController.forward();
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final activated = await AuthService.checkActivationStatus();
      if (activated && mounted) {
        _pollingTimer?.cancel();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _entryController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
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
                        curve: const Interval(
                            0.0, 0.7, curve: Curves.easeOutCubic),
                      )),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Spacer(flex: 2),

                    // Logo 3D animé
                    _buildLogo3D(),
                    SizedBox(height: 36.h),

                    // Titre
                    _buildTitle(),
                    SizedBox(height: 16.h),

                    // Sous-titre
                    _buildSubtitle(),
                    SizedBox(height: 40.h),

                    // Carte glassmorphism statut
                    _buildStatusCard(),
                    SizedBox(height: 32.h),

                    // Bouton néon vérifier
                    _buildNeonButton(),
                    SizedBox(height: 16.h),

                    Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS STYLISÉS
  // ════════════════════════════════════════════════════════════

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
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
      animation: _pulseCtrl,
      builder: (_, child) {
        final scale = 1 + _pulseAnim.value * 0.05;
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (_, child) {
          final y = _floatController.value * -6;
          return Transform.translate(offset: Offset(0, y), child: child);
        },
        child: Container(
          width: 120.w,
          height: 120.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _neonPurple.withOpacity(0.4),
                _neonPurpleDark.withOpacity(0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_neonPurple, _neonPurpleDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonPurple.withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child:  Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 48.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(
            colors: [
              _neonPurpleLight,
              _neonPurple,
              Colors.white.withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
      child: Text(
        'compte attente'.tr(),
        textAlign: TextAlign.center,
        style:  TextStyle(
          color: Colors.white,
          fontSize: 26.sp,
          fontWeight: FontWeight.w800,
          height: 1.3,
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
        padding:  EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: _neonPurple.withOpacity(0.4),
            width: 1.w,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          'dossier soumis'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14.sp,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withOpacity(
                  0.1 + _glowController.value * 0.1,
                ),
                blurRadius: 20 + _glowController.value * 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: _neonPurpleLight.withOpacity(0.3),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _neonPurple.withOpacity(0.1),
              _neonPurpleDark.withOpacity(0.03),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          children: [
            _statusRow(Icons.check_circle_rounded, 'compte cree'.tr(), true),
            SizedBox(height: 14.h),
            _statusRow(Icons.check_circle_rounded, 'profil soumis'.tr(), true),
            SizedBox(height: 14.h),
            _statusRow(
                Icons.radio_button_unchecked_rounded, 'validation cours'.tr(),
                false, loading: true),
            SizedBox(height: 14.h),
            _statusRow(
                Icons.radio_button_unchecked_rounded, 'acces accorde'.tr(),
                false),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, bool done,
      {bool loading = false}) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? _neonPurple.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: done
                  ? _neonPurple.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: 1.w,
            ),
          ),
          child: Icon(
            icon,
            color: done ? _neonPurpleLight : Colors.white24,
            size: 16.w,
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done ? Colors.white : Colors.white38,
              fontSize: 14.sp,
              fontWeight: done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (loading)
          SizedBox(
            width: 14.w,
            height: 14.h,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: _neonPurpleLight.withOpacity(0.5),
            ),
          ),
      ],
    );
  }

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
                  0.3 + _glowController.value * 0.3,
                ),
                blurRadius: 20 + _glowController.value * 15,
                spreadRadius: 2,
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
          gradient: LinearGradient(
            colors: [
              _neonPurple,
              _neonPurpleDark,
            ],
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
            onTap: _checking ? null : _check,
            borderRadius: BorderRadius.circular(16.r),
            splashColor: Colors.white.withOpacity(0.2),
            child: Center(
              child: _checking
                  ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.w,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'verifier maintenant'.tr(),
                    style:  TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


}
