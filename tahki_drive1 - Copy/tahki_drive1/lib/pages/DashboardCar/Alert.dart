import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/notification_service.dart';

class AlertsPage extends StatefulWidget {
  final int driverId;
  const AlertsPage({super.key, required this.driverId});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with SingleTickerProviderStateMixin {
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
    // Récupérer tous les événements
    final events = await NotificationService.fetchAllEvents(widget.driverId);
    // Ne garder que les pannes (doc_type == null)
    final pannes = events.where((e) => e['doc_type'] == null).toList();
    setState(() {
      _allEvents = pannes;
      _isLoading = false;
    });
  }

  Future<void> _markAsNotified(int eventId) async {
    await NotificationService.markEventAsNotified(eventId, widget.driverId);
    _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerte marquée comme lue'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<dynamic> get _filteredEvents {
    if (_searchQuery.isEmpty) return _allEvents;
    return _allEvents.where((e) {
      final title = (e['title'] ?? '').toLowerCase();
      final desc = (e['description'] ?? '').toLowerCase();
      return title.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Map<String, List<dynamic>> get _groupedEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<dynamic>> groups = {
      "Aujourd'hui": [],
      "Cette semaine": [],
      "Plus ancien": [],
    };

    for (final e in _filteredEvents) {
      DateTime? date;
      try {
        date = DateTime.parse(e['date']);
      } catch (_) {}
      if (date == null) continue;
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) {
        groups["Aujourd'hui"]!.add(e);
      } else if (d.isAfter(weekAgo)) {
        groups["Cette semaine"]!.add(e);
      } else {
        groups["Plus ancien"]!.add(e);
      }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedEvents;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8EAF6), Color(0xFFF3E5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF)))
                    : _filteredEvents.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: groups.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                        child: Text(
                          entry.key,
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      ...entry.value.map((event) => _buildAlertItem(event)),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF160078)),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                "Problem History",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7226FF)),
            onPressed: _loadEvents,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: "Rechercher par titre ou description...",
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Color(0xFF7226FF)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? "Aucune panne signalée" : "Aucun résultat",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> event) {
    final isNew = event['is_notified'] == '0' || event['is_notified'] == false;
    final Color mainColor = Colors.red;
    final String title = event['title'] ?? 'Alerte';
    final String subtitle = event['description'] ?? '';
    final String date = _formatDate(event['date']);

    return GestureDetector(
      onTap: () {
        if (isNew) _markAsNotified(event['id']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: isNew ? Border.all(color: mainColor.withOpacity(0.5), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Color(0xFF160078), fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: mainColor, borderRadius: BorderRadius.circular(12)),
                          child: const Text('NEW', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
      if (eventDate == today) dayFormat = "Aujourd'hui";
      else if (eventDate == yesterday) dayFormat = "Hier";
      else dayFormat = '${date.day}/${date.month}/${date.year}';
      return '$dayFormat à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}