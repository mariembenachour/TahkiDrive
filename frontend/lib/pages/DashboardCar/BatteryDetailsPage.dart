import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/detailsPannes_service.dart';
import '../../services/theme_service.dart';
import '../DashboardCar/detailsPannes.dart';
import 'sav_edit_popup.dart';

class BatteryDetailsPage extends StatefulWidget {
  const BatteryDetailsPage({super.key});

  @override
  State<BatteryDetailsPage> createState() => _BatteryDetailsPageState();
}

class _BatteryDetailsPageState extends State<BatteryDetailsPage>
    with TickerProviderStateMixin {

  late AnimationController _entryController;
  late AnimationController _listController;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  Map<String, dynamic>? lastBattery;
  List<dynamic> historique = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _listController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _headerFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeIn));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack));
    _cardFade = Tween<double>(begin: 0, end: 1).animate(_entryController);
    _entryController.forward();
    _loadBattery();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadBattery() async {
    try {
      final data = await DetailPannesService.fetchBattery();
      setState(() {
        lastBattery = data?["last"];
        historique = data?["historique"] ?? [];
        loading = false;
      });
      _listController.forward();
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDark(context);
    final bgTop = isDark ? const Color(0xFF4904BD) : const Color(0xFF7226FF);
    final bgBottom = isDark ? const Color(0xFF0A0015) : const Color(0xFFF0EDF6);
    final cardColor = isDark ? const Color(0xFF1A0035) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF160078);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgBottom,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pushAndRemoveUntil(
                              PageRouteBuilder(
                                pageBuilder: (c, a, b) => const PanneDetailsPage(),
                                transitionsBuilder: (c, a, b, child) => SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
                                      .animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
                                  child: child,
                                ),
                              ),
                                  (route) => false,
                            ),
                            child: Container(
                              height: 50, width: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.4)),
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("maintenance.battery.title".tr(),
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              Text("maintenance.battery.subtitle".tr(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.battery_charging_full, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : error != null
                      ? _buildEmpty(subtitleColor)
                      : SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lastBattery != null) _buildLastCard(lastBattery!, isDark, cardColor, textColor, subtitleColor),
                            const SizedBox(height: 30),
                            Text("common.history".tr(),
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            ...historique.asMap().entries.map((entry) {
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(milliseconds: 400 + (entry.key * 100)),
                                curve: Curves.easeOutBack,
                                builder: (context, value, child) => Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                ),
                                child: _buildHistoryCard(entry.value, entry.key, isDark, cardColor, textColor, subtitleColor),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color? subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_dissatisfied, color: subtitleColor?.withOpacity(0.6), size: 60),
          const SizedBox(height: 15),
          Text("common.no_maintenance_found".tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("common.no_records".tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLastCard(Map<String, dynamic> data, bool isDark, Color cardColor, Color textColor, Color? subtitleColor) {
    final garage = data["garage"] ?? {};
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.battery_charging_full, color: Colors.white, size: 32)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data["maintenance_type"] ?? "—", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_formatDate(data["date_reparation"]), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.3), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade300)),
                  child: Text("common.current".tr(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(children: [Expanded(child: _buildInfoTile(Icons.notes, "common.description".tr(), data["description"] ?? "—", const Color(0xFF160078), isDark))]),
                const SizedBox(height: 15),
                Row(children: [Expanded(child: _buildInfoTile(Icons.attach_money, "common.cost".tr(), "${data["cost"] ?? "—"} ${'common.unit.tnd'.tr()}", Colors.deepPurple, isDark))]),
                const SizedBox(height: 15),
                Row(children: [Expanded(child: _buildInfoTile(Icons.calendar_today, "common.date".tr(), _formatDate(data["date_reparation"]), const Color(0xFF7226FF), isDark))]),
                const SizedBox(height: 18),
                Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200, thickness: 1.5),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF7226FF).withOpacity(0.1))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.store, color: Color(0xFF7226FF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(garage["nom"] ?? "—", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
                      const SizedBox(width: 8),
                      Row(children: List.generate(5, (i) => Icon(i < (garage["rating"] ?? 0).round() ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
                    ]),
                    const SizedBox(height: 8),
                    Text(garage["adresse"] ?? "—", style: TextStyle(color: subtitleColor, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text(garage["telephone"] ?? "—", style: TextStyle(color: subtitleColor, fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, int index, bool isDark, Color cardColor, Color textColor, Color? subtitleColor) {
    final garage = data["garage"] ?? {};
    final isFirst = index == 0;
    return GestureDetector(
      onTap: () => _showHistoryPopup(context, data, isDark, textColor, subtitleColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: isFirst ? Border.all(color: const Color(0xFF7226FF).withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isFirst ? [const Color(0xFF7226FF), const Color(0xFF160078)] : [Colors.grey.shade300, Colors.grey.shade400]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.battery_charging_full, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data["maintenance_type"] ?? "—", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      Text(_formatDate(data["date_reparation"]), style: TextStyle(color: subtitleColor, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(data["description"] ?? "—", style: TextStyle(color: subtitleColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.store, size: 13, color: subtitleColor?.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(garage["nom"] ?? "—", style: TextStyle(color: subtitleColor, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      Text("${data["cost"] ?? "—"} ${'common.unit.tnd'.tr()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7226FF))),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subtitleColor?.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  void _showHistoryPopup(BuildContext context, Map<String, dynamic> data, bool isDark, Color textColor, Color? subtitleColor) {
    final garage = data["garage"] ?? {};
    final popupBg = isDark ? const Color(0xFF1A0035) : Colors.white;
    final popupText = isDark ? Colors.white : const Color(0xFF160078);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: popupBg,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: subtitleColor?.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.all(Radius.circular(24))),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.battery_charging_full, color: Colors.white, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data["maintenance_type"] ?? "—", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_formatDate(data["date_reparation"]), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                    GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    _popupSection("common.maintenance".tr(), [
                      _popupRow(Icons.build, "common.type".tr(), data["maintenance_type"] ?? "—", popupText, subtitleColor),
                      _popupRow(Icons.calendar_month, "common.date".tr(), _formatDate(data["date_reparation"]), popupText, subtitleColor),
                      _popupRow(Icons.attach_money, "common.cost".tr(), "${data["cost"] ?? "—"} ${'common.unit.tnd'.tr()}", popupText, subtitleColor),
                      _popupRow(Icons.notes, "common.observation".tr(), data["description"] ?? "—", popupText, subtitleColor),
                    ], popupText),
                    const SizedBox(height: 15),
                    _popupSection("common.garage".tr(), [
                      _popupRow(Icons.store, "common.name".tr(), garage["nom"] ?? "—", popupText, subtitleColor),
                      _popupRow(Icons.location_on, "common.address".tr(), garage["adresse"] ?? "—", popupText, subtitleColor),
                      _popupRow(Icons.phone, "common.phone".tr(), garage["telephone"] ?? "—", popupText, subtitleColor),
                      _popupRow(Icons.star, "common.rating".tr(), "${garage["rating"] ?? "—"} / 5", popupText, subtitleColor),
                    ], popupText),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              showEditDialog(
                                context: context,
                                data: data,
                                onUpdated: () {
                                  _loadBattery();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("common.modified".tr()),
                                      backgroundColor: const Color(0xFF7226FF),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7226FF).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF7226FF).withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.edit_rounded, color: Color(0xFF7226FF), size: 16),
                                  const SizedBox(width: 7),
                                  Text("common.edit".tr(), style: const TextStyle(color: Color(0xFF7226FF), fontWeight: FontWeight.w700, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              showDeleteConfirmDialog(
                                context: context,
                                idSav: data['id_sav'],
                                onDeleted: () {
                                  _loadBattery();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("common.deleted".tr()),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_rounded, color: Colors.red, size: 16),
                                  const SizedBox(width: 7),
                                  Text("common.delete".tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          PageRouteBuilder(
                            pageBuilder: (c, a, b) => const PanneDetailsPage(),
                            transitionsBuilder: (c, a, b, child) => SlideTransition(
                              position: Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
                              child: child,
                            ),
                          ),
                              (route) => false,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text("common.back".tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7226FF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _popupSection(String title, List<Widget> rows, Color textColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF7226FF).withOpacity(0.08))),
        child: Column(children: rows),
      ),
    ]);
  }

  Widget _popupRow(IconData icon, String label, String value, Color textColor, Color? subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF7226FF)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: subtitleColor, fontSize: 13))),
        const SizedBox(width: 10),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor))),
      ]),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return "—";
    try {
      final d = DateTime.parse(date.toString());
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    } catch (_) { return date.toString(); }
  }
}
