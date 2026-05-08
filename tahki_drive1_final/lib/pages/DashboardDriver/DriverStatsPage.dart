import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../services/driver_dashboard_service.dart';

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

  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
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
      return Center(child: CircularProgressIndicator(
          color: _blue, strokeCap: StrokeCap.round));
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

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: _blue,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(avgScore, scoreLabel),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChart(weeklyScores),
                  const SizedBox(height: 28),
                  _sectionTitle("Indicateurs clés"),
                  const SizedBox(height: 14),
                  _buildBadgeRow(
                    fatiguePct:   fatiguePct,
                    seatbeltOk:   seatbeltOk,
                    smokeOk:      smokeOk,
                    seatbeltDays: seatbeltDays,
                    smokeDays:    smokeDays,
                    avgScore:     avgScore,
                    scoreLabel:   scoreLabel,
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle("Analyse par catégorie"),
                  const SizedBox(height: 14),
                  ..._categoryRows(catScores),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero header ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(int score, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Statistiques",
                        style: GoogleFonts.poppins(
                            color: _blueDark,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          color: _greyBlue, size: 13),
                      const SizedBox(width: 5),
                      Text("7 derniers jours",
                          style: GoogleFonts.poppins(
                              color: _greyBlue, fontSize: 13)),
                    ]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _blue.withOpacity(0.18), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, color: _blue, size: 16),
                  const SizedBox(width: 5),
                  Text("Score $score",
                      style: GoogleFonts.poppins(
                          color: _blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _blue.withOpacity(0.10), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _blue.withOpacity(0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => SizedBox(
                  width: 110, height: 110,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 110, height: 110,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 9,
                        color: const Color(0xFFD0E4F7),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ArcGradientPainter(
                            value: v,
                            startColor: _cyanLight,
                            endColor: _blue,
                          ),
                        ),
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text("$score",
                          style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: _blueDark)),
                      Text("/ 100",
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: _greyBlue)),
                    ]),
                  ]),
                ),
              ),

              const SizedBox(width: 22),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Score moyen",
                        style: GoogleFonts.poppins(
                            color: _greyBlue, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: GoogleFonts.poppins(
                            color: _blueDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _scoreBadge(score),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: score / 100),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFD0E4F7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            score >= 70 ? Colors.green.shade400 : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(int score) {
    final good  = score >= 70;
    final color = good ? Colors.green.shade600 : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(good ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14, color: color),
        const SizedBox(width: 5),
        Text(good ? "En progression" : "À améliorer",
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ── Graphique ───────────────────────────────────────────────────────────────
  Widget _buildChart(Map<String, dynamic> weeklyScores) {
    if (weeklyScores.isEmpty) return const SizedBox.shrink();

    final entries = weeklyScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final scores = entries.map((e) => (e.value as num).toDouble()).toList();
    final maxS   = scores.reduce(max);
    final minS   = scores.reduce(min);

    final todayStr   = DateTime.now().toIso8601String().substring(0, 10);
    final todayIndex = entries.indexWhere((e) => e.key == todayStr);

    const dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    String dayLabel(String dateStr) {
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return '?';
      return dayNames[dt.weekday - 1];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text("Évolution du score",
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: _blueDark))),
            _chip("Max ${maxS.toInt()}", Colors.green.shade600),
            const SizedBox(width: 8),
            _chip("Min ${minS.toInt()}", Colors.orange.shade700),
          ]),
          const SizedBox(height: 22),
          SizedBox(
            height: 210,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(scores.length, (i) {
                final h       = (scores[i] / 100) * 120;
                final isToday = i == todayIndex;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isToday)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.star_rounded,
                            color: Colors.amber.shade600, size: 16),
                      )
                    else
                      const SizedBox(height: 20),

                    AnimatedContainer(
                      duration: Duration(milliseconds: 600 + i * 80),
                      curve: Curves.easeOutCubic,
                      height: h,
                      width: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isToday
                              ? [_blue, _cyanLight]
                              : [
                            _greyBlue.withOpacity(0.25),
                            _greyBlue.withOpacity(0.45),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text("${scores[i].toInt()}",
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? _blue : _greyBlue)),

                    Text(dayLabel(entries[i].key),
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isToday ? _blue : _greyBlue,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),

                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("Auj.",
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Indicateurs clés ────────────────────────────────────────────────────────
  Widget _buildBadgeRow({
    required int fatiguePct,
    required bool seatbeltOk,
    required bool smokeOk,
    required int seatbeltDays,
    required int smokeDays,
    required int avgScore,
    required String scoreLabel,
  }) {
    return Column(children: [
      Row(children: [
        Expanded(child: _kpiCard(
          icon: Icons.bedtime_rounded,
          label: "Fatigue",
          value: "$fatiguePct%",
          sub: fatiguePct > 50 ? "Niveau élevé" : fatiguePct > 20 ? "Modéré" : "Faible",
          color: fatiguePct > 50 ? Colors.red.shade400
              : fatiguePct > 20 ? Colors.orange : Colors.green.shade500,
        )),
        const SizedBox(width: 14),
        Expanded(child: _kpiCard(
          icon: Icons.shield_rounded,
          label: "Ceinture",
          value: seatbeltOk ? "OK" : "${seatbeltDays}j",
          sub: seatbeltOk ? "Toujours bouclée" : "Non bouclée",
          color: seatbeltOk ? Colors.green.shade500 : Colors.orange,
        )),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _kpiCard(
          icon: Icons.smoking_rooms_rounded,
          label: "Tabac",
          value: smokeOk ? "OK" : "${smokeDays}j",
          sub: smokeOk ? "Aucune fumée" : "Fumée détectée",
          color: smokeOk ? Colors.green.shade500 : Colors.red.shade400,
        )),
        const SizedBox(width: 14),
        Expanded(child: _kpiCard(
          icon: Icons.emoji_events_rounded,
          label: "Score moy.",
          value: "$avgScore",
          sub: scoreLabel,
          color: avgScore >= 70 ? Colors.amber.shade600 : _greyBlue,
        )),
      ]),
    ]);
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _blueDark)),
        ]),
        const SizedBox(height: 12),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: _greyBlue, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(sub,
            style: GoogleFonts.poppins(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Catégories ──────────────────────────────────────────────────────────────
  List<Widget> _categoryRows(Map<String, dynamic> catScores) {
    final cats = [
      ("Vigilance", "vigilance", Icons.visibility_rounded, const Color(0xFF6A1B9A), "Attention à la route"),
      ("Fatigue",   "fatigue",   Icons.bed_rounded,        Colors.orange,           "Repos & pauses régulières"),
      ("Sécurité",  "securite",  Icons.shield_rounded,     Colors.green,            "Ceinture & distances"),
    ];

    return cats.map((c) {
      final score = (catScores[c.$2] as num?)?.toInt() ?? 100;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _catCard(c.$1, score, c.$3, c.$4, c.$5),
      );
    }).toList();
  }

  Widget _catCard(String title, int score, IconData icon, Color color, String tip) {
    final pct = score / 100;
    final scoreColor = score >= 80
        ? Colors.green.shade600
        : score >= 60 ? Colors.orange : Colors.red.shade400;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pct),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600, color: _blueDark)),
                  Text(tip,
                      style: GoogleFonts.poppins(fontSize: 11, color: _greyBlue)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("$score",
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.bold, color: scoreColor)),
            ),
          ]),
          const SizedBox(height: 14),
          Stack(children: [
            Container(
              height: 6, width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EFF8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.bold, color: _blueDark));

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.20)),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(
            fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF006AD7).withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

// ── Custom Painter arc gradient ───────────────────────────────────────────────
class _ArcGradientPainter extends CustomPainter {
  final double value;
  final Color startColor;
  final Color endColor;

  _ArcGradientPainter({
    required this.value,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect        = Rect.fromLTWH(0, 0, size.width, size.height);
    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = size.width / 2;
    const strokeWidth = 9.0;
    const startAngle  = -1.5708;
    final sweepAngle  = 2 * 3.14159 * value;

    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round
      ..shader      = LinearGradient(
        begin:  Alignment.topLeft,
        end:    Alignment.bottomRight,
        colors: [startColor, endColor],
      ).createShader(rect);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGradientPainter old) => old.value != value;
}
