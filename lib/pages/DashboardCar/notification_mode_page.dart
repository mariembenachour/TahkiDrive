import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/notification_mode_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça

class NotificationModePage extends StatefulWidget {
  const NotificationModePage({super.key});

  @override
  State<NotificationModePage> createState() => _NotificationModePageState();
}

class _NotificationModePageState extends State<NotificationModePage> {
  static const _purple    = Color(0xFF7226FF);
  static const _darkPurple = Color(0xFF160078);

  bool _loading = true;
  bool _saving  = false;
  Map<String, String> _modes = {};

  final List<Map<String, dynamic>> _groups = [
    {
      'key':      'critique',
      'title':    'Alertes critiques',
      'subtitle': 'Collision, freins, pneu, batterie déchargée...',
      'icon':     Icons.warning_rounded,
      'color':    Color(0xFFDC2626),
    },
    {
      'key':      'conduite',
      'title':    'Alertes de conduite et rapport',
      'subtitle': 'Vitesse, téléphone, distraction, fatigue...',
      'icon':     Icons.directions_car_rounded,
      'color':    Color(0xFF7226FF),
    },
    {
      'key':      'rappels',
      'title':    'Rappels documents',
      'subtitle': 'Entretien, maintenance, échéances...',
      'icon':     Icons.calendar_today_rounded,
      'color':    Color(0xFF059669),
    },
  ];

  final List<Map<String, dynamic>> _modeOptions = [
    {
      'value': NotificationModeService.SON,
      'label': 'Son',
      'subtitle': 'Notification sonore + voix',
      'icon': Icons.volume_up_rounded,
    },
    {
      'value': NotificationModeService.VIBRATION,
      'label': 'Vibration',
      'subtitle': 'Vibration uniquement, sans son',
      'icon': Icons.vibration_rounded,
    },
    {
      'value': NotificationModeService.SON_VIBRATION,
      'label': 'Son + Vibration',
      'subtitle': 'Son, vibration et voix',
      'icon': Icons.notifications_active_rounded,
    },
    {
      'value': NotificationModeService.SILENCIEUX,
      'label': 'Silencieux',
      'subtitle': 'Notification visuelle uniquement',
      'icon': Icons.notifications_off_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final modes = await NotificationModeService.getModes();
    setState(() {
      _modes   = modes;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await NotificationModeService.saveModes(_modes);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Préférences enregistrées'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEAF6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _darkPurple),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text(
          'Mode de notification',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: _darkPurple),
        ),
        actions: [
          if (_saving)
             Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: SizedBox(
                  width: 20.w, height: 20.h,
                  child: CircularProgressIndicator(strokeWidth: 2.w, color: _purple),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            ..._groups.map((group) => _buildGroup(group)),
             SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r)),
                  elevation: 0,
                ),
                child:  Text(
                  'Enregistrer',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
             SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(Map<String, dynamic> group) {
    final key      = group['key'] as String;
    final color    = group['color'] as Color;
    final selected = _modes[key] ?? NotificationModeService.SON;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header groupe
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(group['icon'] as IconData, color: color, size: 22),
            ),
             SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group['title'] as String,
                    style:  TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.bold, color: _darkPurple,
                    ),
                  ),
                  Text(
                    group['subtitle'] as String,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
         SizedBox(height: 12.h),
        // Options
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _modeOptions.asMap().entries.map((entry) {
              final i      = entry.key;
              final option = entry.value;
              final isLast = i == _modeOptions.length - 1;
              final isSelected = selected == option['value'];

              return Column(
                children: [
                  ListTile(
                    onTap: () => setState(() => _modes[key] = option['value'] as String),
                    leading: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.12)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        option['icon'] as IconData,
                        color: isSelected ? color : Colors.grey,
                        size: 20.w,
                      ),
                    ),
                    title: Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : _darkPurple,
                        fontSize: 15.sp,
                      ),
                    ),
                    subtitle: Text(
                      option['subtitle'] as String,
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: color, size: 22)
                        : Icon(Icons.circle_outlined, color: Colors.grey[300], size: 22),
                  ),
                  if (!isLast)
                    Divider(height: 1.h, indent: 70, endIndent: 20, color: Colors.grey[100]),
                ],
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}
