
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

  static const _blue   = Color(0xFF2196F3);
  static const _orange = Color(0xFFFF9800);
  static const _teal   = Color(0xFF00C6A2);

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

  // stream_id long (IMEI-like, >8 chars) = caméra, court = boitier GPS
  bool _isCamera(Map<String, dynamic> d) {
    final streamId = d['stream_id']?.toString() ?? '';
    return streamId.length > 8;
  }

  // Grouper par vehicule_id
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
        // ── Barre recherche ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher serial, IMEI, matricule, chauffeur...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
                  onPressed: _load),
            ],
          ),
        ),

        // ── Compteur ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(
              '${_devices.length} device(s) — ${grouped.length} véhicule(s)',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Liste ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
              : _error != null
              ? Center(child: Text(_error!,
              style: const TextStyle(color: Colors.redAccent)))
              : grouped.isEmpty
              ? const Center(child: Text('Aucun device',
              style: TextStyle(color: Colors.white38)))
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

  // ── Carte par véhicule (1 ou plusieurs devices) ───────────────────────────
  Widget _vehiculeCard(String vehiculeId, List<Map<String, dynamic>> devices) {
    final first      = devices.first;
    final mark       = first['mark']?.toString() ?? '';
    final model      = first['model']?.toString() ?? '';
    final matricule  = first['matricule']?.toString() ?? vehiculeId;
    final driverCin  = first['driver_cin']?.toString();
    final firstName  = first['first_name']?.toString() ?? '';
    final lastName   = first['last_name']?.toString() ?? '';
    final driverName = (firstName + ' ' + lastName).trim();
    final isAssigned = driverCin != null && driverCin.isNotEmpty;

    final hasGps = devices.any((d) => !_isCamera(d));
    final hasCam = devices.any((d) =>  _isCamera(d));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Column(
        children: [
          // ── Header véhicule ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Icône voiture
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10)),
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
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(matricule,
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      if (isAssigned && driverName.isNotEmpty)
                        Text(driverName,
                            style: const TextStyle(color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                ),
                // Badges type device(s)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Assigné / Libre
                    _statusBadge(isAssigned),
                    const SizedBox(height: 4),
                    // GPS / CAM / les deux
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (hasGps) _typeBadge('GPS', _blue),
                      if (hasGps && hasCam) const SizedBox(width: 4),
                      if (hasCam) _typeBadge('CAM', _orange),
                    ]),
                  ],
                ),
              ],
            ),
          ),

          // ── Séparateur ──────────────────────────────────────────────────
          Divider(color: Colors.white.withOpacity(0.06), height: 1),

          // ── Liste des devices de ce véhicule ────────────────────────────
          ...devices.map((d) => _deviceRow(d)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Ligne d'un device individuel ─────────────────────────────────────────
  Widget _deviceRow(Map<String, dynamic> d) {
    final isCam    = _isCamera(d);
    final color    = isCam ? _orange : _blue;
    final icon     = isCam ? Icons.videocam_rounded : Icons.router_rounded;
    final typeLabel = isCam ? 'Caméra' : 'Boitier GPS';

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        '${d['serial'] ?? '-'}',
        style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '$typeLabel  •  Stream: ${d['stream_id'] ?? '-'}',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      iconColor: Colors.white38,
      collapsedIconColor: Colors.white24,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white12),
              _infoRow('Type',      typeLabel),
              _infoRow('Serial',    '${d['serial']    ?? '-'}'),
              _infoRow('IMEI',      '${d['imei']      ?? '-'}'),
              _infoRow('ICC',       '${d['icc']       ?? '-'}'),
              _infoRow('Device #',  '${d['device_number'] ?? '-'}'),
              _infoRow('Stream ID', '${d['stream_id'] ?? '-'}'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showQrDialog(d['id'] as int, isCam: isCam,
                    serial: d['serial']?.toString() ?? ''),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.qr_code_rounded, size: 16),
                label: Text('QR $typeLabel (usage unique)',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Badges ────────────────────────────────────────────────────────────────
  Widget _statusBadge(bool assigned) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: assigned
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        assigned ? 'Assigné' : 'Libre',
        style: TextStyle(
            color: assigned ? Colors.green : Colors.orange,
            fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _typeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 90,
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12))),
      Expanded(child: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );

  // ── Dialog QR ─────────────────────────────────────────────────────────────
  Future<void> _showQrDialog(int deviceId,
      {bool isCam = false, String serial = ''}) async {
    try {
      final data  = await AdminService.getDeviceQrData(deviceId);
      if (!mounted) return;
      final qrJson    = data['qr_json_string'] ?? '';
      final color     = isCam ? _orange : _blue;
      final typeLabel = isCam ? 'Caméra' : 'Boitier GPS';

      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF0D1520),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(isCam ? Icons.videocam_rounded : Icons.router_rounded,
                      color: color, size: 20),
                  const SizedBox(width: 8),
                  Text('QR $typeLabel — Usage unique',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                if (serial.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Serial : $serial',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                // QR image
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(
                    data: qrJson,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Photographiez ce QR avec le téléphone du chauffeur',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8)),
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
                        foregroundColor: color,
                        side: BorderSide(color: color),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copier JSON', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
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
