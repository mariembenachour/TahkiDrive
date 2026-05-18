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
import '../../services/path_service.dart';

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
            height: 200,
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
                  padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _filter == 'date' && _pickedDate != null
                                  ? DateFormat('dd MMM').format(_pickedDate!)
                                  : 'Date',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Filtres ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _filterChip("Aujourd'hui", 'today'),
                    const SizedBox(width: 8),
                    _filterChip('Hier', 'yesterday'),
                    const SizedBox(width: 8),
                    _filterChip('Tous', 'all'),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Liste ─────────────────────────────────────────────────
                Expanded(
                  child: _paths.isEmpty && !_loading
                      ? _buildEmpty()
                      : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.white : Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
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
        Icon(Icons.route_outlined, size: 60, color: _greyBlue.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text("Aucun trajet trouvé", style: GoogleFonts.poppins(fontSize: 15, color: _greyBlue)),
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
    final km       = _fmtKm(p['distance_driven']);
    final duration = _fmtDuration(p['path_duration']);
    final speed    = _fmtSpeed(p['max_speed']);
    final fuel     = _fmtLitre(p['fuel_used']);

    final hasCoords = p['begin_path_latitude'] != null &&
        p['begin_path_longitude'] != null &&
        p['end_path_latitude'] != null &&
        p['end_path_longitude'] != null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PathDetailPage(path: p)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            // ── Mini carte ────────────────────────────────────────────────
            if (hasCoords)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(height: 130, child: _MiniMap(path: p)),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_blue, _blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.route_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(date, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _blueDark)),
                      Text("$start  →  $end", style: GoogleFonts.poppins(fontSize: 12, color: _greyBlue)),
                    ]),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: _greyBlue, size: 20),
                  ]),

                  // ── Adresses départ / arrivée ─────────────────────────
                  if (hasCoords) ...[
                    const SizedBox(height: 12),
                    _loadingAddresses
                        ? Row(children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
                      const SizedBox(width: 8),
                      Text("Chargement des adresses...", style: GoogleFonts.poppins(fontSize: 11, color: _greyBlue)),
                    ])
                        : Column(children: [
                      _addressRow(Icons.radio_button_checked, Colors.green, "Départ", _startAddress),
                      const SizedBox(height: 6),
                      _addressRow(Icons.location_on, Colors.red, "Arrivée", _endAddress),
                    ]),
                  ],

                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stat(Icons.straighten_rounded,        km,       "Distance"),
                      _stat(Icons.timer_rounded,             duration, "Durée"),
                      _stat(Icons.speed_rounded,             speed,    "Vit. max"),
                      _stat(Icons.local_gas_station_rounded, fuel,     "Carburant"),
                    ],
                  ),
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
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 10, color: _greyBlue)),
              Text(
                address ?? "Adresse non disponible",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: _blueDark),
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: _blue, size: 15),
      ),
      const SizedBox(height: 5),
      Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _blueDark)),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: _greyBlue)),
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
    width: 32,
    height: 32,
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

// ══════════════════════════════════════════════════════════════════════════════
//  PAGE DÉTAIL  –  avec adresses reverse geocodées
// ══════════════════════════════════════════════════════════════════════════════
class PathDetailPage extends StatefulWidget {
  final Map<String, dynamic> path;
  const PathDetailPage({super.key, required this.path});

  @override
  State<PathDetailPage> createState() => _PathDetailPageState();
}

class _PathDetailPageState extends State<PathDetailPage> {
  late final MapController _mapController;
  bool _mapExpanded = false;

  String? _startAddress;
  String? _endAddress;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    if (!_hasCoords) {
      if (mounted) setState(() => _loadingAddresses = false);
      return;
    }

    final results = await Future.wait([
      _reverseGeocode(_beginLat, _beginLng),
      _reverseGeocode(_endLat, _endLng),
    ]);

    if (mounted) {
      setState(() {
        _startAddress    = results[0];
        _endAddress      = results[1];
        _loadingAddresses = false;
      });
    }
  }

  bool get _hasCoords =>
      widget.path['begin_path_latitude']  != null &&
          widget.path['begin_path_longitude'] != null &&
          widget.path['end_path_latitude']    != null &&
          widget.path['end_path_longitude']   != null;

  double get _beginLat => (widget.path['begin_path_latitude']  as num).toDouble();
  double get _beginLng => (widget.path['begin_path_longitude'] as num).toDouble();
  double get _endLat   => (widget.path['end_path_latitude']    as num).toDouble();
  double get _endLng   => (widget.path['end_path_longitude']   as num).toDouble();
  double get _centerLat => (_beginLat + _endLat) / 2;
  double get _centerLng => (_beginLng + _endLng) / 2;

  @override
  Widget build(BuildContext context) {
    final p = widget.path;

    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        slivers: [

          // ── SliverAppBar avec carte ───────────────────────────────────────
          SliverAppBar(
            expandedHeight: _mapExpanded ? 420 : 280,
            pinned: true,
            backgroundColor: _blueDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_hasCoords)
                IconButton(
                  icon: Icon(
                    _mapExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _mapExpanded = !_mapExpanded),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _hasCoords
                  ? _buildDetailMap()
                  : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_blue, _blueDark]),
                ),
                child: const Center(
                  child: Icon(Icons.location_off_rounded, color: Colors.white54, size: 60),
                ),
              ),
            ),
          ),

          // ── Header info trajet ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue, _blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _fmtDate(p['begin_path_time'] as String?),
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_fmtTime(p['begin_path_time'] as String?)}  →  ${_fmtTime(p['end_path_time'] as String?)}",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                  ),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _fmtDuration(p['path_duration']),
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),

          // ── Adresses ──────────────────────────────────────────────────────
          if (_hasCoords)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: _loadingAddresses
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
                    ),
                  )
                      : Column(
                    children: [
                      _addressDetailRow(
                        icon: Icons.radio_button_checked,
                        color: Colors.green,
                        label: "Départ",
                        address: _startAddress,
                        coords: "${_beginLat.toStringAsFixed(5)}, ${_beginLng.toStringAsFixed(5)}",
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            SizedBox(height: 2),
                            DashedLine(),
                            SizedBox(height: 2),
                          ],
                        ),
                      ),
                      _addressDetailRow(
                        icon: Icons.location_on,
                        color: Colors.red,
                        label: "Arrivée",
                        address: _endAddress,
                        coords: "${_endLat.toStringAsFixed(5)}, ${_endLng.toStringAsFixed(5)}",
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Résumé stats ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(child: _sectionTitle("Résumé")),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                childAspectRatio: 2.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _bigStat(Icons.straighten_rounded,        _fmtKm(p['distance_driven']),    "Distance",   Colors.blue.shade600),
                  _bigStat(Icons.speed_rounded,             _fmtSpeed(p['max_speed']),        "Vit. max",   Colors.orange.shade600),
                  _bigStat(Icons.local_gas_station_rounded, _fmtLitre(p['fuel_used']),        "Carburant",  Colors.red.shade400),
                  _bigStat(Icons.timer_rounded,             _fmtDuration(p['path_duration']), "Durée",      Colors.purple.shade400),
                ],
              ),
            ),
          ),

          // ── Carburant ─────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(child: _sectionTitle("Carburant")),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _detailCard([
                _row(Icons.battery_full_rounded,      "Début",    _fmtLitre(p['start_fuel']), Colors.green),
                _row(Icons.battery_2_bar_rounded,     "Fin",      _fmtLitre(p['end_fuel']),   Colors.red.shade400),
                _row(Icons.local_gas_station_rounded, "Consommé", _fmtLitre(p['fuel_used']),  Colors.orange.shade600),
              ]),
            ),
          ),

          // ── Kilométrage ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(child: _sectionTitle("Kilométrage")),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _detailCard([
                _row(Icons.radio_button_unchecked, "Compteur départ",  '${(p['start_odo'] as num?)?.toInt() ?? 0} km', _blue),
                _row(Icons.radio_button_checked,   "Compteur arrivée", '${(p['end_odo']   as num?)?.toInt() ?? 0} km', _blueDark),
                _row(Icons.straighten_rounded,     "Distance",         _fmtKm(p['distance_driven']), Colors.teal),
              ]),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _addressDetailRow({
    required IconData icon,
    required Color color,
    required String label,
    required String? address,
    required String coords,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 11, color: _greyBlue)),
              const SizedBox(height: 2),
              Text(
                address ?? "Adresse non disponible",
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _blueDark),
              ),
              const SizedBox(height: 2),
              Text(coords, style: GoogleFonts.poppins(fontSize: 10, color: _greyBlue)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailMap() {
    final initZoom = _calcZoom(_beginLat, _beginLng, _endLat, _endLng);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_centerLat, _centerLng),
        initialZoom: initZoom,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
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
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
          ),
        ]),
        MarkerLayer(markers: [
          _mapMarker(LatLng(_beginLat, _beginLng), Colors.green, Icons.radio_button_checked_rounded, "Départ"),
          _mapMarker(LatLng(_endLat, _endLng),     Colors.red,   Icons.location_on_rounded,          "Arrivée"),
        ]),
      ],
    );
  }

  Marker _mapMarker(LatLng point, Color color, IconData icon, String label) => Marker(
    point: point,
    width: 44,
    height: 54,
    alignment: Alignment.topCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: GoogleFonts.poppins(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

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

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _blueDark)),
  );

  Widget _bigStat(IconData icon, String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _blueDark)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: _greyBlue)),
      ]),
    ]),
  );

  Widget _detailCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Column(
      children: rows.expand((w) => [w, const Divider(height: 18)]).toList()..removeLast(),
    ),
  );

  Widget _row(IconData icon, String label, String value, Color color) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 15),
    ),
    const SizedBox(width: 12),
    Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: _greyBlue))),
    Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _blueDark)),
  ]);
}

// ── Ligne pointillée décorative entre départ/arrivée ─────────────────────────
class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _greyBlue.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashSpace  = 3.0;
    double startY = 0;
    final x = size.width / 2;

    while (startY < size.height) {
      canvas.drawLine(Offset(x, startY), Offset(x, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
