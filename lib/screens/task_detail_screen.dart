import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// This screen displays details of a specific task.
// Users can mark the task as completed or delete it
class TaskDetailScreen extends StatelessWidget {

  // Stores the Firestore document ID of the selected task.
  final String taskId;

  // Stores all task information passed from TaskListScreen.
  final Map<String, dynamic> taskData;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  // Provides a different colour based on status of a task
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

  // Provides a different colour based on the priority of a task
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

  // Transforms a month number into a short month name.
  // Example: 5 -> May
  String monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  // Converts Firestore Timestamp into a readable date format.
  // Example: 2025-05-28 -> 28 May 2025
  String formatDate(dynamic dueDate) {
    if (dueDate is Timestamp) {
      final date = dueDate.toDate();
      return "${date.day} ${monthName(date.month)} ${date.year}";
    }

    return dueDate.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve task information from the passed taskData.
    final title = taskData['title'] ?? '';
    final description = taskData['description'] ?? '';
    final category = taskData['category'] ?? '';
    final priority = taskData['priority'] ?? 'Low';
    final status = taskData['status'] ?? 'Pending';
    final dueDate = formatDate(taskData['dueDate']);

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),

      
      // App Bar
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Task Details",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            
            // Task Status Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor(status).withOpacity(.15),
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

            // Display task title.
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // Display task category.
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

            
            // Description Section
            const Text(
              "Description",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 10),

            
            // Task Information
            detailRow(
              Icons.calendar_today,
              "Due Date",
              dueDate,
            ),

            const SizedBox(height: 18),

            detailRow(
              Icons.flag,
              "Priority",
              priority,
            ),

            const SizedBox(height: 18),

            detailRow(
              Icons.category,
              "Category",
              category,
            ),

            const SizedBox(height: 18),

            detailRow(
              Icons.check_circle_outline,
              "Status",
              status,
            ),

            const SizedBox(height: 40),

            
            // Mark Task as Completed
            // Updates the task status in Firestore.
            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text("Mark as Completed"),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(taskId)
                      .update({
                    'status': 'Completed',
                  });

                  // Return to the previous screen.
                  Navigator.pop(context);
                },
              ),
            ),

            const SizedBox(height: 15),

            
            // Edit and Delete Buttons
            Row(
              children: [

                // Navigate to Edit Task Screen.
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO:
                      // Navigate to EditTaskScreen.
                    },

                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(
                        color: Colors.blue,
                      ),
                    ),

                    child: const Text("Edit Task"),
                  ),
                ),

                const SizedBox(width: 15),

                // Delete the task from Firestore.
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {

                      await FirebaseFirestore.instance
                          .collection('tasks')
                          .doc(taskId)
                          .delete();

                      // Return to Task List Screen.
                      Navigator.pop(context);
                    },

                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(
                        color: Colors.red,
                      ),
                    ),

                    child: const Text("Delete Task"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  
  // Reusable widget for displaying task information.
  // This reduces duplicate code and keeps the UI consistent.
  Widget detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [

        Icon(
          icon,
          color: Colors.grey[700],
        ),

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

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
