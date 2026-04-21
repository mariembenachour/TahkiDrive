import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tahki_drive1/services/event_service.dart';

class AgendaPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const AgendaPage({super.key, this.onBackToDashboard});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<Map<String, dynamic>> _eventsFuture;
  Map<DateTime, List<Map>> _eventsMap = {};
  List<Map> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // Initialisation du jour sélectionné
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _controller.forward();
    _eventsFuture = EventService.fetchEvents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _luxuryAnimatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
  }

  // ================== HELPERS ==================
  String _getTitle(Map e) {
    if (e['event_category'] == 'document') return e['doc_type'] ?? 'Document';
    return e['maintenance_type'] ?? 'Maintenance';
  }

  String _getDate(Map e) {
    if (e['event_category'] == 'document') {
      return e['begin_date']?.toString().split('T')[0] ?? '-';
    }
    return e['date_operation']?.toString().split('T')[0] ?? '-';
  }

  String _getLocation(Map e) {
    if (e['event_category'] == 'document') return e['provider_name'] ?? '-';
    return e['garage_name'] ?? '-';
  }

  String _getUpcomingDate(Map e) {
    if (e['event_category'] == 'document') {
      return e['end_date']?.toString().split('T')[0] ?? '-';
    }
    if (e['next_oil_date'] != null) return e['next_oil_date'].toString().split('T')[0];
    if (e['upcoming_date'] != null) return e['upcoming_date'].toString().split('T')[0];
    if (e['upcoming_km'] != null) return '${e['upcoming_km']} km';
    return '-';
  }

  IconData _getIcon(Map e) {
    if (e['event_category'] == 'document') {
      switch ((e['doc_type'] ?? '').toString().toUpperCase()) {
        case 'INSURANCE': return Icons.security_outlined;
        case 'VISIT': return Icons.assignment_outlined;
        default: return Icons.description_outlined;
      }
    }
    switch ((e['maintenance_type'] ?? '').toString().toLowerCase()) {
      case 'oil change': return Icons.oil_barrel_outlined;
      case 'brake': return Icons.disc_full_outlined;
      case 'battery': return Icons.battery_charging_full_outlined;
      case 'embrayage': return Icons.settings_outlined;
      default: return Icons.build_circle_outlined;
    }
  }

  Color _getColor(Map e) {
    if (e['event_category'] == 'document') return Colors.blue;
    switch ((e['maintenance_type'] ?? '').toString().toLowerCase()) {
      case 'oil change': return Colors.orange;
      case 'brake': return Colors.red;
      case 'battery': return Colors.purple;
      case 'embrayage': return Colors.green;
      default: return Colors.teal;
    }
  }

  bool _isOverdue(Map e) {
    final now = DateTime.now();
    if (e['event_category'] == 'document' && e['end_date'] != null) {
      try {
        final end = DateTime.parse(e['end_date'].toString());
        return end.isBefore(now);
      } catch (_) {}
    }
    return false;
  }

  // ================== POPUP DETAILS ==================
  void _showDetails(Map e) {
    final color = _getColor(e);
    final icon = _getIcon(e);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "details",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${e['mark'] ?? ''} ${e['model'] ?? ''}',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
                          if (e['event_category'] == 'document') ...[
                            _detailRow("Type", e['doc_type']),
                            _detailRow("Début", e['begin_date']?.toString().split('T')[0]),
                            _detailRow("Expiration", e['end_date']?.toString().split('T')[0]),
                          ] else ...[
                            _detailRow("Catégorie", e['event_category']),
                            _detailRow("Type SAV", e['type_sav']),

                            if (e['event_category'] == 'maintenance')
                              _detailRow("Maintenance", e['maintenance_type']),

                            _detailRow("Date", e['date_operation']?.toString().split('T')[0]),
                            _detailRow("Coût", "${e['cost'] ?? '-'} DT"),

                            _detailRow(
                              "Description",
                              e['description'] ?? e['observation'] ?? '-',
                            ),

                            _detailRow("Statut", e['etat']),

                            if (e['garage_name'] != null)
                              _detailRow("Garage", e['garage_name']),

                            if (e['telephone'] != null)
                              _detailRow("Téléphone", e['telephone']),

                            if (e['adresse'] != null)
                              _detailRow("Adresse", e['adresse']),

                            if (e['next_oil_date'] != null)
                              _detailRow("Prochaine vidange", e['next_oil_date'].toString().split('T')[0]),

                            if (e['upcoming_km'] != null)
                              _detailRow("Prochain à", "${e['upcoming_km']} km"),

                            if (e['upcoming_date'] != null)
                              _detailRow("Prochaine date", e['upcoming_date'].toString().split('T')[0]),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: Text("Fermer", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4904BD), Color(0xFFF0EDF6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              _luxuryAnimatedEntry(
                delay: 0.05,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderButton(Icons.arrow_back_ios_new, () {
                        if (widget.onBackToDashboard != null) widget.onBackToDashboard!();
                      }),
                      const Text("Agenda", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      _buildHeaderButton(Icons.refresh, () {
                        setState(() {
                          _eventsFuture = EventService.fetchEvents();
                        });
                      }),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _eventsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }

                    // On vérifie si la clé 'all_events' est directe ou sous 'events'
                    final data = snapshot.data;
                    final allEvents = (data?['all_events'] ?? data?['events']?['all_events'] as List<dynamic>? ?? []);

                    _eventsMap.clear();
                    for (var e in allEvents) {
                      String? dateStr = (e['event_category'] == 'document') ? e['begin_date'] : e['date_operation'];
                      if (dateStr != null) {
                        try {
                          DateTime date = DateTime.parse(dateStr);
                          final day = DateTime(date.year, date.month, date.day);
                          if (_eventsMap[day] == null) _eventsMap[day] = [];
                          _eventsMap[day]!.add(e as Map);
                        } catch (err) { print("Erreur date: $err"); }
                      }
                    }

                    // Calcul des events du jour sélectionné
                    final currentSelection = _selectedDay ?? _focusedDay;
                    _selectedEvents = _eventsMap[DateTime(currentSelection.year, currentSelection.month, currentSelection.day)] ?? [];

                    final upcomingEvents = allEvents.where((e) => e['is_upcoming'] == true).toList();
                    final recentEvents = allEvents.where((e) => e['is_upcoming'] != true).toList();

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CALENDAR
                            _luxuryAnimatedEntry(
                              delay: 0.2,
                              child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                                  ),
                                  child: TableCalendar(
                                    firstDay: DateTime.utc(2020, 1, 1),
                                    lastDay: DateTime.utc(2030, 12, 31),
                                    focusedDay: _focusedDay,
                                    calendarFormat: _calendarFormat,
                                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                    onDaySelected: (selectedDay, focusedDay) {
                                      setState(() {
                                        _selectedDay = selectedDay;
                                        _focusedDay = focusedDay;
                                      });
                                    },
                                    eventLoader: (day) => _eventsMap[DateTime(day.year, day.month, day.day)] ?? [],
                                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                                    calendarStyle: const CalendarStyle(
                                      todayDecoration: BoxDecoration(color: Color(0xFFD1B3FF), shape: BoxShape.circle),
                                      selectedDecoration: BoxDecoration(color: Color(0xFF7226FF), shape: BoxShape.circle),
                                      markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    ),
                                  )
                              ),
                            ),

                            const SizedBox(height: 25),
                            const Text("Events du jour", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                            const SizedBox(height: 10),

                            if (_selectedEvents.isEmpty)
                              const Text("Aucun événement", style: TextStyle(color: Colors.grey))
                            else
                              ..._selectedEvents.map((e) => _buildEventCard(e: e, subtitle: _getDate(e))),

                            const SizedBox(height: 25),
                            // ===== UPCOMING =====
                            _luxuryAnimatedEntry(
                              delay: 0.35,
                              child: const Text("Upcoming", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                            ),
                            const SizedBox(height: 15),

                            if (upcomingEvents.isEmpty)
                              Center(child: Text("Aucun événement à venir", style: TextStyle(color: Colors.grey[600])))
                            else
                              ...upcomingEvents.asMap().entries.map((entry) {
                                final e = entry.value as Map;
                                return _buildEventCard(
                                  e: e,
                                  subtitle: 'Expire: ${_getUpcomingDate(e)}',
                                  tag: _isOverdue(e) ? 'Expiré' : 'À venir',
                                  tagColor: _isOverdue(e) ? Colors.red : Colors.green,
                                );
                              }),

                            const SizedBox(height: 25),
                            // ===== RÉCENTS =====
                            _luxuryAnimatedEntry(
                              delay: 0.5,
                              child: const Text("Récents", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                            ),
                            const SizedBox(height: 15),

                            if (recentEvents.isEmpty)
                              Center(child: Text("Aucun événement récent", style: TextStyle(color: Colors.grey[600])))
                            else
                              ...recentEvents.asMap().entries.map((entry) {
                                final e = entry.value as Map;
                                return _buildEventCard(e: e, subtitle: _getDate(e));
                              }),
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
    );
  }

  Widget _buildEventCard({required Map e, required String subtitle, String? tag, Color? tagColor}) {
    final color = _getColor(e);
    final icon = _getIcon(e);
    return GestureDetector(
      onTap: () => _showDetails(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text(_getTitle(e), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF160078)))),
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: (tagColor ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(tag, style: TextStyle(color: tagColor ?? Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF160078) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}