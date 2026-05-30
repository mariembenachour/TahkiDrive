// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/driver/DashboardChauffeur.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tahki_drive1/pages/DashboardCar/NotificationPage.dart';
import 'package:tahki_drive1/pages/DashboardDriver/PathsPage.dart';
import 'package:tahki_drive1/pages/DashboardDriver/Recentpathswidget.dart';
import 'dart:ui';
import '../../menus/GlobalNavBar.dart';
import '../../services/driver_dashboard_service.dart';
import 'DriverStatsPage.dart';
import 'package:tahki_drive1/pages/Auth/LoginPage.dart';
import 'package:tahki_drive1/services/auth_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça

class DashboardChauffeur extends StatefulWidget {
  final VoidCallback onSwitchCar;
  final bool canSwitch;
  const DashboardChauffeur({
    super.key,
    required this.onSwitchCar,
    this.canSwitch = false,
  });
  @override
  State<DashboardChauffeur> createState() => _DashboardChauffeurState();
}

class _DashboardChauffeurState extends State<DashboardChauffeur>
    with SingleTickerProviderStateMixin {

  // ── Palette ────────────────────────────────────────────────────────────────
  final Color bluePrimary = const Color(0xFF006AD7);
  final Color blueDark    = const Color(0xFF21277B);
  final Color blueLight   = const Color(0xFF9AD9EA);
  final Color greyBlue    = const Color(0xFF5F83B1);

  // ── State ──────────────────────────────────────────────────────────────────
  late AnimationController _animController;
  bool _isFatigueExpanded = false;
  int  _selectedNavIndex  = 0;

  Map<String, dynamic>? _dash;
  bool _dashLoading = true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadDashboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _dashLoading = true);
    final data = await DriverDashboardService.getDashboard();
    if (mounted) {
      setState(() {
        _dash        = data;
        _dashLoading = false;
      });
    }
  }

  // ── Animated entry ─────────────────────────────────────────────────────────
  Widget _entry({required Widget child, required double delay}) {
    final anim = CurvedAnimation(
      parent: _animController,
      curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3), end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fond dégradé
          Container(
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [blueLight.withOpacity(0.5), const Color(0xFFF0EDF6)],
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: 80.h),
              child: IndexedStack(
                index: _selectedNavIndex,
                children: [
                  _buildAccueilContent(),
                  _buildStatsContent(),
                ],
              ),
            ),
          ),

          // GlobalNavBar haut
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: _entry(
              delay: 0.0,
              child: GlobalNavBar(
                currentIndex: 1,
                canSwitch: widget.canSwitch,
                onTabSelected: (i) { if (i == 0) widget.onSwitchCar(); },
                onLogout: () async {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                  );
                },
              ),
            ),
          ),

          // Notification icon
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            right: 20,
            child: _entry(
              delay: 0.0,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(initialTab: NotifTab.driver, isDriver: true),                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: bluePrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                        color: bluePrimary.withOpacity(0.3), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: bluePrimary, size: 26),
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 8.w, height: 8.h,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom nav
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: _entry(delay: 0.5, child: _buildBottomNav()),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACCUEIL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAccueilContent() {
    if (_dashLoading) {
      return Center(child: CircularProgressIndicator(color: bluePrimary));
    }

    final d             = _dash ?? {};
    final score         = (d['score_today']    as num?)?.toInt()    ?? 0;
    final scoreLabel    = d['score_label']      as String?           ?? '—';
    final driverName    = d['driver_name']      as String?           ?? 'Conducteur';
    final ignition      = (d['ignition']        as num?)?.toInt()    ?? 0;
    final fatiguePct    = (d['fatigue_pct']     as num?)?.toDouble() ?? 0.0;
    final avgFatiguePct = (d['avg_fatigue_pct'] as num?)?.toDouble() ?? 0.0;
    final seatbeltOk    = d['seatbelt_ok']      as bool?             ?? true;
    final smokeOk       = d['smoke_ok']         as bool?             ?? true;
    final insight       = d['insight']          as Map?              ?? {};
    final scoreDelta    = d['score_delta']       as int?;
    final telephonePct  = (d['telephone_pct']  as num?)?.toInt() ?? 100;
    final distractionPct= (d['distraction_pct']as num?)?.toInt() ?? 100;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: bluePrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _entry(delay: 0.1,
                child: _buildHeader(driverName, ignition)),
             SizedBox(height: 25.h),
            _entry(delay: 0.15,
                child: _buildScoreCard(score, scoreLabel, scoreDelta)),
             SizedBox(height: 16.h),
            if (insight.isNotEmpty)
              _entry(delay: 0.2, child: _buildInsightCard(insight)),
             SizedBox(height: 16.h),
            _entry(delay: 0.25, child: _buildFatigueCard(fatiguePct, avgFatiguePct)),
             SizedBox(height: 16.h),
// ← NOUVEAU

             SizedBox(height: 20.h),
            _entry(
              delay: 0.3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: _buildSeatbeltCard(seatbeltOk)),
                   SizedBox(width: 15.w),
                  Expanded(child: _buildSmokingCard(smokeOk)),
                ]),
              ),
            ),
             SizedBox(height: 16.h),


// ← AJOUTE ICI
            _entry(delay: 0.28, child: _buildBehaviorCard(telephonePct, distractionPct)),
             SizedBox(height: 16.h),

             SizedBox(height: 25.h),
            _entry(delay: 0.35, child: const RecentPathsSection()),
             SizedBox(height: 100.h),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HEADER — affiche ignition réelle
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(String driverName, int ignition) {
    final firstName  = driverName.split(' ').first;
    final bool enRoute = ignition == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Bonjour, $firstName",
                style: GoogleFonts.poppins(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: blueDark)),
             SizedBox(height: 4.h),
            Container(
              padding:  EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: (enRoute ? Colors.green : greyBlue).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7.w, height: 7.h,
                  margin:  EdgeInsets.only(right: 6.w),
                  decoration: BoxDecoration(
                    color: enRoute ? Colors.green : greyBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  enRoute ? "En route" : "Arrêté",
                  style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: enRoute ? Colors.green.shade700 : greyBlue,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
          Container(
            width: 55.w, height: 55.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [bluePrimary, blueDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: bluePrimary.withOpacity(0.3),
                  blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SCORE CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildScoreCard(int score, String label, int? delta) {
    String deltaStr   = '';
    Color  deltaColor = Colors.white70;
    if (delta != null) {
      deltaStr  = delta >= 0
          ? '↑$delta pts vs hier'
          : '↓${delta.abs()} pts vs hier';
      deltaColor = delta >= 0
          ? Colors.greenAccent.shade100
          : Colors.red.shade100;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding:  EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [bluePrimary, blueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [BoxShadow(
            color: bluePrimary.withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 70.w, height: 70.h,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6.w,
              backgroundColor: Colors.white.withOpacity(0.2),
              color: Colors.white,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text("$score",
                style: GoogleFonts.poppins(
                    fontSize: 20.sp, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text("pts",
                style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    color: Colors.white.withOpacity(0.8))),
          ]),
        ]),
         SizedBox(width: 20.w),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Score du jour",
                style: GoogleFonts.poppins(
                    fontSize: 18.sp, fontWeight: FontWeight.bold,
                    color: Colors.white)),
             SizedBox(height: 4.h),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.85))),
            if (deltaStr.isNotEmpty) ...[
               SizedBox(height: 6.h),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(deltaStr,
                    style: GoogleFonts.poppins(
                        fontSize: 11.sp, color: deltaColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        )),
      ]),
    );
  }
  Widget _buildBehaviorCard(int telephone, int distraction) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: bluePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Icon(Icons.psychology_rounded,
                  color: bluePrimary, size: 20),
            ),
             SizedBox(width: 10.w),
            Text("Comportement du jour",
                style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: blueDark)),
          ]),
           SizedBox(height: 14.h),
          _buildBehaviorRow(
            icon: Icons.phone_android_rounded,
            label: "Téléphone",
            score: telephone,
          ),
           SizedBox(height: 14.h),
          _buildBehaviorRow(
            icon: Icons.directions_car_rounded,
            label: "Distraction",
            score: distraction,
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorRow({
    required IconData icon,
    required String label,
    required int score,
  }) {
    final Color color = score >= 80
        ? Colors.green.shade500
        : score >= 60
        ? Colors.orange
        : Colors.red.shade400;

    final String status = score >= 80
        ? "Bon"
        : score >= 60
        ? "Moyen"
        : "Attention";

    return Row(children: [
      Container(
        padding: EdgeInsets.all(7.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
       SizedBox(width: 12.w),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: blueDark)),
              Row(children: [
                Text(status,
                    style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: color,
                        fontWeight: FontWeight.w600)),
                 SizedBox(width: 6.w),
                Text("$score",
                    style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: blueDark)),
              ]),
            ],
          ),
           SizedBox(height: 6.h),
          Stack(children: [
            Container(
              height: 7.h, width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (score / 100).clamp(0.0, 1.0),
              child: Container(
                height: 7.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.7), color],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ]),
        ],
      )),
    ]);
  }
  // ══════════════════════════════════════════════════════════════════════════
  //  INSIGHT GROQ CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildInsightCard(Map insight) {
    final titre    = insight['titre']    as String? ?? '';
    final message  = insight['message'] as String? ?? '';
    final conseil  = insight['conseil'] as String? ?? '';
    final priorite = insight['priorite'] as String? ?? 'normale';

    Color    accentColor;
    IconData accentIcon;
    switch (priorite) {
      case 'haute':
        accentColor = Colors.orange.shade600;
        accentIcon  = Icons.warning_amber_rounded;
        break;
      case 'faible':
        accentColor = Colors.green.shade500;
        accentIcon  = Icons.emoji_events_rounded;
        break;
      default:
        accentColor = bluePrimary;
        accentIcon  = Icons.lightbulb_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
            color: accentColor.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(accentIcon, color: accentColor, size: 20),
            ),
             SizedBox(width: 10.w),
            Expanded(
              child: Text(titre,
                  style: GoogleFonts.poppins(
                      fontSize: 15.sp, fontWeight: FontWeight.bold,
                      color: blueDark)),
            ),
          ]),
          if (message.isNotEmpty) ...[
             SizedBox(height: 10.h),
            Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 13.sp, color: greyBlue, height: 1.5)),
          ],
          if (conseil.isNotEmpty) ...[
             SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(children: [
                Icon(Icons.arrow_right_alt_rounded,
                    color: accentColor, size: 18),
                 SizedBox(width: 6.w),
                Expanded(
                  child: Text(conseil,
                      style: GoogleFonts.poppins(
                          fontSize: 12.sp, color: blueDark,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FATIGUE CARD
  // ══════════════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════════
//  FATIGUE CARD - CORRIGÉE
// ══════════════════════════════════════════════════════════════════════════
  Widget _buildFatigueCard(double fatiguePct, double avgFatiguePct) {
    String fatigueMsg;
    if (fatiguePct > 60) {
      fatigueMsg = "Repos recommandé dès que possible";
    } else if (fatiguePct > 30) {
      fatigueMsg = "Légère fatigue détectée, restez vigilant";
    } else {
      fatigueMsg = "Aucun signe de fatigue aujourd'hui ✓";
    }

    final Color barColor = fatiguePct > 60
        ? Colors.red
        : fatiguePct > 30
        ? Colors.orange
        : bluePrimary;

    return GestureDetector(
      onTap: () => setState(() => _isFatigueExpanded = !_isFatigueExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        // Supprimer la hauteur fixe pour qu'elle s'adapte au contenu
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,  // ← AJOUTÉ (clé du problème)
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: bluePrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                      child: Icon(Icons.timer,
                          color: bluePrimary, size: 20),
                    ),
                     SizedBox(width: 10.w),
                    Text("Niveau de fatigue",
                        style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: blueDark)),
                  ]),
                  Icon(
                    _isFatigueExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: bluePrimary,
                  ),
                ],
              ),
               SizedBox(height: 20.h),
              _buildBarStat("Aujourd'hui", "${fatiguePct.toInt()}%",
                  fatiguePct / 100, bluePrimary),
               SizedBox(height: 15.h),
              _buildBarStat("Moyenne 7j", "${avgFatiguePct.toInt()}%",
                  avgFatiguePct / 100, blueDark),
              if (_isFatigueExpanded) ...[
                 SizedBox(height: 20.h),
                const Divider(),
                 SizedBox(height: 10.h),
                Row(children: [
                  Icon(Icons.info_outline, color: greyBlue, size: 16),
                   SizedBox(width: 8.w),
                  Expanded(
                    child: Text(fatigueMsg,
                        style: GoogleFonts.poppins(
                            fontSize: 13.sp, color: greyBlue)),
                  ),
                ]),
                 SizedBox(height: 10.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: fatiguePct / 100,
                    minHeight: 8.h,
                    backgroundColor: Colors.grey[200],
                    color: barColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Bar stat ───────────────────────────────────────────────────────────────
  Widget _buildBarStat(
      String label, String value, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14.sp, color: greyBlue,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16.sp, fontWeight: FontWeight.bold,
                  color: blueDark)),
        ]),
         SizedBox(height: 8.h),
        Stack(children: [
          Container(
            height: 10.h, width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          FractionallySizedBox(
            widthFactor: percent.clamp(0.0, 1.0),
            child: Container(
              height: 10.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color]),
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEATBELT CARD — remplace l'ancienne SecurityCard
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSeatbeltCard(bool ok) {
    final color     = ok ? bluePrimary : Colors.orange.shade600;
    final darkColor = ok ? blueDark    : const Color(0xFFE65100);
    final label     = ok ? "Ceinture bouclée" : "Ceinture non bouclée";

    return _buildStatusCard(
      color: color,
      darkColor: darkColor,
      icon: ok ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
      title: "Ceinture",
      label: label,
      ok: ok,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SMOKE CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSmokingCard(bool ok) {
    final color     = ok ? Colors.green.shade600 : Colors.redAccent;
    final darkColor = ok ? Colors.green.shade900  : const Color(0xFFB71C1C);
    final label     = ok ? "Aucune fumée" : "Fumée détectée";

    return _buildStatusCard(
      color: color,
      darkColor: darkColor,
      icon: ok ? Icons.smoke_free : Icons.smoking_rooms,
      title: "Tabac",
      label: label,
      ok: ok,
    );
  }

  // ── Widget générique pour les petites cartes statut ───────────────────────
  Widget _buildStatusCard({
    required Color color,
    required Color darkColor,
    required IconData icon,
    required String title,
    required String label,
    required bool ok,
  }) {
    return Container(
      height: 150.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, darkColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned(
          top: 12, right: 12,
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(
                ok ? Icons.check : Icons.close,
                color: color, size: 14),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r)),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Text(title,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 15.sp,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RECENT ACTIVITIES (placeholder)
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTRES ONGLETS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStatsContent() => const StatsPageChauffeur();


  // ══════════════════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 70.h,
          decoration: BoxDecoration(
            color: bluePrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.grid_view_rounded,          "Accueil", 0),
              _navItem(Icons.bar_chart_rounded,          "Stats",   1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isActive = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedNavIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: isActive ? bluePrimary : greyBlue, size: 26),
          if (isActive)
            Container(
              width: 6.w, height: 6.h,
              margin: EdgeInsets.only(top: 3.h),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: bluePrimary),
            ),
        ],
      ),
    );
  }
}
