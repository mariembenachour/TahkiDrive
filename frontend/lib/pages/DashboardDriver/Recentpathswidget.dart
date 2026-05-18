// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/driver/RecentPathsWidget.dart
// Contient :
//   • _buildRecentActivities()  →  remplace le placeholder dans DashboardChauffeur
//   • PathDetailPage            →  page détail d'un trajet
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tahki_drive1/pages/DashboardDriver/PathsPage.dart';
import '../../services/path_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MIXIN / HELPER  –  à coller dans _DashboardChauffeurState
//  (ou extraire en StatefulWidget séparé si tu préfères)
// ══════════════════════════════════════════════════════════════════════════════

// ─── Couleurs (identiques au Dashboard) ──────────────────────────────────────
const Color _blue       = Color(0xFF006AD7);
const Color _blueDark   = Color(0xFF21277B);
const Color _greyBlue   = Color(0xFF5F83B1);

// ─── Formatters ───────────────────────────────────────────────────────────────
String _fmtTime(String? iso) {
  if (iso == null || iso.isEmpty) return '--:--';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  } catch (_) { return '--:--'; }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "Aujourd'hui";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) return 'Hier';
    return DateFormat('dd MMM', 'fr').format(dt);
  } catch (_) { return '—'; }
}

String _fmtDuration(dynamic seconds) {
  final s = (seconds as num?)?.toInt() ?? 0;
  if (s == 0) return '—';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
  return '${m}min';
}

String _fmtKm(dynamic val) {
  final d = (val as num?)?.toDouble() ?? 0.0;
  if (d == 0) return '—';
  return d >= 1000
      ? '${(d / 1000).toStringAsFixed(1)} km'
      : '${d.toStringAsFixed(0)} m';
}

String _fmtSpeed(dynamic val) {
  final v = (val as num?)?.toInt() ?? 0;
  return '$v km/h';
}

String _fmtLitre(dynamic val) {
  final v = (val as num?)?.toDouble() ?? 0.0;
  if (v == 0) return '—';
  return '${v.toStringAsFixed(1)} L';
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGET PRINCIPAL  –  remplace _buildRecentActivities()
// ══════════════════════════════════════════════════════════════════════════════
class RecentPathsSection extends StatefulWidget {
  const RecentPathsSection({super.key});

  @override
  State<RecentPathsSection> createState() => _RecentPathsSectionState();
}

class _RecentPathsSectionState extends State<RecentPathsSection> {
  List<Map<String, dynamic>> _paths = [];
  bool _loading = true;

  // ─── nombre de trajets affichés ────────────────────────────────────────────
  static const int _initialLimit = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await PathService.getRecentPaths(limit: _initialLimit);
    if (mounted) setState(() { _paths = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.route_rounded,
                        color: _blue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Trajets récents",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _blueDark,
                    ),
                  ),
                ]),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PathsPage(),
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: _blue),
                  child: Text(
                    "Voir tout",
                    style: GoogleFonts.poppins(
                      color: _blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Contenu ──────────────────────────────────────────────────────
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: _blue),
                ),
              )
            else if (_paths.isEmpty)
              _buildEmpty()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _paths.length,
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemBuilder: (ctx, i) => _PathTile(path: _paths[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(children: [
        Icon(Icons.route_outlined,
            size: 40, color: _greyBlue.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text(
          "Aucun trajet enregistré",
          style: GoogleFonts.poppins(fontSize: 13, color: _greyBlue),
        ),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  TILE  –  une ligne = un trajet
// ══════════════════════════════════════════════════════════════════════════════
class _PathTile extends StatelessWidget {
  final Map<String, dynamic> path;
  const _PathTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final date     = _fmtDate(path['begin_path_time'] as String?);
    final start    = _fmtTime(path['begin_path_time'] as String?);
    final end      = _fmtTime(path['end_path_time']   as String?);
    final km       = _fmtKm(path['distance_driven']);
    final duration = _fmtDuration(path['path_duration']);
    final speed    = _fmtSpeed(path['max_speed']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PathDetailPage(path: path)),
      ),
      child: Row(children: [
        // ── Icône rond ──────────────────────────────────────────────────────
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_blue, _blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.directions_car_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),

        // ── Info principale ─────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _blueDark),
              ),
              const SizedBox(height: 3),
              Text(
                "$start → $end",
                style: GoogleFonts.poppins(fontSize: 12, color: _greyBlue),
              ),
            ],
          ),
        ),

        // ── Badges droite ───────────────────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _badge(Icons.straighten_rounded, km, _blue),
          const SizedBox(height: 4),
          _badge(Icons.speed_rounded, speed, Colors.orange.shade600),
        ]),

        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: _greyBlue, size: 20),
      ]),
    );
  }

  Widget _badge(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAGE VOIR TOUT  –  pagination infinie
// ══════════════════════════════════════════════════════════════════════════════
class AllPathsPage extends StatefulWidget {
  const AllPathsPage({super.key});

  @override
  State<AllPathsPage> createState() => _AllPathsPageState();
}

class _AllPathsPageState extends State<AllPathsPage> {
  final List<Map<String, dynamic>> _paths = [];
  final ScrollController _scroll = ScrollController();

  bool _loading  = false;
  bool _hasMore  = true;
  int  _offset   = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final batch = await PathService.getRecentPaths(
        limit: _pageSize, offset: _offset);
    if (mounted) {
      setState(() {
        _paths.addAll(batch);
        _offset  += batch.length;
        _hasMore  = batch.length == _pageSize;
        _loading  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDF6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _blueDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Tous les trajets",
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _blueDark),
        ),
        centerTitle: true,
      ),
      body: _paths.isEmpty && !_loading
          ? Center(
        child: Text("Aucun trajet",
            style: GoogleFonts.poppins(color: _greyBlue)),
      )
          : ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _paths.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _paths.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: CircularProgressIndicator(color: _blue)),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PathCard(path: _paths[i]),
          );
        },
      ),
    );
  }
}

// ── Card dans la liste complète ───────────────────────────────────────────────
class _PathCard extends StatelessWidget {
  final Map<String, dynamic> path;
  const _PathCard({required this.path});

  @override
  Widget build(BuildContext context) {
    final date     = _fmtDate(path['begin_path_time']  as String?);
    final start    = _fmtTime(path['begin_path_time']  as String?);
    final end      = _fmtTime(path['end_path_time']    as String?);
    final km       = _fmtKm(path['distance_driven']);
    final duration = _fmtDuration(path['path_duration']);
    final speed    = _fmtSpeed(path['max_speed']);
    final fuel     = _fmtLitre(path['fuel_used']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PathDetailPage(path: path)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ligne ───────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_blue, _blueDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(date,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _blueDark)),
                Text("$start → $end",
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _greyBlue)),
              ]),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  color: _greyBlue, size: 22),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── 4 stats ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip(Icons.straighten_rounded,       km,       "Distance"),
                _statChip(Icons.timer_rounded,            duration, "Durée"),
                _statChip(Icons.speed_rounded,            speed,    "Vit. max"),
                _statChip(Icons.local_gas_station_rounded, fuel,    "Carburant"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _blue, size: 16),
      ),
      const SizedBox(height: 5),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _blueDark)),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, color: _greyBlue)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAGE DÉTAIL  –  toutes les colonnes de la table path
// ══════════════════════════════════════════════════════════════════════════════
class PathDetailPage extends StatelessWidget {
  final Map<String, dynamic> path;
  const PathDetailPage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final date     = _fmtDate(path['begin_path_time']  as String?);
    final start    = _fmtTime(path['begin_path_time']  as String?);
    final end      = _fmtTime(path['end_path_time']    as String?);
    final km       = _fmtKm(path['distance_driven']);
    final duration = _fmtDuration(path['path_duration']);
    final speed    = _fmtSpeed(path['max_speed']);
    final fuel     = _fmtLitre(path['fuel_used']);
    final startF   = _fmtLitre(path['start_fuel']);
    final endF     = _fmtLitre(path['end_fuel']);
    final startOdo = '${(path['start_odo'] as num?)?.toInt() ?? 0} km';
    final endOdo   = '${(path['end_odo']   as num?)?.toInt() ?? 0} km';

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDF6),
      body: CustomScrollView(
        slivers: [
          // ── AppBar dégradé ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: _blue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_blue, _blueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        date,
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$start  →  $end",
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 4 grandes stats ──────────────────────────────────────
                _sectionTitle("Résumé"),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  childAspectRatio: 1.9,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _bigStatCard(Icons.straighten_rounded,
                        km, "Distance", Colors.blue.shade600),
                    _bigStatCard(Icons.timer_rounded,
                        duration, "Durée", Colors.purple.shade400),
                    _bigStatCard(Icons.speed_rounded,
                        speed, "Vitesse max", Colors.orange.shade600),
                    _bigStatCard(Icons.local_gas_station_rounded,
                        fuel, "Carburant", Colors.red.shade400),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Carburant détail ────────────────────────────────────
                _sectionTitle("Carburant"),
                const SizedBox(height: 12),
                _detailCard([
                  _detailRow(Icons.battery_full_rounded,
                      "Début", startF, Colors.green),
                  _detailRow(Icons.battery_2_bar_rounded,
                      "Fin", endF, Colors.red.shade400),
                  _detailRow(Icons.local_gas_station_rounded,
                      "Consommé", fuel, Colors.orange.shade600),
                ]),

                const SizedBox(height: 20),

                // ── Kilométrage ─────────────────────────────────────────
                _sectionTitle("Kilométrage"),
                const SizedBox(height: 12),
                _detailCard([
                  _detailRow(Icons.radio_button_unchecked,
                      "Compteur départ", startOdo, _blue),
                  _detailRow(Icons.radio_button_checked,
                      "Compteur arrivée", endOdo, _blueDark),
                  _detailRow(Icons.straighten_rounded,
                      "Distance parcourue", km, Colors.teal),
                ]),

                const SizedBox(height: 20),

                // ── Coordonnées GPS ─────────────────────────────────────
                _sectionTitle("Position GPS"),
                const SizedBox(height: 12),
                _detailCard([
                  _detailRow(
                    Icons.location_on_rounded,
                    "Départ",
                    "${path['begin_path_latitude'] ?? '—'}, ${path['begin_path_longitude'] ?? '—'}",
                    Colors.green.shade600,
                  ),
                  _detailRow(
                    Icons.flag_rounded,
                    "Arrivée",
                    "${path['end_path_latitude'] ?? '—'}, ${path['end_path_longitude'] ?? '—'}",
                    Colors.red.shade500,
                  ),
                ]),

              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: _blueDark),
  );

  Widget _bigStatCard(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _blueDark)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: _greyBlue)),
          ]),
        ]),
      );

  Widget _detailCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Column(
      children: rows
          .expand((w) => [w, const Divider(height: 18)])
          .toList()
        ..removeLast(),
    ),
  );

  Widget _detailRow(
      IconData icon, String label, String value, Color color) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: _greyBlue)),
        ),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _blueDark)),
      ]);
}
