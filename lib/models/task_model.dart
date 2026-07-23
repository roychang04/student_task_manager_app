import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String userId;
  final String category;
  final DateTime createdAt;
  final String description;
  final DateTime dueDate;
  final String priority;
  final String reminder;
  final String status;
  final String title;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.createdAt,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.reminder,
    required this.status,
    required this.title,
  });

  factory TaskModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return TaskModel(
      id: document.id,
      userId: data['userId']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      description: data['description']?.toString() ?? '',
      dueDate: _dateFromFirestore(data['dueDate']),
      priority: data['priority']?.toString() ?? 'Low',
      reminder: data['reminder']?.toString() ?? 'No reminder',
      status: data['status']?.toString() ?? 'Pending',
      title: data['title']?.toString() ?? '',
    );
  }

  static DateTime _dateFromFirestore(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority,
      'reminder': reminder,
      'status': status,
      'title': title,
    };
  }


 /// Whether this task is overdue as of [now].
  ///
  /// A task already marked 'Completed' is never overdue, regardless of
  /// its due date.
  bool isOverdue(DateTime now) {
    if (status == 'Completed') {
      return false;
    }

    return now.isAfter(dueDate) || now.isAtSameMomentAs(dueDate);
  }

  /// The status that should actually be displayed to the user as of [now].
  ///
  /// This is business logic (a task whose due date has passed is
  /// "Overdue" even if its stored `status` still says 'Pending'), so it
  /// lives on the model rather than being recomputed in every screen
  /// that shows a task.
  String effectiveStatus(DateTime now) {
    if (isOverdue(now)) {
      return 'Overdue';
    }

    return status;
  }
}
