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

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _tab = 0;
  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

  static const _teal = Color(0xFF00C6A2);
  static const _bg = Color(0xFF080F1A);

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
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
      bottomNavigationBar: MediaQuery.of(context).size.width <= 700
          ? _buildBottomNav()
          : null,
    );
  }

  Widget _buildSidebar() {
    final items = [
      {'icon': Icons.dashboard_rounded,    'label': 'Vue d\'ensemble'},
      {'icon': Icons.people_alt_rounded,   'label': 'Chauffeurs'},
      {'icon': Icons.devices_rounded,      'label': 'Devices'},        // ← changé
      {'icon': Icons.qr_code_2_rounded,    'label': 'QR Revendeurs'},
    ];
    return Container(
      width: 220,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_teal, Color(0xFF006B56)]),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Admin',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final active = _tab == i;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                    color: active ? _teal.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: active ? _teal.withOpacity(0.3) : Colors.transparent)),
                child: Row(children: [
                  Icon(item['icon'] as IconData,
                      color: active ? _teal : Colors.white38, size: 20),
                  const SizedBox(width: 10),
                  Text(item['label'] as String,
                      style: TextStyle(
                          color: active ? _teal : Colors.white60,
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14)),
                ]),
              ),
            );
          }),
          const Spacer(),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
            title: const Text('Déconnexion',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0D1520),
      selectedItemColor: _teal,
      unselectedItemColor: Colors.white38,
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),  label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Chauffeurs'),
        BottomNavigationBarItem(icon: Icon(Icons.devices_rounded),    label: 'Devices'),  // ← changé
        BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_rounded),  label: 'QR'),
      ],
    );
  }

  Widget _buildHeader() {
    final titles = ['Vue d\'ensemble', 'Chauffeurs', 'Devices', 'QR Revendeurs']; // ← changé
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: Row(
        children: [
          Text(titles[_tab],
              style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
            onPressed: _loadStats,
            tooltip: 'Actualiser',
          ),
          if (MediaQuery.of(context).size.width <= 700)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white38),
              onPressed: _logout,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_loadingStats) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _teal, strokeWidth: 2),
      );
    }

    final s = _stats;
    final cards = [
      {
        'label': 'Total chauffeurs',
        'value': '${s?['total_drivers'] ?? '-'}',
        'icon': Icons.people_alt_rounded,
        'color': _teal,
      },
      {
        'label': 'En attente',
        'value': '${s?['pending_drivers'] ?? '-'}',
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFFFAA00),
      },
      {
        'label': 'Actifs',
        'value': '${s?['active_drivers'] ?? '-'}',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'Devices',   // ← changé
        'value': '${s?['total_devices'] ?? '-'}',
        'icon': Icons.devices_rounded,
        'color': const Color(0xFF2196F3),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final c = cards[i];
            return Container(
              width: 160,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: (c['color'] as Color).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (c['color'] as Color).withOpacity(0.2))),
              child: Row(children: [
                Icon(c['icon'] as IconData, color: c['color'] as Color, size: 28),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c['value'] as String,
                        style: TextStyle(color: c['color'] as Color,
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(c['label'] as String,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
              ]),
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
}
