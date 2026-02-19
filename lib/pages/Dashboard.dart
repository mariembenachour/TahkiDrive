import 'package:flutter/material.dart';
import 'DetailsCar.dart';
import 'detailsPannes.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  // ================== ANIMATION CONTROLLER ==================
  late AnimationController _controller;

  // Définition du gradient pour les textes et les barres
  final Gradient _brandGradient = const LinearGradient(
    colors: [Color(0xFF7226FF), Color(0xFF160078)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  bool isMenuOpen = false;

  void _toggleMenu() => setState(() => isMenuOpen = !isMenuOpen);


  // ================== INIT STATE ==================
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ================== LUXURY ENTRY ANIMATION ==================
  Widget _luxuryAnimatedEntry({
    required Widget child,
    required double delay,
  }) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay,
        1,
        curve: Curves.easeOutBack,
      ),
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
              scale: Tween<double>(
                begin: 0.92,
                end: 1,
              ).animate(animation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // --- À AJOUTER : FONCTION DU POP-UP ---
  void _showDetailsPopUp(BuildContext context, String title, String value, IconData icon) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Details",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.bounceOut),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              contentPadding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: Colors.white),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 50, color: const Color(0xFF7226FF)),
                    const SizedBox(height: 20),
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(value, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Fermer"),
                    )
                  ],
                ),
              ),
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
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4904BD),
                  Color(0xFFF0EDF6),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // --- HEADER ---
                      _luxuryAnimatedEntry(
                        delay: 0.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFloatingButton(Icons.menu),
                            _buildFloatingButton(Icons.notifications),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // --- CARTE DE VOITURE ---
                      _luxuryAnimatedEntry(
                        delay: 0.1,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CarDetailsPage()),
                            );
                          },
                          child: Container(
                            height: 400,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(35),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                const Positioned(
                                  top: 25,
                                  left: 25,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Mercedes-Benz GLA",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        "AB 1234 CD",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: -400, end: -200),
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, value, child) {
                                    return Positioned(
                                      top: 200,
                                      bottom: 100,
                                      left: value,
                                      right: 20,
                                      child: Transform.scale(
                                        scale: 3.8,
                                        child: Image.asset(
                                          'images/mercedes_droite.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                Positioned(
                                  bottom: 25,
                                  left: 20,
                                  right: 20,
                                  child: Row(
                                    children: [
                                      Expanded(child: _buildInfoCard("NEXT SERVICE", "3,200 km")),
                                      const SizedBox(width: 20),
                                      Expanded(child: _buildInfoCard("INSURANCE", "Nov 2025")),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // --- CARROUSEL 1 : ESSENCE + KILOMÉTRAGE ---
                      _luxuryAnimatedEntry(
                        delay: 0.25,
                        child: SizedBox(
                          height: 225,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _showDetailsPopUp(context, "Essence", "65 L", Icons.local_gas_station),
                                  child: Container(
                                    width: 370,
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple.withOpacity(0.15),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7226FF).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.local_gas_station,
                                                size: 23,
                                                color: Color(0xFF7226FF),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _buildGradientText(" Essence", 23, FontWeight.bold),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        Expanded(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildCircularStat("Restant", "65 L", 0.65, Colors.purpleAccent),
                                              _buildCircularStat("Conso", "7.5 L", 0.35, Colors.deepPurple),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  width: 370,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topRight,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFF9E71FD), Color(0xFFD1B3FF), Colors.white],
                                      stops: [0.0, 0.4, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7226FF).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.speed, size: 18, color: Color(0xFF7226FF)),
                                          ),
                                          const SizedBox(width: 10),
                                          _buildGradientText(" Kilométrage", 20, FontWeight.bold),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildGradientText("25.000 km", 30, FontWeight.bold),
                                      const SizedBox(height: 18),
                                      _buildStatRow("Journalier", "120 km/j", 0.35),
                                      const SizedBox(height: 12),
                                      _buildStatRow("Hebdomadaire", "840 km/s", 0.75),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // ================= CARROUSEL GLOBAL =================
                      _luxuryAnimatedEntry(
                        delay: 0.4,
                        child: SizedBox(
                          height: 280,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration: const Duration(milliseconds: 800),
                                        reverseTransitionDuration: const Duration(milliseconds: 800),
                                        pageBuilder: (context, animation, secondaryAnimation) => const PanneDetailsPage(),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: 'car_top_view',
                                    child: Container(
                                      width: 210,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        gradient: const RadialGradient(
                                          center: Alignment.center,
                                          radius: 0.8,
                                          colors: [Color(0xFFB388FF), Color(0xFFEDE7FF), Colors.white],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.deepPurple.withOpacity(0.25),
                                            blurRadius: 20,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 20),
                                                child: Image.asset(
                                                  'images/Mercedes-Benz-GLA_top.png',
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                            Positioned(top: 15, left: 15, child: _miniPsi("39")),
                                            Positioned(top: 15, right: 15, child: _miniPsi("39")),
                                            Positioned(bottom: 15, left: 15, child: _miniPsi("34")),
                                            Positioned(bottom: 15, right: 15, child: _miniPsi("35")),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                _buildStatusCard(title: "BATTERY", value: "80%", icon: Icons.battery_charging_full, isDark: true),
                                const SizedBox(width: 15),
                                _buildStatusCard(title: "HUILE", value: "70%", icon: Icons.oil_barrel_rounded, isDark: false),
                                const SizedBox(width: 15),
                                _buildTempThermometer(percent: 0.7),
                                const SizedBox(width: 15),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ================= DESIGN MAP =================
                      _luxuryAnimatedEntry(
                        delay: 0.55,
                        child: Container(
                          height: 260,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
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
                                    width: 70, height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)]),
                                      boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.6), blurRadius: 25, spreadRadius: 5)],
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.white, size: 35),
                                  ),
                                ),
                                Positioned(
                                  top: 15, left: 15,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                                    child: const Text("Vehicle Location", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B00CC))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  // --- HELPERS (Contenu original conservé) ---
  Widget _buildGradientText(String text, double size, FontWeight weight) {
    return ShaderMask(
      shaderCallback: (bounds) => _brandGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: TextStyle(fontSize: size, fontWeight: weight, color: Colors.white)),
    );
  }

  Widget _buildStatRow(String label, String value, double percent) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
            _buildGradientText(value, 13, FontWeight.bold),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
            ),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                height: 6,
                decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildTempThermometer({required double percent}) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const RadialGradient(center: Alignment.center, radius: 1, colors: [Color(0xFFB388FF), Color(0xFFEDE7FF), Colors.white]),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 15),
          const Text("Température", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4B00CC))),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 40, height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0xFFB388FF), width: 2)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                width: 40, height: 120 * percent,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF7226FF), Color(0xFF160078)])),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text("${(percent * 100).toInt()}%", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4B00CC))),
        ],
      ),
    );
  }

  Widget _miniPsi(String value) {
    return Container(
      width: 55, height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4B00CC))),
          const Text("psi", style: TextStyle(fontSize: 16, color: Color(0xFF4B00CC))),
        ],
      ),
    );
  }

  Widget _buildCircularStat(String label, String value, double percent, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70, height: 70,
              child: CircularProgressIndicator(value: percent, strokeWidth: 8, backgroundColor: Colors.grey[200], color: color, strokeCap: StrokeCap.round),
            ),
            Text("${(percent * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF160078))),
      ],
    );
  }

  Widget _buildStatusCard({required String title, required String value, required IconData icon, required bool isDark}) {
    return Container(
      width: 200, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isDark
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7226FF), Color(0xFF160078)])
            : const RadialGradient(center: Alignment.center, radius: 1, colors: [Color(0xFFB388FF), Color(0xFFEDE7FF), Colors.white]),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(isDark ? 0.4 : 0.25), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 55, color: isDark ? Colors.white : Colors.deepPurple),
          const SizedBox(height: 15),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.deepPurple)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.deepPurple)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(colors: [const Color(0xFF4B00CC).withOpacity(0.6), const Color(0xFF9C7BFF).withOpacity(0.6)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFB388FF).withOpacity(0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final smallRoadPaint = Paint()
      ..color = const Color(0xFF9E71FD).withOpacity(0.4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Path mainRoad = Path();
    mainRoad.moveTo(0, size.height * 0.6);
    mainRoad.quadraticBezierTo(size.width * 0.5, size.height * 0.3, size.width, size.height * 0.5);
    canvas.drawPath(mainRoad, roadPaint);

    Path smallRoad = Path();
    smallRoad.moveTo(size.width * 0.2, 0);
    smallRoad.quadraticBezierTo(size.width * 0.7, size.height * 0.5, size.width * 0.3, size.height);
    canvas.drawPath(smallRoad, smallRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}