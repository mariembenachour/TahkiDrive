import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/profile_service.dart';

class AlertThresholdsPage extends StatefulWidget {
  const AlertThresholdsPage({super.key});

  @override
  State<AlertThresholdsPage> createState() => _AlertThresholdsPageState();
}

class _AlertThresholdsPageState extends State<AlertThresholdsPage> {
  static const _purple    = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);

  bool _loading = true;
  bool _saving  = false;

  // Valeurs courantes
  int   _maxSpeed      = 120;
  int   _maxEngineTemp = 100;
  int   _maxCarTemp    = 80;
  int   _idleMinutes   = 5;

  // Valeurs par défaut (pour reset)
  static const _defaults = {
    'max_speed_kmh':    120,
    'max_engine_temp':  100,
    'max_car_temp':     80,
    'idle_max_minutes': 5,
  };

  @override
  void initState() {
    super.initState();
    _loadThresholds();
  }

  Future<void> _loadThresholds() async {
    try {
      final data = await ProfileService.fetchThresholds();
      setState(() {
        _maxSpeed      = data['max_speed_kmh']    ?? 120;
        _maxEngineTemp = data['max_engine_temp']  ?? 100;
        _maxCarTemp    = data['max_car_temp']      ?? 80;
        _idleMinutes   = data['idle_max_minutes'] ?? 5;
        _loading       = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ProfileService.updateThresholds({
      'max_speed_kmh':    _maxSpeed,
      'max_engine_temp':  _maxEngineTemp,
      'max_car_temp':     _maxCarTemp,
      'idle_max_minutes': _idleMinutes,
    });
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Seuils mis à jour' : '❌ Erreur lors de la sauvegarde'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Remettre tous les seuils aux valeurs par défaut ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réinitialiser', style: TextStyle(color: _purple)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _maxSpeed      = _defaults['max_speed_kmh']!;
        _maxEngineTemp = _defaults['max_engine_temp']!;
        _maxCarTemp    = _defaults['max_car_temp']!;
        _idleMinutes   = _defaults['idle_max_minutes']!;
      });
      await _save();
    }
  }

  Future<void> _editValue({
    required String label,
    required String unit,
    required int current,
    required int min,
    required int max,
    required ValueChanged<int> onSaved,
  }) async {
    final ctrl = TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifier $label', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: '$label ($unit)',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            suffixText: unit,
            suffixStyle: const TextStyle(color: _purple),
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val >= min && val <= max) {
                Navigator.pop(ctx, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Valeur entre $min et $max'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('OK', style: TextStyle(color: _purple)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => onSaved(result));
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEAF6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkPurple),
        title: const Text('Seuils d\'alertes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkPurple)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded, color: _purple),
              tooltip: 'Réinitialiser',
              onPressed: _reset,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7226FF)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _purple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _purple, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Vous serez alerté uniquement si la valeur dépasse le seuil défini.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF160078)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('Conduite'),
            const SizedBox(height: 10),
            _card(children: [
              _thresholdRow(
                icon: Icons.speed_rounded,
                label: 'Vitesse maximale',
                value: _maxSpeed,
                unit: 'km/h',
                min: 50, max: 200,
                onEdit: () => _editValue(
                  label: 'Vitesse max',
                  unit: 'km/h',
                  current: _maxSpeed,
                  min: 50, max: 200,
                  onSaved: (v) => _maxSpeed = v,
                ),
              ),
              _divider(),
              _thresholdRow(
                icon: Icons.timer_outlined,
                label: 'Ralenti prolongé',
                value: _idleMinutes,
                unit: 'min',
                min: 1, max: 60,
                onEdit: () => _editValue(
                  label: 'Ralenti max',
                  unit: 'min',
                  current: _idleMinutes,
                  min: 1, max: 60,
                  onSaved: (v) => _idleMinutes = v,
                ),
              ),
            ]),

            const SizedBox(height: 20),
            _sectionTitle('Température'),
            const SizedBox(height: 10),
            _card(children: [
              _thresholdRow(
                icon: Icons.thermostat_rounded,
                label: 'Température moteur',
                value: _maxEngineTemp,
                unit: '°C',
                min: 60, max: 150,
                onEdit: () => _editValue(
                  label: 'Temp. moteur max',
                  unit: '°C',
                  current: _maxEngineTemp,
                  min: 60, max: 150,
                  onSaved: (v) => _maxEngineTemp = v,
                ),
              ),
              _divider(),
              _thresholdRow(
                icon: Icons.device_thermostat_rounded,
                label: 'Température voiture',
                value: _maxCarTemp,
                unit: '°C',
                min: 30, max: 120,
                onEdit: () => _editValue(
                  label: 'Temp. voiture max',
                  unit: '°C',
                  current: _maxCarTemp,
                  min: 30, max: 120,
                  onSaved: (v) => _maxCarTemp = v,
                ),
              ),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkPurple)),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: children),
    );
  }

  Widget _thresholdRow({
    required IconData icon,
    required String label,
    required int value,
    required String unit,
    required int min,
    required int max,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _purple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text('$value $unit',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: _darkPurple)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: _purple, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey[100]);
}
