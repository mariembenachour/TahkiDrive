import 'package:flutter/material.dart';

class CarDetailsPage extends StatefulWidget {
  const CarDetailsPage({super.key});

  @override
  State<CarDetailsPage> createState() => _CarDetailsPageState();
}

class _CarDetailsPageState extends State<CarDetailsPage> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _animate = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: Column(
          children: [
            const SizedBox(height: 50),

            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                  const Text("Car Details",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildCircleButton(Icons.more_horiz, () {}),
                ],
              ),
            ),

            // IMAGE + CARTE BLANCHE
            Expanded(
              flex: 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Carte blanche animée (monte du bas)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    top: _animate ? 270 : MediaQuery.of(context).size.height,
                    left: 0,
                    right: 0,
                    child: Container(
                      // On force la hauteur pour qu'elle descende jusqu'en bas de l'écran
                      height: MediaQuery.of(context).size.height - 270,
                      padding: const EdgeInsets.all(25),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            const Text("Mercedes-Benz GLA",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

                            const SizedBox(height: 25),
                            const Text("Car Info",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),

                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.directions_car, "Modèle : GLA")),
                                Expanded(child: _buildInfoGridItem(Icons.calendar_today, "Année : 2022")),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.color_lens, "Couleur : Noir")),
                                Expanded(child: _buildInfoGridItem(Icons.settings, "Transmission : Auto")),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.local_gas_station, "Carburant : Essence")),
                                Expanded(child: _buildInfoGridItem(Icons.confirmation_number, "Plaque : AB 1234 CD")),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoGridItem(Icons.qr_code, "VIN : XXXXXXXXXXXXXXXX"),

                            const SizedBox(height: 25),
                            const Text("Car Specs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSpecBox("Max. Power", "320", "hp"),
                                _buildSpecBox("0-60 mph", "5.4", "sec."),
                                _buildSpecBox("Top Speed", "187", "mph"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Ombre elliptique
                  Positioned(
                    top: 140,
                    left: MediaQuery.of(context).size.width * 0.15,
                    child: Container(
                      width: 300,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Voiture animée (entre depuis la droite)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    top: 38,
                    left: _animate ? -20 : MediaQuery.of(context).size.width,
                    child: Image.asset(
                      'images/mercedes_normal.png',
                      width: MediaQuery.of(context).size.width * 1.4,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.directions_car, size: 180, color: Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets Utilitaires ---
  Widget _buildInfoGridItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
      ],
    );
  }

  Widget _buildSpecBox(String label, String value, String unit) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                TextSpan(text: " $unit", style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}