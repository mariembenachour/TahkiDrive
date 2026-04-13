/*import 'package:flutter/material.dart';
import '../DashboardCar/Dashboard.dart';

class ChooseVehiculePage extends StatelessWidget {
  final List vehicules;
  const ChooseVehiculePage({super.key, required this.vehicules});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choisir une voiture")),
      body: ListView.builder(
        itemCount: vehicules.length,
        itemBuilder: (context, index) {
          final car = vehicules[index];
          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text("${car['mark']} ${car['model']}"),
              subtitle: Text(car['matricule']),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // 👈 on envoie le véhicule sélectionné au Dashboard
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Dashboard(
                      vehicule: car, // <-- ici !
                      onSwitchProfile: () {},
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}*/