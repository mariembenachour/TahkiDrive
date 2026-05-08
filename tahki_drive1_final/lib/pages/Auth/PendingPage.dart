import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../Main_screen.dart';
import 'LoginPage.dart';

class PendingPage extends StatefulWidget {
  const PendingPage({super.key});

  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Timer? _pollingTimer;
  bool _checking = false;

  static const _purple = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Polling toutes les 10 secondes
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
    _check(); // premier check immédiat
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
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0015),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animation pulsante
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _purple.withOpacity(0.4),
                        _darkPurple.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [_purple, _darkPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: Colors.white, size: 48),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              const Text('Compte en attente\nde validation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.3)),

              const SizedBox(height: 16),

              Text(
                'Votre dossier a été soumis avec succès.\nUn administrateur va valider votre compte.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 15,
                    height: 1.6),
              ),

              const SizedBox(height: 40),

              // Indicateur de statut
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08))),
                child: Column(
                  children: [
                    _statusRow(Icons.check_circle_rounded,
                        'Compte créé', true),
                    const SizedBox(height: 12),
                    _statusRow(Icons.check_circle_rounded,
                        'Profil soumis', true),
                    const SizedBox(height: 12),
                    _statusRow(Icons.radio_button_unchecked_rounded,
                        'Validation en cours...', false),
                    const SizedBox(height: 12),
                    _statusRow(Icons.radio_button_unchecked_rounded,
                        'Accès accordé', false),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Bouton vérifier manuellement
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _checking ? null : _check,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _purple,
                    side: const BorderSide(color: _purple, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _checking
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _purple))
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_checking ? 'Vérification...'
                      : 'Vérifier maintenant'),
                ),
              ),

              const SizedBox(height: 16),

              // Logout
              TextButton(
                onPressed: () async {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false);
                },
                child: Text('Se déconnecter',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 14)),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, bool done) {
    return Row(children: [
      Icon(icon, color: done ? _purple : Colors.white24, size: 20),
      const SizedBox(width: 12),
      Text(label,
          style: TextStyle(
              color: done ? Colors.white : Colors.white38,
              fontSize: 14,
              fontWeight: done ? FontWeight.w600 : FontWeight.normal)),
      if (!done && label.contains('cours')) ...[
        const SizedBox(width: 8),
        SizedBox(width: 12, height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white24)),
      ]
    ]);
  }
}
