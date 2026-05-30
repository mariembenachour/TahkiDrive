import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tahki_drive1/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class FullScreenMapWithGaragesPage extends StatefulWidget {
  final double userLat;
  final double userLng;
  final List<dynamic> garages;

  const FullScreenMapWithGaragesPage({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.garages,
  });

  @override
  State<FullScreenMapWithGaragesPage> createState() => _FullScreenMapWithGaragesPageState();
}

class _FullScreenMapWithGaragesPageState extends State<FullScreenMapWithGaragesPage> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${widget.userLat}&lon=${widget.userLng}&format=json&accept-language=fr',
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

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    markers.add(Marker(
      point: LatLng(widget.userLat, widget.userLng),
      width: 50.w, height: 50.h,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)]),
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
        ),
        child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
      ),
    ));

    final sorted = List.from(widget.garages)
      ..sort((a, b) => ((a['distance_km'] ?? 9999) as num)
          .compareTo((b['distance_km'] ?? 9999) as num));

    for (int i = 0; i < sorted.length; i++) {
      final g = sorted[i];
      final lat = g['latitude'];
      final lng = g['longitude'];
      if (lat == null || lng == null) continue;

      final color = i < 10 ? Colors.green : Colors.orange;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 40.w, height: 40.h,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
          ),
          child: const Icon(Icons.build, color: Colors.white, size: 22),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = context.watch<ThemeService>().isDark(context);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF160078);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(widget.userLat, widget.userLng),
            initialZoom: 13,
            minZoom: 3, maxZoom: 19,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tahkidrive',
            ),
            MarkerLayer(markers: _buildMarkers()),
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
                color: cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF7226FF), size: 20),
            ),
          ),
        ),

        // Card adresse en bas
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
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
                            style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white54 : Colors.grey)),
                        _address != null
                            ? Text(_address!, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: textColor))
                            : Text("Chargement...", style: TextStyle(fontSize: 14.sp, color: isDark ? Colors.white54 : Colors.grey)),
                      ],
                    ),
                  ),
                ]),
                 SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F0FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(children: [
                        const Icon(Icons.circle, color: Colors.green, size: 12),
                         SizedBox(width: 4.w),
                        Text("10 plus proches", style: TextStyle(fontSize: 10.sp, color: isDark ? Colors.white54 : Colors.black54)),
                      ]),
                      Row(children: [
                        const Icon(Icons.circle, color: Colors.orange, size: 12),
                         SizedBox(width: 4.w),
                        Text("Autres garages", style: TextStyle(fontSize: 10.sp, color: isDark ? Colors.white54 : Colors.black54)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
