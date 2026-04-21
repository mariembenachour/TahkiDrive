import 'dart:ui';
import 'package:flutter/material.dart';

class GlobalNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const GlobalNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected
  });

  @override
  Widget build(BuildContext context) {
    // Couleur bleu sombre de ta palette
    final Color blueDark = const Color(0xFF21277B);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: blueDark.withOpacity(0.4), // Garde la transparence mais sans flou
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row( // Supprimé ClipRRect et BackdropFilter
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(0, Icons.directions_car_filled_rounded, "Voiture"),
          const SizedBox(width: 4),
          _buildItem(1, Icons.person_rounded, "Profil"),
        ],
      ),
    );
  }

  Widget _buildItem(int index, IconData icon, String label) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
                icon,
                color: isSelected ? const Color(0xFF21277B) : Colors.white,
                size: 20
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                  label,
                  style: const TextStyle(
                      color: Color(0xFF21277B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13
                  )
              ),
            ],
          ],
        ),
      ),
    );
  }
}