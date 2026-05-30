import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/BrakeDetailsPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/Diagnostic_Detail_Page.dart';
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
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


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
                padding: EdgeInsets.all(9.w),
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
    debugPrint("PANNE DATA: $panne");

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
      pageBuilder: (_, __, ___) => SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1,
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: dotColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning_rounded,
                        color: dotColor, size: 40),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    panne['label'] ?? 'Panne détectée',
                    style:  TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      color: kPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    panne['description'] ?? '',
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: dotColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      positionLabels[panne['position_key']] ??
                          '📍 Position inconnue',
                      style: TextStyle(
                        color: dotColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    (panne['category'] ?? '').toString().toUpperCase(),
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[400],
                        letterSpacing: 1.2.w),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 14.w, color: Colors.grey[500]),
                        SizedBox(width: 6.w),
                        Text(
                          panne['date'] ?? '',
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          pageBuilder: (c, a, b) => DiagnosticDetailPage(
                            eventId: panne['event_id'] ?? 0,
                            cin: _firstVehicule?['cin'] ?? '',
                            quickData: panne,
                          ),
                          transitionsBuilder: (c, a, b, child) => SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.biotech_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8.w),
                          Text(
                            "Voir le diagnostic IA",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
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
      pageBuilder: (_, __, ___) => SizedBox.shrink(),
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
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _firstVehicule != null
                            ? "${_firstVehicule!['mark']} ${_firstVehicule!['model']}"
                            : "Mon véhicule",
                        style:  TextStyle(
                          color: kPrimary,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _firstVehicule?['matricule'] ?? "",
                        style:  TextStyle(
                            color: kAccent,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
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
              height: 110.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildStatButton(Icons.car_repair, "Freins",
                      const BrakeDetailsPage(), context, kDanger),
                  SizedBox(width: 20.w),
                  _buildStatButton(
                      Icons.battery_charging_full_rounded,
                      "Batterie",
                      const BatteryDetailsPage(),
                      context,
                      const Color(0xFFF59E0B)),
                  SizedBox(width: 20.w),
                  _buildStatButton(
                      Icons.settings_applications,
                      "Distribution",
                      const DistributionDetailsPage(),
                      context,
                      const Color(0xFF3B82F6)),
                  SizedBox(width: 20.w),
                  _buildStatButton(Icons.tire_repair, "Pneus",
                      const TireDetailsPage(), context,
                      const Color(0xFF10B981)),
                  SizedBox(width: 20.w),
                  _buildStatButton(
                      Icons.settings_input_component,
                      "Embrayage",
                      EmbrayageDetailsPage(),
                      context,
                      kAccent),
                  SizedBox(width: 20.w),
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
                                :  Icon(Icons.directions_car,
                                size: 150.w, color: kAccent)),
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
            child: _buildActionButton(
              icon: Icons.build_rounded,
              label: "Déclarer une maintenance",
              gradientColors: [kAccent, kPrimary],
              onTap: () => _openSavForm("maintenance"),
            ),
          ),
          if (_lastPannes.isEmpty && !isLoadingImage)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
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
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: Colors.white, size: 22.w),
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3.w,
              ),
            ),
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
            padding: EdgeInsets.all(13.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border:
              Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          SizedBox(height: 6.h),
          Text(label,
              style: TextStyle(
                  fontSize: 11.sp,
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
        height: 46.h,
        width: 46.w,
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

  SavFormDialog(
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
  String? _selectedMaintenanceType;
  String? _inlineError;  // ← message d'erreur inline

  List<String> _maintenanceTypes = [];
  bool _isLoadingTypes = false;
  bool _isSubmitting = false;

  late AnimationController _shimmerController;

  Color get _accentColor => kAccent;
  List<Color> get _gradientColors => [
    const Color(0xFF7C3AED),
    const Color(0xFF4C1D95),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadMaintenanceTypes();
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

  void _showError(String msg) {
    setState(() => _inlineError = msg);
  }

  void _clearError() {
    setState(() => _inlineError = null);
  }

  Future<void> _submit() async {
    _clearError();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null && _selectedMaintenanceType == null) {
      _showError("Veuillez sélectionner une date et un type de maintenance");
      return;
    }
    if (_selectedDate == null) {
      _showError("Veuillez sélectionner une date de réparation");
      return;
    }
    if (_selectedMaintenanceType == null) {
      _showError("Veuillez sélectionner un type de maintenance");
      return;
    }

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> body = {
      "date_reparation": _selectedDate!.toIso8601String().split('T').first,
    };
    if (_descriptionController.text.trim().isNotEmpty)
      body["description"] = _descriptionController.text.trim();
    if (_costController.text.trim().isNotEmpty)
      body["cost"] = double.tryParse(_costController.text.trim());
    if (_selectedMaintenanceType != null)
      body["maintenance_type"] = _selectedMaintenanceType;

    final result = await DetailPannesService.createSav(body);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      widget.onSubmit();
    } else {
      _showError("Erreur lors de la création du SAV");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
      EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32.r),
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
          borderRadius: BorderRadius.circular(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header avec dégradé ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: Icon(
                        Icons.build_rounded,
                        color: Colors.white,
                        size: 34.w,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      "Déclarer une maintenance",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Ajouter votre intervention",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Corps du formulaire ──────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 8.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Date ──
                        _sectionLabel("Date de réparation *"),
                        SizedBox(height: 8.h),
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            decoration: BoxDecoration(
                              color: _selectedDate != null
                                  ? _accentColor.withOpacity(0.06)
                                  : const Color(0xFFF9F8FF),
                              borderRadius: BorderRadius.circular(16.r),
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
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(
                                      Icons.calendar_today_rounded,
                                      color: _accentColor,
                                      size: 18),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? "Sélectionner une date"
                                        : "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}",
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF1F2937),
                                      fontSize: 14.sp,
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
                        SizedBox(height: 18.h),

                        // ── Type maintenance ──
                        _sectionLabel("Type de maintenance *"),
                        SizedBox(height: 8.h),
                        _isLoadingTypes
                            ? _buildLoader()
                            : _styledDropdown<String>(
                          hint: "Sélectionner un type",
                          icon: Icons.build_circle_rounded,
                          value: _selectedMaintenanceType,
                          items: _maintenanceTypes.isEmpty
                              ? [const DropdownMenuItem(value: null, child: Text("Aucun type disponible"))]
                              : _maintenanceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => _selectedMaintenanceType = val),
                        ),
                        SizedBox(height: 18.h),

                        // ── Description ──
                        _sectionLabel("Description (optionnel)"),
                        SizedBox(height: 8.h),
                        _styledTextField(
                          controller: _descriptionController,
                          hint: "Décrivez le problème...",
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        SizedBox(height: 18.h),

                        // ── Coût ──
                        _sectionLabel("Coût estimé (DT)"),
                        SizedBox(height: 8.h),
                        _styledTextField(
                          controller: _costController,
                          hint: "Ex: 250.00",
                          icon: Icons.payments_rounded,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        SizedBox(height: 20.h),

                        // ── Message d'erreur inline ──
                        if (_inlineError != null) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: kDanger.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                  color: kDanger.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: kDanger, size: 18.w),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    _inlineError!,
                                    style: TextStyle(
                                      color: kDanger,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _clearError,
                                  child: Icon(Icons.close,
                                      color: kDanger, size: 16.w),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                        ],

                        // ── Bouton Enregistrer ──
                        GestureDetector(
                          onTap: _isSubmitting ? null : _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 54.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: _isSubmitting
                                      ? [
                                    Colors.grey[300]!,
                                    Colors.grey[400]!
                                  ]
                                      : _gradientColors),
                              borderRadius: BorderRadius.circular(18.r),
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
                                  ? SizedBox(
                                  height: 22.h,
                                  width: 22.w,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5))
                                  : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 20.w,
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    "Enregistrer",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3.w,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
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
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: Color(0xFF374151),
        letterSpacing: 0.2.w,
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
      style: TextStyle(fontSize: 14.sp, color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        prefixIcon: Padding(
          padding: EdgeInsets.all(12.w),
          child: Container(
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: _accentColor, size: 16),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F8FF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: _accentColor, width: 1.8),
        ),
        contentPadding:
        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
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
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: EdgeInsets.all(12.w),
              child: Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: _accentColor, size: 16),
              ),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: _accentColor, width: 1.8),
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 4, vertical: 4),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          hint: Text(hint,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 14)),
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: _accentColor),
          style: TextStyle(
              fontSize: 14.sp, color: Color(0xFF1F2937)),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Container(
      height: 54.h,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FF),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16.w,
            height: 16.h,
            child: CircularProgressIndicator(
                color: _accentColor, strokeWidth: 2),
          ),
          SizedBox(width: 12.w),
          const Text("Chargement...",
              style:
              TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }
}
