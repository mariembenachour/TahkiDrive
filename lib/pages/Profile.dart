import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/Alert.dart';
import 'package:tahki_drive1/pages/Event.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const ProfilePage({super.key, this.onBackToDashboard});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Relance l'animation au retour sur la page
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.reset();
    _controller.forward();
  }

  // ================== LUXURY ENTRY ANIMATION ==================
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
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
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
              // HEADER (Entrée immédiate : delay 0.0)
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
                      const Text(
                        "Profile",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078)),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // CARTE PROFIL (Entrée un peu après : delay 0.1)
                      _luxuryAnimatedEntry(
                        delay: 0.1,
                        child: _buildProfileCard(),
                      ),

                      const SizedBox(height: 25),

                      // MENU (Entrée finale : delay 0.2)
                      _luxuryAnimatedEntry(
                        delay: 0.2,
                        child: _buildMenuContainer([
                          _buildMenuItem(
                            context,
                            Icons.warning_amber_rounded,
                            "Problem History",
                            onTap: () => _navigateTo(context, const AlertsPage()),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            context,
                            Icons.event_note_rounded,
                            "Events",
                            onTap: () => _navigateTo(context, const EventsPage()),
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

  // --- WIDGETS DE CONSTRUCTION ---
  Widget _buildProfileCard() {
    return Container(
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
                const Text("John Miller", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                Text("john.miller92@example.com", style: TextStyle(fontSize: 13, color: Colors.grey[600])),

              ],
            ),
          ),
          const Icon(Icons.edit_note_rounded, color: Color(0xFF7226FF)),
        ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(children: children),
      ),
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
          decoration: BoxDecoration(
            color: const Color(0xFF7226FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
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
        decoration: BoxDecoration(
          color: const Color(0xFF7226FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF7226FF), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF160078), fontSize: 15)),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(value: true, onChanged: (val) {}, activeColor: const Color(0xFF7226FF)),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey[100]);
  }
}