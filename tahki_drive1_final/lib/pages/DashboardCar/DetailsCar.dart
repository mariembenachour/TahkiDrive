import 'dart:convert';
import 'package:flutter/material.dart';

class CarDetailsPage extends StatefulWidget {
  final Map<String, dynamic> car; // Voiture sélectionnée
  const CarDetailsPage({super.key, required this.car});

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

  // --- Fonction utilitaire pour recuperer une valeur ou "Erreur" ---
  String safeField(dynamic value) {
    try {
      if (value == null || value.toString().isEmpty) return "Erreur";
      return value.toString();
    } catch (e) {
      return "Erreur";
    }
  }

  // --- Fonction pour recuperer la 2eme image avec fallback ---
  String getSecondImage() {
    try {
      if (widget.car['images'] == null || widget.car['images'].toString().isEmpty) {
        return 'images/automobile.png';
      }

      List<dynamic> decoded = widget.car['images'];
      if (widget.car['images'] is String) {
        decoded = jsonDecode(widget.car['images']);
      }

      if (decoded.length > 1) {
        return 'http://10.0.2.2:8000/${decoded[1]}';
      } else if (decoded.isNotEmpty) {
        return 'http://10.0.2.2:8000/${decoded[0]}';
      }

      return 'images/automobile.png';
    } catch (e) {
      print("Erreur decodage images: $e");
      return 'images/automobile.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = getSecondImage();
    // --- On cree un map pour fiche_vehicule si dispo ---
    final ficheVehicle = widget.car['fiche_vehicule'] ?? {};

// --- On cree un map "vehicle" pour les champs racine ---
    final vehicle = widget.car;

// --- Fonction utilitaire pour recuperer en priorite fiche_vehicule puis vehicle ---
    String getField(String key) {
      if (ficheVehicle.containsKey(key) && ficheVehicle[key] != null && ficheVehicle[key].toString().isNotEmpty) {
        return ficheVehicle[key].toString();
      } else if (vehicle.containsKey(key) && vehicle[key] != null && vehicle[key].toString().isNotEmpty) {
        return vehicle[key].toString();
      } else {
        return "Erreur";
      }
    }

// --- Recuperation securisee de toutes les infos ---
    final mark = getField('mark');                   // vehicule
    final model = getField('model');                 // vehicule
    final serial = getField('serial_number');        // fiche_vehicule
    final power = getField('power_hp');              // fiche_vehicule
    final seats = getField('seating');               // fiche_vehicule
    final fuel = getField('fuel');                   // fiche_vehicule
    final tank = getField('fuel_tank_capacity');     // fiche_vehicule
    final plate = getField('matricule');             // vehicule
    final transmission = getField('control_magnetic_driver') == 'YES' ? 'Auto' : 'Manuelle';
    final datePurchase = getField('date_purchase');  // fiche_vehicule
    final placePurchase = getField('place_purshace'); // fiche_vehicule
    final firstInstall = getField('first_installation'); // fiche_vehicule
    final lastChange = getField('last_change');     // fiche_vehicule
    final warranty = getField('date_garantie');     // vehicule
    final category = getField('category');          // vehicule
    final capacity = getField('capacity');          // vehicule
    print("Mark: $mark");
    print("Model: $model, Serial: $serial");
    print("Power: $power, Seats: $seats");
    print("Fuel: $fuel, Tank: $tank");
    print("Plate: $plate, Transmission: $transmission");
    print("Date Purchase: $datePurchase, Place: $placePurchase");
    print("First Installation: $firstInstall, Last Change: $lastChange");
    print("Warranty: $warranty, Category: $category");
    print("Capacity: $capacity");

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
                  const Text(
                    "Car Details",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                  // Carte blanche animee
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    top: _animate ? 270 : MediaQuery.of(context).size.height,
                    left: 0,
                    right: 0,
                    child: Container(
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
                            Text(
                              mark,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              "Car Info",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 15),

                            // Modele et Numero de serie
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.directions_car, "Modele : $model")),
                                Expanded(child: _buildInfoGridItem(Icons.qr_code, "S/N : $serial")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Puissance et Nombre de sieges
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.speed, "Puissance : $power hp")),
                                Expanded(child: _buildInfoGridItem(Icons.event_seat, "Sieges : $seats")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Carburant et Reservoir
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.local_gas_station, "Carburant : $fuel")),
                                Expanded(child: _buildInfoGridItem(Icons.invert_colors, "Reservoir : $tank L")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Plaque et Transmission
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.confirmation_number, "Plaque : $plate")),
                                Expanded(child: _buildInfoGridItem(Icons.settings, "Transmission : $transmission")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Date et lieu d'achat
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.calendar_today, "Achat : $datePurchase")),
                                Expanded(child: _buildInfoGridItem(Icons.place, "Lieu : $placePurchase")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Premiere installation et dernier changement
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.install_desktop, "1ere Installation : $firstInstall")),
                                Expanded(child: _buildInfoGridItem(Icons.update, "Dernier Changement : $lastChange")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Date garantie et categorie
                            Row(
                              children: [
                                Expanded(child: _buildInfoGridItem(Icons.shield, "Garantie : $warranty")),
                                Expanded(child: _buildInfoGridItem(Icons.category, "Categorie : $category")),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Capacite
                            _buildInfoGridItem(Icons.people, "Capacite : $capacity places"),
                            const SizedBox(height: 25),
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

                  // Voiture animee (2eme image)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    top: 38,
                    left: _animate ? -20 : MediaQuery.of(context).size.width,
                    child: Builder(
                      builder: (context) {
                        // Fallback si aucune image
                        String fallback = 'images/automobile.png';
                        String imageUrl = fallback;

                        try {
                          var imagesData = widget.car['images'];

                          if (imagesData != null) {
                            List<dynamic> decoded = [];

                            // Si c'est deja une List, on l'utilise
                            if (imagesData is List) {
                              decoded = imagesData;
                            }
                            // Si c'est une String JSON, on decode
                            else if (imagesData is String && imagesData.isNotEmpty) {
                              decoded = jsonDecode(imagesData);
                            }

                            // On prend la deuxieme image uniquement si elle existe
                            if (decoded.length > 1) {
                              imageUrl = 'http://10.0.2.2:8000/${decoded[1]}';
                            }
                            // Sinon fallback sur la premiere image
                            else if (decoded.isNotEmpty) {
                              imageUrl = 'http://10.0.2.2:8000/${decoded[0]}';
                            }

                            // Log pour verifier l'image recuperee
                            print("URL recuperee: $imageUrl");
                          }
                        } catch (e) {
                          print("Erreur decodage images: $e");
                        }

                        // Retourne le widget Image.network avec l'URL finale
                        return Image.network(
                          imageUrl,
                          width: MediaQuery.of(context).size.width * 1.4,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.directions_car, size: 180, color: Colors.white24),
                        );
                      },
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
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 14))),
      ],
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