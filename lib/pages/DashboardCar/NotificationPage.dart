import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/MaintenanceDiagnosticPage.dart';
import 'package:tahki_drive1/services/auth_service.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import 'package:tahki_drive1/pages/DashboardCar/diagnostic_detail_page.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


enum NotifTab { car, reminder, driver }
class NotificationsPage extends StatefulWidget {
  final NotifTab initialTab;
  final bool isDriver;
  const NotificationsPage({
    super.key,
    this.initialTab = NotifTab.car,
    this.isDriver = false,
  });
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> get _carEventsFiltered =>
      _carEvents.where((e) => e['type'] != 'reminder').toList();

  List<dynamic> get _reminderEvents =>
      _carEvents.where((e) => e['type'] == 'reminder').toList();
  List<dynamic> _carEvents    = [];
  List<dynamic> _driverEvents = [];
  bool _isLoading = true;
  String _cin = '';

  static const _criticalCodes = {1, 2, 3, 9, 12, 14, 22, 30, 33, 36, 37, 39, 46, 50};

  Gradient get _gradient => LinearGradient(
    colors: widget.isDriver
        ? [const Color(0xFF006AD7), const Color(0xFF21277B)]
        : [const Color(0xFF7226FF), const Color(0xFF160078)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Color get _carColor => widget.isDriver
      ? const Color(0xFF006AD7)
      : const Color(0xFF7226FF);

  Color get _driverColor => widget.isDriver
      ? const Color(0xFF006AD7)
      : const Color(0xFF10B981);
  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours  < 24) return 'il y a ${diff.inHours}h';
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return dateStr; }
  }
  @override
  void initState() {
    super.initState();
    _tabController = _tabController = TabController(
      length: 2,  // ← change 3 en 2
      vsync: this,
      initialIndex: widget.initialTab == NotifTab.car ? 0 : 1,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _cin = await AuthService.getCin() ?? '';
    final results = await Future.wait([
      NotificationService.fetchCarEvents(_cin),
      NotificationService.fetchDriverEvents(_cin),
    ]);
    if (!mounted) return;
    setState(() {
      _carEvents    = results[0];
      _driverEvents = results[1];
      _isLoading    = false;
    });
  }



  void _openDiagnostic(Map<String, dynamic> event) {
    if (event['type'] == 'reminder') {
      const typeMap = {
        'Vidange':      'Oil Change',
        'Pneu':         'Tire',
        'Frein':        'Brake',
        'Batterie':     'Battery',
        'Distribution': 'Distribution',
        'Embrayage':    'Embrayage',
      };

      final rawType    = event['maintenance_type']?.toString() ?? '';
      final mappedType = typeMap[rawType] ?? rawType;

      final kmSince    = int.tryParse(event['km_parcourus']?.toString() ?? '') ?? 0;
      final kmInterval = int.tryParse(event['km_interval']?.toString()  ?? '') ?? 10000;
      final kmRest     = int.tryParse(event['km_restants']?.toString()  ?? '') ?? 0;

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MaintenanceDiagnosticPage(
          maintenanceType: mappedType,
          kmSinceRepair:   kmSince,
          kmInterval:      kmInterval,
          kmRemaining:     kmRest,
        ),
      ));
      return;
    }

    // Events normaux — vérification id
    final id = event['id'];
    if (id == null) return;
    final eventId = id is int ? id : int.tryParse(id.toString());
    if (eventId == null || eventId == 0) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => DiagnosticDetailPage(
          eventId:   eventId,
          cin:       _cin,
          quickData: {
            'type':       'panne',
            'event_id':   id.toString(),
            'code':       event['code']?.toString() ?? '',
            'car_voice':  event['description'] ?? '',
            'date':       event['date']?.toString() ?? '',
            'driver_cin': _cin,
          },
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _gradient)),        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22.sp,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin:  EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30.r),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                _buildTab(
                  icon: Icons.directions_car_rounded,
                  label: 'Voiture',
                  badge: 0,
                  isSelected: _tabController.index == 0,
                  color: _carColor,
                ),
                _buildTab(
                  icon: Icons.person_rounded,
                  label: 'Chauffeur',
                  badge: 0,
                  isSelected: _tabController.index == 1,
                  color: _driverColor,
                ),
              ],
              onTap: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Colors.white, Color(0xFFF1F5F9)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF)))
            : TabBarView(
          controller: _tabController,
          children: [
            _buildList(_carEvents,    _carColor,    Icons.directions_car_rounded),
            _buildList(_driverEvents, _driverColor, Icons.person_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required int badge,
    required bool isSelected,
    required Color color,
  }) {
    final labelColor = isSelected ? color : Colors.white;
    return Tab(
      height: 40.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18.w, color: labelColor),
           SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
            ),
          ),
          if (badge > 0) ...[
             SizedBox(width: 6.w),
            Container(
              padding:  EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '$badge',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> events, Color accent, IconData emptyIcon) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100.w,
              height: 100.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.08),
              ),
              child: Icon(emptyIcon, size: 48.w, color: accent.withOpacity(0.3)),
            ),
             SizedBox(height: 20.h),
            Text(
              'Aucune notification',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: accent,
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.only(top: 180.h, left: 16, right: 16, bottom: 30),
        itemCount: events.length,
        itemBuilder: (context, index) =>
            _buildCard(events[index], accent, index),
      ),
    );
  }

  Widget _buildCard(
      Map<String, dynamic> event,
      Color accent,
      int index,
      ) {
    final code       = int.tryParse(event['code']?.toString() ?? '') ?? 0;
    final isCritical = _criticalCodes.contains(code);

    final Color mainColor = isCritical ? const Color(0xFFEF4444) : accent;
    final Color darkColor = isCritical ? const Color(0xFFB91C1C) : accent.withOpacity(0.75);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
      ),
      child: Container(
        margin:  EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: mainColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openDiagnostic(event),
            borderRadius: BorderRadius.circular(22.r),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: Colors.grey.shade100,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // icône
                  Container(
                    width: 50.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [mainColor, darkColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: mainColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isCritical
                          ? Icons.warning_rounded
                          : Icons.notifications_rounded,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                   SizedBox(width: 14.w),
                  // contenu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event['title'] ?? 'Alerte véhicule',
                                style:  TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                         SizedBox(height: 5.h),
                        Text(
                          event['description'] ?? '',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 11.w, color: Colors.grey.shade400),
                             SizedBox(width: 4.w),
                            Text(
                              _formatTime(event['date']?.toString()),
                              style: TextStyle(
                                  fontSize: 11.sp, color: Colors.grey.shade400),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                size: 16.w, color: mainColor.withOpacity(0.6)),
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
      ),
    );
  }
}
