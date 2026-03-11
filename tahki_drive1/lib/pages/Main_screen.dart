import 'package:flutter/material.dart';
import '../menus/menu.dart';
import 'DashboardCar/Agenda.dart';
import 'DashboardCar/Carte.dart';
import 'DashboardCar/ChatPage.dart';
import 'DashboardCar/Dashboard.dart';
import 'DashboardDriver/DashboardChauffeur.dart';
import 'DashboardCar/Profile.dart'; // Import indispensable

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _showCarDashboard = true; // Gère le switch interne à l'index 0

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Le menu global ne s'affiche que si on est en mode "Voiture"
    // ou sur les autres onglets (Carte, Agenda, Aura)
    bool shouldShowGlobalMenu = _selectedIndex != 0 || _showCarDashboard;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              // 🏠 Index 0 : Dashboard Dynamique (Voiture ou Profil)
              _showCarDashboard
                  ? Dashboard(
                key: _selectedIndex == 0 && _showCarDashboard ? UniqueKey() : const ValueKey('db'),
                onSwitchProfile: () => setState(() => _showCarDashboard = false),
              )
                  : DashboardChauffeur(
                key: _selectedIndex == 0 && !_showCarDashboard ? UniqueKey() : const ValueKey('chauffeur'),
                onSwitchCar: () => setState(() => _showCarDashboard = true),
              ),

              // 📍 Index 1 : Carte
              NearestMechanicsPage(
                key: _selectedIndex == 1 ? UniqueKey() : const ValueKey('carte'),
                onBackToDashboard: () => _onItemTapped(0),
              ),

              // 📅 Index 2 : Agenda
              AgendaPage(
                key: _selectedIndex == 2 ? UniqueKey() : const ValueKey('agenda'),
                onBackToDashboard: () => _onItemTapped(0),
              ),

              // 🤖 Index 3 : AuraApp (IA)
              AuraApp(
                key: _selectedIndex == 3 ? UniqueKey() : const ValueKey('aura'),
                onBackToDashboard: () => _onItemTapped(0),
              ),

              ProfilePage(
                key: _selectedIndex == 4 ? UniqueKey() : const ValueKey('profile'),
                onBackToDashboard: () => _onItemTapped(0),
              ),
            ],
          ),


          // 📱 Barre de navigation flottante (Menu Global)
          if (shouldShowGlobalMenu)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Menu(
                selectedIndex: _selectedIndex,
                onItemTapped: _onItemTapped,
              ),
            ),
        ],
      ),
    );
  }
}