import 'package:flutter/material.dart';
import '../../menus/GlobalNavBar.dart';
import '../DashboardDriver/DashboardChauffeur.dart';
import 'DetailsCar.dart';
import 'detailsPannes.dart';

class Dashboard extends StatefulWidget {
  final VoidCallback onSwitchProfile;
  const Dashboard({super.key, required this.onSwitchProfile});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  // ================== ANIMATION CONTROLLER ==================
  late AnimationController _controller;
  int selectedIndex = 0;
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
                      // Supprimé les Positioned qui étaient ici
                      const SizedBox(height: 70),

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
                                      Expanded(child: _buildInfoCard("TECHNICAL CHECK", "22 Nov 2026")),
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

                                // ================== CARTE KILOMÉTRAGE (BLANC) ==================
                                Container(
                                  width: 370,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
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
                                            child: const Icon(
                                              Icons.speed,
                                              size: 18,
                                              color: Color(0xFF7226FF),
                                            ),
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

                                // ================== CARTE ESSENCE (GRADIENT) ==================
                                // ================== CARTE CARBURANT (STATISTIQUES DÉTAILLÉES) ==================
                                GestureDetector(
                                  onTap: () => _showDetailsPopUp(
                                    context,
                                    "Carburant",
                                    "45.2 L",
                                    Icons.local_gas_station,
                                  ),
                                  child: Container(
                                    width: 400, // Légèrement plus large pour plus d'infos
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF9E71FD),
                                          Color(0xFFD1B3FF),
                                          Colors.white,
                                        ],
                                        stops: [0.0, 0.4, 1.0],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
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
                                        // En-tête avec icône et titre
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
                                            _buildGradientText(" Carburant", 23, FontWeight.bold),
                                          ],
                                        ),
                                        const SizedBox(height: 15),

                                        // Statistiques principales
                                        const SizedBox(height: 12),

                                        // Consommation et odomètre
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatWithProgress(
                                                label: "Conso moyenne",
                                                value: "7.8 L/100km",
                                                percent: 0.65,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(15),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.speed, size: 16, color: Colors.deepPurple.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "45 230 km",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.deepPurple.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 15),



                                      ],


                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

// ================= NOUVELLE SECTION : CARTE VOITURE + TEMP VERTICALE + CARROUSEL BATTERIE/HUILE =================
                      _luxuryAnimatedEntry(
                        delay: 0.4,
                        child: Column(
                          children: [
                            // Première ligne : Carte voiture + Carte température verticale
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Carte voiture avec "Cliquez pour voir panne" (gauche)
                                Expanded(
                                  flex: 3,
                                  child: GestureDetector(
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
                                        height: 270,
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
                                            children: [
                                              Positioned(
                                                left: 27,
                                                top: 15,
                                                child: Image.asset(
                                                  'images/Mercedes-Benz-GLA_top.png',
                                                  height: 250,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Positioned(
                                                top: 15,
                                                right: 15,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.85),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.info_outline, size: 14, color: Colors.deepPurple.shade700),
                                                      const SizedBox(width: 4),
                                                      Text('Cliquez pour voir panne',
                                                          style: TextStyle(fontSize: 14, color: Colors.deepPurple.shade800, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Carte température verticale (droite)
                                Expanded(
                                  flex: 2,
                                  child: _buildVerticalTempCard(percent: 0.7),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Titre pour la section batterie et huile
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Text(
                                "Derniers entretiens",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Carrousel horizontal des cartes batterie et huile (très grandes)
                            SizedBox(
                              height: 160,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  const SizedBox(width: 5),
                                  _buildExtraLargeStatusCard(
                                    title: "BATTERIE",
                                    icon: Icons.battery_charging_full,
                                    lastChange: "12/02/2024",
                                    isDark: true,
                                  ),
                                  const SizedBox(width: 15),
                                  _buildExtraLargeStatusCard(
                                    title: "HUILE",
                                    icon: Icons.oil_barrel_rounded,
                                    lastChange: "05/01/2024",
                                    isDark: false,
                                  ),
                                  const SizedBox(width: 15),
                                  _buildExtraLargeStatusCard(
                                    title: "FILTRE",
                                    icon: Icons.air,
                                    lastChange: "20/01/2024",
                                    isDark: true,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),


                      // ----------------- MAPS--------------------
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

          // --- MENU SUPERIEUR (Positionné correctement dans le Stack) ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20, // Changé de right à left pour mettre le menu à gauche
            child: GlobalNavBar(
              currentIndex: 0, // 0 car on est sur la page Voiture
              onTabSelected: (index) {
                if (index == 1) widget.onSwitchProfile(); // Déclenche le switch vers Profil
              },
            ),
          ),

// OPTIONNEL : Un bouton notif à droite pour équilibrer
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            right: 20, // Changé de left à right pour mettre la notification à droite
            child: _buildFloatingButton(Icons.notifications_none_rounded),
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
// Carte température en format vertical
  Widget _buildVerticalTempCard({required double percent}) {
    return Container(
      height: 270, // Même hauteur que la carte voiture
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade700, Colors.lightBlue.shade500],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.thermostat,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "TEMPÉRATURE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "${(percent * 100).toInt()}°C",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

// Cartes batterie et huile plus grandes

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


// Cartes batterie et huile extra grandes pour le carrousel
  Widget _buildExtraLargeStatusCard({
    required String title,
    required IconData icon,
    required String lastChange,
    required bool isDark,
  }) {
    return Container(
      width: 350,
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.deepPurple.shade800, Colors.deepPurple.shade600, Colors.deepPurple.shade400]
              : [Colors.amber.shade700, Colors.orange.shade600, Colors.deepOrange.shade400],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.deepPurple : Colors.orange).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white.withOpacity(0.8),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Dernier changement:",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastChange,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 5),
              child: Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.5),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Statistique compacte avec icône
  Widget _buildCompactStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

// Statistique avec barre de progression
  Widget _buildStatWithProgress({
    required String label,
    required String value,
    required double percent,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

// Petit chip d'information
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.deepPurple.shade500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.deepPurple.shade700,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildHorizontalTempCardWide({required double percent}) {
    return Container(
      width: 200, // Plus large
      height: 90, // Plus haut
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.lightBlue.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.thermostat,
                color: Colors.white.withOpacity(0.8),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "TEMPÉRATURE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${(percent * 100).toInt()}°C",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percent,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 5,
                  ),
                ],
              ),
            ),
          ],
        ),
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