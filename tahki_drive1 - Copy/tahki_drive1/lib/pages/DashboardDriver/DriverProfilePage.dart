// DashboardDriver/DriverProfilePage.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverProfilePage extends StatelessWidget {
  const DriverProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Profil Chauffeur',
        style: GoogleFonts.poppins(fontSize: 20),
      ),
    );
  }
}