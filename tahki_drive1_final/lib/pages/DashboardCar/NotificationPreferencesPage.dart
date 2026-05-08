import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/notification_preferences_service.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _loading = true;
  bool _saving = false;

  bool _allAlertsEnabled = true;
  bool _allRemindersEnabled = true;

  // ← Map<String, dynamic> pour supporter daily_report_hour (int)
  Map<String, dynamic> _notifPreferences = {};
  int _dailyReportHour = 20;

  List<int> _reminderThresholds = [];
  List<int> _selectedThresholds = [];
  List<int> _savedReminderThresholds = [];
  List<int> _savedSelectedThresholds = [];

  final TextEditingController _customThresholdController =
  TextEditingController();
  String _customUnit = 'minutes';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loading = true);
    try {
      final prefs = await NotificationPreferencesService.getPreferences();
      if (prefs != null) {
        final rawNotif = Map<String, dynamic>.from(prefs['notif_preferences']);
        final threshList = List<int>.from(prefs['reminder_thresholds']);

        // Extraire l'heure et la retirer du map des bools
        final rawHour = rawNotif['daily_report_hour'];
        final hour = rawHour is int
            ? rawHour
            : int.tryParse(rawHour?.toString() ?? '') ?? 20;
        rawNotif.remove('daily_report_hour');

        final standardThresholds =
        NotificationPreferencesService.getAvailableThresholds();
        final customThresholds =
        threshList.where((s) => !standardThresholds.contains(s)).toList();
        final allThresholds = [...standardThresholds, ...customThresholds]
          ..sort();

        setState(() {
          _notifPreferences = rawNotif;
          _dailyReportHour = hour;
          _reminderThresholds = allThresholds;
          _selectedThresholds = List<int>.from(threshList);
          _savedReminderThresholds = List<int>.from(allThresholds);
          _savedSelectedThresholds = List<int>.from(threshList);
          _allAlertsEnabled =
              _notifPreferences.values.whereType<bool>().every((v) => v);
          _allRemindersEnabled = _selectedThresholds.isNotEmpty;
          _loading = false;
        });
      } else {
        final defaults =
        NotificationPreferencesService.getDefaultReminderThresholds();
        final defaultNotif =
        NotificationPreferencesService.getDefaultNotifPreferences();
        final rawHour = defaultNotif['daily_report_hour'] ?? 20;
        defaultNotif.remove('daily_report_hour');

        setState(() {
          _notifPreferences = defaultNotif;
          _dailyReportHour = rawHour is int ? rawHour : 20;
          _reminderThresholds = List<int>.from(defaults);
          _selectedThresholds = List<int>.from(defaults);
          _savedReminderThresholds = List<int>.from(defaults);
          _savedSelectedThresholds = List<int>.from(defaults);
          _allAlertsEnabled = true;
          _allRemindersEnabled = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      print(">>> [LOAD] ERREUR: $e");
    }
  }

  void _updateAllAlertsState() {
    _allAlertsEnabled =
        _notifPreferences.values.whereType<bool>().every((v) => v);
  }

  void _updateAllRemindersState() {
    _allRemindersEnabled = _selectedThresholds.isNotEmpty;
  }

  void _toggleAllAlerts(bool value) {
    setState(() {
      _allAlertsEnabled = value;
      for (final key in _notifPreferences.keys) {
        if (_notifPreferences[key] is bool) {
          _notifPreferences[key] = value;
        }
      }
    });
  }

  void _toggleAllReminders(bool value) {
    setState(() {
      _allRemindersEnabled = value;
      if (value) {
        _reminderThresholds = _savedReminderThresholds.isNotEmpty
            ? List<int>.from(_savedReminderThresholds)
            : NotificationPreferencesService.getDefaultReminderThresholds();
        _selectedThresholds = _savedSelectedThresholds.isNotEmpty
            ? List<int>.from(_savedSelectedThresholds)
            : List<int>.from(_reminderThresholds);
      } else {
        _savedReminderThresholds = List<int>.from(_reminderThresholds);
        _savedSelectedThresholds = List<int>.from(_selectedThresholds);
        _reminderThresholds = [];
        _selectedThresholds = [];
      }
    });
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);

    // Reconstruit le map complet avec l'heure
    final prefsToSend = Map<String, dynamic>.from(_notifPreferences);
    prefsToSend['daily_report_hour'] = _dailyReportHour;

    final success = await NotificationPreferencesService.updatePreferences(
      notifPreferences: prefsToSend,
      reminderThresholds: _selectedThresholds,
    );

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '✅ Préférences enregistrées'
            : '❌ Erreur lors de l\'enregistrement'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) Navigator.pop(context);
    }
  }

  void _toggleReminderThreshold(int seconds, bool selected) {
    setState(() {
      if (selected && !_selectedThresholds.contains(seconds)) {
        _selectedThresholds.add(seconds);
        _selectedThresholds.sort();
      } else if (!selected && _selectedThresholds.contains(seconds)) {
        _selectedThresholds.remove(seconds);
      }
      _updateAllRemindersState();
    });
  }

  void _removeCustomThreshold(int seconds) {
    setState(() {
      _reminderThresholds.remove(seconds);
      _selectedThresholds.remove(seconds);
      _savedReminderThresholds.remove(seconds);
      _savedSelectedThresholds.remove(seconds);
      _updateAllRemindersState();
    });
  }

  Future<void> _addCustomThreshold() async {
    _customThresholdController.clear();
    _customUnit = 'minutes';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter un rappel personnalisé',
              style: TextStyle(
                  color: Color(0xFF160078), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customThresholdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Valeur',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: ['minutes', 'heures', 'jours'].map((unit) {
                  final isSelected = _customUnit == unit;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setDialogState(() => _customUnit = unit),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7226FF)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF7226FF)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(unit,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Exemple : 30 minutes, 2 heures, 5 jours',
                        style: TextStyle(
                            fontSize: 12, color: Colors.amber.shade800)),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                double.tryParse(_customThresholdController.text);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Veuillez entrer un nombre valide'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7226FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final value = double.parse(_customThresholdController.text);
      int seconds;
      switch (_customUnit) {
        case 'minutes':
          seconds = (value * 60).round();
          break;
        case 'heures':
          seconds = (value * 3600).round();
          break;
        case 'jours':
          seconds = (value * 86400).round();
          break;
        default:
          seconds = (value * 60).round();
      }

      if (seconds < 30) {
        _showError('La valeur minimale est 30 secondes');
        return;
      }
      if (seconds > 15552000) {
        _showError('La valeur maximale est 180 jours');
        return;
      }
      if (_reminderThresholds.contains(seconds)) {
        _showError('Ce délai est déjà dans la liste');
        return;
      }

      setState(() {
        _reminderThresholds.add(seconds);
        _reminderThresholds.sort();
        _selectedThresholds.add(seconds);
        _selectedThresholds.sort();
        _savedReminderThresholds.add(seconds);
        _savedReminderThresholds.sort();
        _savedSelectedThresholds.add(seconds);
        _savedSelectedThresholds.sort();
        _allRemindersEnabled = true;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  String _formatThreshold(int seconds) {
    if (seconds < 60) return '$seconds seconde${seconds > 1 ? 's' : ''}';
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      return '$m minute${m > 1 ? 's' : ''}';
    }
    if (seconds < 86400) {
      final h = seconds ~/ 3600;
      return '$h heure${h > 1 ? 's' : ''}';
    }
    if (seconds < 604800) {
      final d = seconds ~/ 86400;
      return '$d jour${d > 1 ? 's' : ''}';
    }
    if (seconds < 2592000) {
      final w = seconds ~/ 604800;
      return '$w semaine${w > 1 ? 's' : ''}';
    }
    final mo = seconds ~/ 2592000;
    return '$mo mois';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEAF6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF160078)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Préférences notifications',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF160078))),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF7226FF)))),
            ),
        ],
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF7226FF)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ALERTES ──────────────────────────────────────────────
            Row(children: [
              Expanded(
                  child: _buildSectionTitle('Alertes de conduite')),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.info_outline,
                    color: Color(0xFF7226FF), size: 20),
                label: const Text('8 types',
                    style: TextStyle(
                        color: Color(0xFF7226FF), fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Text(
                'Pannes, vitesse, téléphone, distraction, fatigue, fumée, sécurité, infos',
                style:
                TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 12),
            _buildCard([
              _buildGlobalAlertsToggle(),
              _buildDivider(),
              _buildToggleRow(Icons.warning_amber_rounded,
                  'Pannes mécaniques', 'pannes',
                  'Recevoir les alertes de panne moteur, température, etc.'),
              _buildDivider(),
              _buildToggleRow(Icons.speed_rounded, 'Excès de vitesse',
                  'vitesse',
                  'Être informé en cas de dépassement de la limite'),
              _buildDivider(),
              _buildToggleRow(Icons.phone_android_rounded,
                  'Téléphone au volant', 'telephone',
                  'Alertes d\'utilisation du téléphone en conduisant'),
              _buildDivider(),
              _buildToggleRow(Icons.directions_car_rounded,
                  'Distraction', 'distraction',
                  'Détection des comportements dangereux'),
              _buildDivider(),
              _buildToggleRow(Icons.bedtime_rounded, 'Fatigue',
                  'fatigue', 'Signes de somnolence détectés'),
              _buildDivider(),
              _buildToggleRow(Icons.smoke_free_rounded, 'Fume', 'fume',
                  'Détection de cigarettes au volant'),
              _buildDivider(),
              _buildToggleRow(Icons.shield_rounded, 'Sécurité routière',
                  'securite',
                  'Collision, piéton détecté, sortie de voie'),
              _buildDivider(),
              _buildToggleRow(Icons.info_outline_rounded,
                  'Infos véhicule', 'info',
                  'Démarrage et arrêt du véhicule'),
            ]),

            const SizedBox(height: 32),

            // ── RAPPELS DOCUMENTS ─────────────────────────────────────
            Row(children: [
              Expanded(
                  child: _buildSectionTitle('Rappels documents')),
              TextButton.icon(
                onPressed:
                _allRemindersEnabled ? _addCustomThreshold : null,
                icon: Icon(Icons.add_circle,
                    color: _allRemindersEnabled
                        ? const Color(0xFF7226FF)
                        : Colors.grey,
                    size: 20),
                label: Text('Personnalisé',
                    style: TextStyle(
                        color: _allRemindersEnabled
                            ? const Color(0xFF7226FF)
                            : Colors.grey)),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Text(
                'Recevez des rappels avant expiration des documents',
                style:
                TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 12),
            _buildCard([
              _buildGlobalRemindersToggle(),
              if (_allRemindersEnabled) ...[
                _buildDivider(),
                ...NotificationPreferencesService.getAvailableThresholds()
                    .map((seconds) => _buildCheckboxRow(
                  icon: Icons.timer_outlined,
                  label: NotificationPreferencesService
                      .thresholdToLabel(seconds),
                  seconds: seconds,
                  selected:
                  _selectedThresholds.contains(seconds),
                  isCustom: false,
                  onChanged: (s) =>
                      _toggleReminderThreshold(seconds, s),
                )),
                if (_reminderThresholds
                    .where((s) => !NotificationPreferencesService
                    .getAvailableThresholds()
                    .contains(s))
                    .isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Divider(
                        color: Colors.grey[200], thickness: 1),
                  ),
                ..._reminderThresholds
                    .where((s) => !NotificationPreferencesService
                    .getAvailableThresholds()
                    .contains(s))
                    .map((seconds) => _buildCheckboxRow(
                  icon: Icons.edit_note,
                  label: _formatThreshold(seconds),
                  seconds: seconds,
                  selected:
                  _selectedThresholds.contains(seconds),
                  isCustom: true,
                  onChanged: (s) =>
                      _toggleReminderThreshold(seconds, s),
                  onDelete: () =>
                      _removeCustomThreshold(seconds),
                )),
              ],
            ]),

            const SizedBox(height: 32),

            // ── RAPPORT QUOTIDIEN ─────────────────────────────────────
            _buildSectionTitle('Rapport quotidien'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Text(
                'Recevez un résumé de votre journée de conduite',
                style:
                TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 12),
            _buildCard([
              _buildToggleRow(
                Icons.summarize_rounded,
                'Rapport quotidien',
                'daily_report',
                'Résumé de ta journée envoyé chaque soir',
              ),
              if ((_notifPreferences['daily_report'] as bool?) != false) ...[                _buildDivider(),
                _buildReportHourRow(),
              ],
            ]),

            const SizedBox(height: 32),

            // ── INFO MODE TEST ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mode test actif : les délais sont accélérés pour tester les rappels.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.amber.shade800),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7226FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                child: const Text('Enregistrer les préférences',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHourRow() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF7226FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.access_time_rounded,
            color: Color(0xFF7226FF), size: 22),
      ),
      title: const Text(
        'Heure d\'envoi',
        style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF160078),
            fontSize: 15),
      ),
      subtitle: Text(
        '${_dailyReportHour.toString().padLeft(2, '0')}:00 chaque soir',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: DropdownButton<int>(
        value: _dailyReportHour,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        items: List.generate(
          24,
              (i) => DropdownMenuItem(
            value: i,
            child: Text(
              '${i.toString().padLeft(2, '0')}:00',
              style: const TextStyle(
                  color: Color(0xFF160078), fontWeight: FontWeight.w600),
            ),
          ),
        ),
        onChanged: (val) {
          if (val != null) setState(() => _dailyReportHour = val);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: const Color(0xFF7226FF),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF160078))),
    ]);
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: children)),
    );
  }

  Widget _buildGlobalAlertsToggle() {
    final allTrue =
    _notifPreferences.values.whereType<bool>().every((v) => v);
    final allFalse =
    _notifPreferences.values.whereType<bool>().every((v) => !v);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFF7226FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.notifications_active_rounded,
            color: Color(0xFF7226FF), size: 22),
      ),
      title: const Text('TOUTES LES ALERTES',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF160078),
              fontSize: 15,
              letterSpacing: 0.5)),
      subtitle: Text(
        allTrue
            ? 'Toutes les alertes sont activées'
            : allFalse
            ? 'Toutes les alertes sont désactivées'
            : 'Certaines alertes sont désactivées',
        style: TextStyle(
            fontSize: 12,
            color: allTrue ? Colors.green[600] : Colors.orange[600]),
      ),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: _allAlertsEnabled,
          onChanged: _toggleAllAlerts,
          activeColor: const Color(0xFF7226FF),
          inactiveThumbColor: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildGlobalRemindersToggle() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFF7226FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.calendar_today_rounded,
            color: Color(0xFF7226FF), size: 22),
      ),
      title: const Text('TOUS LES RAPPELS',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF160078),
              fontSize: 15,
              letterSpacing: 0.5)),
      subtitle: Text(
        _selectedThresholds.isEmpty
            ? 'Aucun rappel document'
            : '${_selectedThresholds.length} rappel(s) activé(s)',
        style: TextStyle(
            fontSize: 12,
            color: _selectedThresholds.isEmpty
                ? Colors.red[600]
                : Colors.green[600]),
      ),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: _allRemindersEnabled,
          onChanged: _toggleAllReminders,
          activeColor: const Color(0xFF7226FF),
          inactiveThumbColor: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
      IconData icon, String title, String key, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFF7226FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF7226FF), size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF160078),
              fontSize: 15)),
      subtitle:
      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: (_notifPreferences[key] as bool?) ?? true,
          onChanged: (val) {
            setState(() {
              _notifPreferences[key] = val;
              _updateAllAlertsState();
            });
          },
          activeColor: const Color(0xFF7226FF),
          inactiveThumbColor: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required IconData icon,
    required String label,
    required int seconds,
    required bool selected,
    required bool isCustom,
    required Function(bool) onChanged,
    VoidCallback? onDelete,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFF7226FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF7226FF), size: 22),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isCustom
                  ? const Color(0xFF7226FF)
                  : const Color(0xFF160078),
              fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          Checkbox(
            value: selected,
            onChanged: (val) => onChanged(val ?? false),
            activeColor: const Color(0xFF7226FF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            side: BorderSide(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey[100]);
}
