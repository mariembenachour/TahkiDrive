import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tahki_drive1/pages/DashboardCar/Alert.dart';
import 'package:tahki_drive1/pages/DashboardCar/AlertThresholdsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/EventHistorique.dart';
import 'package:tahki_drive1/pages/DashboardCar/NotificationPreferencesPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/notification_mode_page.dart';
import 'package:tahki_drive1/pages/DashboardCar/reports_history_page.dart';
import 'package:tahki_drive1/services/profile_service.dart';
import 'package:tahki_drive1/services/auth_service.dart';
import 'package:tahki_drive1/services/theme_service.dart';
import 'Sav.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const ProfilePage({super.key, this.onBackToDashboard});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Map<String, dynamic>? _driver;
  bool _loading = true;
  String _cin = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _controller.forward();
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    try {
      final data = await ProfileService.fetchMyProfile();
      final cin = await AuthService.getCin();
      setState(() {
        _driver = data;
        _cin = cin ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.reset();
    _controller.forward();
  }

  Widget _luxuryAnimatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
              .animate(animation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOutCubic))
                .animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDark(context);
    final bgColor = isDark ? const Color(0xFF0A0015) : const Color(0xFFF4F0FF);
    final titleColor = isDark ? Colors.white : const Color(0xFF160078);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              _luxuryAnimatedEntry(
                delay: 0.0,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
                        onPressed: () => widget.onBackToDashboard?.call(),
                      ),
                      Text('profil'.tr(),
                          style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: titleColor)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  child: Column(
                    children: [
                      _luxuryAnimatedEntry(
                          delay: 0.1, child: _buildProfileCard()),
                      SizedBox(height: 25.h),
                      _luxuryAnimatedEntry(
                        delay: 0.2,
                        child: _buildMenuContainer([
                          _buildMenuItem(
                            context,
                            Icons.warning_amber_rounded,
                            "Historique des pannes",
                            onTap: () =>
                                _navigateTo(context, AlertsPage(cin: _cin)),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            context,
                            Icons.event_note_rounded,
                            "Historique des événements",
                            onTap: () => _navigateTo(
                                context, const EventHistoriquePage()),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            context,
                            Icons.tune_rounded,
                            "Seuils d'alertes",
                            onTap: () => _navigateTo(
                                context, const AlertThresholdsPage()),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            context,
                            Icons.tune_rounded,
                            "Mode de notification",
                            onTap: () => _navigateTo(
                                context, const NotificationModePage()),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            context,
                            Icons.notifications_none_rounded,
                            "Préférences notifications",
                            onTap: () => _navigateTo(
                                context, const NotificationPreferencesPage()),
                          ),
                          _buildDivider(),
                          _buildThemeSwitch(context),
                        ]),
                      ),
                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSwitch(BuildContext context) {
    final ts = context.watch<ThemeService>();
    final isDark = ts.isDark(context);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: const Color(0xFF7226FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: const Color(0xFF7226FF),
                size: 22.w,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                'Thème',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF160078),
                  fontSize: 15.sp,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                ts.setMode(isDark ? ThemeMode.light : ThemeMode.dark);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                width: 100.w,
                height: 44.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22.r),
                  gradient: isDark
                      ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                  )
                      : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF87CEEB),
                      Color(0xFFB0E0E6),
                      Color(0xFFE0F6FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.4)
                          : Colors.blue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isDark) ...[
                      Positioned(left: 12, top: 8, child: _star(3)),
                      Positioned(left: 28, top: 14, child: _star(2)),
                      Positioned(left: 18, bottom: 10, child: _star(2.5)),
                      Positioned(left: 35, top: 8, child: _star(2)),
                    ],
                    if (!isDark) ...[
                      Positioned(
                        right: 8,
                        top: 6,
                        child: _cloud(18, Colors.white.withOpacity(0.6)),
                      ),
                      Positioned(
                        right: 20,
                        bottom: 8,
                        child: _cloud(14, Colors.white.withOpacity(0.4)),
                      ),
                    ],
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutBack,
                      left: isDark ? 54 : 6,
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFFD4D4D8)
                              : const Color(0xFFFFD700),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(child: isDark ? _moon() : _sun()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _star(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.4),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _cloud(double size, Color color) {
    return Container(
      width: size * 1.5,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
    );
  }

  Widget _sun() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(8, (i) {
          final angle = i * 45 * 3.14159 / 180;
          return Transform.translate(
            offset: Offset(10 * cos(angle), 10 * sin(angle)),
            child: Container(
              width: 3.w,
              height: 3.h,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange,
              ),
            ),
          );
        }),
        Container(
          width: 20.w,
          height: 20.h,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _moon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 22.w,
          height: 22.h,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8E8E8),
          ),
        ),
        Positioned(
          left: 6,
          top: 5,
          child: Container(
            width: 5.w,
            height: 5.h,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.grey[400]),
          ),
        ),
        Positioned(
          right: 5,
          bottom: 6,
          child: Container(
            width: 4.w,
            height: 4.h,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.grey[400]),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            width: 3.w,
            height: 3.h,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final isDark = context.watch<ThemeService>().isDark(context);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF160078);

    if (_loading) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF7226FF))),
      );
    }

    return GestureDetector(
      onTap: () => _navigateTo(
        context,
        DriverDetailScreen(
          driver: _driver ?? {},
          onUpdated: (updated) => setState(() => _driver = updated),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundColor: Color(0xFF7226FF),
              child: Icon(Icons.person, color: Colors.white, size: 40),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_driver?['first_name'] ?? ''} ${_driver?['last_name'] ?? ''}'
                        .trim(),
                    style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: titleColor),
                  ),
                  Text(
                    _driver?['email'] ?? '',
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_note_rounded, color: Color(0xFF7226FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> children) {
    final isDark = context.watch<ThemeService>().isDark(context);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(30.r),
          child: Column(children: children)),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title,
      {String? trailingText, VoidCallback? onTap}) {
    final isDark = context.watch<ThemeService>().isDark(context);
    final titleColor = isDark ? Colors.white : const Color(0xFF160078);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        splashColor: const Color(0xFF7226FF).withOpacity(0.1),
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
              color: const Color(0xFF7226FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r)),
          child: Icon(icon, color: const Color(0xFF7226FF), size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                color: titleColor,
                fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(trailingText,
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey[500],
                      fontSize: 13)),
            SizedBox(width: 5.w),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white24 : Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = context.watch<ThemeService>().isDark(context);
    return Divider(
        height: 1.h,
        indent: 70,
        endIndent: 20,
        color: isDark ? Colors.white10 : Colors.grey[100]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DRIVER DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class DriverDetailScreen extends StatefulWidget {
  final Map<String, dynamic> driver;
  final void Function(Map<String, dynamic>)? onUpdated;

  const DriverDetailScreen({super.key, required this.driver, this.onUpdated});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  late Map<String, dynamic> _driver;
  bool _saving = false;
  bool _obscurePassword = true;

  static const _purple = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);

  @override
  void initState() {
    super.initState();
    _driver = Map<String, dynamic>.from(widget.driver);
  }

  Future<void> _editPassword() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A0035),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r)),
          title: const Text('Modifier le mot de passe',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: TextField(
            controller: ctrl,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              labelStyle:
              TextStyle(color: Colors.white.withOpacity(0.5)),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: _purple),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler',
                    style:
                    TextStyle(color: Colors.white.withOpacity(0.5)))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Enregistrer',
                    style: TextStyle(color: _purple))),
          ],
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _saveField('password', result);
      setState(() => _driver['password decrypted'] = result);
    }
  }

  Future<void> _editTextField({
    required String label,
    required String fieldKey,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final ctrl =
    TextEditingController(text: _driver[fieldKey]?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0035),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r)),
        title: Text('Modifier $label',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
            TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style:
                  TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Enregistrer',
                  style: TextStyle(color: _purple))),
        ],
      ),
    );
    if (result != null && result != _driver[fieldKey]) {
      await _saveField(fieldKey, result);
    }
  }

  Future<void> _saveField(String key, dynamic value) async {
    setState(() {
      _driver[key] = value;
      _saving = true;
    });

    final Map<String, dynamic> payload = {
      'first_name': _driver['first_name'],
      'last_name': _driver['last_name'],
      'telephone': _driver['telephone'],
      'cin': _driver['cin'],
      'email': _driver['email'],
      'driver_authorized': _driver['driver_authorized'],
      'driver_medically': _driver['driver_medically'],
      'driving_training': _driver['driving_training'],
      'driving_safe': _driver['driving_safe'],
    };

    if (key == 'password') payload['password'] = value;

    final ok = await ProfileService.updateProfile(payload);

    setState(() => _saving = false);

    if (ok) {
      widget.onUpdated?.call(_driver);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Profil mis à jour'),
              backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDark(context);
    final bgColor =
    isDark ? const Color(0xFF0A0015) : const Color(0xFFF4F0FF);
    final titleColor = isDark ? Colors.white : const Color(0xFF160078);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        title: Text('Détails du Profil',
            style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: titleColor)),
        actions: [
          if (_saving)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                  child: SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.w, color: _purple))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
                cardColor: cardColor,
                children: [
                  Row(children: [
                    const CircleAvatar(
                        radius: 35,
                        backgroundColor: _purple,
                        child:
                        Icon(Icons.person, color: Colors.white, size: 40)),
                    SizedBox(width: 15.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_driver['first_name'] ?? ''} ${_driver['last_name'] ?? ''}'
                                  .trim(),
                              style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor)),
                          Text(_driver['email'] ?? '',
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey[600])),
                        ],
                      ),
                    ),
                  ]),
                ]),

            SizedBox(height: 20.h),

            _sectionTitle('Informations personnelles', titleColor),
            SizedBox(height: 10.h),
            _card(
                cardColor: cardColor,
                children: [
                  _editableRow(
                      icon: Icons.person_outline,
                      label: 'Prénom',
                      value: _driver['first_name'],
                      onEdit: () => _editTextField(
                          label: 'Prénom', fieldKey: 'first_name'),
                      titleColor: titleColor),
                  _divider(isDark),
                  _editableRow(
                      icon: Icons.person_outline,
                      label: 'Nom',
                      value: _driver['last_name'],
                      onEdit: () => _editTextField(
                          label: 'Nom', fieldKey: 'last_name'),
                      titleColor: titleColor),
                  _divider(isDark),
                  _editableRow(
                      icon: Icons.phone_outlined,
                      label: 'Téléphone',
                      value: _driver['telephone'],
                      onEdit: () => _editTextField(
                          label: 'Téléphone',
                          fieldKey: 'telephone',
                          keyboardType: TextInputType.phone),
                      titleColor: titleColor),
                ]),

            SizedBox(height: 20.h),

            _sectionTitle('Identité & Sécurité', titleColor),
            SizedBox(height: 10.h),
            _card(
                cardColor: cardColor,
                children: [
                  _editableRow(
                      icon: Icons.badge_outlined,
                      label: 'CIN',
                      value: _driver['cin'],
                      onEdit: () =>
                          _editTextField(label: 'CIN', fieldKey: 'cin'),
                      titleColor: titleColor),
                  _divider(isDark),
                  _editableRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _driver['email'],
                      onEdit: () => _editTextField(
                          label: 'Email',
                          fieldKey: 'email',
                          keyboardType: TextInputType.emailAddress),
                      titleColor: titleColor),
                  _divider(isDark),
                  _editableRow(
                    icon: Icons.lock_outline,
                    label: 'Mot de passe',
                    value: (_driver['password decrypted'] != null)
                        ? '•' *
                        _driver['password decrypted']
                            .toString()
                            .length
                        : (_driver['password'] != null &&
                        _driver['password'].length < 20)
                        ? '•' * _driver['password'].length
                        : '••••••••',
                    onEdit: _editPassword,
                    titleColor: titleColor,
                  ),
                  _divider(isDark),
                  _readOnlyRow(Icons.directions_car_outlined, 'Véhicule ID',
                      _driver['vehicule_id'], titleColor),
                ]),

            SizedBox(height: 20.h),

            _sectionTitle('Habilitations', titleColor),
            SizedBox(height: 10.h),
            _card(
                cardColor: cardColor,
                children: [
                  _statusRow(Icons.verified_outlined, 'Compte autorisé',
                      _driver['driver_authorized'],
                      fieldKey: 'driver_authorized'),
                  _divider(isDark),
                  _statusRow(Icons.medical_services_outlined,
                      'Aptitude médicale', _driver['driver_medically'],
                      fieldKey: 'driver_medically'),
                  _divider(isDark),
                  _statusRow(Icons.school_outlined, 'Formation conduite',
                      _driver['driving_training'],
                      fieldKey: 'driving_training'),
                  _divider(isDark),
                  _statusRow(Icons.security_outlined, 'Conduite sécurisée',
                      _driver['driving_safe'],
                      fieldKey: 'driving_safe'),
                ]),

            SizedBox(height: 20.h),

            _sectionTitle('Technique', titleColor),
            SizedBox(height: 10.h),
            _card(
                cardColor: cardColor,
                children: [
                  _readOnlyRow(Icons.qr_code_outlined, 'Code QR',
                      _driver['codeQR'], titleColor),
                  _divider(isDark),
                  _readOnlyRow(
                      Icons.update_outlined,
                      'Dernier reset',
                      _driver['last_password_reset_date']
                          ?.toString()
                          .split('T')[0],
                      titleColor),
                ]),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color titleColor) {
    return Row(
      children: [
        Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.circular(2.r))),
        SizedBox(width: 8.w),
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: titleColor)),
      ],
    );
  }

  Widget _card({required Color cardColor, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Column(children: children),
    );
  }

  Widget _editableRow({
    required IconData icon,
    required String label,
    required dynamic value,
    required VoidCallback onEdit,
    required Color titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r)),
            child: Icon(icon, color: _purple, size: 18),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.sp, color: Colors.grey[500])),
                Text(
                  value?.toString().isNotEmpty == true
                      ? value.toString()
                      : '—',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: titleColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                  color: _purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r)),
              child: const Icon(Icons.edit_outlined,
                  color: _purple, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(
      IconData icon, String label, dynamic value, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r)),
            child: Icon(icon, color: _purple, size: 18),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.sp, color: Colors.grey[500])),
                Text(
                  value?.toString().isNotEmpty == true
                      ? value.toString()
                      : '—',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: titleColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, color: Colors.grey[300], size: 16),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, dynamic value,
      {String? fieldKey}) {
    final ok = value == true || value == 1 || value == '\u0001';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r)),
            child: Icon(icon, color: _purple, size: 18),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _darkPurple)),
          ),
          GestureDetector(
            onTap: fieldKey == null
                ? null
                : () async {
              final newVal = ok ? false : true;
              await _saveField(fieldKey, newVal);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
              EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: ok
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: ok
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ok ? 'Oui' : 'Non',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: ok
                            ? Colors.green[700]
                            : Colors.red[700]),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.edit_outlined,
                      size: 12.w,
                      color: ok ? Colors.green[700] : Colors.red[700]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
      height: 1.h,
      color: isDark ? Colors.white10 : Colors.grey[100]);
}