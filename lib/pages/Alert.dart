import 'package:flutter/material.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with SingleTickerProviderStateMixin {
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
              // --- HEADER (delay 0.0) ---
              _luxuryAnimatedEntry(
                delay: 0.0,
                child: _buildHeader(context),
              ),

              // --- BARRE DE RECHERCHE (delay 0.1) ---
              _luxuryAnimatedEntry(
                delay: 0.1,
                child: _buildSearchBar(),
              ),

              // --- ONGLETS (delay 0.2) ---
              _luxuryAnimatedEntry(
                delay: 0.2,
                child: _buildFilterTabs(),
              ),

              // --- LISTE DES ALERTES ---
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 10),

                    _luxuryAnimatedEntry(
                      delay: 0.3,
                      child: _buildSectionTitle("Today"),
                    ),

                    _luxuryAnimatedEntry(
                      delay: 0.4,
                      child: _buildAlertItem(
                        icon: Icons.oil_barrel_rounded,
                        title: "Engine Oil Change Due",
                        subtitle: "2 hours ago • Recommended within 500km",
                        color: Colors.orange,
                      ),
                    ),

                    _luxuryAnimatedEntry(
                      delay: 0.5,
                      child: _buildAlertItem(
                        icon: Icons.adjust_rounded,
                        title: "Brake Pads Wearing",
                        subtitle: "6 hours ago • Schedule inspection soon",
                        color: Colors.redAccent,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _luxuryAnimatedEntry(
                      delay: 0.6,
                      child: _buildSectionTitle("This Week"),
                    ),

                    _luxuryAnimatedEntry(
                      delay: 0.7,
                      child: _buildAlertItem(
                        icon: Icons.tire_repair_rounded,
                        title: "Tire Pressure Low",
                        subtitle: "2 days ago • Front right tire pressure",
                        color: Colors.orange,
                      ),
                    ),

                    _luxuryAnimatedEntry(
                      delay: 0.8,
                      child: _buildAlertItem(
                        icon: Icons.lock_reset_rounded,
                        title: "Security System Updated",
                        subtitle: "4 days ago • Firmware version 2.4",
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION (Inchangés mais compatibles avec l'anim) ---

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF160078)),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                "Alerts",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078)),
              ),
            ],
          ),
          TextButton(
            onPressed: () {},
            child: const Text("Clear All", style: TextStyle(color: Color(0xFF7226FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const TextField(
          decoration: InputDecoration(
            hintText: "Search by date or category...",
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Color(0xFF7226FF)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = ["All", "Category", "By Date"];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tabs.map((tab) {
          bool isSelected = tab == "All";
          return Column(
            children: [
              Text(
                tab,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF160078) : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 3,
                  width: 25,
                  decoration: BoxDecoration(color: const Color(0xFF7226FF), borderRadius: BorderRadius.circular(2)),
                )
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildAlertItem({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF160078), fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[300], size: 18),
        ],
      ),
    );
  }
}