import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tahki_drive1/pages/Auth/SetupProfilePage.dart';

class VerifyEmailPage extends StatefulWidget {
  final String setupToken; // ← REÇOIT le token
  final String cin;        // ← REÇOIT le cin

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

  static const _purple     = Color(0xFF7226FF);
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
        const SnackBar(
          content: Text('Email vérifié ✓'),
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
          setupToken: widget.setupToken, // ← TRANSMET directement
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
          const SnackBar(content: Text('Mail de confirmation renvoyé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
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
        title: const Text('Vérification email',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110, height: 110,
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
              const SizedBox(height: 32),
              const Text('Vérifiez votre boîte mail',
                  style: TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'Un lien de confirmation a été envoyé à votre adresse email. '
                    'Cliquez dessus pour continuer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.55),
                    fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 40),

              if (!_isEmailVerified) ...[
                const CircularProgressIndicator(
                    color: _purple, strokeWidth: 2),
                const SizedBox(height: 16),
                Text('En attente de vérification...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _canResend ? _resendVerificationEmail : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: BorderSide(
                          color: _canResend ? _purple : Colors.white24,
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_canResend
                        ? 'Renvoyer le mail'
                        : 'Patientez 30 secondes...'),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 22),
                    SizedBox(width: 10),
                    Text('Email vérifié avec succès !',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_purple, _darkPurple],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: _goToSetupProfile,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: const Text('Continuer',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16,
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
