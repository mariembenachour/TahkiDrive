import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


const Color _blue     = Color(0xFF006AD7);
const Color _blueDark = Color(0xFF21277B);
const Color _greyBlue = Color(0xFF5F83B1);

String _fmtTime(String? iso) {
  if (iso == null || iso.isEmpty) return '--:--';
  try { return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal()); }
  catch (_) { return '--:--'; }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt  = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    if (_sameDay(dt, now)) return "Aujourd'hui";
    if (_sameDay(dt, now.subtract(const Duration(days: 1)))) return 'Hier';
    return DateFormat('dd MMM yyyy', 'fr_FR').format(dt);
  } catch (_) { return '—'; }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Future<String?> _reverseGeocode(double lat, double lng) async {
  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&accept-language=fr',
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
      return parts.isNotEmpty ? parts.join(', ') : null;
    }
  } catch (e) {
    print('Erreur geocoding: $e');
  }
  return null;
}

// ══════════════════════════════════════════════════════════════════════════════
class PathMapPage extends StatefulWidget {
  final Map<String, dynamic> path;
  const PathMapPage({super.key, required this.path});

  @override
  State<PathMapPage> createState() => _PathMapPageState();
}

class _PathMapPageState extends State<PathMapPage> {
  String? _startAddress;
  String? _endAddress;
  bool _loadingAddresses = true;

  double get _beginLat => (widget.path['begin_path_latitude']  as num).toDouble();
  double get _beginLng => (widget.path['begin_path_longitude'] as num).toDouble();
  double get _endLat   => (widget.path['end_path_latitude']    as num).toDouble();
  double get _endLng   => (widget.path['end_path_longitude']   as num).toDouble();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final results = await Future.wait([
      _reverseGeocode(_beginLat, _beginLng),
      _reverseGeocode(_endLat,   _endLng),
    ]);
    if (mounted) {
      setState(() {
        _startAddress     = results[0];
        _endAddress       = results[1];
        _loadingAddresses = false;
      });
    }
  }

  double _calcZoom(double lat1, double lng1, double lat2, double lng2) {
    final maxDiff = [(lat1 - lat2).abs(), (lng1 - lng2).abs()].reduce((a, b) => a > b ? a : b);
    if (maxDiff < 0.005) return 15;
    if (maxDiff < 0.02)  return 14;
    if (maxDiff < 0.05)  return 13;
    if (maxDiff < 0.1)   return 12;
    if (maxDiff < 0.5)   return 11;
    if (maxDiff < 1.0)   return 10;
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng((_beginLat + _endLat) / 2, (_beginLng + _endLng) / 2);
    final zoom   = _calcZoom(_beginLat, _beginLng, _endLat, _endLng);

    return Scaffold(
      body: Stack(
        children: [
          // ── Carte plein écran ─────────────────────────────────────────
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                InteractiveFlag.drag      |
                InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tahkidrive',
              ),
              PolylineLayer(polylines: [
                Polyline(
                  points: [LatLng(_beginLat, _beginLng), LatLng(_endLat, _endLng)],
                  color: _blue,
                  strokeWidth: 5.w,
                  strokeCap: StrokeCap.round,
                ),
              ]),
              MarkerLayer(markers: [
                _marker(LatLng(_beginLat, _beginLng), Colors.green, Icons.radio_button_checked_rounded, "Départ"),
                _marker(LatLng(_endLat,   _endLng),   Colors.red,   Icons.location_on_rounded,          "Arrivée"),
              ]),
            ],
          ),

          // ── Bouton retour + heure en haut ─────────────────────────────
          SafeArea(
            child: Padding(
              padding:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded, color: _blueDark, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                    ),
                    child: Row(children: [
                      _infoChip(Icons.radio_button_checked, Colors.green, _fmtTime(widget.path['begin_path_time'] as String?)),
                       SizedBox(width: 6.w),
                      const Icon(Icons.arrow_forward_rounded, color: _greyBlue, size: 14),
                       SizedBox(width: 6.w),
                      _infoChip(Icons.location_on, Colors.red, _fmtTime(widget.path['end_path_time'] as String?)),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Adresses en bas ───────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding:  EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:  BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: _loadingAddresses
                  ?  Center(
                child: Padding(
                  padding:EdgeInsets.all(8.w),
                  child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _addressRow(Icons.radio_button_checked, Colors.green, "Départ",  _startAddress),
                   SizedBox(height: 12.h),
                  _addressRow(Icons.location_on,          Colors.red,   "Arrivée", _endAddress),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String label, String? address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
          child: Icon(icon, color: color, size: 14),
        ),
         SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 10.sp, color: _greyBlue)),
              Text(
                address ?? "Adresse non disponible",
                style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600, color: _blueDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, Color color, String label) => Row(children: [
    Icon(icon, color: color, size: 13),
     SizedBox(width: 4.w),
    Text(label, style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: color)),
  ]);

  Marker _marker(LatLng point, Color color, IconData icon, String label) => Marker(
    point: point,
    width: 44.w,
    height: 54.h,
    alignment: Alignment.topCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36.w, height: 36.h,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(
          padding:  EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6.r)),
          child: Text(label, style: GoogleFonts.poppins(fontSize: 7.sp, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
