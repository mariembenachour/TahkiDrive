import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tahki_drive1/pages/Auth/SetupProfilePage.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça

class VerifyEmailPage extends StatefulWidget {
  final String setupToken;
  final String cin;

  const VerifyEmailPage({
    super.key,
    required this.setupToken,
    required this.cin,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isEmailVerified = false;
  bool _canResend = true;
  Timer? _timer;

  static const _purple = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);

  @override
  void initState() {
    super.initState();
    _isEmailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!_isEmailVerified) {
      _timer = Timer.periodic(
        const Duration(seconds: 4),
            (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final verified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (verified && mounted) {
      _timer?.cancel();
      setState(() => _isEmailVerified = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('email verifie'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      _goToSetupProfile();
    }
  }

  void _goToSetupProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SetupProfilePage(
          setupToken: widget.setupToken,
          cin: widget.cin,
        ),
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend) return;
    setState(() => _canResend = false);

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('mail renvoye'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'erreur'.tr()} : ${e.toString()}')),
        );
      }
    }

    await Future.delayed(const Duration(seconds: 30));
    if (mounted) setState(() => _canResend = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0015),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('verification email'.tr(),
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110.w, height: 110.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_purple.withOpacity(0.3), _darkPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.mark_email_unread_rounded,
                    color: Colors.white, size: 54),
              ),
              SizedBox(height: 32.h),
              Text('verifiez votre boite'.tr(),
                  textAlign: TextAlign.center,
                  style:  TextStyle(color: Colors.white,
                      fontSize: 22.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 12.h),
              Text(
                'lien confirmation envoye'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.55),
                    fontSize: 14.sp, height: 1.6),
              ),
              SizedBox(height: 40.h),

              if (!_isEmailVerified) ...[
                const CircularProgressIndicator(
                    color: _purple, strokeWidth: 2),
                SizedBox(height: 16.h),
                Text('attente verification'.tr(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13)),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: OutlinedButton.icon(
                    onPressed: _canResend ? _resendVerificationEmail : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: BorderSide(
                          color: _canResend ? _purple : Colors.white24,
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_canResend
                        ? 'renvoyer mail'.tr()
                        : 'patientez 30s'.tr()),
                  ),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 22),
                    SizedBox(width: 10.w),
                    Text('email verifie succes'.tr(),
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_purple, _darkPurple],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: ElevatedButton(
                      onPressed: _goToSetupProfile,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r))),
                      child: Text('continuer'.tr(),
                          style:  TextStyle(color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
