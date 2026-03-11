import 'package:flutter/material.dart';
// Suppression de l'import Main_screen pour éviter les imports circulaires inutiles

class NearestMechanicsPage extends StatefulWidget {
  // 1. AJOUTE CETTE LIGNE : On déclare le callback
  final VoidCallback? onBackToDashboard;

  // 2. MODIFIE LE CONSTRUCTEUR : On ajoute le paramètre
  const NearestMechanicsPage({super.key, this.onBackToDashboard});

  @override
  State<NearestMechanicsPage> createState() => _NearestMechanicsPageState();
}

class _NearestMechanicsPageState extends State<NearestMechanicsPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
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
      body: Stack(
        children: [
          // === 1. FOND DÉGRADÉ ===
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4D2091),
                  Color(0xFF5C3897),
                  Color(0xFFF0EDF6),
                  Color(0xFFF0EDF6),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _luxuryAnimatedEntry(
                  delay: 0.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            // 3. MODIFIE ICI : On utilise le callback du widget
                            if (widget.onBackToDashboard != null) {
                              widget.onBackToDashboard!();
                            }
                          },
                        ),
                        const Column(
                          children: [
                            Text("Nearest Mechanics",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text("Find nearby auto repair shops",
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // === CARTE STYLE MAP ===
                _luxuryAnimatedEntry(
                  delay: 0.1,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF5F0FF), Color(0xFFE8DEFF), Colors.white],
                              ),
                            ),
                          ),
                          Positioned.fill(child: CustomPaint(painter: MapPainter())),
                          Center(
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)]),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.6),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.location_on, color: Colors.white, size: 30),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // === FILTRES ===
                _luxuryAnimatedEntry(
                  delay: 0.2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip("Distance", Icons.location_on_outlined, isSelected: true),
                        _buildFilterChip("Rating", Icons.star_outline, isSelected: false),
                        _buildFilterChip("Service", Icons.build_outlined, isSelected: false),
                        _buildFilterChip("Open", Icons.access_time, isSelected: false),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _luxuryAnimatedEntry(delay: 0.3, child: _buildShopCard("AutoCare Plus", 4.8, "0.8 km")),
                      _luxuryAnimatedEntry(delay: 0.4, child: _buildShopCard("Quick Fix Motors", 4.1, "1.5 km")),
                      _luxuryAnimatedEntry(delay: 0.5, child: _buildShopCard("Garage Performance", 4.5, "2.3 km")),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? Colors.white : Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildShopCard(String name, double rating, String distance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Color(0xFF4904BD), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text("$rating  •  $distance away", style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15)),
                  child: const Center(child: Text("Call", style: TextStyle(color: Colors.white))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFF4904BD), borderRadius: BorderRadius.circular(15)),
                  child: const Center(child: Text("Navigate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()..color = const Color(0xFFB388FF).withOpacity(0.5)..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    Path mainRoad = Path()..moveTo(0, size.height * 0.6)..quadraticBezierTo(size.width * 0.5, size.height * 0.3, size.width, size.height * 0.5);
    canvas.drawPath(mainRoad, roadPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}