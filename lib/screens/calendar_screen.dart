import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/calendar_controller.dart';
import '../models/task_model.dart';
import 'task_card.dart';

/// The Calendar tab: a month view on top, and the list of tasks due on
/// whichever day is selected below it.
///
/// This widget is intentionally "dumb" — it holds a [CalendarController]
/// and renders whatever state that controller reports. All Firestore
/// access, day-filtering, and date formatting live in the controller
/// (see `lib/controllers/calendar_controller.dart`); this file is only
/// concerned with layout and styling.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarController _controller = CalendarController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<TaskModel>>(
        stream: _controller.watchTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load tasks: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data ?? const <TaskModel>[];

          // Rebuild just this subtree (not the Firestore subscription
          // above) whenever the user taps a different day.
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _MonthCalendar(controller: _controller, tasks: tasks),
                    const SizedBox(height: 20),
                    _SelectedDayHeader(controller: _controller),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _TaskListForSelectedDay(
                        tasks: _controller.tasksForSelectedDay(tasks),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The month grid itself. Purely presentational — every callback just
/// forwards the event straight to the controller.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.controller, required this.tasks});

  final CalendarController controller;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return TableCalendar<TaskModel>(
      firstDay: DateTime(2024),
      lastDay: DateTime(2035),
      focusedDay: controller.focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, controller.selectedDay),
      onDaySelected: controller.selectDay,
      onPageChanged: controller.changeFocusedDay,
      eventLoader: (day) => controller.tasksForDay(tasks, day),
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
    );
  }
}

/// "Tasks for 28 May 2025" label above the task list.
class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Tasks for ${controller.formattedSelectedDay}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// The list of tasks due on the selected day, or an empty-state message.
class _TaskListForSelectedDay extends StatelessWidget {
  const _TaskListForSelectedDay({required this.tasks});

  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks for this day',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) => TaskCard(task: tasks[index]),
    );
  }
}