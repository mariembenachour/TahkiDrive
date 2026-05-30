import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'AdminLoginPage.dart';
import 'AdminDriversTab.dart';
import 'AdminDevicesTab.dart';
import 'AdminVendorTokensTab.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with TickerProviderStateMixin {
  int _tab = 0;
  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

  // ── palette ──────────────────────────────────────────────────────────────
  static const _neonPurple      = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPurpleDark  = Color(0xFF4A148C);
  static const _neonPink        = Color(0xFFFF00E5);
  static const _darkBg          = Color(0xFF050510);

  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final s = await AdminService.getStats();
      if (mounted) setState(() { _stats = s; _loadingStats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _logout() async {
    await AdminService.clearToken();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const AdminLoginPage()));
  }

  // ── background ───────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _darkBg),
        Positioned(
          top: -100, left: -100, right: -100,
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [_neonPurple.withOpacity(0.18), Colors.transparent],
                radius: 0.8,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100, right: -80,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [_neonPink.withOpacity(0.08), Colors.transparent],
                radius: 0.8,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                _darkBg.withOpacity(0.3),
                _darkBg.withOpacity(0.85),
                _darkBg.withOpacity(0.98),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _floatingParticle(int index) {
    final random = index * 137.5;
    final size   = 1.5 + (index % 3) * 1.2;
    final colors = [
      _neonPurple.withOpacity(0.4),
      _neonPurpleLight.withOpacity(0.35),
      _neonPink.withOpacity(0.25),
      Colors.white.withOpacity(0.2),
    ];
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, child) {
        final t = _floatController.value;
        final x = cos(random + t * 2 * pi) * 60 + (index % 2 == 0 ? 20 : 280);
        final y = sin(random + t * pi)      * 100 + 80 + index * 100;
        final opacity = 0.2 + sin(t * pi + index) * 0.25;
        return Positioned(
          left: x, top: y,
          child: Opacity(
            opacity: opacity.clamp(0.05, 0.6),
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[index % colors.length],
                boxShadow: [BoxShadow(
                  color: colors[index % colors.length].withOpacity(0.8),
                  blurRadius: 4, spreadRadius: 1,
                )],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── sidebar ──────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final items = [
      {'icon': Icons.dashboard_rounded,    'label': 'Vue d\'ensemble'},
      {'icon': Icons.people_alt_rounded,   'label': 'Chauffeurs'},
      {'icon': Icons.devices_rounded,      'label': 'Devices'},
      {'icon': Icons.qr_code_2_rounded,    'label': 'QR Revendeurs'},
    ];
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        width: 220,
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.04),
          border: Border(
            right: BorderSide(
              color: _neonPurple.withOpacity(0.2 + _glowController.value * 0.1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withOpacity(0.05 + _glowController.value * 0.05),
              blurRadius: 20, spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
      child: Column(
        children: [
          // Logo / brand
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_neonPurple, _neonPurpleDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                      color: _neonPurple.withOpacity(0.3 + _pulseController.value * 0.3),
                      blurRadius: 12, spreadRadius: 1,
                    )],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_neonPurpleLight, Colors.white],
                ).createShader(bounds),
                child: const Text('Admin',
                    style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 16, letterSpacing: 1,
                    )),
              ),
            ]),
          ),
          Container(height: 1, color: _neonPurple.withOpacity(0.2)),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((e) {
            final i    = e.key;
            final item = e.value;
            final active = _tab == i;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: active ? _neonPurple.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? _neonPurple.withOpacity(0.5) : Colors.transparent,
                  ),
                  boxShadow: active ? [BoxShadow(
                    color: _neonPurple.withOpacity(0.2),
                    blurRadius: 12, spreadRadius: 0,
                  )] : [],
                ),
                child: Row(children: [
                  Icon(item['icon'] as IconData,
                      color: active ? _neonPurpleLight : Colors.white30, size: 20),
                  const SizedBox(width: 10),
                  Text(item['label'] as String,
                      style: TextStyle(
                        color: active ? _neonPurpleLight : Colors.white38,
                        fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      )),
                ]),
              ),
            );
          }),
          const Spacer(),
          Container(height: 1, color: _neonPurple.withOpacity(0.2)),
          InkWell(
            onTap: _logout,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(children: [
                const Icon(Icons.logout_rounded, color: Colors.white24, size: 18),
                const SizedBox(width: 10),
                Text('Déconnexion',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 13,
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── bottom nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _darkBg,
        border: Border(top: BorderSide(color: _neonPurple.withOpacity(0.25), width: 1)),
        boxShadow: [BoxShadow(
          color: _neonPurple.withOpacity(0.15), blurRadius: 20, spreadRadius: 0,
        )],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: _neonPurpleLight,
        unselectedItemColor: Colors.white24,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),  label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Chauffeurs'),
          BottomNavigationBarItem(icon: Icon(Icons.devices_rounded),    label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_rounded),  label: 'QR'),
        ],
      ),
    );
  }

  // ── header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final titles = ['Vue d\'ensemble', 'Chauffeurs', 'Devices', 'QR Revendeurs'];
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.03),
          border: Border(
            bottom: BorderSide(
              color: _neonPurple.withOpacity(0.15 + _glowController.value * 0.1),
            ),
          ),
        ),
        child: child,
      ),
      child: Row(children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_neonPurpleLight, Colors.white],
          ).createShader(bounds),
          child: Text(
            titles[_tab],
            style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5,
            ),
          ),
        ),
        const Spacer(),
        _iconBtn(Icons.refresh_rounded, _loadStats),
        if (MediaQuery.of(context).size.width <= 700)
          _iconBtn(Icons.logout_rounded, _logout),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: _neonPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _neonPurple.withOpacity(0.25)),
        ),
        child: Icon(icon, color: Colors.white38, size: 18),
      ),
    );
  }

  // ── stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    if (_loadingStats) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: _neonPurple, strokeWidth: 2,
        ),
      );
    }
    final s = _stats;
    final cards = [
      {'label': 'Total chauffeurs', 'value': '${s?['total_drivers'] ?? '-'}',
        'icon': Icons.people_alt_rounded, 'color': _neonPurple},
      {'label': 'En attente', 'value': '${s?['pending_drivers'] ?? '-'}',
        'icon': Icons.hourglass_top_rounded, 'color': const Color(0xFFFFAA00)},
      {'label': 'Actifs', 'value': '${s?['active_drivers'] ?? '-'}',
        'icon': Icons.check_circle_rounded, 'color': const Color(0xFF4CAF50)},
      {'label': 'Devices', 'value': '${s?['total_devices'] ?? '-'}',
        'icon': Icons.devices_rounded, 'color': _neonPink},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final c = cards[i];
            final color = c['color'] as Color;
            return AnimatedBuilder(
              animation: _glowController,
              builder: (_, child) => Container(
                width: 155,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withOpacity(0.2 + _glowController.value * 0.15),
                  ),
                  boxShadow: [BoxShadow(
                    color: color.withOpacity(0.08 + _glowController.value * 0.08),
                    blurRadius: 12, spreadRadius: 0,
                  )],
                ),
                child: Row(children: [
                  Icon(c['icon'] as IconData, color: color, size: 26),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c['value'] as String,
                          style: TextStyle(
                            color: color, fontSize: 22, fontWeight: FontWeight.w800,
                          )),
                      Text(c['label'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4), fontSize: 10,
                          )),
                    ],
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case 0:  return const AdminDriversTab(defaultFilter: 'pending');
      case 1:  return const AdminDriversTab(defaultFilter: 'all');
      case 2:  return const AdminDevicesTab();
      case 3:  return const AdminVendorTokensTab();
      default: return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          // Background ambiance
          Positioned.fill(child: _buildBackground()),
          // Particles (subtle)
          ...List.generate(5, (i) => _floatingParticle(i)),
          // Main layout
          SafeArea(
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width > 700)
                  _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(),
                      if (_tab == 0) _buildStatsRow(),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 700
          ? _buildBottomNav()
          : null,
    );
  }
}