import 'package:flutter/material.dart';

class StudentBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const StudentBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF4B4EF7);
  static const Color inactiveColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            icon: Icons.home_rounded,
            label: 'Home',
            index: 0,
          ),
          _navItem(
            icon: Icons.task_alt_rounded,
            label: 'Tasks',
            index: 1,
          ),
          _navItem(
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            index: 2,
          ),
          _navItem(
            icon: Icons.category_rounded,
            label: 'Categories',
            index: 3,
          ),
          _navItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            index: 4,
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool isSelected = currentIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? primaryColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primaryColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}