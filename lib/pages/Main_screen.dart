import 'package:flutter/material.dart';
import '../menus/menu.dart';
import 'Agenda.dart';
import 'Carte.dart';
import 'ChatPage.dart';
import 'Dashboard.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Dashboard(),
    NearestMechanicsPage(),
    AgendaPage(),
    AuraApp()

  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // 👇 Pages persistantes
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),

          // 👇 Ton Menu global ici
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
