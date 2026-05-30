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

  // ── palette ───────────────────────────────────────────────────────────────
  static const _neonPurple      = Color(0xFF7226FF);
  static const _neonPurpleLight = Color(0xFF9B4DFF);
  static const _neonPurpleDark  = Color(0xFF4A148C);

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
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0A0518),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _neonPurple.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
              const SizedBox(height: 12),
              const Text('Confirmer la suppression',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Supprimer ce token revendeur ?',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Annuler',
                      style: TextStyle(color: Colors.white.withOpacity(0.4))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Supprimer'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminService.deleteVendorToken(tokenId);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_tokens.length} token(s)',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
              const Spacer(),
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
              const SizedBox(width: 8),
              // Generate button (neon style matching login button)
              GestureDetector(
                onTap: _showGenerateDialog,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_neonPurple, _neonPurpleDark],
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _neonPurpleLight.withOpacity(0.4)),
                    boxShadow: [BoxShadow(
                      color: _neonPurple.withOpacity(0.4), blurRadius: 12, spreadRadius: 1,
                    )],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Générer QR',
                          style: TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Liste ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(
              color: _neonPurple, strokeWidth: 2))
              : _error != null
              ? Center(child: Text(_error!,
              style: const TextStyle(color: Colors.redAccent)))
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
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _neonPurple.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _neonPurple.withOpacity(0.2)),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white12, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Aucun QR revendeur',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showGenerateDialog,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_neonPurple, _neonPurpleDark],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                  color: _neonPurple.withOpacity(0.4), blurRadius: 12,
                )],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Générer le premier QR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokenCard(Map<String, dynamic> t) {
    final usesLeft  = t['uses_left'] as int? ?? 0;
    final expiresAt = t['expires_at'] as String? ?? '';
    final isExpired = expiresAt.isNotEmpty &&
        DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) == true;
    final isActive  = usesLeft > 0 && !isExpired;
    final qrJson    = t['qr_json_string'] ??
        '{"type":"vendor","vendor_id":"${t['vendor_id']}","token":"${t['token']}"}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _neonPurple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? _neonPurple.withOpacity(0.18)
              : Colors.red.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // QR miniature
            GestureDetector(
              onTap: () => _showQrImage(t),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                    color: _neonPurple.withOpacity(0.3), blurRadius: 10,
                  )],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: QrImageView(
                    data: qrJson, version: QrVersions.auto,
                    size: 52, backgroundColor: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    '${t['token']?.toString().substring(0, 12) ?? ''}...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    _chip('$usesLeft utilisation(s)',
                        isActive ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    _chip(
                      isExpired ? 'Expiré' : 'Expire ${_formatDate(expiresAt)}',
                      isExpired ? Colors.red : Colors.white38,
                    ),
                  ]),
                ],
              ),
            ),
            Column(
              children: [
                _actionBtn(Icons.qr_code_rounded, Colors.white54, () => _showQrImage(t)),
                _actionBtn(Icons.copy_rounded, Colors.white38, () {
                  Clipboard.setData(ClipboardData(text: qrJson));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copié !')));
                }),
                _actionBtn(Icons.delete_outline_rounded, Colors.red, () => _delete(t['id'] as int)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Icon(icon, color: color, size: 15),
    ),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10)),
  );

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return iso; }
  }

  void _showQrImage(Map<String, dynamic> t) {
    final qrJson = t['qr_json_string'] ??
        '{"type":"vendor","vendor_id":"${t['vendor_id']}","token":"${t['token']}"}';

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
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_neonPurpleLight, Colors.white],
                ).createShader(bounds),
                child: Text('QR Revendeur — ${t['vendor_id']}',
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                    )),
              ),
              const SizedBox(height: 4),
              Text('Usage unique — photographiez ce QR',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: _neonPurple.withOpacity(0.4), blurRadius: 24, spreadRadius: 2,
                  )],
                ),
                child: QrImageView(
                  data: qrJson, version: QrVersions.auto,
                  size: 220, backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _neonPurple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _neonPurple.withOpacity(0.2)),
                ),
                child: SelectableText(
                  qrJson,
                  style: TextStyle(
                    color: _neonPurpleLight, fontFamily: 'monospace', fontSize: 10,
                  ),
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
                    foregroundColor: _neonPurpleLight,
                    side: BorderSide(color: _neonPurple.withOpacity(0.6)),
                    backgroundColor: _neonPurple.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copier', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    shadowColor: _neonPurple,
                    elevation: 8,
                  ),
                  child: const Text('Fermer', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenerateDialog() {
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: const Color(0xFF0A0518),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _neonPurple.withOpacity(0.4), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_neonPurpleLight, Colors.white],
                  ).createShader(bounds),
                  child: const Text('Générer QR Revendeur',
                      style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18,
                      )),
                ),
                const SizedBox(height: 6),
                Text(
                  'Un ID revendeur unique sera généré automatiquement.',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.25)),
                    ),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 20),
                Container(height: 1, color: _neonPurple.withOpacity(0.15)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Annuler',
                          style: TextStyle(color: Colors.white.withOpacity(0.4))),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: loading ? null : () async {
                        setS(() { loading = true; error = null; });
                        try {
                          final result = await AdminService.generateVendorToken(
                            uses: 1, daysValid: 365,
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
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: loading ? null : const LinearGradient(
                            colors: [_neonPurple, _neonPurpleDark],
                          ),
                          color: loading ? Colors.white10 : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: loading ? [] : [BoxShadow(
                            color: _neonPurple.withOpacity(0.4), blurRadius: 12,
                          )],
                        ),
                        child: Center(
                          child: loading
                              ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2,
                            ),
                          )
                              : const Text('Générer',
                              style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}