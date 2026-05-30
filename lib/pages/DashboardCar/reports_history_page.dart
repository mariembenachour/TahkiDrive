import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import 'package:tahki_drive1/pages/DashboardCar/DailyReportPage.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class ReportsHistoryPage extends StatefulWidget {
  final String cin;
  const ReportsHistoryPage({super.key, required this.cin});

  @override
  State<ReportsHistoryPage> createState() => _ReportsHistoryPageState();
}

class _ReportsHistoryPageState extends State<ReportsHistoryPage> {
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await NotificationService.fetchReportsHistory();
    if (!mounted) return;
    setState(() {
      _reports = data;
      _isLoading = false;
    });
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF30D158);
    if (score >= 60) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF2D55);
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Correct';
    return 'À améliorer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8EAF6), Color(0xFFF3E5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:  EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Color(0xFF160078)),
                          onPressed: () => Navigator.pop(context),
                        ),
                         Text(
                          "Historique des rapports",
                          style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF160078)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Color(0xFF7226FF)),
                      onPressed: _load,
                    ),
                  ],
                ),
              ),

              // Liste
              Expanded(
                child: _isLoading
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7226FF)))
                    : _reports.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart_rounded,
                          size: 60.w, color: Colors.grey[300]),
                       SizedBox(height: 16.h),
                      Text("Aucun rapport disponible",
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) =>
                      _buildReportCard(_reports[index], index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> item, int index) {
    final score = item['score_today'] ?? 0;
    final date = item['report_date'] ?? '';
    final report = item['report'] as Map<String, dynamic>?;
    final color = _scoreColor(score);
    final label = _scoreLabel(score);

    // Formater la date
    String formattedDate = date;
    try {
      final d = DateTime.parse(date);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final rd = DateTime(d.year, d.month, d.day);
      if (rd == today) formattedDate = "Aujourd'hui";
      else if (rd == yesterday) formattedDate = "Hier";
      else formattedDate = '${d.day}/${d.month}/${d.year}';
    } catch (_) {}

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + index * 60),
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: GestureDetector(
            onTap: () {
              // Ouvre DailyReportPage avec la date spécifique
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DailyReportPage(
                    cin: widget.cin,
                    date: date, // ← on passe la date
                  ),
                ),
              );
            },
            child: Container(
              margin:  EdgeInsets.only(bottom: 14.h),
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  // Score circle
                  Container(
                    width: 60.w, height: 60.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.1),
                      border: Border.all(color: color.withOpacity(0.3), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$score',
                            style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: color)),
                        Text('/100',
                            style: TextStyle(
                                fontSize: 8.sp,
                                color: color.withOpacity(0.7))),
                      ],
                    ),
                  ),
                   SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formattedDate,
                            style:  TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF160078))),
                         SizedBox(height: 4.h),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ),
                        if (report?['tip'] != null) ...[
                           SizedBox(height: 6.h),
                          Text(report!['tip'],
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[500],
                                  height: 1.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
