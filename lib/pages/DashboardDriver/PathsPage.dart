// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/driver/PathsPage.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:tahki_drive1/pages/DashboardDriver/PathMapPage.dart';
import '../../services/path_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


// ── Palette ───────────────────────────────────────────────────────────────────
const Color _blue      = Color(0xFF006AD7);
const Color _blueDark  = Color(0xFF21277B);
const Color _greyBlue  = Color(0xFF5F83B1);
const Color _bgColor   = Color(0xFFF0EDF6);

// ── Reverse geocoding ─────────────────────────────────────────────────────────
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

// ── Formatters ────────────────────────────────────────────────────────────────
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

String _fmtDuration(dynamic seconds) {
  final s = (seconds as num?)?.toInt() ?? 0;
  if (s == 0) return '—';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}min' : '${m}min';
}

String _fmtKm(dynamic val) {
  final d = (val as num?)?.toDouble() ?? 0.0;
  if (d == 0) return '—';
  return d >= 1000
      ? '${(d / 1000).toStringAsFixed(1)} km'
      : '${d.toStringAsFixed(0)} m';
}

String _fmtSpeed(dynamic val) => '${(val as num?)?.toInt() ?? 0} km/h';
String _fmtLitre(dynamic val) {
  final v = (val as num?)?.toDouble() ?? 0.0;
  return v == 0 ? '—' : '${v.toStringAsFixed(1)} L';
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAGE PRINCIPALE — liste + filtres
// ══════════════════════════════════════════════════════════════════════════════
class PathsPage extends StatefulWidget {
  const PathsPage({super.key});

  @override
  State<PathsPage> createState() => _PathsPageState();
}

class _PathsPageState extends State<PathsPage>
    with SingleTickerProviderStateMixin {

  String _filter = 'all';
  DateTime? _pickedDate;

  List<Map<String, dynamic>> _paths = [];
  bool _loading = false;
  bool _hasMore = true;
  int  _offset  = 0;
  static const int _pageSize = 15;

  final ScrollController _scroll = ScrollController();
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() => _loading = true);

    if (reset) {
      _paths  = [];
      _offset = 0;
      _hasMore = true;
    }

    final batch = await PathService.getRecentPaths(
      limit: _pageSize,
      offset: _offset,
    );

    final filtered = _applyFilter(batch);

    if (mounted) {
      setState(() {
        _paths.addAll(filtered);
        _offset  += batch.length;
        _hasMore  = batch.length == _pageSize;
        _loading  = false;
      });
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> raw) {
    final now       = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return raw.where((p) {
      final iso = p['begin_path_time'] as String?;
      if (iso == null) return false;
      try {
        final dt = DateTime.parse(iso).toLocal();
        switch (_filter) {
          case 'today':     return _sameDay(dt, now);
          case 'yesterday': return _sameDay(dt, yesterday);
          case 'date':      return _pickedDate != null && _sameDay(dt, _pickedDate!);
          default:          return true;
        }
      } catch (_) { return false; }
    }).toList();
  }

  void _setFilter(String f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _load(reset: true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _blue,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _pickedDate = picked; _filter = 'date'; });
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Container(
            height: 200.h,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue, _blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── AppBar ────────────────────────────────────────────────
                Padding(
                  padding:  EdgeInsets.fromLTRB(8.w, 10.h, 16.w, 0.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          "Mes trajets",
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: Colors.white.withOpacity(0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                             SizedBox(width: 6.w),
                            Text(
                              _filter == 'date' && _pickedDate != null
                                  ? DateFormat('dd MMM').format(_pickedDate!)
                                  : 'Date',
                              style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                 SizedBox(height: 12.h),

                // ── Filtres ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _filterChip("Aujourd'hui", 'today'),
                     SizedBox(width: 8.w),
                    _filterChip('Hier', 'yesterday'),
                     SizedBox(width: 8.w),
                    _filterChip('Tous', 'all'),
                  ]),
                ),

                 SizedBox(height: 16.h),

                // ── Liste ─────────────────────────────────────────────────
                Expanded(
                  child: _paths.isEmpty && !_loading
                      ? _buildEmpty()
                      : ListView.builder(
                    controller: _scroll,
                    padding:  EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 32.h),
                    itemCount: _paths.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _paths.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(color: _blue)),
                        );
                      }
                      return _PathCard(path: _paths[i], index: i);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: active ? Colors.white : Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: active ? _blue : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.route_outlined, size: 60.w, color: _greyBlue.withOpacity(0.4)),
         SizedBox(height: 12.h),
        Text("Aucun trajet trouvé", style: GoogleFonts.poppins(fontSize: 15.sp, color: _greyBlue)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  CARD  –  un trajet dans la liste (avec adresses)
// ══════════════════════════════════════════════════════════════════════════════
class _PathCard extends StatefulWidget {
  final Map<String, dynamic> path;
  final int index;
  const _PathCard({required this.path, required this.index});

  @override
  State<_PathCard> createState() => _PathCardState();
}

class _PathCardState extends State<_PathCard> {
  String? _startAddress;
  String? _endAddress;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final p = widget.path;
    final hasCoords = p['begin_path_latitude'] != null &&
        p['begin_path_longitude'] != null &&
        p['end_path_latitude'] != null &&
        p['end_path_longitude'] != null;

    if (!hasCoords) {
      if (mounted) setState(() => _loadingAddresses = false);
      return;
    }

    final beginLat = (p['begin_path_latitude']  as num).toDouble();
    final beginLng = (p['begin_path_longitude'] as num).toDouble();
    final endLat   = (p['end_path_latitude']    as num).toDouble();
    final endLng   = (p['end_path_longitude']   as num).toDouble();

    final results = await Future.wait([
      _reverseGeocode(beginLat, beginLng),
      _reverseGeocode(endLat, endLng),
    ]);

    if (mounted) {
      setState(() {
        _startAddress    = results[0];
        _endAddress      = results[1];
        _loadingAddresses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.path;
    final date     = _fmtDate(p['begin_path_time']  as String?);
    final start    = _fmtTime(p['begin_path_time']  as String?);
    final end      = _fmtTime(p['end_path_time']    as String?);

    final hasCoords = p['begin_path_latitude'] != null &&
        p['begin_path_longitude'] != null &&
        p['end_path_latitude'] != null &&
        p['end_path_longitude'] != null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PathMapPage(path: p)),  // ✅ remplace PathDetailPage
      ),
      child: Container(
        margin:  EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            // ── Mini carte ────────────────────────────────────────────────
            if (hasCoords)
              ClipRRect(
                borderRadius:  BorderRadius.vertical(top: Radius.circular(24.r)),
                child: SizedBox(height: 130.h, child: _MiniMap(path: p)),
              ),

            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: EdgeInsets.all(7.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_blue, _blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(11.r),
                      ),
                      child: const Icon(Icons.route_rounded, color: Colors.white, size: 16),
                    ),
                     SizedBox(width: 10.w),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(date, style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.bold, color: _blueDark)),
                      Text("$start  →  $end", style: GoogleFonts.poppins(fontSize: 12.sp, color: _greyBlue)),
                    ]),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: _greyBlue, size: 20),
                  ]),

                  // ── Adresses départ / arrivée ─────────────────────────
                  if (hasCoords) ...[
                     SizedBox(height: 12.h),
                    _loadingAddresses
                        ? Row(children: [
                       SizedBox(width: 16.w, height: 16.h, child: CircularProgressIndicator(strokeWidth: 2.w, color: _blue)),
                       SizedBox(width: 8.w),
                      Text("Chargement des adresses...", style: GoogleFonts.poppins(fontSize: 11.sp, color: _greyBlue)),
                    ])
                        : Column(children: [
                      _addressRow(Icons.radio_button_checked, Colors.green, "Départ", _startAddress),
                       SizedBox(height: 6.h),
                      _addressRow(Icons.location_on, Colors.red, "Arrivée", _endAddress),
                    ]),
                  ],

                   SizedBox(height: 14.h),
                  const Divider(height: 1),
                   SizedBox(height: 14.h),

                  // Stats

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String label, String? address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
          child: Icon(icon, color: color, size: 12),
        ),
         SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 10.sp, color: _greyBlue)),
              Text(
                address ?? "Adresse non disponible",
                style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w500, color: _blueDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) => Column(
    children: [
      Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(9.r)),
        child: Icon(icon, color: _blue, size: 15),
      ),
       SizedBox(height: 5.h),
      Text(value, style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.bold, color: _blueDark)),
      Text(label, style: GoogleFonts.poppins(fontSize: 10.sp, color: _greyBlue)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  MINI CARTE
// ══════════════════════════════════════════════════════════════════════════════
class _MiniMap extends StatelessWidget {
  final Map<String, dynamic> path;
  const _MiniMap({required this.path});

  @override
  Widget build(BuildContext context) {
    final beginLat = (path['begin_path_latitude']  as num).toDouble();
    final beginLng = (path['begin_path_longitude'] as num).toDouble();
    final endLat   = (path['end_path_latitude']    as num).toDouble();
    final endLng   = (path['end_path_longitude']   as num).toDouble();

    final center = LatLng((beginLat + endLat) / 2, (beginLng + endLng) / 2);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: _calcZoom(beginLat, beginLng, endLat, endLng),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.tahkidrive',
        ),
        PolylineLayer(polylines: [
          Polyline(
            points: [LatLng(beginLat, beginLng), LatLng(endLat, endLng)],
            color: _blue,
            strokeWidth: 3.5,
          ),
        ]),
        MarkerLayer(markers: [
          _marker(LatLng(beginLat, beginLng), Colors.green, Icons.radio_button_checked),
          _marker(LatLng(endLat, endLng),     Colors.red,   Icons.location_on),
        ]),
      ],
    );
  }

  Marker _marker(LatLng point, Color color, IconData icon) => Marker(
    point: point,
    width: 32.w,
    height: 32.h,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    ),
  );

  double _calcZoom(double lat1, double lng1, double lat2, double lng2) {
    final maxDiff = [(lat1 - lat2).abs(), (lng1 - lng2).abs()].reduce((a, b) => a > b ? a : b);
    if (maxDiff < 0.005) return 14;
    if (maxDiff < 0.02)  return 13;
    if (maxDiff < 0.05)  return 12;
    if (maxDiff < 0.1)   return 11;
    if (maxDiff < 0.5)   return 10;
    if (maxDiff < 1.0)   return 9;
    return 8;
  }
}


