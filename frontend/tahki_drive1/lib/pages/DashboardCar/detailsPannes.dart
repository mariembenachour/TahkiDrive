import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/BrakeDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/DistributionDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/EmbrayageDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/TireDetailsPage.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';
import 'package:tahki_drive1/services/dashboard_service.dart';
import '../../menus/menu.dart';
import 'BatteryDetailsPage.dart';

class PanneDetailsPage extends StatefulWidget {
  const PanneDetailsPage({super.key});

  @override
  State<PanneDetailsPage> createState() => _PanneDetailsPageState();
}

class _PanneDetailsPageState extends State<PanneDetailsPage>
    with TickerProviderStateMixin {
  String? imageUrl;
  bool isLoadingImage = true;
  bool isMenuOpen = true;
  double carScale = 1.2;

  Map<String, dynamic>? _firstVehicule;

  // Données de maintenance
  Map<String, dynamic>? _batteryData;
  Map<String, dynamic>? _oilChangeData;
  Map<String, dynamic>? _brakeData;
  Map<String, dynamic>? _embrayageData;
  double? _temperatureData;

  late AnimationController _entryController;
  late Animation<Offset> _carSlide;
  late Animation<double> _carFade;
  late Animation<Offset> _menuSlide;
  late Animation<double> _menuFade;
  late AnimationController _pulseController;

  void _toggleMenu() => setState(() => isMenuOpen = !isMenuOpen);

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

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

    _menuFade = Tween<double>(begin: 0, end: 1).animate(_entryController);

    _entryController.forward();
    _loadVehicule();
    _loadMaintenanceData();
  }

  Future<void> _loadVehicule() async {
    setState(() => isLoadingImage = true);
    try {
      final dataList = await DashService.getUserVehicules();
      if (dataList.isNotEmpty) {
        _firstVehicule = dataList[0];
        setState(() {
          imageUrl = _getTopImageUrl();
          isLoadingImage = false;
        });
      } else {
        setState(() => isLoadingImage = false);
      }
    } catch (e) {
      print("Erreur chargement véhicule: $e");
      setState(() => isLoadingImage = false);
    }
  }

  Future<void> _loadMaintenanceData() async {
    try {
      final battery = await DashService.getLastBattery();
      final oil = await DashService.getLastOilChange();
      final temp = await DashService.getLastTemp();

      setState(() {
        _batteryData = battery;
        _oilChangeData = oil;
        if (temp != null && temp != "Pas de donnée") {
          _temperatureData = double.tryParse(temp.toString()) ?? 0.0;
        }
      });
    } catch (e) {
      print("Erreur chargement maintenance: $e");
    }
  }

  String _getTopImageUrl() {
    String topImageUrl = '';
    try {
      if (_firstVehicule?['images'] != null &&
          _firstVehicule!['images'].toString().isNotEmpty) {
        var decoded = jsonDecode(_firstVehicule!['images']) as List;
        if (decoded.length > 2) {
          topImageUrl = 'http://10.0.2.2:8000/${decoded[2]}';
        }
      }
    } catch (e) {
      print("Erreur top image: $e");
    }
    return topImageUrl;
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
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
              backgroundColor: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF7226FF), size: 40),
                  const SizedBox(height: 15),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20,
                          color: Color(0xFF160078))),
                  const SizedBox(height: 10),
                  Text(detail, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14)),
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
          // FOND AVEC GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE8E2FF), Colors.white, Color(0xFFF0EDF6)],
              ),
            ),
          ),

          // HEADER
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _buildCircleButton(Icons.arrow_back, () {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                      const MainScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(-1.0, 0.0);
                        const end = Offset.zero;
                        final tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: Curves.easeInOut));
                        final offsetAnimation = animation.drive(tween);
                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                        (route) => false,
                  );
                }),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _firstVehicule != null
                            ? "${_firstVehicule!['mark']} ${_firstVehicule!['model']}"
                            : "Mon véhicule",
                        style: const TextStyle(
                          color: Color(0xFF160078),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _firstVehicule?['matricule'] ?? "",
                        style: const TextStyle(
                          color: Color(0xFF7226FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Indicateur de santé
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "Bon état",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // STATS D'ENTRETIEN (5 boutons)
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatButton(Icons.car_repair, "Freins",
                      const BrakeDetailsPage(), context, Colors.red),
                  const SizedBox(width: 25),
                  _buildStatButton(Icons.battery_charging_full_rounded, "Batterie",
                      const BatteryDetailsPage(), context, Colors.orange),
                  const SizedBox(width: 25),
                  _buildStatButton(
                      Icons.settings_applications,
                      "Distribution",
                      const DistributionDetailsPage(),
                      context, Colors.blue),
                  const SizedBox(width: 25),
                  _buildStatButton(
                      Icons.tire_repair, "Pneus", const TireDetailsPage(), context, Colors.teal),
                  const SizedBox(width: 25),
                  _buildStatButton(Icons.settings_input_component, "Embrayage",
                      const EmbrayageDetailsPage(), context, Colors.purple),
                ],
              ),
            ),
          ),

          // CARTE INFORMATION RAPIDE (Température et Batterie seulement)
          Positioned(
            top: 220,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Température
                  Expanded(
                    child: _buildQuickInfo(
                      Icons.thermostat,
                      "Température",
                      _temperatureData != null ? "${_temperatureData!.toStringAsFixed(1)}" : "---",
                      "°C",
                      color: _temperatureData != null && _temperatureData! > 90 ? Colors.red : Colors.orange,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),

                ],
              ),
            ),
          ),

          // VOITURE ANIMÉE (AGRANDIE)
          Center(
            child: SlideTransition(
              position: _carSlide,
              child: FadeTransition(
                opacity: _carFade,
                child: Align(
                  alignment: const Alignment(0, 0.7),
                  child: Transform.scale(
                    scale: carScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        isLoadingImage
                            ? const CircularProgressIndicator(color: Color(0xFF7226FF))
                            : (imageUrl != null && imageUrl!.isNotEmpty
                            ? Image.network(
                          imageUrl!,
                          height: 500,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.directions_car, size: 150, color: Color(0xFF7226FF));
                          },
                        )
                            : const Icon(Icons.directions_car, size: 150, color: Color(0xFF7226FF))),

                        // Alertes sur la voiture
                        Positioned(
                          top: 70,
                          left: 50,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5 * _pulseController.value),
                                      blurRadius: 15 * _pulseController.value,
                                      spreadRadius: 5 * _pulseController.value,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.warning, color: Colors.white, size: 18),
                              );
                            },
                          ),
                        ),

                        Positioned(
                          bottom: 60,
                          right: 40,
                          child: GestureDetector(
                            onTap: () => _showDetailPopup(
                                context,
                                "Pression des pneus",
                                "Vérifier le pneu arrière droit\nPression actuelle: 1.8 bar",
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
        ],
      ),
    );
  }

  Widget _buildQuickInfo(IconData icon, String label, String value, String unit, {Color color = const Color(0xFF7226FF)}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          "$value $unit",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatButton(
      IconData icon, String label, Widget page, BuildContext context, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (c, a, b) => page,
          transitionsBuilder: (c, a, b, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
            child: child,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap,
      {Color color = const Color(0xFF160078)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2)
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _AlertPulse extends StatefulWidget {
  const _AlertPulse();
  @override
  State<_AlertPulse> createState() => _AlertPulseState();
}

class _AlertPulseState extends State<_AlertPulse>
    with SingleTickerProviderStateMixin {
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
            boxShadow:[
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