import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/Accueil.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TahkiDrive App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const MainScreen(),
    );
  }
}