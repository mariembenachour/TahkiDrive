import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tahki_drive1/services/garage_service.dart';
import 'package:tahki_drive1/services/dashboard_service.dart';

class NearestMechanicsPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const NearestMechanicsPage({super.key, this.onBackToDashboard});

  @override
  State<NearestMechanicsPage> createState() => _NearestMechanicsPageState();
}

class _NearestMechanicsPageState extends State<NearestMechanicsPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  List<dynamic> _garages = [];
  List<dynamic> _allGarages = [];
  bool _isLoading = true;
  String? _error;

  int _currentLimit = 10;
  double? _currentMinRating;
  bool _filterByAll = true;
  bool _filterByDistance = false;
  bool _filterByRating = false;
  bool _filterByOpen = false;

  double _minRatingValueDistance = 0.0;
  double _minRatingValueRating = 0.0;
  bool _showRatingFilter = false;

  double? _userLat;
  double? _userLng;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
    _loadUserLocation();
    _loadGarages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    final userLocation = await DashService.fetchLocation();
    setState(() {
      if (userLocation != null) {
        _userLat = userLocation['latitude'];
        _userLng = userLocation['longitude'];
      }
      _loadingLocation = false;
    });
  }

  Future<void> _loadGarages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<dynamic> garages = [];

      if (_filterByRating) {
        final allGaragesList = await GarageService.getTopRatedGarages();
        _allGarages = allGaragesList;

        if (_minRatingValueRating > 0) {
          garages = allGaragesList.where((garage) {
            final rating = (garage['rating'] ?? 0).toDouble();
            return rating >= _minRatingValueRating;
          }).toList();
        } else {
          garages = allGaragesList;
        }

      } else if (_filterByDistance) {
        final userLocation = await DashService.fetchLocation();

        if (userLocation == null) {
          setState(() {
            _error = "Position non disponible. Activez la localisation.";
            _isLoading = false;
          });
          return;
        }

        garages = await GarageService.getNearestGarages(
          limit: _currentLimit,
          minRating: _minRatingValueDistance > 0 ? _minRatingValueDistance : null,
          latitude: userLocation['latitude'],
          longitude: userLocation['longitude'],
        );
        _allGarages = garages;
      } else if (_filterByOpen) {
        final allGaragesList = await GarageService.getAllGarages();
        _allGarages = allGaragesList;
        garages = allGaragesList.where((garage) {
          final horaires = garage['horaires'];
          return GarageOpenHelper.isOpenNow(horaires);
        }).toList();
      } else {
        final allGaragesList = await GarageService.getAllGarages();
        _allGarages = allGaragesList;
        garages = allGaragesList;
      }

      setState(() {
        _garages = garages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (filter == 'all') {
        _filterByAll = true;
        _filterByDistance = false;
        _filterByRating = false;
        _filterByOpen = false;
        _currentMinRating = null;
        _showRatingFilter = false;
      } else if (filter == 'distance') {
        _filterByAll = false;
        _filterByDistance = true;
        _filterByRating = false;
        _filterByOpen = false;
        _showRatingFilter = false;
      } else if (filter == 'rating') {
        _filterByAll = false;
        _filterByDistance = false;
        _filterByRating = true;
        _filterByOpen = false;
      } else if (filter == 'open') {
        _filterByAll = false;
        _filterByDistance = false;
        _filterByRating = false;
        _filterByOpen = true;
        _showRatingFilter = false;
      }
      _loadGarages();
    });
  }

  void _updateMinRatingDistance(double value) {
    setState(() {
      _minRatingValueDistance = value;
      _currentMinRating = value > 0 ? value : null;
    });
    _loadGarages();
  }

  void _updateMinRatingRating(double value) {
    setState(() {
      _minRatingValueRating = value;
    });
    _loadGarages();
  }

  void _toggleRatingFilter() {
    setState(() {
      _showRatingFilter = !_showRatingFilter;
      if (!_showRatingFilter) {
        _minRatingValueRating = 0.0;
        _loadGarages();
      }
    });
  }

  void _showWeeklyScheduleDialog(BuildContext context, String garageName, List<dynamic> horaires) {
    const joursOrdre = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

    final Map<String, dynamic> horairesMap = {};
    for (var horaire in horaires) {
      horairesMap[horaire['jour']] = horaire;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                      child: Text(
                        garageName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white54, height: 20),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Weekly Schedule",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...joursOrdre.map((jour) {
                  final horaire = horairesMap[jour];
                  final isToday = jour == _getCurrentDay();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isToday
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday
                          ? Border.all(color: Colors.white, width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isToday)
                              const Icon(Icons.today, color: Colors.white, size: 16),
                            if (isToday)
                              const SizedBox(width: 8),
                            Text(
                              jour,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (horaire != null)
                          Text(
                            horaire['est_ferme'] == true
                                ? "Fermé"
                                : "${horaire['heure_debut']} - ${horaire['heure_fin']}",
                            style: TextStyle(
                              color: horaire['est_ferme'] == true
                                  ? Colors.red[300]
                                  : Colors.white70,
                              fontSize: 13,
                            ),
                          )
                        else
                          const Text(
                            "Non disponible",
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Today is highlighted in white",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCallOptions(BuildContext context, String garageName, String? phoneNumber) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  garageName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4D2091),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              if (phoneNumber != null && phoneNumber.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    phoneNumber,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              if (phoneNumber != null && phoneNumber.isNotEmpty)
                _buildCallOption(
                  icon: Icons.phone,
                  iconColor: Colors.green,
                  title: "Appeler",
                  subtitle: phoneNumber,
                  onTap: () {
                    Navigator.pop(context);
                    _makePhoneCall(phoneNumber);
                  },
                ),
              if (phoneNumber != null && phoneNumber.isNotEmpty)
                _buildCallOption(
                  icon: Icons.copy,
                  iconColor: Colors.blue,
                  title: "Copier le numéro",
                  subtitle: phoneNumber,
                  onTap: () {
                    Navigator.pop(context);
                    _copyToClipboard(phoneNumber);
                  },
                ),
              _buildCallOption(
                icon: Icons.close,
                iconColor: Colors.red,
                title: "Annuler",
                subtitle: null,
                onTap: () {
                  Navigator.pop(context);
                },
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isLast = false,
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    if (!cleanNumber.startsWith('+') && !cleanNumber.startsWith('00')) {
      if (cleanNumber.startsWith('9') || cleanNumber.startsWith('2') || cleanNumber.startsWith('5')) {
        cleanNumber = '+216$cleanNumber';
      }
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Impossible de faire l'appel sur l'émulateur ")),
          );
        }
      }
    } catch (e) {
      print("Erreur appel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  void _copyToClipboard(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Numéro copié : $phoneNumber"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ================== FONCTIONS DE LA CARTE ==================

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    if (_userLat != null && _userLng != null) {
      markers.add(
        Marker(
          point: LatLng(_userLat!, _userLng!),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _showUserLocationDialog();
            },
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
              child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
    }

    List<dynamic> sortedGarages = List.from(_allGarages);
    if (_userLat != null && _userLng != null) {
      sortedGarages.sort((a, b) {
        double distA = a['distance_km'] ?? 9999;
        double distB = b['distance_km'] ?? 9999;
        return distA.compareTo(distB);
      });
    }

    for (int i = 0; i < sortedGarages.length; i++) {
      final garage = sortedGarages[i];
      final lat = garage['latitude'];
      final lng = garage['longitude'];

      if (lat != null && lng != null) {
        Color markerColor;
        if (i < 10) {
          markerColor = Colors.green;
        } else if (garage['rating'] != null && garage['rating'] >= 4.5) {
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
                _showGarageInfoDialog(garage);
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
                child: const Icon(Icons.build, color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showUserLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Votre position"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Latitude: ${_userLat?.toStringAsFixed(6)}"),
            Text("Longitude: ${_userLng?.toStringAsFixed(6)}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showGarageInfoDialog(dynamic garage) {
    final isOpen = garage['horaires'] != null
        ? GarageOpenHelper.isOpenNow(garage['horaires'])
        : false;
    final statusColor = isOpen ? Colors.green : Colors.red;
    final statusText = isOpen ? "Ouvert" : "Fermé";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                garage['nom'] ?? 'Garage',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (garage['rating'] != null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text("${garage['rating']} / 5"),
                ],
              ),
            const SizedBox(height: 8),
            if (garage['adresse'] != null)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(garage['adresse'])),
                ],
              ),
            const SizedBox(height: 8),
            if (garage['telephone'] != null)
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(garage['telephone']),
                ],
              ),
            if (garage['distance_km'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("${garage['distance_km']} km de vous"),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          if (garage['telephone'] != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _makePhoneCall(garage['telephone']);
              },
              icon: const Icon(Icons.phone, size: 16),
              label: const Text("Appeler"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D2091),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_loadingLocation || _userLat == null || _userLng == null) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(0.1),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7226FF)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenMapWithGaragesPage(
              userLat: _userLat!,
              userLng: _userLng!,
              garages: _allGarages,
            ),
          ),
        );
      },
      child: Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_userLat!, _userLng!),
                  initialZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
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
                top: 15,
                left: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fullscreen, color: Color(0xFF7226FF), size: 16),
                      SizedBox(width: 5),
                      Text(
                        "Cliquez pour agrandir",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B00CC), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 15,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem(Colors.green, "10 plus proches"),
                      _buildLegendItem(Colors.purple, "Note ≥ 4.5"),
                      _buildLegendItem(Colors.orange, "Note ≥ 3"),
                      _buildLegendItem(Colors.red, "Note < 3"),
                      _buildLegendItem(const Color(0xFF7226FF), "Votre position"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF160078)),
          ),
        ],
      ),
    );
  }

  Widget _luxuryAnimatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4D2091),
                  Color(0xFF5C3897),
                  Color(0xFFF0EDF6),
                  Color(0xFFF0EDF6),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 1. EN-TÊTE
                _luxuryAnimatedEntry(
                  delay: 0.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (widget.onBackToDashboard != null) {
                              widget.onBackToDashboard!();
                            }
                          },
                        ),
                        const Column(
                          children: [
                            Text("Nearest Mechanics",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text("Find nearby auto repair shops",
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                // 2. CARTE (AJOUTÉE ICI - EN HAUT)
                _buildMap(),
                const SizedBox(height: 12),
                // 3. FILTRES
                _luxuryAnimatedEntry(
                  delay: 0.2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleFilter('all'),
                          child: _buildFilterChip("All", Icons.format_list_bulleted, isSelected: _filterByAll),
                        ),
                        GestureDetector(
                          onTap: () => _toggleFilter('distance'),
                          child: _buildFilterChip("Distance", Icons.location_on_outlined, isSelected: _filterByDistance),
                        ),
                        GestureDetector(
                          onTap: () => _toggleFilter('rating'),
                          child: _buildFilterChip("Rating", Icons.star_outline, isSelected: _filterByRating),
                        ),
                        GestureDetector(
                          onTap: () => _toggleFilter('open'),
                          child: _buildFilterChip("Open", Icons.access_time, isSelected: _filterByOpen),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_filterByOpen) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Showing garages open today (${_getCurrentDay()} ${_getCurrentTime()})",
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Minimum rating: ${_minRatingValueDistance.toStringAsFixed(1)}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Slider(
                            value: _minRatingValueDistance,
                            min: 0,
                            max: 5,
                            divisions: 10,
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
                if (_filterByRating) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _showRatingFilter
                              ? [Colors.orange.shade800, Colors.deepOrange.shade600]
                              : [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: _showRatingFilter ? Colors.orange : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleRatingFilter,
                          borderRadius: BorderRadius.circular(25),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.filter_alt, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Filter by minimum rating",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (_minRatingValueRating > 0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "${_minRatingValueRating.toStringAsFixed(1)} ★",
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Icon(
                                          _showRatingFilter ? Icons.expand_less : Icons.expand_more,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (_showRatingFilter) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("0 ★", style: TextStyle(color: Colors.white70)),
                                            Text(
                                              "${_minRatingValueRating.toStringAsFixed(1)} ★",
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            const Text("5 ★", style: TextStyle(color: Colors.white70)),
                                          ],
                                        ),
                                        Slider(
                                          value: _minRatingValueRating,
                                          min: 0,
                                          max: 5,
                                          divisions: 10,
                                          activeColor: Colors.orange,
                                          inactiveColor: Colors.white30,
                                          thumbColor: Colors.white,
                                          label: _minRatingValueRating.toStringAsFixed(1),
                                          onChanged: _updateMinRatingRating,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(child: _buildRatingChip(1, _minRatingValueRating >= 1)),
                                            const SizedBox(width: 8),
                                            Expanded(child: _buildRatingChip(2, _minRatingValueRating >= 2)),
                                            const SizedBox(width: 8),
                                            Expanded(child: _buildRatingChip(3, _minRatingValueRating >= 3)),
                                            const SizedBox(width: 8),
                                            Expanded(child: _buildRatingChip(4, _minRatingValueRating >= 4)),
                                            const SizedBox(width: 8),
                                            Expanded(child: _buildRatingChip(5, _minRatingValueRating >= 5)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF)))
                      : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                      : _garages.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filterByOpen ? Icons.access_time : Icons.search_off,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterByOpen
                              ? "No garage open at this time"
                              : "No garage found",
                          style: const TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _garages.length,
                    itemBuilder: (context, index) {
                      final garage = _garages[index];
                      return _luxuryAnimatedEntry(
                        delay: 0.3 + (index * 0.05),
                        child: _buildShopCard(
                          name: garage['nom'] ?? 'Garage',
                          rating: (garage['rating'] ?? 0).toDouble(),
                          distance: garage['distance_km'] != null
                              ? '${garage['distance_km']} km'
                              : null,
                          address: garage['adresse'],
                          phone: garage['telephone'],
                          horaires: garage['horaires'],
                          garageData: garage,
                        ),
                      );
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

  String _getCurrentDay() {
    const joursFrancais = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final now = DateTime.now();
    return joursFrancais[now.weekday - 1];
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRatingChip(int stars, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _minRatingValueRating = stars.toDouble();
        });
        _loadGarages();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.orange : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star,
              size: 14,
              color: isActive ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              "$stars+",
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? Colors.white : Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildShopCard({
    required String name,
    required double rating,
    String? distance,
    String? address,
    String? phone,
    List<dynamic>? horaires,
    dynamic garageData,
  }) {
    final isOpen = horaires != null ? GarageOpenHelper.isOpenNow(horaires) : false;
    final statusText = horaires != null ? GarageOpenHelper.getOpenStatusText(horaires) : "Horaires non disponibles";
    final statusColor = horaires != null ? GarageOpenHelper.getOpenStatusColor(horaires) : Colors.grey;
    final openHours = horaires != null ? GarageOpenHelper.getTodayHours(horaires) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                  style: const TextStyle(color: Color(0xFF4904BD), fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (horaires != null && horaires.isNotEmpty) {
                _showWeeklyScheduleDialog(context, name, horaires);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: statusColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.black54, size: 14),
              const SizedBox(width: 4),
              if (distance != null) ...[
                Text(distance, style: const TextStyle(color: Colors.black54)),
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ] else if (address != null && address.isNotEmpty) ...[
                Expanded(
                  child: Text(address,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (openHours != null && openHours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.black54, size: 14),
                const SizedBox(width: 4),
                Text(
                  openHours,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _showCallOptions(context, name, phone);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text("Call", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_userLat != null && _userLng != null && garageData != null) {
                      _openGoogleMaps(_userLat!, _userLng!, garageData);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4904BD),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text("Navigate",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openGoogleMaps(double userLat, double userLng, dynamic garage) {
    final garageLat = garage['latitude'];
    final garageLng = garage['longitude'];
    final garageName = garage['nom'];

    if (garageLat != null && garageLng != null) {
      final url = 'https://www.google.com/maps/dir/$userLat,$userLng/$garageLat,$garageLng/${Uri.encodeComponent(garageName)}';
      launchUrl(Uri.parse(url));
    }
  }
}

// Page plein écran pour la carte
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
          child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
        ),
      ),
    );

    List<dynamic> sortedGarages = List.from(garages);
    sortedGarages.sort((a, b) {
      double distA = a['distance_km'] ?? 9999;
      double distB = b['distance_km'] ?? 9999;
      return distA.compareTo(distB);
    });

    for (int i = 0; i < sortedGarages.length; i++) {
      final garage = sortedGarages[i];
      final lat = garage['latitude'];
      final lng = garage['longitude'];

      if (lat != null && lng != null) {
        Color markerColor;
        if (i < 10) {
          markerColor = Colors.green;
        } else if (garage['rating'] != null && garage['rating'] >= 4.5) {
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
              child: const Icon(Icons.build, color: Colors.white, size: 22),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.green, size: 12),
                            SizedBox(width: 4),
                            Text("10 plus proches", style: TextStyle(fontSize: 10)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.purple, size: 12),
                            SizedBox(width: 4),
                            Text("Note ≥ 4.5", style: TextStyle(fontSize: 10)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.orange, size: 12),
                            SizedBox(width: 4),
                            Text("Note ≥ 3", style: TextStyle(fontSize: 10)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.red, size: 12),
                            SizedBox(width: 4),
                            Text("Note < 3", style: TextStyle(fontSize: 10)),
                          ],
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