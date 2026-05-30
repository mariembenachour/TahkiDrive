import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class FullScreenMapPage extends StatefulWidget {
  final double latitude;
  final double longitude;

  const FullScreenMapPage({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${widget.latitude}&lon=${widget.longitude}&format=json&accept-language=fr',
      );
      final response = await http.get(url, headers: {'User-Agent': 'tahkidrive/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? {};
        final parts = [
          address['road'],
          address['suburb'] ?? address['neighbourhood'],
          address['city'] ?? address['town'] ?? address['village'],
        ].where((p) => p != null).toList();
        if (mounted) setState(() => _address = parts.join(', '));
      }
    } catch (e) {
      print('Erreur geocoding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.latitude, widget.longitude),
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tahkidrive',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitude, widget.longitude),
                    width: 60.w, height: 60.h,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)]),
                        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.6), blurRadius: 25, spreadRadius: 5)],
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bouton retour
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF7226FF), size: 20),
              ),
            ),
          ),

          // Info card en bas
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)]),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                   SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text("Position actuelle",
                            style: TextStyle(fontSize: 17.sp, color: Colors.grey)),
                        _address != null
                            ? Text(_address!,
                            style:  TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Color(0xFF160078)))
                            :  Text("Chargement...",
                            style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
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
