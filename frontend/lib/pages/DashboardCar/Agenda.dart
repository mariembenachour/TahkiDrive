import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tahki_drive1/services/event_service.dart';
import 'package:tahki_drive1/services/theme_service.dart';

class AgendaPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const AgendaPage({super.key, this.onBackToDashboard});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<Map<String, dynamic>> _eventsFuture;
  int _refreshKey = 0;
  Map<DateTime, List<Map>> _eventsMap = {};
  List<Map> _selectedEvents = [];

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _controller.forward();
    _eventsFuture = EventService.fetchEvents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _refreshKey++;
      _eventsFuture = EventService.fetchEvents();
    });
  }

  void _showSuccess(String msg) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(msg,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF4904BD),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String msg) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _luxuryAnimatedEntry(
      {required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(animation),
        child: ScaleTransition(
          scale:
          Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
  }

  // ================== HELPERS ==================

  String _getTitle(Map e) {
    if (e['event_category'] == 'document') {
      final isOffense =
          (e['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';
      if (isOffense) return e['offense_type'] ?? 'Offense';
      switch ((e['doc_type'] ?? '').toString().toUpperCase()) {
        case 'INSURANCE':
          return 'agenda.insurance'.tr();
        case 'VISIT':
          return 'agenda.technical_visit'.tr();
        case 'ROAD_TAXES':
          return 'agenda.road_tax'.tr();
        case 'TOLL':
          return 'agenda.toll'.tr();
        case 'PARCKING':
          return 'agenda.parking'.tr();
        case 'CAR_WASH':
          return 'agenda.car_wash'.tr();
        case 'EXTINCTEURS':
          return 'agenda.extinguishers'.tr();
        case 'PERMIT_CIRCULATION':
          return 'agenda.circulation_permit'.tr();
        case 'METOLOGICA_NOTBOOK':
          return 'agenda.metrological_notebook'.tr();
        case 'OPERATIONAL_CERTIFICATION':
          return 'agenda.operational_certification'.tr();
        default:
          return e['doc_type'] ?? 'agenda.document'.tr();
      }
    }
    return e['maintenance_type'] ?? 'agenda.maintenance'.tr();
  }

  String _getDate(Map e) {
    String raw;
    final isOffense =
        (e['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';
    if (isOffense) {
      raw = (e['offense_date'] ?? e['date'] ?? '').toString();
    } else if (e['event_category'] == 'document') {
      raw = (e['end_date'] ?? e['date'] ?? '').toString();
    } else {
      raw = (e['_calendar_date'] ??
          e['date_reparation'] ??
          e['date_panne'] ??
          e['date'] ??
          '')
          .toString();
    }
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _getUpcomingDate(Map e) {
    final nextDate = e['_next_date'] ?? e['estimated_next_date'];
    if (nextDate != null) return nextDate.toString().split('T')[0];
    if (e['next_oil_km'] != null) return '${e['next_oil_km']} km';
    if (e['end_date'] != null)
      return e['end_date'].toString().split('T')[0];
    return '-';
  }

  IconData _getIcon(Map e) {
    final isOffense =
        (e['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';
    if (isOffense) return Icons.warning_amber_outlined;
    if (e['event_category'] == 'document') {
      switch ((e['doc_type'] ?? '').toString().toUpperCase()) {
        case 'INSURANCE':
          return Icons.security_outlined;
        case 'VISIT':
          return Icons.assignment_outlined;
        case 'ROAD_TAXES':
          return Icons.account_balance_outlined;
        case 'TOLL':
          return Icons.toll_outlined;
        case 'PARCKING':
          return Icons.local_parking_outlined;
        case 'CAR_WASH':
          return Icons.local_car_wash_outlined;
        case 'EXTINCTEURS':
          return Icons.fire_extinguisher_outlined;
        case 'PERMIT_CIRCULATION':
          return Icons.credit_card_outlined;
        case 'METOLOGICA_NOTBOOK':
          return Icons.book_outlined;
        case 'OPERATIONAL_CERTIFICATION':
          return Icons.verified_outlined;
        default:
          return Icons.description_outlined;
      }
    }
    switch ((e['maintenance_type'] ?? '').toString().toLowerCase()) {
      case 'oil change':
        return Icons.oil_barrel_outlined;
      case 'brake':
        return Icons.disc_full_outlined;
      case 'battery':
        return Icons.battery_charging_full_outlined;
      case 'embrayage':
        return Icons.settings_outlined;
      case 'distribution':
        return Icons.settings_backup_restore_outlined;
      case 'tire':
        return Icons.tire_repair_outlined;
      default:
        return Icons.build_circle_outlined;
    }
  }

  Color _getColor(Map e) {
    final isOffense =
        (e['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';
    if (isOffense) return Colors.deepOrange;
    if (e['event_category'] == 'document') return Colors.blue;
    switch ((e['maintenance_type'] ?? '').toString().toLowerCase()) {
      case 'oil change':
        return Colors.orange;
      case 'brake':
        return Colors.red;
      case 'battery':
        return Colors.purple;
      case 'embrayage':
        return Colors.green;
      case 'distribution':
        return Colors.indigo;
      case 'tire':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  bool _isOverdue(Map e) {
    if (e['end_date'] != null) {
      try {
        return DateTime.parse(e['end_date'].toString())
            .isBefore(DateTime.now());
      } catch (_) {}
    }
    return false;
  }

  bool _isOffenseEvent(Map e) =>
      (e['doc_type'] ?? '').toString().toUpperCase() == 'OFFENSE';

  // ================== DETAIL DIALOG ==================

  void _showDetails(Map e) {
    final color = _getColor(e);
    final icon = _getIcon(e);
    final isDocument = e['event_category'] == 'document';
    final isOffense = _isOffenseEvent(e);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "details",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale:
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 45),
                    const SizedBox(height: 8),
                    Text(
                      _getTitle(e).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          if (isOffense) ...[
                            _detailRow("agenda.offense_type".tr(),
                                e['offense_type'] ?? '-'),
                            _detailRow(
                                "agenda.date".tr(),
                                e['offense_date']
                                    ?.toString()
                                    .split('T')[0] ??
                                    '-'),
                            _detailRow("agenda.amount".tr(),
                                "${e['paying'] ?? '-'} TND"),
                          ] else if (isDocument) ...[
                            _detailRow("agenda.type".tr(), e['doc_type']),
                            _detailRow(
                                "agenda.expiration".tr(),
                                e['end_date']
                                    ?.toString()
                                    .split('T')[0] ??
                                    '-'),
                          ] else ...[
                            _detailRow(
                                "agenda.type".tr(), e['maintenance_type']),
                            _detailRow("agenda.description".tr(),
                                e['description'] ?? '-'),
                            _detailRow(
                                "agenda.date".tr(),
                                e['date_reparation']
                                    ?.toString()
                                    .split('T')[0] ??
                                    '-'),
                            _detailRow("agenda.cost".tr(),
                                "${e['cost'] ?? '-'} DT"),
                            _detailRow("agenda.labor_cost".tr(),
                                "${e['labor_cost'] ?? '-'} DT"),
                            _detailRow("agenda.odometer".tr(),
                                "${e['odometre'] ?? '-'} km"),
                            _detailRow("agenda.status".tr(), e['etat']),
                            if (e['estimated_next_date'] != null)
                              _detailRow(
                                  "agenda.next_scheduled".tr(),
                                  e['estimated_next_date']
                                      .toString()
                                      .split('T')[0]),
                            if (e['next_oil_km'] != null)
                              _detailRow("agenda.next_at".tr(),
                                  "${e['next_oil_km']} km"),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showEditPopup(e);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              decoration: BoxDecoration(
                                color:
                                Colors.white.withOpacity(0.2),
                                borderRadius:
                                BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white
                                        .withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.edit_outlined,
                                      color: Colors.white,
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Text("agenda.edit".tr(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                          FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _confirmDelete(e);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.25),
                                borderRadius:
                                BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                    Colors.red.withOpacity(0.6)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_outline,
                                      color: Colors.white,
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Text("agenda.delete".tr(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                          FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(30)),
                        child: Text("agenda.close".tr(),
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
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

  // ================== CONFIRM DELETE ==================

  void _confirmDelete(Map e) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "confirm_delete",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale:
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "agenda.delete_event".tr(),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF160078)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "agenda.irreversible".tr(),
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius:
                                BorderRadius.circular(15),
                              ),
                              child: Text("agenda.cancel".tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DeleteButton(
                            event: e,
                            onDeleted: () {
                              Navigator.pop(ctx);
                              _refresh();
                              _showSuccess('agenda.deleted_success'.tr());
                            },
                            onError: () => _showError(
                                'agenda.delete_error'.tr()),
                          ),
                        ),
                      ],
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

  // ================== EDIT POPUP ==================

  void _showEditPopup(Map e) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "edit",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale:
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: _EditEventPopup(
              event: e,
              onUpdated: () {
                _refresh();
                _showSuccess('agenda.updated_success'.tr());
              },
              onError: () =>
                  _showError('agenda.update_error'.tr()),
            ),
          ),
        );
      },
    );
  }

  // ================== CREATE POPUP ==================

  void _showCreatePopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "create",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale:
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: _CreateEventPopup(
              onCreated: () {
                _refresh();
                _showSuccess('agenda.created_success'.tr());
              },
              onError: () => _showError('agenda.create_error'.tr()),
            ),
          ),
        );
      },
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDark(context);
    final bgColor = isDark ? const Color(0xFF0A0015) : const Color(0xFFF4F0FF);
    final titleColor = isDark ? Colors.white : const Color(0xFF160078);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF160078);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600];

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0035), Color(0xFF0A0015)],
            )
                : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4904BD), Color(0xFFF0EDF6)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _luxuryAnimatedEntry(
                  delay: 0.05,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeaderButton(
                            Icons.arrow_back_ios_new, () {
                          widget.onBackToDashboard?.call();
                        }, isDark: isDark),
                        Text("agenda.title".tr(),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Row(
                          children: [
                            _buildHeaderButton(
                                Icons.refresh, _refresh, isDark: isDark),
                            const SizedBox(width: 10),
                            _buildHeaderButton(
                                Icons.add, _showCreatePopup, isDark: isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    key: ValueKey(_refreshKey),
                    future: _eventsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white));
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                            child: Text('${"agenda.error".tr()}: ${snapshot.error}',
                                style: const TextStyle(
                                    color: Colors.white)));
                      }

                      final data = snapshot.data!;
                      final List<Map> allEvents =
                      List<Map>.from(data['all_events'] ?? []);
                      final List<Map> upcomingEvents =
                      List<Map>.from(
                          data['upcoming_events'] ?? []);
                      final List<Map> recentEvents = List<Map>.from(
                          data['recent_events'] ?? []);

                      _eventsMap = {};
                      for (final e in allEvents) {
                        final dateStr =
                        e['_calendar_date']?.toString();
                        if (dateStr == null) continue;
                        final parsed = DateTime.tryParse(dateStr);
                        if (parsed == null) continue;
                        final local = parsed.toLocal();
                        final day = DateTime.utc(
                            local.year, local.month, local.day);
                        _eventsMap[day] ??= [];
                        _eventsMap[day]!.add(e);
                      }

                      for (final e in upcomingEvents) {
                        final dateStr =
                            e['_next_date']?.toString() ??
                                e['estimated_next_date']?.toString();
                        if (dateStr == null) continue;
                        final parsed = DateTime.tryParse(dateStr);
                        if (parsed == null) continue;
                        final local = parsed.toLocal();
                        final day = DateTime.utc(
                            local.year, local.month, local.day);
                        _eventsMap[day] ??= [];
                        final alreadyAdded = _eventsMap[day]!
                            .any((x) => x['id_sav'] == e['id_sav']);
                        if (!alreadyAdded) _eventsMap[day]!.add(e);
                      }

                      final sel = _selectedDay ?? _focusedDay;
                      final selKey =
                      DateTime.utc(sel.year, sel.month, sel.day);
                      _selectedEvents = _eventsMap[selKey] ?? [];

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _luxuryAnimatedEntry(
                                delay: 0.2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius:
                                    BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.1),
                                          blurRadius: 20,
                                          offset:
                                          const Offset(0, 10))
                                    ],
                                  ),
                                  child: TableCalendar(
                                    firstDay:
                                    DateTime.utc(2020, 1, 1),
                                    lastDay:
                                    DateTime.utc(2030, 12, 31),
                                    focusedDay: _focusedDay,
                                    calendarFormat: _calendarFormat,
                                    selectedDayPredicate: (day) =>
                                        isSameDay(_selectedDay, day),
                                    onDaySelected:
                                        (selectedDay, focusedDay) {
                                      setState(() {
                                        _selectedDay = selectedDay;
                                        _focusedDay = focusedDay;
                                      });
                                    },
                                    eventLoader: (day) {
                                      final key = DateTime.utc(
                                          day.year,
                                          day.month,
                                          day.day);
                                      return _eventsMap[key] ?? [];
                                    },
                                    headerStyle: HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                      titleTextStyle: TextStyle(
                                        color: textColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      leftChevronIcon: Icon(
                                        Icons.chevron_left,
                                        color: textColor,
                                      ),
                                      rightChevronIcon: Icon(
                                        Icons.chevron_right,
                                        color: textColor,
                                      ),
                                    ),
                                    calendarStyle: CalendarStyle(
                                      defaultTextStyle: TextStyle(color: textColor),
                                      weekendTextStyle: TextStyle(color: textColor.withOpacity(0.7)),
                                      outsideTextStyle: TextStyle(color: textColor.withOpacity(0.3)),
                                      todayDecoration: const BoxDecoration(
                                          color: Color(0xFFD1B3FF),
                                          shape: BoxShape.circle),
                                      selectedDecoration:
                                      const BoxDecoration(
                                          color:
                                          Color(0xFF7226FF),
                                          shape:
                                          BoxShape.circle),
                                      markerDecoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                    ),
                                    daysOfWeekStyle: DaysOfWeekStyle(
                                      weekdayStyle: TextStyle(color: textColor.withOpacity(0.8)),
                                      weekendStyle: TextStyle(color: textColor.withOpacity(0.6)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Text("agenda.day_events".tr(),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor)),
                              const SizedBox(height: 10),
                              if (_selectedEvents.isEmpty)
                                Text("agenda.no_events".tr(),
                                    style: TextStyle(
                                        color: subtitleColor))
                              else
                                ..._selectedEvents.map((e) =>
                                    _buildEventCard(
                                        e: e,
                                        subtitle: _getDate(e),
                                        isDark: isDark)),
                              const SizedBox(height: 25),
                              _luxuryAnimatedEntry(
                                delay: 0.35,
                                child: Text("agenda.upcoming".tr(),
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor)),
                              ),
                              const SizedBox(height: 15),
                              if (upcomingEvents.isEmpty)
                                Center(
                                    child: Text(
                                        "agenda.no_upcoming".tr(),
                                        style: TextStyle(
                                            color:
                                            subtitleColor)))
                              else
                                ...upcomingEvents.map((e) =>
                                    _buildEventCard(
                                      e: e,
                                      subtitle:
                                      e['display_mode'] == 'km'
                                          ? 'agenda.next_at'.tr(args: [_getUpcomingDate(e)])
                                          : 'agenda.scheduled_for'.tr(args: [_getUpcomingDate(e)]),
                                      tag: 'agenda.upcoming_tag'.tr(),
                                      tagColor: Colors.green,
                                      isDark: isDark,
                                    )),
                              const SizedBox(height: 25),
                              _luxuryAnimatedEntry(
                                delay: 0.5,
                                child: Text("agenda.recent".tr(),
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor)),
                              ),
                              const SizedBox(height: 15),
                              if (recentEvents.isEmpty)
                                Center(
                                    child: Text(
                                        "agenda.no_recent".tr(),
                                        style: TextStyle(
                                            color:
                                            subtitleColor)))
                              else
                                ...recentEvents.map((e) =>
                                    _buildEventCard(
                                      e: e,
                                      subtitle: _getDate(e),
                                      tag: _isOverdue(e)
                                          ? 'agenda.expired'.tr()
                                          : null,
                                      tagColor: Colors.red,
                                      isDark: isDark,
                                    )),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13)),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
      {required Map e,
        required String subtitle,
        String? tag,
        Color? tagColor,
        required bool isDark}) {
    final color = _getColor(e);
    final icon = _getIcon(e);
    return GestureDetector(
      onTap: () => _showDetails(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A0035) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          child: Text(_getTitle(e),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : const Color(0xFF160078)))),
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: (tagColor ?? Colors.grey)
                                  .withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(10)),
                          child: Text(tag,
                              style: TextStyle(
                                  color: tagColor ?? Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap,
      {bool isPrimary = false, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF160078)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ================== DELETE BUTTON ==================

class _DeleteButton extends StatefulWidget {
  final Map event;
  final VoidCallback onDeleted;
  final VoidCallback onError;
  const _DeleteButton(
      {required this.event,
        required this.onDeleted,
        required this.onError});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _loading = false;

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      final ok = await EventService.deleteEvent(widget.event);
      if (!mounted) return;
      if (ok) {
        widget.onDeleted();
      } else {
        setState(() => _loading = false);
        widget.onError();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _delete,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(15),
        ),
        child: _loading
            ? const Center(
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)))
            : Text("agenda.delete".tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ================== EDIT POPUP ==================

class _EditEventPopup extends StatefulWidget {
  final Map event;
  final VoidCallback onUpdated;
  final VoidCallback onError;
  const _EditEventPopup(
      {required this.event,
        required this.onUpdated,
        required this.onError});

  @override
  State<_EditEventPopup> createState() => _EditEventPopupState();
}

class _EditEventPopupState extends State<_EditEventPopup> {
  // Document fields
  late String? _selectedDocType;
  DateTime? _endDate;

  // Offense fields
  late String? _selectedOffenseType;
  String? _autreOffenseText;
  final _autreOffenseCtrl = TextEditingController();
  DateTime? _offenseDate;
  final _payingCtrl = TextEditingController();

  bool _loading = false;

  bool get _isDocument => widget.event['event_category'] == 'document';
  bool get _isOffense =>
      (widget.event['doc_type'] ?? '').toString().toUpperCase() ==
          'OFFENSE';

  static const _docTypes = [
    'INSURANCE',
    'VISIT',
    'ROAD_TAXES',
    'TOLL',
    'PARCKING',
    'CAR_WASH',
    'EXTINCTEURS',
    'PERMIT_CIRCULATION',
    'METOLOGICA_NOTBOOK',
    'OPERATIONAL_CERTIFICATION',
    'Autre',
  ];

  static const _knownDocTypes = [
    'INSURANCE',
    'VISIT',
    'ROAD_TAXES',
    'TOLL',
    'PARCKING',
    'CAR_WASH',
    'EXTINCTEURS',
    'PERMIT_CIRCULATION',
    'METOLOGICA_NOTBOOK',
    'OPERATIONAL_CERTIFICATION',
  ];

  static const _offenseTypes = [
    'Excès de vitesse',
    'Stationnement interdit',
    'Feu rouge grillé',
    'Téléphone au volant',
    'Ceinture de sécurité',
    'Autre',
  ];

  static const _knownOffenseTypes = [
    'Excès de vitesse',
    'Stationnement interdit',
    'Feu rouge grillé',
    'Téléphone au volant',
    'Ceinture de sécurité',
  ];

  @override
  void initState() {
    super.initState();

    // Document type init
    final rawDocType = widget.event['doc_type']?.toString();
    if (_knownDocTypes.contains(rawDocType)) {
      _selectedDocType = rawDocType;
    } else if (rawDocType != null &&
        rawDocType.isNotEmpty &&
        rawDocType != 'OFFENSE') {
      _selectedDocType = 'Autre';
    } else {
      _selectedDocType = null;
    }

    final endRaw = widget.event['end_date']?.toString();
    _endDate =
    endRaw != null ? DateTime.tryParse(endRaw)?.toLocal() : null;

    // Offense type init
    final rawOffenseType = widget.event['offense_type']?.toString();
    if (_knownOffenseTypes.contains(rawOffenseType)) {
      _selectedOffenseType = rawOffenseType;
    } else if (rawOffenseType != null && rawOffenseType.isNotEmpty) {
      _selectedOffenseType = 'Autre';
      _autreOffenseCtrl.text = rawOffenseType;
    } else {
      _selectedOffenseType = null;
    }

    final offRaw = widget.event['offense_date']?.toString();
    _offenseDate =
    offRaw != null ? DateTime.tryParse(offRaw)?.toLocal() : null;
    _payingCtrl.text = widget.event['paying']?.toString() ?? '';
  }

  @override
  void dispose() {
    _payingCtrl.dispose();
    _autreOffenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isOffense) async {
    final initial =
        (isOffense ? _offenseDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme:
          const ColorScheme.light(primary: Color(0xFF4904BD)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
              () => isOffense ? _offenseDate = picked : _endDate = picked);
    }
  }

  String _fmt(DateTime? d) => d == null
      ? 'agenda.choose_date'.tr()
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submit() async {
    if (_isOffense) {
      if (_selectedOffenseType == null || _offenseDate == null) {
        _snack('agenda.fill_all_fields'.tr());
        return;
      }
      if (_selectedOffenseType == 'Autre' &&
          _autreOffenseCtrl.text.trim().isEmpty) {
        _snack("agenda.specify_offense_type".tr());
        return;
      }
      if (double.tryParse(_payingCtrl.text.trim()) == null) {
        _snack('agenda.invalid_amount'.tr());
        return;
      }
    } else if (_isDocument) {
      if (_selectedDocType == null || _endDate == null) {
        _snack('agenda.fill_all_fields'.tr());
        return;
      }
    }

    setState(() => _loading = true);
    bool ok = false;
    try {
      final offenseTypeFinal = _selectedOffenseType == 'Autre'
          ? _autreOffenseCtrl.text.trim()
          : _selectedOffenseType;

      ok = await EventService.updateEvent(
        event: widget.event,
        docType: _selectedDocType,
        endDate: _endDate,
        offenseDate: _offenseDate,
        offenseType: offenseTypeFinal,
        paying: double.tryParse(_payingCtrl.text.trim()),
      );
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pop(context);
      widget.onUpdated();
    } else {
      widget.onError();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  bool get _canSubmit => _isDocument || _isOffense;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isDark
              ? const LinearGradient(
            colors: [Color(0xFF1A0035), Color(0xFF2D1B69)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [Color(0xFF4904BD), Color(0xFF7226FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 36),
              const SizedBox(height: 10),
              Text("agenda.edit_event".tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1)),
              const SizedBox(height: 24),

              // ── Document fields ──────────────────────────────────────
              if (_isDocument && !_isOffense) ...[
                _label('agenda.document_type'.tr()),
                const SizedBox(height: 8),
                _dropdown(_docTypes, _selectedDocType,
                        (v) => setState(() => _selectedDocType = v)),
                if (_selectedDocType == 'Autre') ...[
                  const SizedBox(height: 12),
                  _textField(
                    hint: 'agenda.specify_document_type'.tr(),
                    icon: Icons.edit,
                    onChanged: (_) => setState(() {}),
                    controller: _autreOffenseCtrl,
                  ),
                ],
                const SizedBox(height: 16),
                _label("agenda.expiration_date".tr()),
                const SizedBox(height: 8),
                _datePicker(_fmt(_endDate), () => _pickDate(false)),
              ],

              // ── Offense fields ───────────────────────────────────────
              if (_isOffense) ...[
                _label("agenda.offense_type".tr()),
                const SizedBox(height: 8),
                _dropdown(_offenseTypes, _selectedOffenseType,
                        (v) => setState(() => _selectedOffenseType = v)),
                if (_selectedOffenseType == 'Autre') ...[
                  const SizedBox(height: 12),
                  _textField(
                    hint: "agenda.specify_offense_type".tr(),
                    icon: Icons.edit,
                    controller: _autreOffenseCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                _label("agenda.offense_date".tr()),
                const SizedBox(height: 8),
                _datePicker(
                    _fmt(_offenseDate), () => _pickDate(true)),
                const SizedBox(height: 16),
                _label('agenda.amount_tnd'.tr()),
                const SizedBox(height: 8),
                _textField(
                  hint: 'Ex: 150.00',
                  icon: Icons.payment,
                  controller: _payingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ],

              // ── Maintenance read-only ────────────────────────────────
              if (!_isDocument) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          "agenda.maintenance_readonly".tr(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text('agenda.cancel'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                      (_loading || !_canSubmit) ? null : _submit,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _canSubmit
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: _loading
                            ? const Center(
                            child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF4904BD),
                                    strokeWidth: 2)))
                            : Text('agenda.save'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _canSubmit
                                    ? const Color(0xFF4904BD)
                                    : Colors.white54,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600)),
  );

  Widget _dropdown(
      List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text('agenda.choose'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.5))),
          isExpanded: true,
          dropdownColor: const Color(0xFF4904BD),
          icon: Icon(Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.7)),
          items: items
              .map((e) => DropdownMenuItem(
            value: e,
            child: Text(e,
                style: const TextStyle(color: Colors.white)),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _textField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon:
        Icon(icon, color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Widget _datePicker(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  color: label == 'agenda.choose_date'.tr()
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}

// ================== CREATE POPUP ==================

class _CreateEventPopup extends StatefulWidget {
  final VoidCallback onCreated;
  final VoidCallback onError;
  const _CreateEventPopup(
      {required this.onCreated, required this.onError});

  @override
  State<_CreateEventPopup> createState() => _CreateEventPopupState();
}

class _CreateEventPopupState extends State<_CreateEventPopup> {
  String _tab = 'document';

  String? _selectedDocType;
  DateTime? _endDate;

  String? _selectedOffenseType;
  DateTime? _offenseDate;
  final _payingCtrl = TextEditingController();
  final _autreDocCtrl = TextEditingController();
  final _autreOffenseCtrl = TextEditingController();

  bool _loading = false;

  static const _docTypes = [
    'INSURANCE',
    'VISIT',
    'ROAD_TAXES',
    'TOLL',
    'PARCKING',
    'CAR_WASH',
    'EXTINCTEURS',
    'PERMIT_CIRCULATION',
    'METOLOGICA_NOTBOOK',
    'OPERATIONAL_CERTIFICATION',
    'Autre',
  ];

  static const _offenseTypes = [
    'Excès de vitesse',
    'Stationnement interdit',
    'Feu rouge grillé',
    'Téléphone au volant',
    'Ceinture de sécurité',
    'Autre',
  ];

  @override
  void dispose() {
    _payingCtrl.dispose();
    _autreOffenseCtrl.dispose();
    _autreDocCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isOffense) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: isOffense ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme:
          const ColorScheme.light(primary: Color(0xFF4904BD)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
              () => isOffense ? _offenseDate = picked : _endDate = picked);
    }
  }

  String _fmt(DateTime? d) => d == null
      ? 'agenda.choose_date'.tr()
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submit() async {
    if (_tab == 'document') {
      if (_selectedDocType == null || _endDate == null) {
        _snack('agenda.fill_all_fields'.tr());
        return;
      }
      if (_selectedDocType == 'Autre' &&
          _autreDocCtrl.text.trim().isEmpty) {
        _snack('agenda.specify_document_type'.tr());
        return;
      }
    } else {
      if (_selectedOffenseType == null || _offenseDate == null) {
        _snack('agenda.fill_all_fields'.tr());
        return;
      }
      if (_selectedOffenseType == 'Autre' &&
          _autreOffenseCtrl.text.trim().isEmpty) {
        _snack("agenda.specify_offense_type".tr());
        return;
      }
      if (double.tryParse(_payingCtrl.text.trim()) == null) {
        _snack('agenda.invalid_amount'.tr());
        return;
      }
    }

    setState(() => _loading = true);
    bool ok = false;
    try {
      if (_tab == 'document') {
        final docType = _selectedDocType == 'Autre'
            ? _autreDocCtrl.text.trim()
            : _selectedDocType!;
        ok = await EventService.createDocument(
          docType: docType,
          endDate: _endDate!,
        );
      } else {
        final offenseType = _selectedOffenseType == 'Autre'
            ? _autreOffenseCtrl.text.trim()
            : _selectedOffenseType!;
        ok = await EventService.createOffense(
          offenseType: offenseType,
          offenseDate: _offenseDate!,
          paying: double.parse(_payingCtrl.text.trim()),
        );
      }
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pop(context);
      widget.onCreated();
    } else {
      widget.onError();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isDark
              ? const LinearGradient(
            colors: [Color(0xFF1A0035), Color(0xFF2D1B69)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [Color(0xFF4904BD), Color(0xFF7226FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("agenda.new_event".tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 20),

              // ── Tabs ──────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _tabBtn('document', '📄 ${"agenda.document".tr()}'),
                    _tabBtn('offense', '⚠️ ${"agenda.offense".tr()}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Document fields ───────────────────────────────────────
              if (_tab == 'document') ...[
                _label('agenda.document_type'.tr()),
                const SizedBox(height: 8),
                _dropdown(_docTypes, _selectedDocType,
                        (v) => setState(() => _selectedDocType = v)),
                if (_selectedDocType == 'Autre') ...[
                  const SizedBox(height: 12),
                  _textField(
                    hint: 'agenda.specify_document_type'.tr(),
                    icon: Icons.edit,
                    controller: _autreDocCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                _label("agenda.expiration_date".tr()),
                const SizedBox(height: 8),
                _datePicker(_fmt(_endDate), () => _pickDate(false)),
              ],

              // ── Offense fields ────────────────────────────────────────
              if (_tab == 'offense') ...[
                _label("agenda.offense_type".tr()),
                const SizedBox(height: 8),
                _dropdown(_offenseTypes, _selectedOffenseType,
                        (v) => setState(() => _selectedOffenseType = v)),
                if (_selectedOffenseType == 'Autre') ...[
                  const SizedBox(height: 12),
                  _textField(
                    hint: "agenda.specify_offense_type".tr(),
                    icon: Icons.edit,
                    controller: _autreOffenseCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                _label("agenda.offense_date".tr()),
                const SizedBox(height: 8),
                _datePicker(
                    _fmt(_offenseDate), () => _pickDate(true)),
                const SizedBox(height: 16),
                _label('agenda.amount_tnd'.tr()),
                const SizedBox(height: 8),
                _textField(
                  hint: 'Ex: 150.00',
                  icon: Icons.payment,
                  controller: _payingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text('agenda.cancel'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _loading ? null : _submit,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: _loading
                            ? const Center(
                            child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF4904BD),
                                    strokeWidth: 2)))
                            : Text('agenda.save'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF4904BD),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String value, String label) {
    final selected = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF4904BD)
                    : Colors.white,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13,
              )),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600)),
  );

  Widget _dropdown(
      List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text('agenda.choose'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.5))),
          isExpanded: true,
          dropdownColor: const Color(0xFF4904BD),
          icon: Icon(Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.7)),
          items: items
              .map((e) => DropdownMenuItem(
            value: e,
            child: Text(e,
                style: const TextStyle(color: Colors.white)),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _textField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon:
        Icon(icon, color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Widget _datePicker(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  color: label == 'agenda.choose_date'.tr()
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}
