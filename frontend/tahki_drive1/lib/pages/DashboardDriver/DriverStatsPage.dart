import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsPageChauffeur extends StatelessWidget {
  final Color bluePrimary = const Color(0xFF006AD7);
  final Color blueDark = const Color(0xFF21277B);
  final Color greyBlue = const Color(0xFF5F83B1);

  const StatsPageChauffeur({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Statistiques détaillées",
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold, color: blueDark)),
          const SizedBox(height: 20),

          // Card Fatigue
          _buildStatCard(
            context,
            title: "Fatigue",
            icon: Icons.timer,
            value: "25%",
            description: "Aujourd'hui",
            percent: 0.25,
            color: bluePrimary,
          ),
          const SizedBox(height: 20),

          // Card Sécurité
          _buildStatCard(
            context,
            title: "Sécurité",
            icon: Icons.security,
            value: "100%",
            description: "Ceinture bouclée",
            percent: 1.0,
            color: blueDark,
          ),
          const SizedBox(height: 20),

          // Card Tabac
          _buildStatCard(
            context,
            title: "Tabac",
            icon: Icons.smoking_rooms,
            value: "0%",
            description: "Aucune fumée détectée",
            percent: 0.0,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 20),

          // Card Scoring global
          _buildStatCard(
            context,
            title: "Score global",
            icon: Icons.bar_chart,
            value: "85 pts",
            description: "Top 10% des conducteurs",
            percent: 0.85,
            color: bluePrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required String title,
        required IconData icon,
        required String value,
        required String description,
        required double percent,
        required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            color: color,
            backgroundColor: Colors.grey[200],
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(description, style: GoogleFonts.poppins(fontSize: 13, color: greyBlue)),
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color)),
            ],
          )
        ],
      ),
    );
  }
}