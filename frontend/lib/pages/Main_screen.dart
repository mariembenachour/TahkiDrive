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
  bool _showCarDashboard = true;
  String _currentCin = '';

  @override
  void initState() {
    super.initState();
    _loadCin();
  }

  Future<void> _loadCin() async {
    final cin = await AuthService.getCin();
    if (cin != null && cin.isNotEmpty) {
      setState(() => _currentCin = cin);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    bool shouldShowGlobalMenu = _selectedIndex != 0 || _showCarDashboard;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _showCarDashboard
                  ? Dashboard(
                key: _selectedIndex == 0 && _showCarDashboard
                    ? UniqueKey()
                    : const ValueKey('db'),
                onSwitchProfile: () =>
                    setState(() => _showCarDashboard = false),
              )
                  : DashboardChauffeur(
                key: _selectedIndex == 0 && !_showCarDashboard
                    ? UniqueKey()
                    : const ValueKey('chauffeur'),
                onSwitchCar: () =>
                    setState(() => _showCarDashboard = true),
              ),
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
