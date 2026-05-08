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

  static const _teal = Color(0xFF00C6A2);

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
    return _drivers.where((d) {
      return '${d['first_name']} ${d['last_name']} ${d['email']} ${d['cin']}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  // ← CORRECTION : on utilise cin (String) au lieu de user_id (int)
  Future<void> _activate(String cin) async {
    try {
      await AdminService.activateDriver(cin);
      _showSnack('Chauffeur activé ✓', Colors.green);
      _load();
    } catch (e) {
      _showSnack('Erreur: $e', Colors.red);
    }
  }

  Future<void> _block(String cin) async {
    try {
      await AdminService.blockDriver(cin);
      _showSnack('Chauffeur bloqué', Colors.orange);
      _load();
    } catch (e) {
      _showSnack('Erreur: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filtres + recherche ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ...[
                ('all', 'Tous'),
                ('pending', 'En attente'),
                ('active', 'Actifs'),
              ].map((item) {
                final active = _filter == item.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _filter = item.$1);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: active
                              ? _teal.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active
                                  ? _teal
                                  : Colors.white.withOpacity(0.1))),
                      child: Text(item.$2,
                          style: TextStyle(
                              color: active ? _teal : Colors.white54,
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                width: 180,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style:
                  const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white38, size: 18),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white38),
                  onPressed: _load),
            ],
          ),
        ),

        // ── Contenu ────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
              child: CircularProgressIndicator(
                  color: _teal, strokeWidth: 2))
              : _error != null
              ? Center(
              child: Text(_error!,
                  style:
                  const TextStyle(color: Colors.redAccent)))
              : _filtered.isEmpty
              ? const Center(
              child: Text('Aucun chauffeur',
                  style: TextStyle(color: Colors.white38)))
              : ListView.builder(
            padding:
            const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            itemBuilder: (_, i) =>
                _driverCard(_filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final authorized = d['driver_authorized'] == true;
    final name =
    '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();

    // ← CORRECTION : cin est la clé, pas user_id
    final String cin = d['cin']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: Colors.white.withOpacity(0.07))),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: authorized
              ? Colors.green.withOpacity(0.15)
              : Colors.orange.withOpacity(0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color:
                authorized ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name.isEmpty ? 'Sans nom' : name,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(d['email'] ?? '',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
            if (cin.isNotEmpty)
              Text('CIN: $cin',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge statut
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: authorized
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                authorized ? 'Actif' : 'En attente',
                style: TextStyle(
                    color: authorized
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            // Menu actions
            PopupMenuButton<String>(
              color: const Color(0xFF1A2535),
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white38, size: 20),
              onSelected: (action) {
                if (action == 'activate') _activate(cin);
                if (action == 'block') _block(cin);
                if (action == 'detail') _showDetail(cin);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'detail',
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Text('Voir détails',
                          style:
                          TextStyle(color: Colors.white70)),
                    ])),
                if (!authorized)
                  const PopupMenuItem(
                      value: 'activate',
                      child: Row(children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Activer',
                            style:
                            TextStyle(color: Colors.green)),
                      ])),
                if (authorized)
                  const PopupMenuItem(
                      value: 'block',
                      child: Row(children: [
                        Icon(Icons.block_rounded,
                            color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text('Bloquer',
                            style: TextStyle(
                                color: Colors.orange)),
                      ])),
              ],
            ),
          ],
        ),
      ),
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
  final String cin; // ← String, pas int
  const _DriverDetailDialog({required this.cin});

  @override
  State<_DriverDetailDialog> createState() => _DriverDetailDialogState();
}

class _DriverDetailDialogState extends State<_DriverDetailDialog> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  static const _teal = Color(0xFF00C6A2);

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
      backgroundColor: const Color(0xFF0D1520),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(maxWidth: 420, maxHeight: 550),
        child: _loading
            ? const Center(
            child: CircularProgressIndicator(
                color: _teal, strokeWidth: 2))
            : _detail == null
            ? const Center(
            child: Text('Erreur',
                style: TextStyle(color: Colors.white)))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final driver =
        d['driver'] as Map<String, dynamic>? ?? d;
    final name =
    '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'
        .trim();

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13))),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: _teal.withOpacity(0.15),
              radius: 24,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Sans nom' : name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    Text(driver['email'] ?? '',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                )),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          Expanded(
            child: ListView(children: [
              row('CIN', '${driver['cin'] ?? '-'}'),
              row('Téléphone', '${driver['telephone'] ?? '-'}'),
              row('Groupe sanguin',
                  '${driver['blood_group'] ?? '-'}'),
              row('Langue', '${driver['language'] ?? '-'}'),
              row(
                  'Statut',
                  driver['driver_authorized'] == true
                      ? '✅ Actif'
                      : '⏳ En attente'),
              row('QR Boitier', '${driver['codeQR'] ?? '-'}'),
            ]),
          ),
        ],
      ),
    );
  }
}
