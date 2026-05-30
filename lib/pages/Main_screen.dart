import 'package:flutter/material.dart';
import '../menus/menu.dart';
import 'DashboardCar/Agenda.dart';
import 'DashboardCar/Garage.dart';
import 'DashboardCar/ChatPage.dart';
import 'DashboardCar/Dashboard.dart';
import 'DashboardCar/Profile.dart';
import 'DashboardDriver/DashboardChauffeur.dart';
import '../services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Mode actif du dashboard (voiture ou chauffeur)
  bool _showCarDashboard = true;

  // Capacités du device lié au driver
  bool _hasCam      = false;
  bool _hasBoitier  = false;
  bool _modeLoaded  = false;

  String _currentCin = '';

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final cin        = await AuthService.getCin();
    final hasCam     = await AuthService.getHasCam();
    final hasBoitier = await AuthService.getHasBoitier();

    // Règle d'affichage initial :
    // - boitier seul  → démarre sur Dashboard voiture
    // - cam seul      → démarre sur DashboardChauffeur
    // - les deux      → démarre sur Dashboard voiture (switch disponible)
    bool startOnCar = hasBoitier; // si boitier dispo, on commence voiture

    setState(() {
      _currentCin      = cin ?? '';
      _hasCam          = hasCam;
      _hasBoitier      = hasBoitier;
      _showCarDashboard = startOnCar;
      _modeLoaded      = true;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Switch vers la vue voiture — disponible seulement si _hasBoitier
  void _switchToCar() {
    if (_hasBoitier) setState(() => _showCarDashboard = true);
  }

  /// Switch vers la vue chauffeur — disponible seulement si _hasCam
  void _switchToDriver() {
    if (_hasCam) setState(() => _showCarDashboard = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_modeLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Le bouton switch n'apparaît que si l'utilisateur a les DEUX modes
    final bool canSwitch = _hasCam && _hasBoitier;

    // Page d'accueil (index 0) selon le mode
    Widget homePage;
    if (_showCarDashboard && _hasBoitier) {
      homePage = Dashboard(
        key: _selectedIndex == 0 ? UniqueKey() : const ValueKey('db'),
        // N'affiche le bouton switch que si cam aussi disponible
        onSwitchProfile: canSwitch ? _switchToDriver : () {},
        canSwitch: canSwitch,   // ← AJOUTER (une seule ligne)
      );
    } else if (!_showCarDashboard && _hasCam) {
      homePage = DashboardChauffeur(
        key: _selectedIndex == 0 ? UniqueKey() : const ValueKey('chauffeur'),
        // N'affiche le bouton switch que si boitier aussi disponible
        onSwitchCar: canSwitch ? _switchToCar : () {},
        canSwitch: canSwitch,   // ← AJOUTER (une seule ligne)

      );
    } else if (_hasCam) {
      // Seulement cam → toujours chauffeur
      homePage = DashboardChauffeur(
        key: const ValueKey('chauffeur_only'),
        onSwitchCar: () {}, // callback vide, pas de boitier
      );
    } else {
      // Seulement boitier → toujours voiture
      homePage = Dashboard(
        key: const ValueKey('car_only'),
        onSwitchProfile: () {}, // callback vide, pas de cam
      );
    }

    bool shouldShowGlobalMenu = _selectedIndex != 0 || _showCarDashboard;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              homePage,
              NearestMechanicsPage(
                key: _selectedIndex == 1
                    ? UniqueKey()
                    : const ValueKey('carte'),
                onBackToDashboard: () => _onItemTapped(0),
              ),
              AgendaPage(
                key: _selectedIndex == 2
                    ? UniqueKey()
                    : const ValueKey('agenda'),
                onBackToDashboard: () => _onItemTapped(0),
              ),
              TakhiChatApp(
                key: _selectedIndex == 3
                    ? UniqueKey()
                    : const ValueKey('aura'),
                onBackToHome: () => _onItemTapped(0),
                driverId: _currentCin,
              ),
              ProfilePage(
                key: _selectedIndex == 4
                    ? UniqueKey()
                    : const ValueKey('profile'),
                onBackToDashboard: () => _onItemTapped(0),
              ),
            ],
          ),
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