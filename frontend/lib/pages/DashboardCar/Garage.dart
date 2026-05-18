import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tahki_drive1/services/garage_service.dart';
import 'package:tahki_drive1/services/dashboard_service.dart';
import 'package:tahki_drive1/services/theme_service.dart';
import 'package:tahki_drive1/pages/DashboardCar/FullScreenMapWithGaragesPage.dart';

class NearestMechanicsPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const NearestMechanicsPage({super.key, this.onBackToDashboard});

  @override
  State<NearestMechanicsPage> createState() => _NearestMechanicsPageState();
}

class _NearestMechanicsPageState extends State<NearestMechanicsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  List<dynamic> _garages    = [];
  List<dynamic> _allGarages = [];
  bool   _isLoading = true;
  String? _error;

  // Filtres
  bool _filterByDistance = true;
  bool _filterByOpen     = false;
  double _minRatingValueDistance = 0.0;

  // Recherche
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery  = '';
  bool   _searchVisible = false;   // ← toggle barre

  // Debounce — évite les appels réseau en rafale (slider, recherche)
  Timer? _debounceTimer;

  // Localisation
  double? _userLat;
  double? _userLng;
  bool _loadingLocation = true;

  // ── Getter filtrage + tri ─────────────────────────────────────────────────
  List<dynamic> get _filteredGarages {
    List<dynamic> list = List.from(_garages);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((g) {
        final name = (g['nom'] ?? '').toString().toLowerCase();
        final addr = (g['adresse'] ?? '').toString().toLowerCase();
        final dist = (g['distance_km'] ?? '').toString();
        return name.contains(q) || addr.contains(q) || dist.contains(q);
      }).toList();
    }

    if (_filterByDistance) {
      list.sort((a, b) =>
          ((a['distance_km'] ?? 9999) as num)
              .compareTo((b['distance_km'] ?? 9999) as num));
    } else {
      list.sort((a, b) =>
          (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadUserLocation();
    await _loadGarages();
  }

  Future<void> _loadUserLocation() async {
    final loc = await DashService.fetchLocation();
    if (!mounted) return;
    setState(() {
      if (loc != null) {
        _userLat = loc['latitude'];
        _userLng = loc['longitude'];
      }
      _loadingLocation = false;
    });
  }

  Future<void> _loadGarages() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      List<dynamic> garages = [];
      if (_filterByDistance) {
        if (_userLat == null || _userLng == null) {
          final loc = await DashService.fetchLocation();
          if (!mounted) return;
          if (loc == null) {
            setState(() {
              _error = "Position non disponible. Activez la localisation.";
              _isLoading = false;
            });
            return;
          }
          _userLat = loc['latitude'];
          _userLng = loc['longitude'];
        }
        garages = await GarageService.getNearestGarages(
          latitude:  _userLat!,
          longitude: _userLng!,
          limit:     20,
          radiusM:   10000,
          minRating: _minRatingValueDistance > 0 ? _minRatingValueDistance : null,
        );
        if (!mounted) return;
        _allGarages = garages;
      } else if (_filterByOpen) {
        final all = await GarageService.getAllGarages(limit: 100);
        if (!mounted) return;
        _allGarages = all;
        garages = all.where((g) => GarageService.isOpenNow(g)).toList();
      }
      if (!mounted) return;
      setState(() { _garages = garages; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Filtres ───────────────────────────────────────────────────────────────
  void _toggleFilter(String filter) {
    setState(() {
      _filterByDistance = filter == 'distance';
      _filterByOpen     = filter == 'open';
      _searchQuery      = '';
      _searchController.clear();
    });
    _loadGarages();
  }

  void _updateMinRatingDistance(double value) {
    setState(() => _minRatingValueDistance = value);
    // Debounce : attend 600ms après le dernier mouvement du slider
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _loadGarages();
    });
  }

  // ── Toggle barre de recherche ─────────────────────────────────────────────
  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchQuery = '';
        _searchController.clear();
        _searchFocus.unfocus();
      } else {
        // auto-focus quand on ouvre
        Future.delayed(const Duration(milliseconds: 80),
                () => _searchFocus.requestFocus());
      }
    });
  }

  // ── Dialogues ─────────────────────────────────────────────────────────────
  void _showWeeklyScheduleDialog(
      BuildContext context, String garageName, Map<String, dynamic> garage) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4D2091), Color(0xFF5C3897)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(garageName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white54, height: 20),
              const Row(children: [
                Icon(Icons.schedule, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("Horaires d'ouverture",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              for (final day in ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'])
                _buildScheduleRow(day, garage['heure_ouverture'],
                    garage['heure_fermeture'], garage['conge']),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleRow(String day, String? open, String? close, String? conge) {
    final isToday  = day == _getCurrentDay();
    final isClosed = conge != null && conge.contains(day);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isToday
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: Colors.white, width: 1) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            if (isToday) ...[
              const Icon(Icons.today, color: Colors.white, size: 16),
              const SizedBox(width: 8),
            ],
            Text(day,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14)),
          ]),
          Text(
            isClosed
                ? "Fermé"
                : (open != null && close != null ? "$open - $close" : "Non disponible"),
            style: TextStyle(
                color: isClosed ? Colors.red[300] : Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showCallOptions(BuildContext context, String garageName, String? phoneNumber) {
    final isDark    = context.read<ThemeService>().isDark(context);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF4D2091);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(garageName,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  textAlign: TextAlign.center),
            ),
            if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(phoneNumber,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
              _buildCallOption(
                icon: Icons.phone, iconColor: Colors.green,
                title: "Appeler", subtitle: phoneNumber, isDark: isDark,
                onTap: () { Navigator.pop(context); _makePhoneCall(phoneNumber); },
              ),
              _buildCallOption(
                icon: Icons.copy, iconColor: Colors.blue,
                title: "Copier le numéro", subtitle: phoneNumber, isDark: isDark,
                onTap: () { Navigator.pop(context); _copyToClipboard(phoneNumber); },
              ),
            ],
            _buildCallOption(
              icon: Icons.close, iconColor: Colors.red,
              title: "Annuler", subtitle: null, isDark: isDark,
              onTap: () => Navigator.pop(context), isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallOption({
    required IconData icon, required Color iconColor,
    required String title, String? subtitle,
    required VoidCallback onTap, required bool isDark, bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87)),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }

  // ── Carte ─────────────────────────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_userLat != null && _userLng != null) {
      markers.add(Marker(
        point: LatLng(_userLat!, _userLng!),
        width: 50, height: 50,
        child: GestureDetector(
          onTap: _showUserLocationDialog,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                  colors: [Color(0xFF7226FF), Color(0xFF160078)]),
              boxShadow: [
                BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.6),
                    blurRadius: 10, spreadRadius: 2)
              ],
            ),
            child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
          ),
        ),
      ));
    }
    final sorted = List.from(_allGarages)
      ..sort((a, b) =>
          ((a['distance_km'] ?? 9999) as num)
              .compareTo((b['distance_km'] ?? 9999) as num));
    for (int i = 0; i < sorted.length; i++) {
      final g = sorted[i];
      final lat = g['latitude'];
      final lng = g['longitude'];
      if (lat == null || lng == null) continue;
      final Color color = i < 10 ? Colors.green : Colors.orange;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 40, height: 40,
        child: GestureDetector(
          onTap: () => _showGarageInfoDialog(g),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: color,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)
              ],
            ),
            child: const Icon(Icons.build, color: Colors.white, size: 22),
          ),
        ),
      ));
    }
    return markers;
  }

  void _showUserLocationDialog() {
    final isDark = context.read<ThemeService>().isDark(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A0035) : Colors.white,
        title: Text("Votre position",
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF160078))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Latitude: ${_userLat?.toStringAsFixed(6)}",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          Text("Longitude: ${_userLng?.toStringAsFixed(6)}",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer",
                  style: TextStyle(color: Color(0xFF7226FF)))),
        ],
      ),
    );
  }

  void _showGarageInfoDialog(dynamic garage) {
    final isDark      = context.read<ThemeService>().isDark(context);
    final isOpen      = GarageService.isOpenNow(garage);
    final statusColor = isOpen ? Colors.green : Colors.red;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A0035) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Expanded(
            child: Text(garage['nom'] ?? 'Garage',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF160078)),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: statusColor)),
              const SizedBox(width: 4),
              Text(isOpen ? "Ouvert" : "Fermé",
                  style: TextStyle(color: statusColor, fontSize: 12)),
            ]),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (garage['rating'] != null)
              Row(children: [
                const Icon(Icons.star, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text("${garage['rating']} / 5",
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87)),
              ]),
            if (garage['adresse'] != null && garage['adresse'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(garage['adresse'],
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87))),
              ]),
            ],
            if (garage['telephone'] != null && garage['telephone'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(garage['telephone'],
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87)),
              ]),
            ],
            if (garage['distance_km'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text("${garage['distance_km']} km de vous",
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87)),
              ]),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer",
                  style: TextStyle(color: Color(0xFF7226FF)))),
          if (garage['telephone'] != null && garage['telephone'].isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _makePhoneCall(garage['telephone']);
              },
              icon: const Icon(Icons.phone, size: 16),
              label: const Text("Appeler"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D2091),
                  foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    if (_loadingLocation || _userLat == null || _userLng == null) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(0.1),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF7226FF))),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenMapWithGaragesPage(
            userLat: _userLat!, userLng: _userLng!, garages: _allGarages,
          ),
        ),
      ),
      child: Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.deepPurple.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(_userLat!, _userLng!),
                initialZoom: 12,
                interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
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
              top: 15, left: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.2),
                        blurRadius: 10)
                  ],
                ),
                child: const Row(children: [
                  Icon(Icons.fullscreen, color: Color(0xFF7226FF), size: 16),
                  SizedBox(width: 5),
                  Text("Cliquez pour agrandir",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B00CC),
                          fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────
  Widget _luxuryAnimatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(animation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        ),
      ),
    );
  }

  String _getCurrentDay() {
    const days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    return days[DateTime.now().weekday - 1];
  }

  String _getCurrentTime() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}';
  }

  Widget _buildFilterChip(String label, IconData icon, {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? Colors.white : Colors.white24),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── Barre de recherche animée ─────────────────────────────────────────────
  Widget _buildSearchBar() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: _searchVisible
          ? Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white38),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _filterByDistance
                  ? 'Rechercher par nom ou km…'
                  : 'Rechercher par nom…',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon:
              const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.white54, size: 20),
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                }),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 4),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildShopCard({
    required String name,
    required double rating,
    String? distance,
    String? address,
    String? phone,
    required dynamic garageData,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    final statusTxt = GarageService.getOpenStatusText(garageData);
    final statusClr = GarageService.getOpenStatusColor(garageData);
    final hours     = GarageService.getTodayHours(garageData);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF4904BD),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
          if (rating > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.star, color: Colors.orange, size: 14),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showWeeklyScheduleDialog(
              context, name, garageData as Map<String, dynamic>),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusClr.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: statusClr)),
              const SizedBox(width: 6),
              Text(statusTxt,
                  style: TextStyle(
                      color: statusClr,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: statusClr),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.location_on,
              color: isDark ? Colors.white54 : Colors.black54, size: 14),
          const SizedBox(width: 4),
          if (distance != null) ...[
            Text(distance,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54)),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                  child: Text(address,
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
            ],
          ] else if (address != null && address.isNotEmpty)
            Expanded(
                child: Text(address,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
        ]),
        if (hours.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.schedule,
                color: isDark ? Colors.white54 : Colors.black54, size: 14),
            const SizedBox(width: 4),
            Text(hours,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12)),
          ]),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showCallOptions(context, name, phone),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.15) : Colors.black87,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                    child: Text("Appeler",
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.white))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_userLat != null && _userLng != null) {
                  _openGoogleMaps(_userLat!, _userLng!, garageData);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFF4904BD),
                    borderRadius: BorderRadius.circular(15)),
                child: const Center(
                    child: Text("Naviguer",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!clean.startsWith('+') && !clean.startsWith('00')) {
      if (clean.startsWith('9') || clean.startsWith('2') || clean.startsWith('5')) {
        clean = '+216$clean';
      }
    }
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Impossible de faire l'appel sur l'émulateur")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  void _copyToClipboard(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Numéro copié : $phoneNumber"),
          duration: const Duration(seconds: 2)));
    }
  }

  void _openGoogleMaps(double userLat, double userLng, dynamic garage) {
    final lat  = garage['latitude'];
    final lng  = garage['longitude'];
    final name = garage['nom'];
    if (lat != null && lng != null) {
      launchUrl(Uri.parse(
          'https://www.google.com/maps/dir/$userLat,$userLng/$lat,$lng/${Uri.encodeComponent(name)}'));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark    = context.watch<ThemeService>().isDark(context);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF160078);
    final garages   = _filteredGarages;

    return Scaffold(
      body: Stack(children: [
        Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0035), Color(0xFF0A0015)])
                : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4D2091), Color(0xFF5C3897),
                  Color(0xFFF0EDF6), Color(0xFFF0EDF6)
                ]),
          ),
        ),
        SafeArea(
          child: Column(children: [

            // ── En-tête ──────────────────────────────────────────────────
            _luxuryAnimatedEntry(
              delay: 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => widget.onBackToDashboard?.call(),
                    ),
                    const Column(children: [
                      Text("Mécaniciens proches",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text("Trouver un garage auto à proximité",
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                    // Icône loupe : ouvre/ferme la barre de recherche
                    IconButton(
                      icon: Icon(
                        _searchVisible ? Icons.search_off : Icons.search,
                        color: Colors.white,
                      ),
                      onPressed: _toggleSearch,
                    ),
                  ],
                ),
              ),
            ),

            // ── Barre de recherche (apparaît sous le header) ─────────────
            _buildSearchBar(),

            // Compteur résultats (visible seulement si recherche active)
            if (_searchVisible && _searchQuery.isNotEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${garages.length} résultat${garages.length > 1 ? 's' : ''} pour "$_searchQuery"',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),

            // ── Carte ────────────────────────────────────────────────────
            _buildMap(isDark),
            const SizedBox(height: 12),

            // ── Filtres ──────────────────────────────────────────────────
            _luxuryAnimatedEntry(
              delay: 0.2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  GestureDetector(
                      onTap: () => _toggleFilter('distance'),
                      child: _buildFilterChip("Distance",
                          Icons.location_on_outlined,
                          isSelected: _filterByDistance)),
                  GestureDetector(
                      onTap: () => _toggleFilter('open'),
                      child: _buildFilterChip("Ouvert", Icons.access_time,
                          isSelected: _filterByOpen)),
                ]),
              ),
            ),

            // Panneau filtre Ouvert
            if (_filterByOpen) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Garages ouverts aujourd'hui "
                            "(${_getCurrentDay()} ${_getCurrentTime()})",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ),
            ],

            // Panneau filtre Distance (note min)
            if (_filterByDistance) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.star, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Note minimum : ${_minRatingValueDistance.toStringAsFixed(1)}",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ]),
                      Slider(
                        value: _minRatingValueDistance,
                        min: 0, max: 5, divisions: 10,
                        activeColor: Colors.orange,
                        inactiveColor: Colors.white24,
                        label: _minRatingValueDistance.toStringAsFixed(1),
                        onChanged: _updateMinRatingDistance,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ── Liste des garages ─────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7226FF)))
                  : _error != null
                  ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white)))
                  : garages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty
                          ? Icons.search_off
                          : _filterByOpen
                          ? Icons.access_time
                          : Icons.search_off,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Aucun résultat pour "$_searchQuery"'
                          : _filterByOpen
                          ? "Aucun garage ouvert à cette heure"
                          : "Aucun garage trouvé",
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        }),
                        icon: const Icon(Icons.clear,
                            color: Colors.white54, size: 16),
                        label: const Text("Effacer la recherche",
                            style:
                            TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ],
                ),
              )
                  : ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: garages.length,
                itemBuilder: (context, index) {
                  final g = garages[index];
                  return _luxuryAnimatedEntry(
                    delay: 0.3 + (index * 0.05).clamp(0.0, 0.5),
                    child: _buildShopCard(
                      name: g['nom'] ?? 'Garage',
                      rating: (g['rating'] ?? 0).toDouble(),
                      distance: g['distance_km'] != null
                          ? '${g['distance_km']} km'
                          : null,
                      address: g['adresse'],
                      phone: g['telephone'],
                      garageData: g,
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
