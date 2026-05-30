import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class GlobalNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final bool canSwitch;
  final VoidCallback? onLogout;

  const GlobalNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.canSwitch = false,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final Color blueDark = const Color(0xFF21277B);

    // Si rien à afficher → widget invisible
    if (!canSwitch && onLogout == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: blueDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          if (canSwitch) ...[
            _buildItem(0, Icons.directions_car_filled_rounded, "Voiture"),
            SizedBox(width: 4.w),
            _buildItem(1, Icons.person_rounded, "Profil"),
          ],

          if (onLogout != null) ...[
            if (canSwitch) SizedBox(width: 4.w),
            GestureDetector(
              onTap: onLogout,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child:  Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8.w),
                    Text(
                      "Déconnexion",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF21277B) : Colors.white,
              size: 20.w,
            ),
            if (isSelected) ...[
              SizedBox(width: 8.w),
              Text(
                label,
                style:  TextStyle(
                  color: Color(0xFF21277B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
