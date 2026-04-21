import 'package:flutter/material.dart';
import '../../services/sav_service.dart';

class SavPage extends StatefulWidget {
  const SavPage({super.key});

  @override
  State<SavPage> createState() => _SavPageState();
}

class _SavPageState extends State<SavPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _accidents = [];
  List<dynamic> _pannes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final accidents = await SavService.fetchAccidents();
      final pannes = await SavService.fetchPannes();

      setState(() {
        _accidents = accidents;
        _pannes = pannes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF160078)),
        title: const Text(
          "Assistance",
          style: TextStyle(
            color: Color(0xFF160078),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7226FF),
          labelColor: const Color(0xFF7226FF),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Accidents"),
            Tab(text: "Pannes"),
          ],
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7226FF),
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildList(_accidents),
          _buildList(_pannes),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          "Aucune donnée",
          style: TextStyle(
            color: Color(0xFF160078),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _SavCard(data: list[i]),
    );
  }
}

class _SavCard extends StatefulWidget {
  final Map<String, dynamic> data;

  const _SavCard({required this.data});

  @override
  State<_SavCard> createState() => _SavCardState();
}

class _SavCardState extends State<_SavCard> {
  bool open = false;

  Color _statusColor(String etat) {
    switch (etat.toLowerCase()) {
      case "terminé":
      case "termine":
        return Colors.green;
      case "en cours":
        return Colors.orange;
      case "en attente":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _date(dynamic val) {
    if (val == null) return "-";
    return val.toString().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data;

    // ✅ FIX IMPORTANT
    final isAccident = s["type_sav"] == "accident";

    final etat = s["etat"]?.toString() ?? "-";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => open = !open),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7226FF).withOpacity(.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isAccident
                          ? Icons.car_crash_rounded
                          : Icons.build_circle_rounded,
                      color: const Color(0xFF7226FF),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAccident ? "Accident" : "Panne",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF160078),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // ✅ FIX DATE
                        Text(
                          _date(s["date_creation"]),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(etat).withOpacity(.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      etat,
                      style: TextStyle(
                        color: _statusColor(etat),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  )
                ],
              ),
            ),
          ),

          if (open) ...[
            Divider(color: Colors.grey[100]),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row(Icons.description, "Description",
                      s["description"]),

                  _row(Icons.garage, "Garage",
                      s["id_garage"]?.toString()),

                  _row(Icons.build, "Type SAV",
                      s["type_sav"]),

                  _row(Icons.calendar_month, "Date réparation",
                      _date(s["actual_repair_time"])),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7226FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(
                  value?.toString() ?? "-",
                  style: const TextStyle(
                    color: Color(0xFF160078),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}




