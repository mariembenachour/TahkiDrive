import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tahki_drive1/services/language_service.dart';
import '../../services/auth_service.dart';
import 'PendingPage.dart';

class SetupProfilePage extends StatefulWidget {
  final String setupToken; // ← REÇOIT directement
  final String cin;

  const SetupProfilePage({
    super.key,
    required this.setupToken,
    required this.cin,
  });

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _formKey      = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _telCtrl       = TextEditingController();
  String _language = 'fr';
  bool _loading    = false;
  String? _error;

  static const _purple     = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);
  final _languages = {
    'fr': '🇫🇷 Français',
    'ar': '🇹🇳 Arabe',
    'en': '🇬🇧 English'
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      // ← On passe token et cin directement, sans SharedPreferences
      await AuthService.setupProfile(
        setupToken: widget.setupToken,
        cin:        widget.cin,
        firstName:  _firstNameCtrl.text.trim(),
        lastName:   _lastNameCtrl.text.trim(),
        telephone:  _telCtrl.text.trim(),
        language:   _language,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingPage()),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0015),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('setup profil'.tr(),
            style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Bandeau info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _purple.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: _purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'compte en attente'.tr(),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 28),

                Row(children: [
                  Expanded(child: _field(
                      ctrl: _firstNameCtrl,
                      label: 'prenom'.tr(),
                      icon: Icons.person_outline,
                      validator: (v) =>
                      v!.isEmpty ? 'requis'.tr() : null)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(
                      ctrl: _lastNameCtrl,
                      label: 'nom'.tr(),
                      icon: Icons.person_outline,
                      validator: (v) =>
                      v!.isEmpty ? 'requis'.tr() : null)),
                ]),

                const SizedBox(height: 14),

                _field(
                  ctrl: _telCtrl,
                  label: 'telephone'.tr(),
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.length < 8
                      ? 'telephone invalide'.tr()
                      : null,
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _language,
                  onChanged: (v) {
                    setState(() => _language = v!);
                    LanguageService.changeLanguage(context, v!); // ← ajoute ça
                  },
                  dropdownColor: const Color(0xFF1A0035),
                  style: const TextStyle(color: Colors.white),
                  decoration: _dropDeco(
                      'Langue', Icons.language_outlined),
                  items: _languages.entries
                      .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                      .toList(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13))),
                    ]),
                  ),
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
                      boxShadow: [
                        BoxShadow(
                            color: _purple.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(16))),
                      child: _loading
                          ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                          : Text('soumettre profil'.tr(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator ?? (v) => v!.isEmpty ? 'requis'.tr() : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: _purple, width: 1.5)),
        errorStyle:
        const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  InputDecoration _dropDeco(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: _purple, width: 1.5)),
      );
}
