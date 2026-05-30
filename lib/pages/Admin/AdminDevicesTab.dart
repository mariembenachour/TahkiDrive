import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/admin_service.dart';

class AdminDevicesTab extends StatefulWidget {
  const AdminDevicesTab({super.key});

  @override
  State<AdminDevicesTab> createState() => _AdminDevicesTabState();
}

class _AdminDevicesTabState extends State<AdminDevicesTab> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  // ── palette ───────────────────────────────────────────────────────────────
  static const _neonPurple      = Color(0xFFD7CEE8);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPink        = Color(0xFFFF00E5);
  static const _camColor        = Color(0xFFFF9800);
  static const _gpsColor        = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await AdminService.getDevices();
      if (mounted) setState(() { _devices = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  bool _isCamera(Map<String, dynamic> d) =>
      (d['stream_id']?.toString() ?? '').length > 8;

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final Map<String, List<Map<String, dynamic>>> map = {};
    final source = _search.isEmpty ? _devices : _devices.where((d) {
      final q = _search.toLowerCase();
      return '${d['serial']} ${d['imei']} ${d['mark']} ${d['model']} '
          '${d['matricule']} ${d['vehicule_id']} ${d['driver_cin']} '
          '${d['first_name']} ${d['last_name']}'
          .toLowerCase().contains(q);
    }).toList();
    for (final d in source) {
      final vid = d['vehicule_id']?.toString() ?? 'non_assigné';
      map.putIfAbsent(vid, () => []).add(d);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Column(
      children: [
        // ── Barre recherche ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _neonPurple.withOpacity(0.2)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher serial, IMEI, matricule, chauffeur...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                      prefixIcon: Icon(Icons.search,
                          color: _neonPurple.withOpacity(0.5), size: 18),
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

        // ── Compteur ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(
              '${_devices.length} device(s) — ${grouped.length} véhicule(s)',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Liste ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
              color: _neonPurple, strokeWidth: 2))
              : _error != null
              ? Center(child: Text(_error!,
              style: const TextStyle(color: Colors.redAccent)))
              : grouped.isEmpty
              ? Center(child: Text('Aucun device',
              style: TextStyle(color: Colors.white.withOpacity(0.3))))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: grouped.keys.length,
            itemBuilder: (_, i) {
              final vid     = grouped.keys.elementAt(i);
              final devices = grouped[vid]!;
              return _vehiculeCard(vid, devices);
            },
          ),
        ),
      ],
    );
  }

  Widget _vehiculeCard(String vehiculeId, List<Map<String, dynamic>> devices) {
    final first      = devices.first;
    final mark       = first['mark']?.toString() ?? '';
    final model      = first['model']?.toString() ?? '';
    final matricule  = first['matricule']?.toString() ?? vehiculeId;
    final driverCin  = first['driver_cin']?.toString();
    final firstName  = first['first_name']?.toString() ?? '';
    final lastName   = first['last_name']?.toString() ?? '';
    final driverName = '$firstName $lastName'.trim();
    final isAssigned = driverCin != null && driverCin.isNotEmpty;
    final hasGps = devices.any((d) => !_isCamera(d));
    final hasCam = devices.any((d) =>  _isCamera(d));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _neonPurple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonPurple.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // Header véhicule
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_neonPurple.withOpacity(0.3), _neonPurple.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _neonPurple.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: Colors.white54, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mark.isNotEmpty ? '$mark $model' : matricule,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                        ),
                      ),
                      Text(matricule,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35), fontSize: 12,
                          )),
                      if (isAssigned && driverName.isNotEmpty)
                        Text(driverName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2), fontSize: 11,
                            )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(isAssigned),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (hasGps) _typeBadge('GPS', _gpsColor),
                      if (hasGps && hasCam) const SizedBox(width: 4),
                      if (hasCam) _typeBadge('CAM', _camColor),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: _neonPurple.withOpacity(0.12)),
          ...devices.map((d) => _deviceRow(d)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _deviceRow(Map<String, dynamic> d) {
    final isCam     = _isCamera(d);
    final color     = isCam ? _camColor : _gpsColor;
    final icon      = isCam ? Icons.videocam_rounded : Icons.router_rounded;
    final typeLabel = isCam ? 'Caméra' : 'Boitier GPS';

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text('${d['serial'] ?? '-'}',
            style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
            )),
        subtitle: Text('$typeLabel  •  Stream: ${d['stream_id'] ?? '-'}',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white24,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: _neonPurple.withOpacity(0.15)),
                const SizedBox(height: 8),
                _infoRow('Type',      typeLabel),
                _infoRow('Serial',    '${d['serial']        ?? '-'}'),
                _infoRow('IMEI',      '${d['imei']          ?? '-'}'),
                _infoRow('ICC',       '${d['icc']           ?? '-'}'),
                _infoRow('Device #',  '${d['device_number'] ?? '-'}'),
                _infoRow('Stream ID', '${d['stream_id']     ?? '-'}'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showQrDialog(d['id'] as int,
                      isCam: isCam, serial: d['serial']?.toString() ?? ''),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.6)),
                    backgroundColor: color.withOpacity(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: Text('QR $typeLabel', style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool assigned) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: assigned ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: assigned ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
      ),
    ),
    child: Text(
      assigned ? 'Assigné' : 'Libre',
      style: TextStyle(
        color: assigned ? Colors.green : Colors.orange,
        fontSize: 10, fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _typeBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 90,
        child: Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
      ),
      Expanded(child: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );

  // ── Dialog QR ─────────────────────────────────────────────────────────────
  Future<void> _showQrDialog(int deviceId,
      {bool isCam = false, String serial = ''}) async {
    try {
      final data      = await AdminService.getDeviceQrData(deviceId);
      if (!mounted) return;
      final qrJson    = data['qr_json_string'] ?? '';
      final color     = isCam ? _camColor : _gpsColor;
      final typeLabel = isCam ? 'Caméra' : 'Boitier GPS';

      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF0A0518),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _neonPurple.withOpacity(0.4), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(isCam ? Icons.videocam_rounded : Icons.router_rounded,
                      color: color, size: 20),
                  const SizedBox(width: 8),
                  Text('QR $typeLabel',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                      )),
                ]),
                if (serial.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Serial : $serial',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12,
                      )),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: _neonPurple.withOpacity(0.3), blurRadius: 20, spreadRadius: 2,
                    )],
                  ),
                  child: QrImageView(
                    data: qrJson, version: QrVersions.auto,
                    size: 200, backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Photographiez ce QR avec le téléphone du chauffeur',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _neonPurple.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _neonPurple.withOpacity(0.2)),
                  ),
                  child: SelectableText(qrJson,
                      style: TextStyle(color: color,
                          fontFamily: 'monospace', fontSize: 11)),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrJson));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('JSON copié !')));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _neonPurpleLight,
                      side: BorderSide(color: _neonPurple.withOpacity(0.6)),
                      backgroundColor: _neonPurple.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copier JSON', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }
}