import 'package:flutter/material.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class Menu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const Menu({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu>
    with TickerProviderStateMixin {

  final List<String> menuItems = [
    'Accueil',
    'Carte',
    'Agenda',
    'AI',
    'Profil',
  ];

  final List<IconData> menuIcons = [
    Icons.home,
    Icons.map,
    Icons.calendar_today,
    Icons.smart_toy,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(35.r),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(menuItems.length, (index) {
          final isSelected = widget.selectedIndex == index;

          return GestureDetector(
            onTap: () => widget.onItemTapped(index),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurple.shade300.withOpacity(0.6)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      menuIcons[index],
                      color: isSelected ? Colors.white : Colors.black54,
                      size: 24.w,
                    ),

                    /// 🔥 Texte visible uniquement si sélectionné
                    if (isSelected) ...[
                      SizedBox(width: 8.w),
                      Text(
                        menuItems[index],
                        style:  TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
