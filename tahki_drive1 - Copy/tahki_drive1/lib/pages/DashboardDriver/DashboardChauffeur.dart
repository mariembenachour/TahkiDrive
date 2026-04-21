import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../menus/GlobalNavBar.dart';
import 'dart:ui';
import 'DriverChatPage.dart';
import 'DriverStatsPage.dart';

class DashboardChauffeur extends StatefulWidget {
  final VoidCallback onSwitchCar;

  const DashboardChauffeur({super.key, required this.onSwitchCar});

  @override
  State<DashboardChauffeur> createState() => _DashboardChauffeurState();
}

class _DashboardChauffeurState extends State<DashboardChauffeur>
    with SingleTickerProviderStateMixin {
  final Color bluePrimary = const Color(0xFF006AD7);
  final Color blueDark = const Color(0xFF21277B);
  final Color blueLight = const Color(0xFF9AD9EA);
  final Color white = const Color(0xFFFFFFFF);
  final Color greyBlue = const Color(0xFF5F83B1);

  late AnimationController _animationController;
  bool _isFatigueCardExpanded = false;
  int _selectedBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _animatedEntry({required Widget child, required double delay}) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fond avec gradient
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

          // Contenu principal - PLUS DE SingleChildScrollView ICI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Contenu variable selon l'onglet sélectionné
                  Expanded(
                    child: IndexedStack(
                      index: _selectedBottomNavIndex,
                      children: [
                        _buildAccueilContent(), // index 0 - avec son propre scroll
                        _buildStatsContent(),   // index 1
                        _buildChatContent(), // index 2 - avec son propre scroll
                        _buildProfilContent(),  // index 3
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Menu du haut (GlobalNavBar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: _animatedEntry(
              delay: 0.0,
              child: GlobalNavBar(
                currentIndex: 1,
                onTabSelected: (index) {
                  if (index == 0) widget.onSwitchCar();
                },
              ),
            ),
          ),

          // Icône de notification en haut à droite
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            right: 20,
            child: _animatedEntry(
              delay: 0.0,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Notifications",
                          style: GoogleFonts.poppins()),
                      backgroundColor: bluePrimary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 1, end: 1.2),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bluePrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: bluePrimary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: bluePrimary,
                          size: 26,
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 8,
                            height: 8,
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
          ),

          // Menu du bas (navigation)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _animatedEntry(
              delay: 0.5,
              child: _buildProfileBottomNav(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONTENU DE L'ACCUEIL ====================
  Widget _buildAccueilContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AJOUTEZ LE HEADER ICI
          _animatedEntry(
            delay: 0.1,
            child: _buildHeader(),
          ),
          const SizedBox(height: 25),
          // Widget de score 85%
          _animatedEntry(
            delay: 0.15,
            child: _buildScoreCard(),
          ),

          const SizedBox(height: 20),

          // Stats de fatigue avec barres
          _animatedEntry(
            delay: 0.2,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isFatigueCardExpanded = !_isFatigueCardExpanded;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: _isFatigueCardExpanded ? 320 : 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: bluePrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(Icons.timer,
                                    color: bluePrimary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Niveau de fatigue",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: blueDark,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _isFatigueCardExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: bluePrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats avec barres
                      _buildBarStat("Aujourd'hui", "25%", 0.25, bluePrimary),
                      const SizedBox(height: 15),
                      _buildBarStat("Moyenne", "42%", 0.42, blueDark),

                      if (_isFatigueCardExpanded) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: greyBlue, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "Repos recommandé dans 2h",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: greyBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: 0.7,
                          backgroundColor: Colors.grey[200],
                          color: bluePrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Deux cartes côte à côte : Sécurité et Tabac
          _animatedEntry(
            delay: 0.4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildSecurityCard()),
                  const SizedBox(width: 15),
                  Expanded(child: _buildSmokingCard()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          // Activités récentes
          _animatedEntry(
            delay: 0.4,
            child: _buildRecentActivities(),
          ),

          const SizedBox(height: 30), // Espace supplémentaire en bas
        ],
      ),
    );
  }

  // ==================== CONTENU DES STATISTIQUES ====================
  Widget _buildStatsContent() {
    return const StatsPageChauffeur();
  }
  // ==================== CONTENU DU CHAT ====================
  Widget _buildChatContent() {
    return const DriverChatPage();
  }

  // ==================== CONTENU DU PROFIL ====================
  Widget _buildProfilContent() {
    return const Center(
      child: Text(
        "Page de profil\n(à implémenter)",
        textAlign: TextAlign.center,
      ),
    );
  }

  // ==================== WIDGETS EXISTANTS (inchangés) ====================
  Widget _buildScoreCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bluePrimary, blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: bluePrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score circulaire 85%
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: 0.85,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "85",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "pts",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Score de conduite",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Excellent ! Top 10% des conducteurs",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarStat(String label, String value, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: greyBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: blueDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color == bluePrimary ? bluePrimary : blueDark],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Bonjour, Marc",
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: blueDark)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bluePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("En service ●",
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: bluePrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bluePrimary, blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bluePrimary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ceinture de sécurité vérifiée",
                style: GoogleFonts.poppins()),
            backgroundColor: bluePrimary,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 1, end: 1.02),
        duration: const Duration(milliseconds: 200),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bluePrimary, blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: bluePrimary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Indicateur de validation en haut à droite
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration:
                  const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.check, color: bluePrimary, size: 14),
                ),
              ),
              // Contenu Principal
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.security,
                          color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      "Sécurité",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Ceinture bouclée",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
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

  Widget _buildSmokingCard() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text("Pas de fumée détectée", style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 1, end: 1.02),
        duration: const Duration(milliseconds: 200),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration:
                  const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child:
                  const Icon(Icons.check, color: Colors.redAccent, size: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.smoking_rooms,
                          color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      "Tabac",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Aucune fumée",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
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

  Widget _buildRecentActivities() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Activités récentes",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: blueDark,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: bluePrimary,
                  ),
                  child: Text(
                    "Voir tout",
                    style: GoogleFonts.poppins(
                      color: bluePrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildActivityItem(
                "Trajet Paris", "Il y a 2h", Icons.directions_car),
            _buildActivityItem(
                "Pause déjeuner", "Il y a 5h", Icons.free_breakfast),
            _buildActivityItem("Fin de service", "Hier", Icons.logout),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text("Détails de l'activité", style: GoogleFonts.poppins()),
            backgroundColor: bluePrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bluePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: bluePrimary, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: blueDark,
                    ),
                  ),
                  Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: greyBlue,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: greyBlue, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: bluePrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.grid_view_rounded, "Accueil", 0),
              _buildNavItem(Icons.bar_chart_rounded, "Stats", 1),
              _buildNavItem(Icons.notifications_none_rounded, "Alertes", 2),
              _buildNavItem(Icons.person_outline_rounded, "Profil", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _selectedBottomNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomNavIndex = index;
        });
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 1, end: isActive ? 1.1 : 1),
        duration: const Duration(milliseconds: 300),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? bluePrimary : greyBlue,
              size: 26,
            ),
            if (isActive) ...[
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bluePrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}