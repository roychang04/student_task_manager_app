import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'edit_task_screen.dart';

class TaskDetailController {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskDetailController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  DateTime? convertDueDate(dynamic value) {
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

  bool canChangeBackToPending(dynamic dueDate) {
    final DateTime? convertedDate = convertDueDate(dueDate);

    return convertedDate != null &&
        convertedDate.isAfter(DateTime.now());
  }

  Future<DocumentReference<Map<String, dynamic>>>
      _ownedTaskReference(String taskId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please log in to manage tasks.',
      );
    }

    final reference = _firestore.collection('tasks').doc(taskId);
    final snapshot = await reference.get();

    if (!snapshot.exists || snapshot.data()?['userId'] != user.uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'You can only manage your own tasks.',
      );
    }

    return reference;
  }

  Future<void> markTaskAsCompleted(String taskId) async {
    final reference = await _ownedTaskReference(taskId);
    await reference.update({
      'status': 'Completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> changeTaskBackToPending(String taskId) async {
    final reference = await _ownedTaskReference(taskId);
    await reference.update({
      'status': 'Pending',
      'completedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String taskId) async {
    final reference = await _ownedTaskReference(taskId);
    await reference.delete();
  }
}

class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  Color statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Overdue':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return months[month - 1];
  }

  String formatDate(dynamic dueDate) {
    final TaskDetailController controller = TaskDetailController();
    final DateTime? date = controller.convertDueDate(dueDate);

    if (date == null) {
      return 'No due date';
    }

    final int displayHour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${monthName(date.month)} ${date.year}, '
        '$displayHour:$minute $period';
  }

  void _showError(
    BuildContext context,
    Object error,
    String fallbackMessage,
  ) {
    final String message = error is FirebaseException
        ? error.message ?? fallbackMessage
        : fallbackMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markTaskAsCompleted(
    BuildContext context,
    TaskDetailController controller,
  ) async {
    try {
      await controller.markTaskAsCompleted(taskId);

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (context.mounted) {
        _showError(
          context,
          error,
          'Unable to mark the task as completed.',
        );
      }
    }
  }

  Future<void> _changeTaskBackToPending(
    BuildContext context,
    TaskDetailController controller,
  ) async {
    if (!controller.canChangeBackToPending(taskData['dueDate'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This task cannot be changed to pending because '
            'its due date and time have passed.',
          ),
        ),
      );
      return;
    }

    final bool? shouldChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Status'),
          content: const Text(
            'Change this completed task back to pending?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Change to Pending'),
            ),
          ],
        );
      },
    );

    if (shouldChange != true) {
      return;
    }

    try {
      await controller.changeTaskBackToPending(taskId);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task status changed to pending.'),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        _showError(
          context,
          error,
          'Unable to change the task status.',
        );
      }
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    TaskDetailController controller,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text(
            'Are you sure you want to delete this task?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await controller.deleteTask(taskId);

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (context.mounted) {
        _showError(
          context,
          error,
          'Unable to delete the task.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TaskDetailController controller = TaskDetailController();

    final String title = taskData['title']?.toString() ?? '';
    final String description =
        taskData['description']?.toString() ?? '';
    final String category =
        taskData['category']?.toString() ?? '';
    final String priority =
        taskData['priority']?.toString() ?? 'Low';
    final String status =
        taskData['status']?.toString() ?? 'Pending';
    final String reminder =
        taskData['reminder']?.toString() ?? 'No reminder';
    final String dueDate = formatDate(taskData['dueDate']);

    final bool isCompleted =
        status.trim().toLowerCase() == 'completed';

    final bool canChangeBackToPending =
        controller.canChangeBackToPending(taskData['dueDate']);

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Task Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor(status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xffEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: const TextStyle(
                  color: Color(0xff4F46E5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            detailRow(Icons.calendar_today, 'Due Date', dueDate),
            const SizedBox(height: 18),
            detailRow(
              Icons.flag,
              'Priority',
              priority,
              valueColor: priorityColor(priority),
            ),
            const SizedBox(height: 18),
            detailRow(Icons.category, 'Category', category),
            const SizedBox(height: 18),
            detailRow(
              Icons.notifications_outlined,
              'Reminder',
              reminder,
            ),
            const SizedBox(height: 18),
            detailRow(
              Icons.check_circle_outline,
              'Status',
              status,
              valueColor: statusColor(status),
            ),
            const SizedBox(height: 40),
            if (!isCompleted)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _markTaskAsCompleted(context, controller);
                  },
                ),
              ),
            if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Task Completed',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: canChangeBackToPending
                      ? () {
                          _changeTaskBackToPending(
                            context,
                            controller,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.undo),
                  label: Text(
                    canChangeBackToPending
                        ? 'Change Status to Pending'
                        : 'Due Date Has Passed',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    disabledForegroundColor: Colors.grey,
                    side: BorderSide(
                      color: canChangeBackToPending
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 15),
            Row(
              children: [
                if (!isCompleted)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditTaskScreen(
                              taskId: taskId,
                              taskData: taskData,
                            ),
                          ),
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      child: const Text('Edit Task'),
                    ),
                  ),
                if (!isCompleted) const SizedBox(width: 15),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _deleteTask(context, controller);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Delete Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
