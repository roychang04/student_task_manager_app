import 'package:flutter/material.dart';
import 'package:student_task_manager_app/models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;

  const TaskCard({
    super.key,
    required this.task,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color get _statusColor {
    switch (task.status) {
      case 'Completed':
        return Colors.green;
      case 'Overdue':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get _formattedTime {
    final hour = task.dueDate.hour;
    final minute = task.dueDate.minute;

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minuteText = minute.toString().padLeft(2, '0');

    return '$hour12:$minuteText $period';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: _priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    task.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '${task.priority} Priority',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _priorityColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.status,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}