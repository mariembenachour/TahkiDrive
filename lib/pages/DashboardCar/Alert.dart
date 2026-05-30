import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tahki_drive1/pages/DashboardCar/diagnostic_detail_page.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import 'package:tahki_drive1/services/theme_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça

class AlertsPage extends StatefulWidget {
  final String cin;
  const AlertsPage({super.key, required this.cin});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<dynamic> _allEvents = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.forward();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await NotificationService.fetchAllPannes();
    if (!mounted) return;
    setState(() {
      _allEvents = events;
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredEvents {
    if (_searchQuery.isEmpty) return _allEvents;
    return _allEvents.where((e) {
      final title = (e['title'] ?? '').toLowerCase();
      final description = (e['description'] ?? '').toLowerCase();
      return title.contains(_searchQuery.toLowerCase()) ||
          description.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Map<String, List<dynamic>> get _groupedEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<dynamic>> groups = {
      "alerts.today": [],
      "alerts.this_week": [],
      "alerts.older": [],
    };

    for (final e in _filteredEvents) {
      DateTime? date;
      try {
        date = DateTime.parse(e['date']);
      } catch (_) {}
      if (date == null) continue;
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) {
        groups["alerts.today"]!.add(e);
      } else if (d.isAfter(weekAgo)) {
        groups["alerts.this_week"]!.add(e);
      } else {
        groups["alerts.older"]!.add(e);
      }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  void _openDiagnostic(Map<String, dynamic> event) {
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
    final isDark = context.watch<ThemeService>().isDark(context);
    final bgColor = isDark ? const Color(0xFF0A0015) : const Color(0xFFE8EAF6);
    final titleColor = isDark ? Colors.white : const Color(0xFF160078);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF160078);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600];
    final hintColor = isDark ? Colors.white38 : Colors.grey;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF7226FF);

    final groups = _groupedEvents;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0035), Color(0xFF0A0015)],
          )
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8EAF6), Color(0xFFF3E5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark, titleColor),
              _buildSearchBar(cardColor, hintColor, iconColor),
              Expanded(
                child: _isLoading
                    ? Center(
                    child: CircularProgressIndicator(
                        color: iconColor))
                    : _filteredEvents.isEmpty
                    ? _buildEmptyState(subtitleColor)
                    : ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  children: groups.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 16, bottom: 8, left: 4),
                        child: Text(
                          entry.key.tr(),
                          style: TextStyle(
                              color: subtitleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                      ...entry.value
                          .map((event) => _buildAlertItem(event, cardColor, textColor, subtitleColor, isDark)),
                    ];
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color titleColor) {
    return Padding(
      padding:  EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new,
                    color: titleColor),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                "alerts.title".tr(),
                style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: titleColor),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : const Color(0xFF7226FF)),
            onPressed: _loadEvents,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color cardColor, Color? hintColor, Color iconColor) {
    return Padding(
      padding:  EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: TextStyle(color: hintColor),
          decoration: InputDecoration(
            hintText: "alerts.search_hint".tr(),
            hintStyle: TextStyle(color: hintColor, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: iconColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color? subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 80.w, color: subtitleColor?.withOpacity(0.5)),
          SizedBox(height: 16.h),
          Text(
            _searchQuery.isEmpty ? "alerts.no_breakdowns".tr() : "alerts.no_results".tr(),
            style: TextStyle(color: subtitleColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> event, Color cardColor, Color textColor, Color? subtitleColor, bool isDark) {
    final code = event['code'] ?? 0;
    final isCritical = {1, 2, 3, 9, 12, 14, 22, 30, 33, 36, 37, 39, 46, 50}.contains(code);
    final color = isCritical ? Colors.red : Colors.orange;
    final String title = event['title'] ?? 'alerts.alert'.tr();
    final String subtitle = event['description'] ?? '';
    final String date = _formatDate(event['date'] ?? '');

    return GestureDetector(
      onTap: () => _openDiagnostic(event),
      child: Container(
        margin:  EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(
                isCritical ? Icons.warning_rounded : Icons.info_outline_rounded,
                color: color, size: 24.w,
              ),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(subtitle,
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12.w, color: subtitleColor?.withOpacity(0.7)),
                      SizedBox(width: 4.w),
                      Text(date,
                          style: TextStyle(fontSize: 11.sp, color: subtitleColor?.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final eventDate = DateTime(date.year, date.month, date.day);
      String dayFormat;
      if (eventDate == today)
        dayFormat = "alerts.today".tr();
      else if (eventDate == yesterday)
        dayFormat = "alerts.yesterday".tr();
      else
        dayFormat = '${date.day}/${date.month}/${date.year}';
      return '$dayFormat ${"alerts.at".tr()} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
