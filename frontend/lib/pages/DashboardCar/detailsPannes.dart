import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/BrakeDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/DistributionDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/EmbrayageDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/MoteurDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/TireDetailsPage.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';
import 'package:tahki_drive1/services/dashboard_service.dart';
import 'package:tahki_drive1/services/detailsPannes_service.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import 'package:tahki_drive1/services/garage_service.dart';
import 'BatteryDetailsPage.dart';

const kPrimary  = Color(0xFF5B21B6);
const kAccent   = Color(0xFF7C3AED);
const kDanger   = Color(0xFFDC2626);
const kSurface  = Color(0xFFF8F7FF);
const kCard     = Colors.white;

// ─────────────────────────────────────────
//  PAGE PRINCIPALE
// ─────────────────────────────────────────
class PanneDetailsPage extends StatefulWidget {
  const PanneDetailsPage({super.key});
  @override
  State<PanneDetailsPage> createState() => _PanneDetailsPageState();
}

class _PanneDetailsPageState extends State<PanneDetailsPage>
    with TickerProviderStateMixin {
  String? imageUrl;
  bool isLoadingImage = true;
  double carScale = 1.2;
  Map<String, dynamic>? _firstVehicule;
  List<dynamic> _lastPannes = [];

  late AnimationController _entryController;
  late Animation<Offset> _carSlide;
  late Animation<double> _carFade;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _carSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entryController, curve: Curves.easeOutCubic));
    _carFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeIn));
    _entryController.forward();
    _loadVehicule();
    _loadLastPannes();
  }

  Future<void> _loadLastPannes() async {
    try {
      final pannes = await NotificationService.getLastPannes();
      if (mounted) setState(() => _lastPannes = pannes);
    } catch (e) {
      debugPrint("Erreur chargement pannes: $e");
    }
  }

  Future<void> _loadVehicule() async {
    if (mounted) setState(() => isLoadingImage = true);
    try {
      final dataList = await DashService.getUserVehicules();
      if (dataList.isNotEmpty) {
        _firstVehicule = dataList[0];
        if (mounted) setState(() {
          imageUrl = _getTopImageUrl();
          isLoadingImage = false;
        });
      } else {
        if (mounted) setState(() => isLoadingImage = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingImage = false);
    }
  }

  String _getTopImageUrl() {
    try {
      if (_firstVehicule?['images'] != null &&
          _firstVehicule!['images'].toString().isNotEmpty) {
        var decoded = jsonDecode(_firstVehicule!['images']) as List;
        if (decoded.length > 2) {
          return 'http://10.0.2.2:8000/${decoded[2]}';
        }
      }
    } catch (e) {
      debugPrint("Erreur image: $e");
    }
    return '';
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<Widget> _buildPannePoints(double imgH, double imgW) {
    return _lastPannes.map((panne) {
      Color dotColor = Colors.red;
      try {
        final hex = (panne['color'] as String).replaceAll('#', '');
        dotColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
      final double top  = ((panne['pos_top']  as num).toDouble()) * imgH;
      final double left = ((panne['pos_left'] as num).toDouble()) * imgW;
      return Positioned(
        top: top,
        left: left,
        child: GestureDetector(
          onTap: () => _showPanneDetailPopup(context, panne),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor
                          .withOpacity(0.6 * _pulseController.value),
                      blurRadius: 16 * _pulseController.value,
                      spreadRadius: 5 * _pulseController.value,
                    ),
                  ],
                ),
                child: const Icon(Icons.warning,
                    color: Colors.white, size: 16),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  void _showPanneDetailPopup(
      BuildContext context, Map<String, dynamic> panne) {
    Color dotColor = Colors.red;
    try {
      final hex = (panne['color'] as String).replaceAll('#', '');
      dotColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    final Map<String, String> positionLabels = {
      "moteur":       "🔧 Zone Moteur",
      "batterie":     "🔋 Zone Batterie",
      "freins":       "🛑 Zone Freins",
      "transmission": "⚙️ Zone Transmission",
      "pneu":         "🔵 Zone Pneu",
      "carburant":    "⛽ Zone Carburant",
      "surchauffe":   "🔥 Zone Surchauffe",
      "avant":        "⚠️ Zone Avant",
      "vitesse":      "💨 Vitesse",
      "conducteur":   "👤 Comportement Conducteur",
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1,
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dotColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning_rounded,
                        color: dotColor, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    panne['label'] ?? 'Panne détectée',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: kPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    panne['description'] ?? '',
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: dotColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      positionLabels[panne['position_key']] ??
                          '📍 Position inconnue',
                      style: TextStyle(
                        color: dotColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (panne['category'] ?? '').toString().toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          panne['date'] ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSavForm(String typeSav) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'sav_form',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved =
        CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: Center(
              child: SavFormDialog(
                typeSav: typeSav,
                onSubmit: () async => await _loadLastPannes(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEDE9FE),
                  Colors.white,
                  Color(0xFFF5F3FF)
                ],
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _buildCircleButton(Icons.arrow_back, () {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const MainScreen(),
                      transitionsBuilder: (_, a, __, child) =>
                          SlideTransition(
                            position: Tween(
                              begin: const Offset(-1.0, 0.0),
                              end: Offset.zero,
                            )
                                .chain(CurveTween(curve: Curves.easeInOut))
                                .animate(a),
                            child: child,
                          ),
                    ),
                        (route) => false,
                  );
                }),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _firstVehicule != null
                            ? "${_firstVehicule!['mark']} ${_firstVehicule!['model']}"
                            : "Mon véhicule",
                        style: const TextStyle(
                          color: kPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _firstVehicule?['matricule'] ?? "",
                        style: const TextStyle(
                            color: kAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lastPannes.isEmpty
                        ? Colors.green.withOpacity(0.12)
                        : kDanger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _lastPannes.isEmpty
                          ? Colors.green.withOpacity(0.3)
                          : kDanger.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 135,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildStatButton(Icons.car_repair, "Freins",
                      const BrakeDetailsPage(), context, kDanger),
                  const SizedBox(width: 20),
                  _buildStatButton(
                      Icons.battery_charging_full_rounded,
                      "Batterie",
                      const BatteryDetailsPage(),
                      context,
                      const Color(0xFFF59E0B)),
                  const SizedBox(width: 20),
                  _buildStatButton(
                      Icons.settings_applications,
                      "Distribution",
                      const DistributionDetailsPage(),
                      context,
                      const Color(0xFF3B82F6)),
                  const SizedBox(width: 20),
                  _buildStatButton(Icons.tire_repair, "Pneus",
                      const TireDetailsPage(), context,
                      const Color(0xFF10B981)),
                  const SizedBox(width: 20),
                  _buildStatButton(
                      Icons.settings_input_component,
                      "Embrayage",
                      const EmbrayageDetailsPage(),
                      context,
                      kAccent),
                  const SizedBox(width: 20),
                  _buildStatButton(Icons.engineering, "Moteur",
                      const MoteurDetailsPage(), context,
                      const Color(0xFF78716C)),
                ],
              ),
            ),
          ),
          Center(
            child: SlideTransition(
              position: _carSlide,
              child: FadeTransition(
                opacity: _carFade,
                child: Align(
                  alignment: const Alignment(0, 0.55),
                  child: Transform.scale(
                    scale: carScale,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const double imgH = 500.0;
                        final double imgW = constraints.maxWidth;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            isLoadingImage
                                ? const CircularProgressIndicator(
                                color: kAccent)
                                : (imageUrl != null &&
                                imageUrl!.isNotEmpty
                                ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..scale(1.0, -1.0),
                              child: Image.network(imageUrl!,
                                  height: imgH,
                                  fit: BoxFit.contain),
                            )
                                : const Icon(Icons.directions_car,
                                size: 150, color: kAccent)),
                            ..._buildPannePoints(imgH, imgW),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 258,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                    child: _buildActionButton(
                      icon: Icons.car_crash_rounded,
                      label: "Accident",
                      gradientColors: [
                        const Color(0xFFEF4444),
                        const Color(0xFFB91C1C)
                      ],
                      onTap: () => _openSavForm("accident"),
                    )),
                const SizedBox(width: 14),
                Expanded(
                    child: _buildActionButton(
                      icon: Icons.build_rounded,
                      label: "Maintenance",
                      gradientColors: [kAccent, kPrimary],
                      onTap: () => _openSavForm("maintenance"),
                    )),
              ],
            ),
          ),
          if (_lastPannes.isEmpty && !isLoadingImage)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    "✅ Aucune panne récente détectée",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatButton(IconData icon, String label, Widget page,
      BuildContext context, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (c, a, b) => page,
          transitionsBuilder: (c, a, b, child) => SlideTransition(
            position: Tween<Offset>(
                begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(
                parent: a, curve: Curves.easeInOut)),
            child: child,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border:
              Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap,
      {Color color = kPrimary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                spreadRadius: 1)
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  DIALOG CENTRÉ — DESIGN PREMIUM
// ─────────────────────────────────────────
class SavFormDialog extends StatefulWidget {
  final String typeSav;
  final VoidCallback onSubmit;

  const SavFormDialog(
      {super.key, required this.typeSav, required this.onSubmit});

  @override
  State<SavFormDialog> createState() => _SavFormDialogState();
}

class _SavFormDialogState extends State<SavFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController();
  int? _selectedGarageId;
  String? _selectedMaintenanceType;

  List<dynamic> _garages = [];
  List<String> _maintenanceTypes = [];
  bool _isLoadingGarages = false;
  bool _isLoadingTypes = false;
  bool _isSubmitting = false;

  late AnimationController _shimmerController;

  bool get _isAccident => widget.typeSav == "accident";

  // Couleurs selon type
  Color get _accentColor => _isAccident ? kDanger : kAccent;
  List<Color> get _gradientColors => _isAccident
      ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
      : [const Color(0xFF7C3AED), const Color(0xFF4C1D95)];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadGarages();
    if (!_isAccident) _loadMaintenanceTypes();
  }

  Future<void> _loadGarages() async {
    if (!mounted) return;
    setState(() => _isLoadingGarages = true);
    try {
      final garages = await GarageService.getAllGarages();
      if (mounted) setState(() => _garages = garages);
    } catch (e) {
      debugPrint("Erreur garages: $e");
    } finally {
      if (mounted) setState(() => _isLoadingGarages = false);
    }
  }

  Future<void> _loadMaintenanceTypes() async {
    if (!mounted) return;
    setState(() => _isLoadingTypes = true);
    try {
      final types = await DetailPannesService.fetchMaintenanceTypes();
      if (mounted) setState(() => _maintenanceTypes = types);
    } catch (e) {
      debugPrint("Erreur types: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTypes = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _costController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack("Veuillez sélectionner une date", isError: true);
      return;
    }
    setState(() => _isSubmitting = true);

    final Map<String, dynamic> body = {
      "type_sav": widget.typeSav,
      "date_reparation":
      _selectedDate!.toIso8601String().split('T').first,
    };
    if (_descriptionController.text.trim().isNotEmpty)
      body["description"] = _descriptionController.text.trim();
    if (_costController.text.trim().isNotEmpty)
      body["cost"] = double.tryParse(_costController.text.trim());
    if (_selectedGarageId != null) body["garage_id"] = _selectedGarageId;
    if (!_isAccident && _selectedMaintenanceType != null)
      body["maintenance_type"] = _selectedMaintenanceType;

    final result = await DetailPannesService.createSav(body);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      _showSnack("SAV créé avec succès !", isError: false);
      widget.onSubmit();
    } else {
      _showSnack("Erreur lors de la création", isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      backgroundColor: isError ? kDanger : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withOpacity(0.18),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header avec dégradé ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Bouton fermer
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Icône principale
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: Icon(
                        _isAccident
                            ? Icons.car_crash_rounded
                            : Icons.build_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isAccident
                          ? "Déclarer un accident"
                          : "Déclarer une maintenance",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isAccident
                          ? "Renseignez les détails de l'incident"
                          : "Planifiez votre intervention",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Corps du formulaire ──────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Date ──
                        _sectionLabel("Date de réparation *"),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                      primary: _accentColor),
                                ),
                                child: child!,
                              ),
                            );
                            if (date != null)
                              setState(() => _selectedDate = date);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            decoration: BoxDecoration(
                              color: _selectedDate != null
                                  ? _accentColor.withOpacity(0.06)
                                  : const Color(0xFFF9F8FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedDate != null
                                    ? _accentColor.withOpacity(0.5)
                                    : const Color(0xFFE5E7EB),
                                width:
                                _selectedDate != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                      Icons.calendar_today_rounded,
                                      color: _accentColor,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? "Sélectionner une date"
                                        : "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}",
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF1F2937),
                                      fontSize: 14,
                                      fontWeight: _selectedDate != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (_selectedDate != null)
                                  Icon(Icons.check_circle_rounded,
                                      color: _accentColor, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Garage ──
                        _sectionLabel("Garage (optionnel)"),
                        const SizedBox(height: 8),
                        _isLoadingGarages
                            ? _buildLoader()
                            : _styledDropdown<int>(
                          hint: "Aucun garage",
                          icon: Icons.garage_rounded,
                          value: _selectedGarageId,
                          items: [
                            DropdownMenuItem<int>(
                              value: null,
                              child: Text("Aucun garage",
                                  style: TextStyle(
                                      color: Colors.grey[500])),
                            ),
                            ..._garages.map((g) =>
                                DropdownMenuItem<int>(
                                  value: g['id'],
                                  child: Text(g['nom'] ??
                                      "Garage ${g['id']}"),
                                )),
                          ],
                          onChanged: (val) => setState(
                                  () => _selectedGarageId = val),
                        ),
                        const SizedBox(height: 18),

                        // ── Type maintenance ──
                        if (!_isAccident) ...[
                          _sectionLabel("Type de maintenance"),
                          const SizedBox(height: 8),
                          _isLoadingTypes
                              ? _buildLoader()
                              : _styledDropdown<String>(
                            hint: "Sélectionner un type",
                            icon: Icons.build_circle_rounded,
                            value: _selectedMaintenanceType,
                            items: _maintenanceTypes.isEmpty
                                ? [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                      "Aucun type disponible"))
                            ]
                                : _maintenanceTypes
                                .map((t) => DropdownMenuItem(
                                value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) => setState(() =>
                            _selectedMaintenanceType = val),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // ── Description ──
                        _sectionLabel("Description (optionnel)"),
                        const SizedBox(height: 8),
                        _styledTextField(
                          controller: _descriptionController,
                          hint: "Décrivez le problème...",
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 18),

                        // ── Coût ──
                        _sectionLabel("Coût estimé (DT)"),
                        const SizedBox(height: 8),
                        _styledTextField(
                          controller: _costController,
                          hint: "Ex: 250.00",
                          icon: Icons.payments_rounded,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: 28),

                        // ── Bouton Enregistrer ──
                        GestureDetector(
                          onTap: _isSubmitting ? null : _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: _isSubmitting
                                      ? [
                                    Colors.grey[300]!,
                                    Colors.grey[400]!
                                  ]
                                      : _gradientColors),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: _isSubmitting
                                  ? []
                                  : [
                                BoxShadow(
                                  color: _accentColor
                                      .withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isSubmitting
                                  ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5))
                                  : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isAccident
                                        ? Icons.save_rounded
                                        : Icons
                                        .check_circle_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Enregistrer",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF374151),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _accentColor, size: 16),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F8FF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _accentColor, width: 1.8),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _styledDropdown<T>({
    required String hint,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _accentColor, size: 16),
              ),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _accentColor, width: 1.8),
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 4),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          hint: Text(hint,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 14)),
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: _accentColor),
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF1F2937)),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: _accentColor, strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          const Text("Chargement...",
              style:
              TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }
}
