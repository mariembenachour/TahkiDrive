import 'package:flutter/material.dart';
import '../../services/event_service.dart';

class EventHistoriquePage extends StatefulWidget {
  const EventHistoriquePage({super.key});

  @override
  State<EventHistoriquePage> createState() => _EventHistoriquePageState();
}

class _EventHistoriquePageState extends State<EventHistoriquePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allEvents = [];
  bool _loading = true;
  String _searchQuery = "";
  String _selectedTab = "All";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await EventService.fetchEvents();
      setState(() {
        _allEvents = data['all_events'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      print("Erreur load: $e");
      setState(() => _loading = false);
    }
  }

  List<dynamic> _filtered() {
    List<dynamic> base = _allEvents;

    if (_selectedTab == "Category") {
      base = _allEvents;
    } else if (_selectedTab == "By Date") {
      base = _allEvents;
    }

    if (_searchQuery.isEmpty) return base;
    return base.where((e) {
      final title = _eventTitle(e).toLowerCase();
      final subtitle = _eventSubtitle(e).toLowerCase();
      final date = _eventDate(e).toLowerCase();
      final type = (e['doc_type'] ?? e['maintenance_type'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) ||
          subtitle.contains(_searchQuery) ||
          date.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();
  }

  Map<String, List<dynamic>> _groupByDate(List<dynamic> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedTab == "By Date") {
      final upcoming = events.where((e) => e['is_upcoming'] == true).toList();
      final recent = events.where((e) => e['is_upcoming'] != true).toList();
      final Map<String, List<dynamic>> g = {};
      if (upcoming.isNotEmpty) g["Upcoming"] = upcoming;
      if (recent.isNotEmpty) g["Recent"] = recent;
      return g;
    }
    if (_selectedTab == "Category") {
      final Map<String, List<dynamic>> g = {};
      for (final e in events) {
        final groupKey = e['event_category'] == 'maintenance'
            ? "Maintenance"
            : "Documents";
        g.putIfAbsent(groupKey, () => []).add(e);
      }
      return g;
    }

    final Map<String, List<dynamic>> groups = {
      "Today": [], "This Week": [], "This Month": [], "Older": [],
    };

    for (final e in events) {
      DateTime? date;
      try {
        final raw = e['date_operation'] ?? e['begin_date'];
        if (raw != null) date = DateTime.parse(raw.toString());
      } catch (_) {}

      if (date == null) { groups["Older"]!.add(e); continue; }

      final d = DateTime(date.year, date.month, date.day);
      final diff = today.difference(d).inDays;

      if (d == today)       groups["Today"]!.add(e);
      else if (diff <= 7)   groups["This Week"]!.add(e);
      else if (diff <= 30)  groups["This Month"]!.add(e);
      else                  groups["Older"]!.add(e);
    }

    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  IconData _eventIcon(Map<String, dynamic> e) {
    if (e['event_category'] == 'maintenance') {
      final t = (e['maintenance_type'] ?? '').toString().toLowerCase();
      if (t.contains('oil')) return Icons.oil_barrel_rounded;
      return Icons.build_circle_outlined;
    }
    switch (e['doc_type']) {
      case 'INSURANCE':                 return Icons.shield_rounded;
      case 'VISIT':                     return Icons.assignment_rounded;
      case 'FUEL':                      return Icons.local_gas_station_rounded;
      case 'CAR_WASH':                  return Icons.local_car_wash_rounded;
      case 'EXTINCTEURS':               return Icons.fire_extinguisher_rounded;
      case 'TOLL':                      return Icons.toll_rounded;
      case 'ROAD_TAXES':                return Icons.account_balance_rounded;
      case 'PARCKING':                  return Icons.local_parking_rounded;
      case 'PERMIT_CIRCULATION':        return Icons.credit_card_rounded;
      case 'METOLOGICA_NOTBOOK':        return Icons.book_rounded;
      case 'OPERATIONAL_CERTIFICATION': return Icons.verified_rounded;
      default:                          return Icons.event_rounded;
    }
  }

  Color _eventColor(Map<String, dynamic> e) {
    if (e['event_category'] == 'maintenance') return const Color(0xFFF59E0B);
    switch (e['doc_type']) {
      case 'INSURANCE':                 return const Color(0xFF3B82F6);
      case 'VISIT':                     return const Color(0xFF8B5CF6);
      case 'FUEL':                      return const Color(0xFF10B981);
      case 'CAR_WASH':                  return const Color(0xFF06B6D4);
      case 'EXTINCTEURS':               return const Color(0xFFEF4444);
      case 'TOLL':                      return const Color(0xFF6366F1);
      case 'ROAD_TAXES':                return const Color(0xFFEF4444);
      case 'PARCKING':                  return const Color(0xFF64748B);
      case 'PERMIT_CIRCULATION':        return const Color(0xFF7226FF);
      case 'METOLOGICA_NOTBOOK':        return const Color(0xFF7C3AED);
      case 'OPERATIONAL_CERTIFICATION': return const Color(0xFF059669);
      default:                          return const Color(0xFF7226FF);
    }
  }

  String _eventTitle(Map<String, dynamic> e) {
    if (e['event_category'] == 'maintenance') {
      return e['maintenance_type'] ?? 'Maintenance';
    }
    switch (e['doc_type']) {
      case 'INSURANCE':                 return 'Assurance';
      case 'VISIT':                     return 'Visite technique';
      case 'FUEL':                      return 'Carburant';
      case 'CAR_WASH':                  return 'Lavage';
      case 'EXTINCTEURS':               return 'Extincteurs';
      case 'TOLL':                      return 'Péage';
      case 'ROAD_TAXES':                return 'Vignette';
      case 'PARCKING':                  return 'Parking';
      case 'PERMIT_CIRCULATION':        return 'Permis de circulation';
      case 'METOLOGICA_NOTBOOK':        return 'Carnet métrologique';
      case 'OPERATIONAL_CERTIFICATION': return 'Certification opérationnelle';
      default:                          return e['doc_type'] ?? '';
    }
  }

  String _eventDate(Map<String, dynamic> e) {
    final raw = e['date_operation'] ?? e['begin_date'] ?? '';
    return raw.toString().length >= 10
        ? raw.toString().substring(0, 10)
        : raw.toString();
  }

  String _eventSubtitle(Map<String, dynamic> e) {
    final parts = <String>[];
    if (e['provider_name'] != null) parts.add(e['provider_name']);
    if (e['garage_name'] != null) parts.add(e['garage_name']);
    if (e['cost'] != null) parts.add('${e['cost']} TND');
    return parts.join(' • ');
  }

  Widget _animated({required Widget child, required double delay}) {
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.clamp(0.0, 0.9), 1.0, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final groups = _groupByDate(filtered);

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDF6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _animated(
              delay: 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Color(0xFF160078), size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("Historique",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
                    ]),
                    TextButton(
                      onPressed: () => _searchController.clear(),
                      child: const Text("Clear All",
                          style: TextStyle(color: Color(0xFF7226FF), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            // Search
            _animated(
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Rechercher par date ou catégorie...",
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF7226FF), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
            ),

            // Tabs
            _animated(
              delay: 0.15,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["All", "Category", "By Date"].map((tab) {
                    final isSelected = _selectedTab == tab;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTab = tab),
                      child: Column(
                        children: [
                          Text(tab,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF160078) : Colors.grey,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              )),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              height: 3, width: 25,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7226FF),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Liste
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF)))
                  : filtered.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty ? 'Aucun événement trouvé' : 'Aucun résultat pour "$_searchQuery"',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
                  : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: groups.entries.expand((entry) {
                  return [
                    _animated(
                      delay: 0.2,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                        child: Text(entry.key,
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                    ...entry.value.asMap().entries.map((item) {
                      final e = item.value as Map<String, dynamic>;
                      final color = _eventColor(e);
                      return _animated(
                        delay: (0.25 + item.key * 0.05).clamp(0.0, 0.9),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_eventIcon(e), color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_eventTitle(e),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
                                    const SizedBox(height: 3),
                                    Text(_eventSubtitle(e),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              // ── DATE SEULEMENT, PLUS DE FLÈCHE ──
                              Text(
                                _eventDate(e),
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ];
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}