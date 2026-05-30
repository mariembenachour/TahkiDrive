import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tahki_drive1/services/language_service.dart';
import '../../services/auth_service.dart';
import 'PendingPage.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class SetupProfilePage extends StatefulWidget {
  final String setupToken; // ← REÇOIT directement
  final String cin;

  SetupProfilePage({
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
        MaterialPageRoute(builder: (_) => PendingPage(
          cin: widget.cin,
          setupToken: widget.setupToken,
        )),
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
                SizedBox(height: 12.h),

                // Bandeau info
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                      color: _purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                          color: _purple.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: _purple, size: 20),
                    SizedBox(width: 10.w),
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

                SizedBox(height: 28.h),

                Row(children: [
                  Expanded(child: _field(
                      ctrl: _firstNameCtrl,
                      label: 'prenom'.tr(),
                      icon: Icons.person_outline,
                      validator: (v) =>
                      v!.isEmpty ? 'requis'.tr() : null)),
                  SizedBox(width: 12.w),
                  Expanded(child: _field(
                      ctrl: _lastNameCtrl,
                      label: 'nom'.tr(),
                      icon: Icons.person_outline,
                      validator: (v) =>
                      v!.isEmpty ? 'requis'.tr() : null)),
                ]),

                SizedBox(height: 14.h),

                _field(
                  ctrl: _telCtrl,
                  label: 'telephone'.tr(),
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.length < 8
                      ? 'telephone invalide'.tr()
                      : null,
                ),

                SizedBox(height: 14.h),

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
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 8.w),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13))),
                    ]),
                  ),
                ],

                SizedBox(height: 32.h),

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
                              BorderRadius.circular(16.r))),
                      child: _loading
                          ? SizedBox(
                          width: 24.w, height: 24.h,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                          : Text('soumettre profil'.tr(),
                          style:  TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
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
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
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
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide:
            const BorderSide(color: _purple, width: 1.5)),
      );
}
