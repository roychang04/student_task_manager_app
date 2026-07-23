import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const StudentBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF4B4EF7);
  static const Color inactiveColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
              .collection('userdata')
              .doc(user.uid)
              .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data();

        final bool notificationsEnabled =
            userData?['notificationsEnabled'] as bool? ?? true;

        return StreamBuilder<QuerySnapshot>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                  .collection('tasks')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
          builder: (context, snapshot) {
            int reminderCount = 0;

            if (snapshot.hasData) {
              reminderCount = _calculateReminderCount(
                snapshot.data!.docs,
                notificationsEnabled: notificationsEnabled,
              );
            }

            return Container(
              height: 70,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
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
                    notificationCount: reminderCount,
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
          },
        );
      },
    );
  }

  int _calculateReminderCount(
    List<QueryDocumentSnapshot> documents, {
    required bool notificationsEnabled,
    }
  ) {
    if (!notificationsEnabled) {
      return 0;
    }
    
    int count = 0;
    final DateTime now = DateTime.now();

    for (final document in documents) {
      final data = document.data() as Map<String, dynamic>;

      final String status =
          data['status']?.toString().trim().toLowerCase() ??
              'pending';

      final String reminder =
          data['reminder']?.toString().trim().toLowerCase() ??
              'no reminder';

      // Do not count completed tasks.
      if (status == 'completed') {
        continue;
      }

      // Do not count tasks without reminders.
      if (reminder.isEmpty || reminder == 'no reminder') {
        continue;
      }

      final dynamic dueDateValue = data['dueDate'];

      final DateTime? dueDate = _convertToDateTime(
        dueDateValue,
      );

      if (dueDate == null) {
        continue;
      }

      final DateTime? reminderTime = _getReminderTime(
        dueDate: dueDate,
        reminder: reminder,
      );

      if (reminderTime == null) {
        continue;
      }

      /*
       Count the reminder only when:
       1. The reminder time has arrived.
       2. The task due time has not passed.
       3. The task is not completed.
      */
      final bool reminderHasStarted =
    now.isAtSameMomentAs(reminderTime) ||
        now.isAfter(reminderTime);

if (reminderHasStarted) {
  count++;
}
    }

    return count;
  }

  DateTime? _convertToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  DateTime? _getReminderTime({
    required DateTime dueDate,
    required String reminder,
  }) {
    switch (reminder) {
      case '10 minutes before':
        return dueDate.subtract(
          const Duration(minutes: 10),
        );

      case '1 hour before':
        return dueDate.subtract(
          const Duration(hours: 1),
        );

      case '1 day before':
        return dueDate.subtract(
          const Duration(days: 1),
        );

      default:
        return null;
    }
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    int notificationCount = 0,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? primaryColor
                      : inactiveColor,
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: -13,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        notificationCount > 99
                            ? '99+'
                            : notificationCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isSelected
                    ? primaryColor
                    : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}