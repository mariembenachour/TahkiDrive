import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tahki_drive1/services/garage_service.dart';

class FullScreenMapWithGaragesPage extends StatelessWidget {
  final double userLat;
  final double userLng;
  final List<dynamic> garages;

  const FullScreenMapWithGaragesPage({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.garages,
  });

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Marqueur utilisateur
    markers.add(
      Marker(
        point: LatLng(userLat, userLng),
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF7226FF), Color(0xFF160078)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 28),
        ),
      ),
    );

    // Marqueurs garages
    for (var garage in garages) {
      final lat = garage['latitude'];
      final lng = garage['longitude'];

      if (lat != null && lng != null) {
        Color markerColor;
        if (garage['rating'] != null && garage['rating'] >= 4.5) {
          markerColor = Colors.purple;
        } else if (garage['rating'] != null && garage['rating'] >= 3) {
          markerColor = Colors.orange;
        } else {
          markerColor = Colors.red;
        }

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                // Afficher les infos du garage
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markerColor,
                  boxShadow: [
                    BoxShadow(
                      color: markerColor.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(userLat, userLng),
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tahkidrive',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF7226FF),
                  size: 20,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7226FF), Color(0xFF160078)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Position actuelle",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "Votre véhicule",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF160078)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}