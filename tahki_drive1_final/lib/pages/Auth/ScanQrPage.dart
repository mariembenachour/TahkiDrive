
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tahki_drive1/pages/Auth/VerifyEmailPage.dart';
import 'SetupProfilePage.dart';
import '../../services/auth_service.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  // Controllers QR — device obligatoire, cam optionnel, vendor obligatoire
  final _deviceQrCtrl = TextEditingController();
  final _camQrCtrl    = TextEditingController(); // optionnel
  final _vendorQrCtrl = TextEditingController();
  final _cinCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool  _loading = false;
  bool  _obscure = true;
  bool  _hasCam  = false; // toggle pour afficher le champ caméra
  String? _error;

  static const _purple     = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);
  static const _orange     = Color(0xFFFF9800);
  static const _blue       = Color(0xFF2196F3);

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

      // Cam optionnelle
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

  // Lance le scanner caméra natif
  Future<void> _scanQr(TextEditingController ctrl) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (result != null && mounted) {
      setState(() => ctrl.text = result);
    }
  }

  @override
  void dispose() {
    _deviceQrCtrl.dispose();
    _camQrCtrl.dispose();
    _vendorQrCtrl.dispose();
    _cinCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0015),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Inscription', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Étape 1 — Boitier GPS (obligatoire) ──────────────────
                _buildStepTitle(0, 'Boitier GPS', 'Scannez le QR du boitier GPS', _blue),
                const SizedBox(height: 12),
                _buildQrField(
                  controller: _deviceQrCtrl,
                  label: 'QR Boitier GPS',
                  color: _blue,
                  icon: Icons.router_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),

                // Toggle caméra
                GestureDetector(
                  onTap: () => setState(() => _hasCam = !_hasCam),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: _hasCam ? _orange.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _hasCam ? _orange.withOpacity(0.4) : Colors.white.withOpacity(0.1))),
                    child: Row(children: [
                      Icon(Icons.videocam_rounded,
                          color: _hasCam ? _orange : Colors.white38, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hasCam ? 'Ce véhicule a aussi une caméra' : 'Ajouter une caméra (optionnel)',
                          style: TextStyle(
                              color: _hasCam ? _orange : Colors.white54,
                              fontSize: 13),
                        ),
                      ),
                      Icon(_hasCam ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          color: _hasCam ? _orange : Colors.white24, size: 20),
                    ]),
                  ),
                ),

                // Champ caméra (si activé)
                if (_hasCam) ...[
                  const SizedBox(height: 12),
                  _buildStepTitle(null, 'Caméra', 'Scannez le QR de la caméra', _orange),
                  const SizedBox(height: 10),
                  _buildQrField(
                    controller: _camQrCtrl,
                    label: 'QR Caméra',
                    color: _orange,
                    icon: Icons.videocam_rounded,
                    validator: null, // optionnel
                  ),
                ],

                const SizedBox(height: 24),

                // ── Étape 2 — QR Revendeur ────────────────────────────────
                _buildStepTitle(1, 'QR Revendeur', 'Scannez le QR fourni par votre revendeur', _purple),
                const SizedBox(height: 12),
                _buildQrField(
                  controller: _vendorQrCtrl,
                  label: 'QR Revendeur',
                  color: _purple,
                  icon: Icons.qr_code_2_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 24),

                // ── Étape 3 — Compte ──────────────────────────────────────
                _buildStepTitle(2, 'Créer votre compte', 'Ces identifiants serviront à vous connecter', _purple),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _cinCtrl,
                  label: 'Numéro CIN',
                  icon: Icons.credit_card_outlined,
                  validator: (v) => v == null || v.trim().isEmpty ? 'CIN requis' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _passCtrl,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white38),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => v == null || v.length < 4 ? 'Minimum 4 caractères' : null,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildError(_error!),
                ],

                const SizedBox(height: 32),

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
                      boxShadow: [BoxShadow(
                          color: _purple.withOpacity(0.4),
                          blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Continuer',
                          style: TextStyle(color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
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
                borderRadius: BorderRadius.circular(8)),
            child: Text('Étape ${step + 1}',
                style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        if (step != null) const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(sub,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
      ],
    );
  }

  Widget _buildQrField({
    required TextEditingController controller,
    required String label,
    required Color color,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            validator: validator,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
              prefixIcon: Icon(icon, color: color.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: color, width: 1.5)),
              errorStyle: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Bouton scanner caméra
        GestureDetector(
          onTap: () => _scanQr(controller),
          child: Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white38),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _purple, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
      ]),
    );
  }
}

// ── Page scanner QR caméra ────────────────────────────────────────────────────

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
        title: const Text('Scanner le QR', style: TextStyle(color: Colors.white)),
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
          // Overlay viseur
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF7226FF), width: 2),
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: const Text(
              'Centrez le QR code dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
