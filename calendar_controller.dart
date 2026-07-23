import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;

import '../models/task_model.dart';
import '../services/auth_service.dart';

/// Controller for the Calendar feature.
///
/// This is the "C" in MVC for the calendar screen: it owns the screen's
/// state (which day is selected/focused) and all of the business logic
/// (fetching tasks, filtering them by day, formatting the day label).
/// The View (`CalendarPage`) should not talk to Firestore or do any date
/// math itself — it only reads state from here and calls methods on it
/// in response to user input.
///
/// Extends [ChangeNotifier] so the View can rebuild itself with a
/// [ListenableBuilder]/[AnimatedBuilder] whenever the selected day changes.
class CalendarController extends ChangeNotifier {
  CalendarController({DateTime? initialDay, AuthService? authService})
      : selectedDay = initialDay ?? DateTime.now(),
        focusedDay = initialDay ?? DateTime.now(),
        _authService = authService ?? AuthService();

  final AuthService _authService;

  /// The day currently selected on the calendar (drives the task list).
  DateTime selectedDay;

  /// The month/page the calendar widget is currently showing.
  DateTime focusedDay;

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

  /// A live stream of the current user's tasks, mapped from raw Firestore
  /// documents into [TaskModel]s. The View subscribes to this via a
  /// `StreamBuilder`.
  ///
  /// Scoped to `userId` so it matches `home_screen.dart` and
  /// `task_list_screen.dart` — without this filter, the calendar would show
  /// every user's tasks instead of just the signed-in user's.
  Stream<List<TaskModel>> watchTasks() {
    final userId = _authService.currentUserId;

    if (userId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TaskModel.fromFirestore).toList());
  }

  /// Human-readable label for [selectedDay], e.g. "28 May 2025".
  String get formattedSelectedDay {
    return '${selectedDay.day} '
        '${_months[selectedDay.month - 1]} '
        '${selectedDay.year}';
  }

  /// Returns the subset of [tasks] due on [day], sorted by due time.
  List<TaskModel> tasksForDay(List<TaskModel> tasks, DateTime day) {
    final tasksOnDay =
        tasks.where((task) => isSameDay(task.dueDate, day)).toList();

    tasksOnDay.sort((first, second) => first.dueDate.compareTo(second.dueDate));

    return tasksOnDay;
  }

  /// Convenience wrapper around [tasksForDay] for whichever day is
  /// currently selected.
  List<TaskModel> tasksForSelectedDay(List<TaskModel> tasks) {
    return tasksForDay(tasks, selectedDay);
  }

  /// Called when the user taps a date on the calendar.
  void selectDay(DateTime selected, DateTime focused) {
    selectedDay = selected;
    focusedDay = focused;
    notifyListeners();
  }

  /// Called when the user swipes to a different month.
  ///
  /// Deliberately does NOT call [notifyListeners]: `TableCalendar` already
  /// repaints itself when its `focusedDay` changes on a page swipe, so
  /// notifying here would just trigger a redundant rebuild of the whole
  /// screen (including the task list, which hasn't changed).
  void changeFocusedDay(DateTime focused) {
    focusedDay = focused;
  }
}
