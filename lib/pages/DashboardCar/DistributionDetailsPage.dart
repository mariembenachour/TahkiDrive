import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/detailsPannes_service.dart';
import '../../services/theme_service.dart';
import '../DashboardCar/detailsPannes.dart';
import 'sav_edit_popup.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class DistributionDetailsPage extends StatefulWidget {
  const DistributionDetailsPage({super.key});

  @override
  State<DistributionDetailsPage> createState() => _DistributionDetailsPageState();
}

class _DistributionDetailsPageState extends State<DistributionDetailsPage>
    with TickerProviderStateMixin {

  late AnimationController _entryController;
  late AnimationController _listController;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  Map<String, dynamic>? lastDistribution;
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
    _loadDistribution();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadDistribution() async {
    try {
      final data = await DetailPannesService.fetchDistribution();
      setState(() {
        lastDistribution = data?["last"];
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
                      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0.h),
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
                              height: 50.h, width: 50.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.4)),
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                            ),
                          ),
                          SizedBox(width: 15.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Distribution", style: TextStyle(color: Colors.white, fontSize: 26.sp, fontWeight: FontWeight.bold)),
                              Text("Maintenance & Historique", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.settings_applications, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25.h),
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
                        padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 30.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lastDistribution != null) _buildLastCard(lastDistribution!, isDark, cardColor, textColor, subtitleColor),
                            SizedBox(height: 30.h),
                            Text("Historique", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                            SizedBox(height: 15.h),
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
          SizedBox(height: 15.h),
          Text("Aucune maintenance trouvée", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          Text("Aucun enregistrement disponible", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLastCard(Map<String, dynamic> data, bool isDark, Color cardColor, Color textColor, Color? subtitleColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(22.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.settings_applications, color: Colors.white, size: 32),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data["maintenance_type"] ?? "—", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    Text(_formatDate(data["date_reparation"]), style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.3), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.green.shade300)),
                  child: Text("Actuel", style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(22.w),
            child: Column(
              children: [
                Row(children: [Expanded(child: _buildInfoTile(Icons.notes, "Description", data["description"] ?? "—", const Color(0xFF160078), isDark))]),
                SizedBox(height: 15.h),
                Row(children: [Expanded(child: _buildInfoTile(Icons.attach_money, "Coût", "${data["cost"] ?? "—"} TND", Colors.deepPurple, isDark))]),
                SizedBox(height: 15.h),
                Row(children: [Expanded(child: _buildInfoTile(Icons.calendar_today, "Date", _formatDate(data["date_reparation"]), const Color(0xFF7226FF), isDark))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, int index, bool isDark, Color cardColor, Color textColor, Color? subtitleColor) {
    final isFirst = index == 0;
    return GestureDetector(
      onTap: () => _showHistoryPopup(context, data, isDark, textColor, subtitleColor),
      child: Container(
        margin: EdgeInsets.only(bottom: 15.h),
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22.r),
          border: isFirst ? Border.all(color: const Color(0xFF7226FF).withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isFirst ? [const Color(0xFF7226FF), const Color(0xFF160078)] : [Colors.grey.shade300, Colors.grey.shade400]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_applications, color: Colors.white, size: 18),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data["maintenance_type"] ?? "—", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: textColor)),
                      Text(_formatDate(data["date_reparation"]), style: TextStyle(color: subtitleColor, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Text(data["description"] ?? "—", style: TextStyle(color: subtitleColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      Text("${data["cost"] ?? "—"} TND", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF7226FF))),
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
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30.r), topRight: Radius.circular(30.r)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8),
                width: 40.w, height: 4.h,
                decoration: BoxDecoration(color: subtitleColor?.withOpacity(0.3), borderRadius: BorderRadius.circular(10.r)),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 0.h),
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7226FF), Color(0xFF160078)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.all(Radius.circular(24.r)),
                ),
                child: Row(
                  children: [
                    Container(padding: EdgeInsets.all(10.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.settings_applications, color: Colors.white, size: 24)),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data["maintenance_type"] ?? "—", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                        Text(_formatDate(data["date_reparation"]), style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 20.h),
                  children: [
                    _popupSection("Maintenance", [
                      _popupRow(Icons.build, "Type", data["maintenance_type"] ?? "—", popupText, subtitleColor),
                      _popupRow(Icons.calendar_month, "Date", _formatDate(data["date_reparation"]), popupText, subtitleColor),
                      _popupRow(Icons.attach_money, "Coût", "${data["cost"] ?? "—"} TND", popupText, subtitleColor),
                      _popupRow(Icons.notes, "Observation", data["description"] ?? "—", popupText, subtitleColor),
                    ], popupText),
                    SizedBox(height: 20.h),
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
                                  _loadDistribution();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Modifié avec succès ✅"),
                                      backgroundColor: const Color(0xFF7226FF),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              height: 50.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7226FF).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: const Color(0xFF7226FF).withOpacity(0.25)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_rounded, color: Color(0xFF7226FF), size: 16),
                                  SizedBox(width: 7),
                                  Text("Modifier", style: TextStyle(color: Color(0xFF7226FF), fontWeight: FontWeight.w700, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              showDeleteConfirmDialog(
                                context: context,
                                idSav: data['id_sav'],
                                onDeleted: () {
                                  _loadDistribution();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Supprimé avec succès ✅"),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Container(
                              height: 50.h,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: Colors.red.withOpacity(0.25)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_rounded, color: Colors.red, size: 16),
                                  SizedBox(width: 7),
                                  Text("Supprimer", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
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
                      label: const Text("Retour"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7226FF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
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
      margin: EdgeInsets.all(5.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        SizedBox(height: 8.h),
        Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 11)),
        SizedBox(height: 3.h),
        Text(value, style: TextStyle(color: color, fontSize: 14.sp, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _popupSection(String title, List<Widget> rows, Color textColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: textColor)),
      SizedBox(height: 10.h),
      Container(
        decoration: BoxDecoration(color: const Color(0xFF7226FF).withOpacity(0.04), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: const Color(0xFF7226FF).withOpacity(0.08))),
        child: Column(children: rows),
      ),
    ]);
  }

  Widget _popupRow(IconData icon, String label, String value, Color textColor, Color? subtitleColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(children: [
        Icon(icon, size: 16.w, color: const Color(0xFF7226FF)),
        SizedBox(width: 10.w),
        Expanded(child: Text(label, style: TextStyle(color: subtitleColor, fontSize: 13))),
        SizedBox(width: 10.w),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: textColor))),
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
