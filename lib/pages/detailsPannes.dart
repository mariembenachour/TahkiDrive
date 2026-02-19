import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/Dashboard.dart';

import '../menus/menu.dart';

class PanneDetailsPage extends StatefulWidget {
  const PanneDetailsPage({super.key});

  @override
  State<PanneDetailsPage> createState() => _PanneDetailsPageState();
}

class _PanneDetailsPageState extends State<PanneDetailsPage>
    with TickerProviderStateMixin {
  bool isMenuOpen = true;
  double carScale = 1.1;

  late AnimationController _entryController;
  late Animation<Offset> _carSlide;
  late Animation<double> _carFade;
  late Animation<Offset> _menuSlide;
  late Animation<double> _menuFade;


  void _toggleMenu() => setState(() => isMenuOpen = !isMenuOpen);


  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _carSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    _carFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeIn));

    _menuSlide = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    ));

    _menuFade =
        Tween<double>(begin: 0, end: 1).animate(_entryController);

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _showDetailPopup(
      BuildContext context, String title, String detail, IconData icon) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1,
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF7226FF), size: 40),
                  const SizedBox(height: 15),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 10),
                  Text(detail, textAlign: TextAlign.center),
                ],
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
      backgroundColor: const Color(0xFFF5F5F9),
      body: Stack(
        children: [
          // FOND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE8E2FF), Colors.white],
              ),
            ),
          ),

          // HEADER
          Positioned(
            top: 60,
            left: 20,
            child: Row(
              children: [
                _buildCircleButton(
                  Icons.arrow_back,
                      () {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const Dashboard(), // ta page précédente
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          const begin = Offset(-1.0, 0.0); // départ depuis la gauche
                          const end = Offset.zero;          // arrivée à sa place
                          final tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: Curves.easeInOut));
                          final offsetAnimation = animation.drive(tween);
                          return SlideTransition(position: offsetAnimation, child: child);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "GLA 250",
                      style: TextStyle(
                          color: Color(0xFF160078),
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Mercedes-Benz",
                      style: TextStyle(color: Color(0xFF7226FF), fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),


          // STATS
          Positioned(
            top: 150,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopStat(context, "Autonomie", "320 km", Icons.bolt_rounded),
                _buildTopStat(context, "Batterie", "75%", Icons.battery_charging_full_rounded),
                _buildTopStat(context, "Temp", "22°C", Icons.thermostat_rounded),
                _buildTopStat(context, "Vitesse", "0 km/h", Icons.speed_rounded),
              ],
            ),
          ),

          // VOITURE ANIMÉE
          Center(
            child: SlideTransition(
              position: _carSlide,
              child: FadeTransition(
                opacity: _carFade,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  padding: EdgeInsets.only(
                    right: isMenuOpen ? 140 : 90,
                  ),
                  child: Align(
                    alignment: isMenuOpen
                        ? const Alignment(-0.2, 0)
                        : const Alignment(-0.2, 0.2),
                    child: Transform.scale(
                      scale: carScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'images/Mercedes-Benz-GLA_top.png',
                            fit: BoxFit.contain,
                          ),
                          Positioned(
                            bottom: 180,
                            right: 100,
                            child: GestureDetector(
                              onTap: () => _showDetailPopup(
                                  context,
                                  "Pression",
                                  "Vérifier pneu arrière droit",
                                  Icons.tire_repair),
                              child: const _AlertPulse(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // MENU ANIMÉ DROITE
          Positioned(
            right: isMenuOpen ? 20 : -150,
            top: MediaQuery.of(context).size.height * 0.25,
            child: SlideTransition(
              position: _menuSlide,
              child: FadeTransition(
                opacity: _menuFade,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutQuint,
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        children: [
                          _buildMenuIcon(context, Icons.lock_outline_rounded, "Verrou", true),
                          const SizedBox(height: 35),
                          _buildMenuIcon(context, Icons.ac_unit_rounded, "Clim", false),
                          const SizedBox(height: 35),
                          _buildMenuIcon(context, Icons.lightbulb_outline, "Phares", false),
                          const SizedBox(height: 35),
                          _buildMenuIcon(context, Icons.volume_up_rounded, "Klaxon", false),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // BOUTON FLOTTANT
          Positioned(
            bottom: 100,
            right: 30,
            child: _buildCircleButton(
              isMenuOpen ? Icons.close : Icons.grid_view_rounded,
              _toggleMenu,
              color: isMenuOpen ? Colors.red : const Color(0xFF7226FF),
            ),
          ),
        ],
      ),
    );
  }

  // Méthodes auxiliaires
  Widget _buildTopStat(
      BuildContext context, String label, String value, IconData icon) {
    return GestureDetector(
      onTap: () => _showDetailPopup(context, label, "Détails : $value", icon),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7226FF).withOpacity(0.6), size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMenuIcon(
      BuildContext context, IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () => _showDetailPopup(context, label, "Action sur : $label", icon),
      child: Column(
        children: [
          Icon(icon, color: active ? const Color(0xFF7226FF) : Colors.grey[600], size: 30),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {Color color = const Color(0xFF160078)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _AlertPulse extends StatefulWidget {
  const _AlertPulse();
  @override
  State<_AlertPulse> createState() => _AlertPulseState();
}

class _AlertPulseState extends State<_AlertPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5 * _controller.value),
                blurRadius: 15 * _controller.value,
                spreadRadius: 5 * _controller.value,
              )
            ],
          ),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 14),
        );
      },
    );
  }
}
