import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminDriversTab extends StatefulWidget {
  final String defaultFilter;
  const AdminDriversTab({super.key, this.defaultFilter = 'all'});

  @override
  State<AdminDriversTab> createState() => _AdminDriversTabState();
}

class _AdminDriversTabState extends State<AdminDriversTab> {
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;
  String? _error;
  late String _filter;
  String _search = '';

  // ── palette ───────────────────────────────────────────────────────────────
  static const _neonPurple      = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _darkBg          = Color(0xFF050510);

  @override
  void initState() {
    super.initState();
    _filter = widget.defaultFilter;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await AdminService.getDrivers(status: _filter);
      if (mounted) setState(() { _drivers = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _drivers;
    final q = _search.toLowerCase();
    return _drivers.where((d) =>
        '${d['first_name']} ${d['last_name']} ${d['email']} ${d['cin']}'
            .toLowerCase().contains(q)).toList();
  }

  Future<void> _activate(String cin) async {
    try {
      await AdminService.activateDriver(cin);
      _showSnack('Chauffeur activé ✓', Colors.green);
      _load();
    } catch (e) { _showSnack('Erreur: $e', Colors.red); }
  }

  Future<void> _block(String cin) async {
    try {
      await AdminService.blockDriver(cin);
      _showSnack('Chauffeur bloqué', Colors.orange);
      _load();
    } catch (e) { _showSnack('Erreur: $e', Colors.red); }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filtres + recherche ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ...[('all', 'Tous'), ('pending', 'En attente'), ('active', 'Actifs')]
                  .map((item) {
                final active = _filter == item.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _filter = item.$1); _load(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active
                            ? _neonPurple.withOpacity(0.18)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? _neonPurple.withOpacity(0.6)
                              : Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: active ? [BoxShadow(
                          color: _neonPurple.withOpacity(0.2),
                          blurRadius: 10, spreadRadius: 0,
                        )] : [],
                      ),
                      child: Text(item.$2,
                          style: TextStyle(
                            color: active ? _neonPurpleLight : Colors.white38,
                            fontSize: 12,
                            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                          )),
                    ),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                width: 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _neonPurple.withOpacity(0.15)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: _neonPurple.withOpacity(0.5), size: 18),
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _neonPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _neonPurple.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 18),
                ),
              ),
            ],
          ),
        ),

        // ── Liste ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(
              color: _neonPurple, strokeWidth: 2))
              : _error != null
              ? Center(child: Text(_error!,
              style: const TextStyle(color: Colors.redAccent)))
              : _filtered.isEmpty
              ? Center(child: Text('Aucun chauffeur',
              style: TextStyle(color: Colors.white.withOpacity(0.3))))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _driverCard(_filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final authorized = d['driver_authorized'] == true;
    final name = '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
    final String cin = d['cin']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _neonPurple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: authorized
              ? _neonPurple.withOpacity(0.15)
              : Colors.orange.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: authorized
                ? _neonPurple.withOpacity(0.15)
                : Colors.orange.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: authorized
                  ? _neonPurple.withOpacity(0.4)
                  : Colors.orange.withOpacity(0.4),
            ),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: authorized ? _neonPurpleLight : Colors.orange,
                fontWeight: FontWeight.bold, fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          name.isEmpty ? 'Sans nom' : name,
          style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(d['email'] ?? '',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
            if (cin.isNotEmpty)
              Text('CIN: $cin',
                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Statut badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: authorized
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: authorized
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Text(
                authorized ? 'Actif' : 'En attente',
                style: TextStyle(
                  color: authorized ? Colors.green : Colors.orange,
                  fontSize: 11, fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Menu
            Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: const Color(0xFF0D0820),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _neonPurple.withOpacity(0.3)),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                onSelected: (action) {
                  if (action == 'activate') _activate(cin);
                  if (action == 'block')    _block(cin);
                  if (action == 'detail')   _showDetail(cin);
                },
                itemBuilder: (_) => [
                  _menuItem('detail',   Icons.info_outline,       'Voir détails', Colors.white54),
                  if (!authorized)
                    _menuItem('activate', Icons.check_circle_outline, 'Activer',     Colors.green),
                  if (authorized)
                    _menuItem('block',    Icons.block_rounded,       'Bloquer',     Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color)),
      ]),
    );
  }

  Future<void> _showDetail(String cin) async {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _DriverDetailDialog(cin: cin),
    );
  }
}

// ─── Dialog détail driver ─────────────────────────────────────────────────────

class _DriverDetailDialog extends StatefulWidget {
  final String cin;
  const _DriverDetailDialog({required this.cin});

  @override
  State<_DriverDetailDialog> createState() => _DriverDetailDialogState();
}

class _DriverDetailDialogState extends State<_DriverDetailDialog> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  static const _neonPurple      = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);

  @override
  void initState() {
    super.initState();
    AdminService.getDriverDetail(widget.cin).then((d) {
      if (mounted) setState(() { _detail = d; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0518),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _neonPurple.withOpacity(0.35), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 550),
        child: _loading
            ? Center(child: CircularProgressIndicator(
            color: _neonPurple, strokeWidth: 2))
            : _detail == null
            ? const Center(child: Text('Erreur',
            style: TextStyle(color: Colors.white)))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final d      = _detail!;
    final driver = d['driver'] as Map<String, dynamic>? ?? d;
    final name   = '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'.trim();

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
          ),
          Expanded(child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_neonPurple, _neonPurpleLight],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(
                  color: _neonPurple.withOpacity(0.4), blurRadius: 12, spreadRadius: 1,
                )],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Sans nom' : name,
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16,
                      )),
                  Text(driver['email'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12,
                      )),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Container(height: 1, color: _neonPurple.withOpacity(0.2)),
          Expanded(
            child: ListView(children: [
              const SizedBox(height: 12),
              row('CIN',           '${driver['cin']          ?? '-'}'),
              row('Téléphone',     '${driver['telephone']    ?? '-'}'),
              row('Groupe sanguin','${driver['blood_group']  ?? '-'}'),
              row('Langue',        '${driver['language']     ?? '-'}'),
              row('Statut',
                  driver['driver_authorized'] == true ? '✅ Actif' : '⏳ En attente'),
              row('QR Boitier',    '${driver['codeQR']       ?? '-'}'),
            ]),
          ),
        ],
      ),
    );
  }
}