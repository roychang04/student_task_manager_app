import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_task_manager_app/models/task_model.dart';
import 'package:table_calendar/table_calendar.dart';

import 'task_card.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String get _formattedSelectedDay {
    return '${selectedDay.day} '
        '${_months[selectedDay.month - 1]} '
        '${selectedDay.year}';
  }

  List<TaskModel> _tasksForDay(
    List<TaskModel> tasks,
    DateTime day,
  ) {
    final selectedTasks = tasks
        .where((task) => isSameDay(task.dueDate, day))
        .toList();

    selectedTasks.sort(
      (firstTask, secondTask) {
        return firstTask.dueDate.compareTo(secondTask.dueDate);
      },
    );

    return selectedTasks;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseAuth.instance.currentUser == null
            ? const Stream.empty()
            : FirebaseFirestore.instance
                .collection('tasks')
                .where(
                  'userId',
                  isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                )
                .orderBy('dueDate')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load tasks: ${snapshot.error}',
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final tasks = snapshot.data!.docs
              .map(TaskModel.fromFirestore)
              .toList();

          final tasksForSelectedDay = _tasksForDay(
            tasks,
            selectedDay,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TableCalendar<TaskModel>(
                  firstDay: DateTime(2024),
                  lastDay: DateTime(2035),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) {
                    return isSameDay(day, selectedDay);
                  },
                  onDaySelected: (selected, focused) {
                    setState(() {
                      selectedDay = selected;
                      focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    focusedDay = focused;
                  },
                  eventLoader: (day) {
                    return _tasksForDay(tasks, day);
                  },
                  headerStyle: const HeaderStyle(
  titleCentered: true,
  formatButtonVisible: false,
  titleTextStyle: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  ),
),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.deepPurple.shade200,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tasks for $_formattedSelectedDay',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: tasksForSelectedDay.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks for this day',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tasksForSelectedDay.length,
                          itemBuilder: (context, index) {
                            return TaskCard(
                              task: tasksForSelectedDay[index],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}