import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tahki_drive1/menus/GlobalNavBar.dart';
import 'package:tahki_drive1/pages/Auth/LoginPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/DailyReportPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/problem_history_page.dart';
import 'package:tahki_drive1/services/auth_service.dart';
import 'package:tahki_drive1/services/dashboard_service.dart' as DashService;
import 'package:tahki_drive1/services/detailsPannes_service.dart';
import 'DetailsCar.dart';
import 'detailsPannes.dart';
import 'FullScreenMapPage.dart';

class Dashboard extends StatefulWidget {
  final VoidCallback onSwitchProfile;
  const Dashboard({super.key, required this.onSwitchProfile});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  // ================== ANIMATION CONTROLLER ==================
  late AnimationController _controller;
  String? _currentAddress;
  bool _loadingAddress = false;
  // ================== DONNÉES MAINTENANCE ==================
  Map<String, dynamic>? _batteryData;
  Map<String, dynamic>? _oilChangeData;
  Map<String, dynamic>? _brakeData;        // ← AJOUTÉ
  Map<String, dynamic>? _embrayageData;    // ← AJOUTÉ
  double? _temperatureData;
  Map<String, dynamic>? _firstVehicule; // ← AJOUTÉ


  // ================== DONNÉES LOCALISATION & CARBURANT ==================
  double? vehicleLat;
  double? vehicleLng;
  bool loadingLocation = true;
  double odo = 0;
  double journalier = 0;
  bool loadingOdo = true;
  double fuelRemaining = 0;
  double fuelConsumption = 0;
  bool loadingFuel = true;

  // ================== GRADIENT ==================
  final Gradient _brandGradient = const LinearGradient(
    colors: [Color(0xFF7226FF), Color(0xFF160078)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ================== INIT ==================
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _controller.forward();

    _loadAllData();
    _loadVehicule();

  }
  Future<void> _loadVehicule() async {
    try {
      final dataList = await DashService.DashService.getUserVehicules();
      if (!mounted) return; // ← ajouter ici
      if (dataList.isNotEmpty) {
        setState(() => _firstVehicule = dataList[0]);
      }
    } catch (e) {
      print("❌ ERROR load vehicule: $e");
    }
  }
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadBatteryData(),
      _loadOilChangeData(),
      _loadBrakeData(),
      _loadEmbrayageData(),
      _loadTemperatureData(),
      _loadLocation(),
      _loadOdo(),
      _loadFuel(),
    ]);
  }

  Future<void> _loadBatteryData() async {
    try {
      final data = await DetailPannesService.fetchBattery();
      if (!mounted) return; // ← ajouter ici
      setState(() => _batteryData = data?["last"]);
    } catch (e) {
      print("Erreur battery: $e");
      if (!mounted) return; // ← ajouter ici
      setState(() => _batteryData = null);
    }
  }
  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }
  Future<void> _loadOilChangeData() async {
    try {
      final data = await DetailPannesService.fetchOilChange();
      if (!mounted) return; // ← ajouter ici
      setState(() => _oilChangeData = data?["last"]);
    } catch (e) {
      print("Erreur oil change: $e");
      if (!mounted) return; // ← ajouter ici
      setState(() => _oilChangeData = null);
    }
  }

  Future<void> _loadBrakeData() async {
    try {
      final data = await DetailPannesService.fetchBrake();
      if (!mounted) return; // ← ajouter ici
      setState(() => _brakeData = data?["last"]);
    } catch (e) {
      print("Erreur brake: $e");
      if (!mounted) return; // ← ajouter ici
      setState(() => _brakeData = null);
    }
  }
  Future<void> _loadEmbrayageData() async {
    try {
      final data = await DetailPannesService.fetchEmbrayage();
      if (!mounted) return; // ← ajouter ici
      setState(() => _embrayageData = data?["last"]);
    } catch (e) {
      print("Erreur embrayage: $e");
      if (!mounted) return; // ← ajouter ici
      setState(() => _embrayageData = null);
    }
  }
  Future<void> _loadTemperatureData() async {
    final data = await DashService.DashService.getLastTemp();
    if (!mounted) return; // ← ajouter ici
    if (data != null && data != "Pas de donnée") {
      setState(() => _temperatureData = double.tryParse(data.toString()) ?? 0.0);
    }
  }
  Future<void> _loadLocation() async {
    try {
      final data = await DashService.DashService.fetchLocation();
      if (!mounted) return; // ← ajouter ici
      if (data != null) {
        setState(() {
          vehicleLat = (data["latitude"] ?? 0).toDouble();
          vehicleLng = (data["longitude"] ?? 0).toDouble();
          loadingLocation = false;
        });
      } else {
        setState(() => loadingLocation = false);
      }
    } catch (e) {
      if (!mounted) return; // ← ajouter ici
      setState(() => loadingLocation = false);
      print("Erreur fetchLocation: $e");
    }
  }

  Future<void> _loadFuel() async {
    try {
      final data = await DashService.DashService.fetchFuel();
      if (!mounted) return; // ← ajouter ici
      if (data != null) {
        setState(() {
          fuelRemaining = (data["remaining_fuel"] ?? 0).toDouble();
          fuelConsumption = (data["last_consumption"]?["fuel"] ?? 0).toDouble();
          loadingFuel = false;
        });
      } else {
        setState(() {
          fuelRemaining = 0;
          fuelConsumption = 0;
          loadingFuel = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // ← ajouter ici
      setState(() {
        fuelRemaining = 0;
        fuelConsumption = 0;
        loadingFuel = false;
      });
      print("Erreur fetchFuel: $e");
    }
  }
  Future<void> _loadOdo() async {
    try {
      final data = await DashService.DashService.fetchOdo();
      if (!mounted) return; // ← ajouter ici
      if (data != null) {
        setState(() {
          odo = data["odo"] ?? 0;
          journalier = data["journalier"] ?? 0;
          loadingOdo = false;
        });
      } else {
        setState(() {
          odo = 0;
          journalier = 0;
          loadingOdo = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // ← ajouter ici
      setState(() {
        odo = 0;
        journalier = 0;
        loadingOdo = false;
      });
      print("Erreur fetchOdo: $e");
    }
  }
  Future<void> _getDriverIdAndNavigate() async {
    if (mounted) {
      // Récupérer le CIN actuel depuis AuthService
      final cin = await AuthService.getCin() ?? '';

      if (cin.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProblemHistoryPage(cin: cin),
          ),
        );
      } else {
        // Optionnel : afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger l\'historique des problèmes'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ================== DIALOGS ==================
  void _showBatteryDetails() {
    final lastService = _batteryData;

    showGeneralDialog(

      context: context,
      barrierDismissible: true,
      barrierLabel: "Battery",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7226FF), Color(0xFF160078)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.battery_charging_full,
                      color: Colors.white,
                      size: 45,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "BATTERIE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          // On crée une variable locale pour raccourcir le code

                          _buildDialogRow(
                            "Coût",
                            "${lastService?['cost'] ?? '-'} DT",
                          ),
                          _buildDialogRow(
                            "Info", // Corrigé : 'description' au lieu de 'observation'
                            lastService?['description'] ?? '-',
                          ),
                          _buildDialogRow(
                            "Date",
                            lastService?['date_reparation'] != null
                                ? lastService!['date_reparation'].toString().split('T')[0]
                                : '-',
                          ),

                          _buildDialogRow(
                            "Garage",
                            lastService?['garage']?['nom'] ?? '-',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "Fermer",
                          style: TextStyle(
                            color: Color(0xFF7226FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOilChangeDetails() {
    final lastOil = _oilChangeData;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "OilChange",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.oil_barrel_rounded,
                      color: Colors.white,
                      size: 45,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "HUILE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        // Création d'un raccourci pour pointer sur le dernier entretien

                        children: [
                          _buildDialogRow(
                            "Coût",
                            "${lastOil?['cost'] ?? '-'} DT",
                          ),
                          _buildDialogRow(
                            "Info", // Corrigé : 'description' au lieu d'observation
                            lastOil?['description'] ?? '-',
                          ),
                          _buildDialogRow(
                            "Date",
                            lastOil?['date_reparation'] != null
                                ? lastOil!['date_reparation'].toString().split('T')[0]
                                : '-',
                          ),

                          _buildDialogRow(
                            "Garage",
                            lastOil?['garage']?['nom'] ?? '-',
                          ),
                        ],

                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "Fermer",
                          style: TextStyle(
                            color: Color(0xFFFF8C00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBrakeDetails() {
    final data = _brakeData ?? {};
    final garage = data['garage'] ?? {};
    final lastBrake = _brakeData;


    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Brake",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.car_repair, color: Colors.white, size: 45),
                    const SizedBox(height: 8),
                    const Text(
                      "FREINAGE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          // 1. On récupère d'abord l'objet qui contient les dernières infos

// 2. On affiche les lignes

                          _buildDialogRow(
                            "Coût",
                            "${lastBrake?['cost'] ?? '-'} DT",
                          ),
                          _buildDialogRow(
                            "Info", // Corrigé : 'description' au lieu d'observation
                            lastBrake?['description'] ?? '-',
                          ),
                          _buildDialogRow(
                            "Date",
                            lastBrake?['date_reparation'] != null
                                ? lastBrake!['date_reparation'].toString().split('T')[0]
                                : '-',
                          ),
                          _buildDialogRow(
                            "Garage",
                            lastBrake?['garage']?['nom'] ?? '-', // Accès sécurisé au nom du garage
                          ),
                        ],

                      ),
                    ),

                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "Fermer",
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  void _showEmbrayageDetails() {
    final data = _embrayageData ?? {};
    final garage = data["garage"] ?? {};
    final lastEmbrayage = _embrayageData;


    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Embrayage",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.gears, color: Colors.white, size: 45),
                    const SizedBox(height: 8),
                    const Text("EMBRAYAGE", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [

                          _buildDialogRow(
                            "Coût",
                            "${lastEmbrayage?['cost'] ?? '-'} DT",
                          ),
                          _buildDialogRow(
                            "Info", // Corrigé : 'description' au lieu d'observation
                            lastEmbrayage?['description'] ?? '-',
                          ),
                          _buildDialogRow(
                            "Date",
                            lastEmbrayage?['date_reparation'] != null
                                ? lastEmbrayage!['date_reparation'].toString().split('T')[0]
                                : '-',
                          ),
                          _buildDialogRow(
                            "Garage",
                            lastEmbrayage?['garage']?['nom'] ?? '-',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: const Text("Fermer", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value?.toString() ?? "N/A",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // ================== ANIMATION ==================
  Widget _luxuryAnimatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(parent: _controller, curve: Interval(delay, 1, curve: Curves.easeOutBack));
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
            child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(animation), child: child),
          ),
        );
      },
    );
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
    print("TOP IMAGE URL: $topImageUrl");
    return topImageUrl;
  }
  dynamic findEvent(List events, String type) {
    try {
      return events.firstWhere((e) => e['doc_type'] == type);
    } catch (e) {
      return null;
    }
  }
  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4904BD), Color(0xFFF0EDF6)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 70),

                      // ================== CARTE VÉHICULE DYNAMIQUE ==================
                      FutureBuilder<List<dynamic>>(
                        future: DashService.DashService.getUserVehicules(),
                        builder: (context, snapshot) {

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text("Aucun véhicule trouvé"));
                          }

                          final vehicules = snapshot.data!;

                          return Column(
                            children: vehicules.map((v) {

                              final events = v['events'] as List<dynamic>? ?? [];

                              final insuranceDoc = findEvent(events, "INSURANCE");
                              final visitDoc = findEvent(events, "VISIT");

                              String getDate(dynamic doc) {
                                if (doc == null || doc['end_date'] == null) return "N/A";
                                return doc['end_date'].toString().split('T')[0];
                              }

                              return _luxuryAnimatedEntry(
                                delay: 0.1,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CarDetailsPage(car: v),
                                    ),
                                  ),

                                  child: Container(
                                    height: 400,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(35),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                        )
                                      ],
                                    ),

                                    child: Stack(
                                      children: [

                                        // ================= INFO CAR =================
                                        Positioned(
                                          top: 25,
                                          left: 25,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${v['mark']} ${v['model']}",
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                v['matricule'] ?? "",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black38,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // ================= IMAGE =================
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: -400, end: -200),
                                          duration: const Duration(milliseconds: 1500),
                                          curve: Curves.easeOutQuart,
                                          builder: (context, value, child) {

                                            String imageUrl = 'images/automobile.png';

                                            try {
                                              if (v['images'] != null && v['images'].toString().isNotEmpty) {
                                                var decoded = jsonDecode(v['images']) as List;
                                                if (decoded.isNotEmpty) {
                                                  imageUrl = 'http://10.0.2.2:8000/${decoded[0]}';
                                                }
                                              }
                                            } catch (_) {}

                                            return Positioned(
                                              top: 200,
                                              bottom: 100,
                                              left: value,
                                              right: 20,
                                              child: Transform.scale(
                                                scale: 3.8,
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.directions_car, size: 80),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // ================= DOCS =================
                                        Positioned(
                                          bottom: 25,
                                          left: 20,
                                          right: 20,
                                          child: Row(
                                            children: [

                                              Expanded(
                                                child: _buildInfoCard(
                                                  "INSURANCE",
                                                  getDate(insuranceDoc),
                                                ),
                                              ),

                                              const SizedBox(width: 20),

                                              Expanded(
                                                child: _buildInfoCard(
                                                  "VISIT",
                                                  getDate(visitDoc),
                                                ),
                                              ),

                                            ],
                                          ),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                              );

                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                     /* ElevatedButton(
                        onPressed: () async {
                          final cin = await AuthService.getCin() ?? '';
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DailyReportPage(cin: cin),
                          ));
                        },
                        child: const Text('Test Rapport'),
                      ),*/
                      // ================== CARROUSEL KILOMÉTRAGE + CARBURANT ==================
                      _luxuryAnimatedEntry(
                        delay: 0.25,
                        child: SizedBox(
                          height: 225,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                // Carte Kilométrage
                                Container(
                                  width: 370,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20)]),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.speed, size: 18, color: Color(0xFF7226FF))),
                                          const SizedBox(width: 10),
                                          _buildGradientText("Kilométrage", 20, FontWeight.bold),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      loadingOdo ? const CircularProgressIndicator() : _buildGradientText("${odo.toStringAsFixed(0)} km", 30, FontWeight.bold),
                                      const SizedBox(height: 18),
                                      loadingOdo ? const SizedBox() : _buildStatRow("Journalier", "${journalier.toStringAsFixed(0)} km/j", (journalier / 100).clamp(0.0, 1.0)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),

                                // Carte Carburant
                                Container(
                                  width: 370,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.15), blurRadius: 20)]),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.local_gas_station, size: 23, color: Color(0xFF7226FF))),
                                          const SizedBox(width: 10),
                                          _buildGradientText("Carburant", 23, FontWeight.bold),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      loadingFuel
                                          ? const Center(child: CircularProgressIndicator())
                                          : Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildCircularStat("Restant", "${fuelRemaining.toStringAsFixed(1)} L", (fuelRemaining / 100).clamp(0.0, 1.0), Colors.purpleAccent),
                                          _buildCircularStat("Conso", "${fuelConsumption.toStringAsFixed(1)} L/100km", (fuelConsumption / 100).clamp(0.0, 1.0), Colors.deepPurple),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // ================== SECTION VOITURE TOP + TEMPÉRATURE + ENTRETIENS ==================
                      _luxuryAnimatedEntry(
                        delay: 0.4,
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          transitionDuration: const Duration(milliseconds: 800),
                                          reverseTransitionDuration: const Duration(milliseconds: 800),
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                          const PanneDetailsPage(),
                                        ),
                                      );
                                    },
                                    child: Hero(
                                      tag: 'car_top_view',
                                      child: Container(
                                        height: 270,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(28),
                                          gradient: const RadialGradient(
                                            center: Alignment.center,
                                            radius: 0.8,
                                            colors: [Color(0xFFB388FF), Color(0xFFEDE7FF), Colors.white],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.deepPurple.withOpacity(0.25),
                                              blurRadius: 20,
                                              offset: const Offset(0, 12),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Stack(
                                            children: [
                                              // ← IMAGE DYNAMIQUE 3ᵉ IMAGE DU BACK
                                              Positioned(
                                                left: 27,
                                                top: 15,
                                                child: () {
                                                  final url = _getTopImageUrl();
                                                  return url.isNotEmpty
                                                      ? Image.network(
                                                    url,
                                                    height: 250,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Text(
                                                        "ERREUR IMAGE",
                                                        style: TextStyle(
                                                            color: Colors.red,
                                                            fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  )
                                                      : const SizedBox();
                                                }(),
                                              ),
                                              // ← INFO "Cliquez pour voir panne"
                                              Positioned(
                                                top: 15,
                                                right: 15,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.85),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.info_outline,
                                                          size: 14, color: Colors.deepPurple.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Cliquez pour voir panne',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.deepPurple.shade800,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildVerticalTempCard(percent: (_temperatureData ?? 0) / 100, temp: _temperatureData ?? 0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Text("Derniers entretiens", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 160,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: _showBatteryDetails,
                                    child: _buildExtraLargeStatusCard(
                                      title: "BATTERIE",
                                      icon: Icons.battery_charging_full,
                                      lastChange: _batteryData?['date_reparation'] != null
                                          ? _batteryData!['date_reparation'].toString().split('T')[0].split('-').reversed.join('/')
                                          : "...",
                                      isDark: true,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  GestureDetector(
                                    onTap: _showOilChangeDetails,
                                    child: _buildExtraLargeStatusCard(
                                      title: "HUILE",
                                      icon: Icons.oil_barrel_rounded,
                                      lastChange: _oilChangeData?['date_reparation'] != null
                                          ? _oilChangeData!['date_reparation'].toString().split('T')[0].split('-').reversed.join('/')
                                          : "...",
                                      isDark: false,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  GestureDetector(
                                    onTap: _showBrakeDetails,
                                    child: _buildExtraLargeStatusCard(
                                      title: "FREINAGE",
                                      icon: Icons.car_repair,
                                      lastChange: _brakeData?['date_reparation'] != null
                                          ? _brakeData!['date_reparation'].toString().split('T')[0].split('-').reversed.join('/')
                                          : "...",
                                      isDark: true,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  GestureDetector(
                                    onTap: _showEmbrayageDetails,
                                    child: _buildExtraLargeStatusCard(
                                      title: "EMBRAYAGE",
                                      icon: Icons.settings,                                      lastChange: _embrayageData?['date_reparation'] != null
                                        ? _embrayageData!['date_reparation'].toString().split('T')[0].split('-').reversed.join('/')
                                        : "...",
                                      isDark: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ================== CARTE FLUTTER MAP ==================
                      _luxuryAnimatedEntry(
                        delay: 0.55,
                        child: GestureDetector(
                          onTap: () {
                            if (!loadingLocation && vehicleLat != null && vehicleLng != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenMapPage(latitude: vehicleLat!, longitude: vehicleLng!)));
                            }
                          },
                          child: Container(
                            height: 260,
                            width: double.infinity,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: loadingLocation
                                  ? Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF5F0FF), Color(0xFFE8DEFF), Colors.white])), child: const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF))))
                                  : vehicleLat == null || vehicleLng == null
                                  ? Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF5F0FF), Color(0xFFE8DEFF), Colors.white])), child: const Center(child: Text("Position non disponible", style: TextStyle(color: Color(0xFF7226FF), fontWeight: FontWeight.bold))))
                                  : Stack(
                                children: [
                                  FlutterMap(
                                    options: MapOptions(initialCenter: LatLng(vehicleLat!, vehicleLng!), initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                                    children: [
                                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.tahkidrive'),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(vehicleLat!, vehicleLng!),
                                            width: 45,
                                            height: 45,
                                            child: Container(
                                              decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)]), boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)]),
                                              child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: 15, left: 15,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.2), blurRadius: 10)]),
                                      child: const Row(children: [Icon(Icons.location_on, color: Color(0xFF7226FF), size: 16), SizedBox(width: 5), Text("Cliquez pour agrandir", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B00CC)))]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            right: 70, // ← décalé pour laisser place aux notifications
            child: GestureDetector(
              onTap: _logout,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          // ================== MENU SUPERIEUR ==================
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GlobalNavBar(
              currentIndex: 0,
              onTabSelected: (index) {
                if (index == 1) widget.onSwitchProfile();
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            right: 20,
            child: _buildFloatingButton(Icons.notifications_none_rounded),
          ),
        ],
      ),
    );
  }

  // ================== WIDGETS AIDE ==================
  Widget _buildGradientText(String text, double size, FontWeight weight) {
    return ShaderMask(
      shaderCallback: (bounds) => _brandGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: TextStyle(fontSize: size, fontWeight: weight, color: Colors.white)),
    );
  }

  Widget _buildStatRow(String label, String value, double percent) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
            _buildGradientText(value, 13, FontWeight.bold),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(height: 6, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10))),
            FractionallySizedBox(widthFactor: percent, child: Container(height: 6, decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(10)))),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingButton(IconData icon) {
    return GestureDetector(
      onTap: () {
        _getDriverIdAndNavigate();
      },
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          gradient: _brandGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildVerticalTempCard({required double percent, required double temp}) {
    return Container(
      height: 270,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.thermostat, color: Colors.white, size: 32)),
            const SizedBox(height: 15),
            Text(
              "TEMPÉRATURE MOTEUR",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("${temp.toStringAsFixed(1)}°C", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            LinearProgressIndicator(value: percent, backgroundColor: Colors.white.withOpacity(0.3), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 8, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularStat(String label, String value, double percent, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(width: 70, height: 70, child: CircularProgressIndicator(value: percent, strokeWidth: 8, backgroundColor: Colors.grey[200], color: color, strokeCap: StrokeCap.round)),
            Text("${(percent * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF160078))),
      ],
    );
  }

  Widget _buildExtraLargeStatusCard({required String title, required IconData icon, required String lastChange, required bool isDark}) {
    return Container(
      width: 350,
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? [Colors.deepPurple.shade800, Colors.deepPurple.shade600, Colors.deepPurple.shade400] : [Colors.amber.shade700, Colors.orange.shade600, Colors.deepOrange.shade400],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: (isDark ? Colors.deepPurple : Colors.orange).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(children: [Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.8), size: 14), const SizedBox(width: 6), Text("Dernier changement:", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15))]),
                  const SizedBox(height: 4),
                  Text(lastChange, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(margin: const EdgeInsets.only(left: 5), child: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), gradient: LinearGradient(colors: [const Color(0xFF4B00CC).withOpacity(0.6), const Color(0xFF9C7BFF).withOpacity(0.6)])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
