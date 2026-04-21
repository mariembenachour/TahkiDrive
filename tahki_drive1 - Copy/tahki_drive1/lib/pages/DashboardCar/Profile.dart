import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/Alert.dart';
import 'package:tahki_drive1/pages/DashboardCar/EventHistorique.dart';
import 'package:tahki_drive1/services/profile_service.dart';
import 'package:tahki_drive1/services/auth_service.dart'; // ← AJOUTE CET IMPORT
import 'Sav.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const ProfilePage({super.key, this.onBackToDashboard});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Map<String, dynamic>? _driver;
  bool _loading = true;
  int? _driverId; // ← AJOUTE CETTE VARIABLE

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _controller.forward();
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    try {
      final data = await ProfileService.fetchMyProfile();
      final id = await AuthService.getDriverId(); // ← RÉCUPÈRE L'ID
      setState(() {
        _driver = data;
        _driverId = id;
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
      builder: (context, _) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8EAF6), Color(0xFFF3E5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _luxuryAnimatedEntry(
                delay: 0.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF160078)),
                        onPressed: () => widget.onBackToDashboard?.call(),
                      ),
                      const Text("Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      _luxuryAnimatedEntry(delay: 0.1, child: _buildProfileCard()),
                      const SizedBox(height: 25),
                      _luxuryAnimatedEntry(
                        delay: 0.2,
                        child: _buildMenuContainer([
                          // ← MODIFIÉ : Passe driverId
                          _buildMenuItem(context, Icons.warning_amber_rounded, "Problem History",
                              onTap: () => _navigateTo(context, AlertsPage(driverId: _driverId ?? 6))),
                          _buildDivider(),
                          _buildMenuItem(
                              context,
                              Icons.event_note_rounded,
                              "Events",
                              onTap: () => _navigateTo(context, EventHistoriquePage())
                          ),
                          _buildDivider(),
                          _buildMenuItem(context, Icons.query_stats_rounded, "Statistics"),
                          _buildDivider(),
                          _buildMenuItem(context, Icons.biotech_rounded, "Diagnostic"),
                          _buildDivider(),
                          _buildSwitchItem(Icons.notifications_none_rounded, "Notifications"),
                          _buildDivider(),
                          _buildMenuItem(context, Icons.language_rounded, "Language", trailingText: "English"),
                          _buildDivider(),
                          _buildSwitchItem(Icons.dark_mode_outlined, "Dark mode"),
                          _buildMenuItem(
                            context,
                            Icons.history_rounded,
                            "Historique des pannes & accidents",
                            onTap: () => _navigateTo(context, const SavPage()),
                          ),
                          _buildDivider(),
                        ]),
                      ),
                      const SizedBox(height: 100),
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

  Widget _buildProfileCard() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF))),
      );
    }

    return GestureDetector(
      onTap: () => _navigateTo(context, DriverDetailScreen(driver: _driver ?? {})),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundColor: Color(0xFF7226FF),
              child: Icon(Icons.person, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_driver?['first_name'] ?? ''} ${_driver?['last_name'] ?? ''}'.trim(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF160078)),
                  ),
                  Text(
                    _driver?['user_email'] ?? _driver?['email'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Column(children: children)),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {String? trailingText, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        splashColor: const Color(0xFF7226FF).withOpacity(0.1),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF7226FF), size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF160078), fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) Text(trailingText, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF7226FF), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF160078), fontSize: 15)),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(value: true, onChanged: (val) {}, activeColor: const Color(0xFF7226FF)),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey[100]);
}

// ============================================================
//  DRIVER DETAIL SCREEN
// ============================================================
class DriverDetailScreen extends StatelessWidget {
  final Map<String, dynamic> driver;
  const DriverDetailScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEAF6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF160078)),
        title: const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _card(children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Color(0xFF7226FF),
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'.trim(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF160078)),
                        ),
                        Text(driver['user_email'] ?? driver['email'] ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          driver['username'] != null ? '@${driver['username']}' : '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF7226FF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Compte'),
            const SizedBox(height: 10),
            _card(children: [
              _infoRow(Icons.person_rounded, 'Nom affiché', driver['display_name']),
              _divider(),
              _infoRow(Icons.alternate_email, 'Username', driver['username']),
              _divider(),
              _infoRow(Icons.email_rounded, 'Email login', driver['user_email'] ?? driver['email']),
              _divider(),
              _infoRow(Icons.lock_rounded, 'Mot de passe', '••••••••'),
              _divider(),
              _infoRow(Icons.calendar_today_rounded, 'Créé le', driver['createdat']?.toString().substring(0, 10)),
              _divider(),
              _statusRow(Icons.toggle_on_rounded, 'Compte actif', driver['enabled']),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Identité'),
            const SizedBox(height: 10),
            _card(children: [
              _infoRow(Icons.badge_rounded, 'CIN', driver['cin']),
              _divider(),
              _infoRow(Icons.email_rounded, 'Email', driver['email']),
              _divider(),
              _infoRow(Icons.phone_rounded, 'Téléphone', driver['telephone']),
              _divider(),
              _infoRow(Icons.bloodtype_rounded, 'Groupe sanguin', driver['blood_group']),
              _divider(),
              _infoRow(Icons.star_rounded, 'Rang / Classe', driver['rang_class']),
              _divider(),
              _infoRow(Icons.location_on_rounded, 'Sites intervention',
                  (driver['intervention_sites'] == 1 || driver['intervention_sites'] == true)
                      ? 'Autorisé' : driver['intervention_sites']?.toString()),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Habilitations'),
            const SizedBox(height: 10),
            _card(children: [
              _statusRow(Icons.medical_services_rounded, 'Médicalement apte', driver['driver_medically']),
              _divider(),
              _statusRow(Icons.school_rounded, 'Formation conduite', driver['driving_training']),
              _divider(),
              _statusRow(Icons.shield_rounded, 'Conduite sécurisée', driver['driving_safe']),
              _divider(),
              _statusRow(Icons.verified_rounded, 'Autorisé', driver['driver_authorized']),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF7226FF), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF7226FF), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(value?.toString() ?? 'N/A',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF160078)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, dynamic value) {
    final ok = value == true || value == 1 || value == '\u0001';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF7226FF), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF160078)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ok ? 'Oui' : 'Non',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ok ? Colors.green[700] : Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey[100]);
}