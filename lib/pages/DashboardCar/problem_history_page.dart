import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/diagnostic_detail_page.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class ProblemHistoryPage extends StatefulWidget {
  final String cin;
  const ProblemHistoryPage({required this.cin, super.key});

  @override
  State<ProblemHistoryPage> createState() => _ProblemHistoryPageState();
}

class _ProblemHistoryPageState extends State<ProblemHistoryPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _events = [];
  bool _isLoading = true;
  bool _showOnlyNew = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const _criticalCodes = {1, 2, 3, 9, 12, 14, 22, 30, 33, 36, 37, 39, 46, 50};

  final Gradient _gradient = const LinearGradient(
    colors: [Color(0xFF7226FF), Color(0xFF160078)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _loadEvents();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    // ✅ Récupère TOUTES les pannes d'abord
    final allEvents = await NotificationService.fetchAllPannes();

    // ✅ Filtre pour garder seulement celles d'aujourd'hui
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayEvents = allEvents.where((event) {
      try {
        final eventDate = DateTime.parse(event['date']?.toString() ?? '');
        final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
        return eventDay == today;
      } catch (e) {
        return false;
      }
    }).toList();

    if (mounted) {
      setState(() {
        _events = todayEvents;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsNotified(int eventId) async {
    await NotificationService.markEventAsNotified(eventId, widget.cin);
    if (mounted) {
      setState(() {
        final index = _events.indexWhere((e) => e['id'] == eventId);
        if (index != -1) _events[index]['is_notified'] = '1';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:  Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12.w),
              Text('Alerte marquée comme lue'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
    }
  }

  void _openDiagnostic(Map<String, dynamic> event) {
    final isNew = event['is_notified'] == '0' ||
        event['is_notified'] == false ||
        event['is_notified'] == null;
    if (isNew) {
      _markAsNotified(event['id'] as int);
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => DiagnosticDetailPage(
          eventId: event['id'] as int,
          cin: widget.cin,
          quickData: {
            'type': 'panne',
            'event_id': event['id'].toString(),
            'code': event['code']?.toString() ?? '',
            'car_voice': event['description'] ?? '',
            'date': event['date']?.toString() ?? '',
            'driver_cin': widget.cin,
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedEvents = _showOnlyNew
        ? _events
        .where((e) =>
    e['is_notified'] == '0' ||
        e['is_notified'] == false ||
        e['is_notified'] == null)
        .toList()
        : _events;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text(
          "Problem History",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22.sp,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _gradient)),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _showOnlyNew
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                key: ValueKey(_showOnlyNew),
                color: Colors.white,
                size: 24.w,
              ),
            ),
            onPressed: () => setState(() => _showOnlyNew = !_showOnlyNew),
            tooltip: _showOnlyNew ? 'Voir tout' : 'Voir uniquement les nouveaux',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 24),
            onPressed: _loadEvents,
            tooltip: 'Rafraîchir',
          ),
        ],
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
            ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF7226FF), strokeWidth: 3),
        )
            : displayedEvents.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.only(
              top: 120, left: 16, right: 16, bottom: 30),
          itemCount: displayedEvents.length,
          itemBuilder: (context, index) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildEventCard(displayedEvents[index], index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7226FF).withOpacity(0.1),
                  const Color(0xFF160078).withOpacity(0.05),
                ],
              ),
            ),
            child: Icon(
              _showOnlyNew
                  ? Icons.notifications_off_outlined
                  : Icons.car_repair,
              size: 60.w,
              color: const Color(0xFF7226FF).withOpacity(0.4),
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            _showOnlyNew ? 'Aucune nouvelle alerte' : 'Aucune panne aujourd\'hui',
            style:  TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3),
          ),
          SizedBox(height: 12.h),
          Text(
            _showOnlyNew
                ? 'Toutes les alertes sont déjà lues'
                : 'Aucun problème détecté aujourd\'hui',
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, int index) {
    final isNew = event['is_notified'] == '0' ||
        event['is_notified'] == false ||
        event['is_notified'] == null;

    final code = event['code'] ?? 0;
    final isCritical = _criticalCodes.contains(code);
    final mainColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final darkColor = isCritical ? const Color(0xFFB91C1C) : const Color(0xFFD97706);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(
          opacity: value,
          child: Container(
            margin:  EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                    color: mainColor.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openDiagnostic(event),
                borderRadius: BorderRadius.circular(24.r),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: isNew
                          ? mainColor.withOpacity(0.3)
                          : Colors.grey.shade100,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56.w,
                        height: 56.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [mainColor, darkColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                                color: mainColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Icon(
                          isCritical ? Icons.warning_rounded : Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 28.w,
                        ),
                      ),
                      SizedBox(width: 16.w),
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
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.3),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isNew)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: [mainColor, darkColor]),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child:  Text('NEW',
                                        style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5.w)),
                                  ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              event['description'] ?? '',
                              style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade600,
                                  height: 1.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 12.w, color: Colors.grey.shade400),
                                SizedBox(width: 6.w),
                                Text(
                                  _formatTime(event['date']?.toString() ?? ''),
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey.shade500),
                                ),
                                if (event['mark'] != null) ...[
                                  SizedBox(width: 16.w),
                                  Icon(Icons.directions_car_rounded,
                                      size: 12.w, color: Colors.grey.shade400),
                                   SizedBox(width: 6.w),
                                  Text(
                                    '${event['mark']} ${event['model'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                                const Spacer(),
                                 Icon(Icons.chevron_right_rounded,
                                    size: 16.w,
                                    color: Color(0xFFEF4444)),
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
        ),
      ),
    );
  }

  // Format time only (since date is today)
  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
