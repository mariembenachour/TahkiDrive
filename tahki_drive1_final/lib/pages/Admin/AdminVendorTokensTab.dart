
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/admin_service.dart';

class AdminVendorTokensTab extends StatefulWidget {
  const AdminVendorTokensTab({super.key});

  @override
  State<AdminVendorTokensTab> createState() => _AdminVendorTokensTabState();
}

class _AdminVendorTokensTabState extends State<AdminVendorTokensTab> {
  List<Map<String, dynamic>> _tokens = [];
  bool _loading = true;
  String? _error;

  static const _purple = Color(0xFF7226FF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final t = await AdminService.getVendorTokens();
      if (mounted) setState(() { _tokens = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _delete(int tokenId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        title: const Text('Confirmer', style: TextStyle(color: Colors.white)),
        content: const Text('Supprimer ce token revendeur ?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminService.deleteVendorToken(tokenId);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_tokens.length} token(s)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
                  onPressed: _load),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _showGenerateDialog,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Générer QR', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _purple, strokeWidth: 2))
              : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _tokens.isEmpty
              ? _emptyState()
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tokens.length,
            itemBuilder: (_, i) => _tokenCard(_tokens[i]),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2_rounded, color: Colors.white12, size: 64),
          const SizedBox(height: 12),
          const Text('Aucun QR revendeur',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showGenerateDialog,
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Générer le premier QR'),
          ),
        ],
      ),
    );
  }

  Widget _tokenCard(Map<String, dynamic> t) {
    final usesLeft = t['uses_left'] as int? ?? 0;
    final expiresAt = t['expires_at'] as String? ?? '';
    final isExpired = expiresAt.isNotEmpty &&
        DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) == true;
    final isActive = usesLeft > 0 && !isExpired;
    final qrJson = t['qr_json_string'] ??
        '{"type":"vendor","vendor_id":"${t['vendor_id']}","token":"${t['token']}"}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive ? Colors.white.withOpacity(0.07) : Colors.red.withOpacity(0.15))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // QR miniature cliquable
            GestureDetector(
              onTap: () => _showQrImage(t),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: QrImageView(
                    data: qrJson,
                    version: QrVersions.auto,
                    size: 52,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['vendor_id'] ?? '-',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${t['token']?.toString().substring(0, 12) ?? ''}...',
                    style: const TextStyle(color: Colors.white38, fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    _chip('$usesLeft utilisation(s)', isActive ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    _chip(isExpired ? 'Expiré' : 'Expire ${_formatDate(expiresAt)}',
                        isExpired ? Colors.red : Colors.white38),
                  ]),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_rounded, color: Colors.white54, size: 20),
                  tooltip: 'Voir QR',
                  onPressed: () => _showQrImage(t),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
                  tooltip: 'Copier JSON',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qrJson));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('JSON copié !')));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(t['id'] as int),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQrImage(Map<String, dynamic> t) {
    final qrJson = t['qr_json_string'] ??
        '{"type":"vendor","vendor_id":"${t['vendor_id']}","token":"${t['token']}"}';

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
              Text('QR Revendeur — ${t['vendor_id']}',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Usage unique — photographiez ce QR',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: QrImageView(
                  data: qrJson,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8)),
                child: SelectableText(
                  qrJson,
                  style: const TextStyle(color: _purple,
                      fontFamily: 'monospace', fontSize: 10),
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qrJson));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copié !')));
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: const BorderSide(color: _purple),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copier', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
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
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10)),
  );

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return iso; }
  }

  void _showGenerateDialog() {
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: const Color(0xFF0D1520),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Générer QR Revendeur',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 6),
                const Text(
                  'Un ID revendeur unique sera généré automatiquement.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.white38)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: loading ? null : () async {
                        setS(() { loading = true; error = null; });
                        try {
                          final result = await AdminService.generateVendorToken(
                            uses: 1,
                            daysValid: 365,
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          _load();
                          if (mounted) _showQrImage(result);
                        } catch (e) {
                          setS(() {
                            loading = false;
                            error = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: loading
                          ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Générer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }}
