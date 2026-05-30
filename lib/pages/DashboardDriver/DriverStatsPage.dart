import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' show pi, cos, sin;
import '../../services/driver_dashboard_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça

class StatsPageChauffeur extends StatefulWidget {
  const StatsPageChauffeur({super.key});

  @override
  State<StatsPageChauffeur> createState() => _StatsPageChauffeurState();
}

class _StatsPageChauffeurState extends State<StatsPageChauffeur>
    with SingleTickerProviderStateMixin {
  static const _blue      = Color(0xFF006AD7);
  static const _blueDark  = Color(0xFF21277B);
  static const _greyBlue  = Color(0xFF5F83B1);
  static const _cyanLight = Color(0xFF38B6FF);
  static const _bgLight   = Color(0xFFF0F6FF);

  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _loadStats();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final data = await DriverDashboardService.getWeeklyStats();
    if (mounted) setState(() { _stats = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _bgLight,
        child: Center(
          child: CircularProgressIndicator(
            color: _blue,
            strokeCap: StrokeCap.round,
            strokeWidth: 3.w,
          ),
        ),
      );
    }

    final s             = _stats ?? {};
    final avgScore      = (s['avg_score']          as num?)?.toInt()  ?? 0;
    final scoreLabel    =  s['score_label']         as String?        ?? '—';
    final fatiguePct    = (s['fatigue_week_pct']    as num?)?.toInt() ?? 0;
    final seatbeltOk    =  s['seatbelt_ok']         as bool?          ?? true;
    final smokeOk       =  s['smoke_ok']            as bool?          ?? true;
    final seatbeltDays  = (s['seatbelt_days_count'] as num?)?.toInt() ?? 0;
    final smokeDays     = (s['smoke_days_count']    as num?)?.toInt() ?? 0;
    final weeklyScores  =  s['weekly_scores']       as Map<String, dynamic>? ?? {};
    final catScores     =  s['category_scores']     as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: _bgLight,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: _blue,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildCurvedHeader(avgScore, scoreLabel),
            ),
            SliverPadding(
              padding:  EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 0.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                   SizedBox(height: 24.h),
                  _buildSmoothChart(weeklyScores),
                   SizedBox(height: 28.h),
                  _sectionTitle("Indicateurs clés"),
                   SizedBox(height: 14.h),
                  _buildKpiCards(
                    fatiguePct:   fatiguePct,
                    seatbeltOk:   seatbeltOk,
                    smokeOk:      smokeOk,
                    seatbeltDays: seatbeltDays,
                    smokeDays:    smokeDays,
                    avgScore:     avgScore,
                    scoreLabel:   scoreLabel,
                  ),
                   SizedBox(height: 28.h),
                  _sectionTitle("Analyse par catégorie"),
                  SizedBox(height: 14.h),
                  ..._categoryCards(catScores),
                  SizedBox(height: 90.h),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header avec vague courbe ───────────────────────────────────────────────
  Widget _buildCurvedHeader(int score, String label) {
    return Stack(
      children: [
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            height: 320.h,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blueDark, _blue],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding:  EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 0.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Statistiques",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child:  Icon(
                                Icons.calendar_today_rounded,
                                color: Colors.white70,
                                size: 12.w,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "7 derniers jours",
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding:  EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 6.w),
                          Text(
                            "Score $score",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 28.h),
                Center(
                  child: Container(
                    padding: EdgeInsets.all(28.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32.r),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: score / 100),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => SizedBox(
                            width: 120.w,
                            height: 120.h,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 120.w,
                                  height: 120.h,
                                  child: CircularProgressIndicator(
                                    value: 1,
                                    strokeWidth: 10.w,
                                    color: const Color(0xFFE8F0FE),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                SizedBox(
                                  width: 120.w,
                                  height: 120.h,
                                  child: CustomPaint(
                                    painter: _SmoothArcPainter(
                                      progress: v,
                                      startColor: _cyanLight,
                                      endColor: _blue,
                                      strokeWidth: 10.w,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "$score",
                                      style: GoogleFonts.poppins(
                                        fontSize: 32.sp,
                                        fontWeight: FontWeight.bold,
                                        color: _blueDark,
                                      ),
                                    ),
                                    Text(
                                      "/ 100",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.sp,
                                        color: _greyBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 24.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Score moyen",
                              style: GoogleFonts.poppins(
                                color: _greyBlue,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              label,
                              style: GoogleFonts.poppins(
                                color: _blueDark,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            _modernBadge(score),
                            SizedBox(height: 14.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: score / 100),
                                duration:  Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => Container(
                                  width: 140.w,
                                  height: 6.h,
                                  decoration: BoxDecoration(
                                    color:  Color(0xFFE8F0FE),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: v,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: score >= 70
                                              ? [Colors.green.shade400, Colors.green.shade600]
                                              : [Colors.orange.shade400, Colors.orange.shade600],
                                        ),
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modernBadge(int score) {
    final good = score >= 70;
    final color = good ? Colors.green.shade600 : Colors.orange.shade600;
    return Container(
      padding:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: good
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            good ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14.w,
            color: color,
          ),
           SizedBox(width: 6.w),
          Text(
            good ? "En progression" : "À améliorer",
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Graphique courbe lisse ─────────────────────────────────────────────────
  Widget _buildSmoothChart(Map<String, dynamic> weeklyScores) {
    if (weeklyScores.isEmpty) return  SizedBox.shrink();

    final entries = weeklyScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final scores = entries.map((e) => (e.value as num).toDouble()).toList();

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayIndex = entries.indexWhere((e) => e.key == todayStr);

    final List<String> dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    String dayLabel(String dateStr) {
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return '?';
      return dayNames[dt.weekday - 1];
    }

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: _modernCardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Évolution du score",
                  style: GoogleFonts.poppins(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: _blueDark,
                  ),
                ),
              ),
            ],
          ),
           SizedBox(height: 24.h),
          SizedBox(
            height: 200.h,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: _SmoothCurvePainter(
                scores: scores,
                todayIndex: todayIndex,
                primaryColor: _blue,
                secondaryColor: _cyanLight,
                inactiveColor: _greyBlue.withOpacity(0.3),
              ),
            ),
          ),
           SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(scores.length, (i) {
              final isToday = i == todayIndex;
              return Column(
                children: [
                  Text(
                    "${scores[i].toInt()}",
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday ? _blue : _greyBlue,
                    ),
                  ),
                   SizedBox(height: 4.h),
                  Container(
                    padding:  EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: isToday
                        ? BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(8.r),
                    )
                        : null,
                    child: Text(
                      dayLabel(entries[i].key),
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? Colors.white : _greyBlue,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Indicateurs clés en style "pills" horizontaux défilants ────────────────
  Widget _buildKpiCards({
    required int fatiguePct,
    required bool seatbeltOk,
    required bool smokeOk,
    required int seatbeltDays,
    required int smokeDays,
    required int avgScore,
    required String scoreLabel,
  }) {
    final kpis = [
      (
      icon: Icons.bedtime_rounded,
      label: "Fatigue",
      value: "$fatiguePct%",
      sub: fatiguePct > 50 ? "Élevé" : fatiguePct > 20 ? "Modéré" : "Faible",
      color: fatiguePct > 50 ? Colors.red.shade400
          : fatiguePct > 20 ? Colors.orange : Colors.green.shade500,
      progress: fatiguePct / 100,
      gradient: [ Color(0xFFFFE4E1),  Color(0xFFFFCDD2)],
      ),
      (
      icon: Icons.shield_rounded,
      label: "Ceinture",
      value: seatbeltOk ? "OK" : "${seatbeltDays}j",
      sub: seatbeltOk ? "Parfait" : "Alerte",
      color: seatbeltOk ? Colors.green.shade500 : Colors.orange,
      progress: seatbeltOk ? 1.0 : 0.3,
      gradient: [ Color(0xFFE8F5E9),  Color(0xFFC8E6C9)],
      ),
      (
      icon: Icons.smoking_rooms_rounded,
      label: "Tabac",
      value: smokeOk ? "OK" : "${smokeDays}j",
      sub: smokeOk ? "Aucune" : "Détectée",
      color: smokeOk ? Colors.green.shade500 : Colors.red.shade400,
      progress: smokeOk ? 1.0 : 0.2,
      gradient: [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
      ),
      (
      icon: Icons.emoji_events_rounded,
      label: "Score",
      value: "$avgScore",
      sub: scoreLabel,
      color: avgScore >= 70 ? Colors.amber.shade600 : _greyBlue,
      progress: avgScore / 100,
      gradient: [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
      ),
    ];

    return SizedBox(
      height: 130.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: kpis.length,
        separatorBuilder: (_, __) =>SizedBox(width: 12.w),
        itemBuilder: (context, i) {
          final kpi = kpis[i];
          return _pillKpiCard(kpi);
        },
      ),
    );
  }

  Widget _pillKpiCard(dynamic kpi) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: kpi.progress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, progress, __) => Container(
        width: 150.w,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kpi.gradient[0],
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: kpi.color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: kpi.color.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: kpi.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(kpi.icon, color: kpi.color, size: 18),
                ),
                Container(
                  padding:  EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: kpi.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    kpi.sub,
                    style: GoogleFonts.poppins(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: kpi.color,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              kpi.value,
              style: GoogleFonts.poppins(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: _blueDark,
                height: 1.h,
              ),
            ),
           SizedBox(height: 4.h),
            Text(
              kpi.label,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: _greyBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
           SizedBox(height: 8.h),
            // Barre de progression arrondie en bas
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: Container(
                height: 4.h,
                width: double.infinity,
                color: kpi.color.withOpacity(0.1),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kpi.color,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Catégories avec design "gauge" semi-circulaire ─────────────────────────
  List<Widget> _categoryCards(Map<String, dynamic> catScores) {
    final cats = [
      ("Distraction", "distraction", Icons.phone_android_rounded, const Color(0xFF7C4DFF), "Attention à la route"),
      ("Fatigue",   "fatigue",   Icons.bed_rounded,        Colors.orange.shade700,  "Repos & pauses régulières"),
      ("Sécurité",  "securite",  Icons.shield_rounded,     Colors.green.shade600,   "Ceinture & distances"),
    ];

    return cats.map((c) {
      final score = (catScores[c.$2] as num?)?.toInt() ?? 100;
      return Padding(
        padding:  EdgeInsets.only(bottom: 14.h),
        child: _gaugeCatCard(c.$1, score, c.$3, c.$4, c.$5),
      );
    }).toList();
  }

  Widget _gaugeCatCard(String title, int score, IconData icon, Color color, String tip) {
    final pct = score / 100;
    final scoreColor = score >= 80
        ? Colors.green.shade600
        : score >= 60 ? Colors.orange.shade600 : Colors.red.shade400;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _modernCardDeco(),
      child: Row(
        children: [
          // Gauge semi-circulaire
          SizedBox(
            width: 90.w,
            height: 55.h,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CustomPaint(
                size: const Size(90, 55),
                painter: _GaugePainter(
                  progress: v,
                  color: color,
                  scoreColor: scoreColor,
                  score: score,
                ),
              ),
            ),
          ),
         SizedBox(width: 18.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                   SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: _blueDark,
                            ),
                          ),
                          Text(
                            tip,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: _greyBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
               SizedBox(height: 14.h),
                // Segments de progression style échelle
                Row(
                  children: List.generate(10, (i) {
                    final filled = i < (score / 10).round();
                    return Expanded(
                      child: Container(
                        height: 6.h,
                        margin: EdgeInsets.only(right: i < 9 ? 3 : 0),
                        decoration: BoxDecoration(
                          color: filled
                              ? Color.lerp(color, color.withOpacity(0.5), i / 9)
                              : const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(
    t,
    style: GoogleFonts.poppins(
      fontSize: 18.sp,
      fontWeight: FontWeight.bold,
      color: _blueDark,
      letterSpacing: -0.3,
    ),
  );

  Widget _modernChip(String label, Color color) => Container(
    padding:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withOpacity(0.1),
          color.withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 11.sp,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  BoxDecoration _modernCardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24.r),
    boxShadow: [
      BoxShadow(
        color: _blue.withOpacity(0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: -2,
      ),
    ],
  );
}

// ── Clipper pour la vague du header ──────────────────────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 30,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 60,
      size.width,
      size.height - 20,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painter pour arc circulaire lisse ────────────────────────────────────────
class _SmoothArcPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;

  _SmoothArcPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [startColor, endColor, startColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SmoothArcPainter old) => old.progress != progress;
}

// ── Painter pour gauge semi-circulaire ───────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color scoreColor;
  final int score;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.scoreColor,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 4;

    // Arc de fond
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8F0FE);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Arc de progression avec dégradé
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color, color.withOpacity(0.6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * progress,
      false,
      progressPaint,
    );

    // Pointeur
    final angle = pi + (pi * progress);
    final pointerX = center.dx + (radius - 4) * cos(angle);
    final pointerY = center.dy + (radius - 4) * sin(angle);

    final pointerPaint = Paint()
      ..color = scoreColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(pointerX, pointerY), 5, pointerPaint);

    // Bordure blanche du pointeur
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(pointerX, pointerY), 5, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Painter pour courbe lisse ────────────────────────────────────────────────
class _SmoothCurvePainter extends CustomPainter {
  final List<double> scores;
  final int todayIndex;
  final Color primaryColor;
  final Color secondaryColor;
  final Color inactiveColor;

  _SmoothCurvePainter({
    required this.scores,
    required this.todayIndex,
    required this.primaryColor,
    required this.secondaryColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final width = size.width;
    final height = size.height - 40;
    final stepX = width / (scores.length - 1);

    final points = List.generate(scores.length, (i) {
      final x = i * stepX;
      final y = height - (scores[i] / 100) * height * 0.8 - 20;
      return Offset(x, y);
    });

    final fillPath = Path();
    fillPath.moveTo(points.first.dx, height + 20);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      for (double t = 0; t <= 1; t += 0.05) {
        final cp = _catmullRom(p0, p1, p2, p3, t);
        fillPath.lineTo(cp.dx, cp.dy);
      }
    }

    fillPath.lineTo(points.last.dx, height + 20);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height + 20));

    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      for (double t = 0; t <= 1; t += 0.02) {
        final cp = _catmullRom(p0, p1, p2, p3, t);
        linePath.lineTo(cp.dx, cp.dy);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [secondaryColor, primaryColor],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < points.length; i++) {
      final isToday = i == todayIndex;
      final point = points[i];

      if (isToday) {
        final glowPaint = Paint()
          ..color = primaryColor.withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 14, glowPaint);
      }

      final circlePaint = Paint()
        ..color = isToday ? primaryColor : inactiveColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, isToday ? 8 : 5, circlePaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(point, isToday ? 8 : 5, borderPaint);
    }
  }

  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;

    final x = 0.5 * (
        2 * p1.dx +
            (-p0.dx + p2.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3
    );

    final y = 0.5 * (
        2 * p1.dy +
            (-p0.dy + p2.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3
    );

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
