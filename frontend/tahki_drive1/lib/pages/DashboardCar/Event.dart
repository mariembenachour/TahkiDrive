import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/event_service.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String selectedTab = "All";
  late Future<Map<String, dynamic>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
    _eventsFuture = EventService.fetchEvents();


  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.reset();
    _controller.forward();
  }

  // ================== LUXURY ENTRY ANIMATION ==================
  Widget _luxuryAnimatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              // Header (delay 0.0)
              _luxuryAnimatedEntry(
                delay: 0.0,
                child: _buildHeader(context),
              ),

              // Search Bar (delay 0.1)
              _luxuryAnimatedEntry(
                delay: 0.1,
                child: _buildSearchBar(),
              ),

              // Filter Tabs (delay 0.2)
              _luxuryAnimatedEntry(
                delay: 0.2,
                child: _buildFilterTabs(),
              ),

              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _eventsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Aucun événement'));
                    }

                    final events = snapshot.data!['all_events'] as List<dynamic>;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final e = events[index];
                        return _luxuryAnimatedEntry(
                          delay: 0.3 + index * 0.05,
                          child: _buildEventItem(
                            icon: e['event_category'] == 'maintenance' ? Icons.build_circle_outlined : Icons.route_outlined,
                            title: e['event_category'] == 'maintenance' ? 'Maintenance' : 'Document',
                            desc: e['event_category'] == 'maintenance' ? '${e['observation'] ?? ''}' : 'Début: ${e['begin_date']}',
                            time: e['event_category'] == 'maintenance' ? '${e['next_oil_date'] ?? ''}' : '${e['begin_date']}',
                            color: e['event_category'] == 'maintenance' ? Colors.green : Colors.blue,
                          ),
                        );
                      },
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

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildFilterTabs() {
    final tabs = ["All", "Category", "Timeline"];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tabs.map((tab) {
          bool isSelected = selectedTab == tab;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedTab = tab;
              });
            },
            child: Column(
              children: [
                Text(
                  tab,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF160078) : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 3,
                    width: 25,
                    decoration: BoxDecoration(
                        color: const Color(0xFF7226FF),
                        borderRadius: BorderRadius.circular(2)),
                  )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF160078)), onPressed: () => Navigator.pop(context)),
            const Text("Events", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF160078))),
          ]),
          IconButton(icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF7226FF)), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: const TextField(
          decoration: InputDecoration(hintText: "Search events...", prefixIcon: Icon(Icons.search, color: Color(0xFF7226FF)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF160078)),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF160078), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ]),
    );
  }

  Widget _buildEventItem({required IconData icon, required String title, required String desc, required String time, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF160078), fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13))])),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}