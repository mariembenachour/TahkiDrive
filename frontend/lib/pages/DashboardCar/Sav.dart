import 'package:flutter/material.dart';
import '../../services/sav_service.dart';
import 'sav_edit_popup.dart';

class SavPage extends StatefulWidget {
  const SavPage({super.key});

  @override
  State<SavPage> createState() => _SavPageState();
}

class _SavPageState extends State<SavPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  List<dynamic> _accidents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final accidents = await SavService.fetchAccidents();
      if (!mounted) return;
      setState(() {
        _accidents = accidents;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
          style: TextStyle(color: Color(0xFF160078), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7226FF),
          labelColor: const Color(0xFF7226FF),
          tabs: const [Tab(text: "Accidents")],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF)))
          : TabBarView(
        controller: _tabController,
        children: [_buildList(_accidents)],
      ),
    );
  }

  Widget _buildList(List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text("Aucune donnée",
            style: TextStyle(color: Color(0xFF160078), fontWeight: FontWeight.w600)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _SavCard(data: list[i], onRefresh: _load),
    );
  }
}

// ─────────────────────────────────────────────

class _SavCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  const _SavCard({required this.data, required this.onRefresh});

  @override
  State<_SavCard> createState() => _SavCardState();
}

class _SavCardState extends State<_SavCard> {
  bool open = false;

  String _date(dynamic val) {
    if (val == null) return "-";
    final s = val.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data;

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
          // ── Header de la carte ──
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
                    child: const Icon(Icons.car_crash_rounded, color: Color(0xFF7226FF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          _date(s["date_reparation"]),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),

          // ── Détails expandés ──
          if (open) ...[
            Divider(color: Colors.grey[100]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _row(Icons.description, "Description", s["description"]),
                  _row(Icons.calendar_month, "Date réparation", _date(s["date_reparation"])),
                  _row(Icons.payments_rounded, "Coût",
                      s["cost"] != null ? "${s["cost"]} TND" : "-"),
                  const SizedBox(height: 12),

                  // ── Boutons Modifier / Supprimer ──
                  Row(
                    children: [
                      // Modifier
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showEditDialog(
                              context: context,
                              data: s,
                              onUpdated: widget.onRefresh,
                            );
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7226FF), Color(0xFF160078)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7226FF).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text("Modifier",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Supprimer
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showDeleteConfirmDialog(
                              context: context,
                              idSav: s["id_sav"],
                              onDeleted: widget.onRefresh,
                            );
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3), width: 1),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 16),
                                SizedBox(width: 6),
                                Text("Supprimer",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(
                  value?.toString() ?? "-",
                  style: const TextStyle(
                      color: Color(0xFF160078), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
