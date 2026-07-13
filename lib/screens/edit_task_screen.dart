import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// This screen allows the user to edit an existing task.
// The task information is received from the Task Detail Screen.
class EditTaskScreen extends StatefulWidget {
  // Firestore document ID of the selected task.
  final String taskId;

  // Stores all task information passed from the previous screen.
  final Map<String, dynamic> taskData;

  const EditTaskScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {

  // Used to validate the form before updating the task.
  final _formKey = GlobalKey<FormState>();

  // Controllers for the text input fields.
  late TextEditingController titleController;
  late TextEditingController descriptionController;

  // Variables used to store the selected values.
  String selectedCategory = "";
  String selectedPriority = "Low";
  String reminder = "1 day before";

  // Stores the selected due date.
  DateTime selectedDate = DateTime.now();

  // Available categories shown in the dropdown menu.
  final List<String> categories = [
    "Mobile App Development",
    "Database",
    "Programming",
    "Assignment",
    "Quiz",
    "Other"
  ];

  // Available reminder options.
  final List<String> reminders = [
    "None",
    "1 day before",
    "2 days before",
    "1 week before"
  ];

  @override
  void initState() {
    super.initState();

    // Load the existing task data into the input fields.
    titleController =
        TextEditingController(text: widget.taskData['title']);

    descriptionController =
        TextEditingController(text: widget.taskData['description']);

    selectedCategory =
        widget.taskData['category'] ?? categories.first;

    selectedPriority =
        widget.taskData['priority'] ?? "Low";

    // Convert the Firestore Timestamp into a DateTime object.
    final dueDate = widget.taskData['dueDate'];

    if (dueDate is Timestamp) {
      selectedDate = dueDate.toDate();
    }
  }

  @override
  void dispose() {
    // Release the controllers when the screen is closed.
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // Converts a DateTime object into a readable format.
  // Example: 28 May 2025
  String formatDate(DateTime date) {
    const months = [
      '',
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
      'Dec'
    ];

    return "${date.day} ${months[date.month]} ${date.year}";
  }

  // Returns a different colour based on the selected priority.
  Color priorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red;

      case "Medium":
        return Colors.orange;

      default:
        return Colors.green;
    }
  }

  // Opens the calendar so the user can choose a due date.
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    // Update the selected date after the user chooses one.
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // Updates the task information in Firestore.
  Future<void> updateTask() async {

    // Stop the update if any required field is empty.
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance
        .collection("tasks")
        .doc(widget.taskId)
        .update({

      "title": titleController.text.trim(),
      "description": descriptionController.text.trim(),
      "category": selectedCategory,
      "priority": selectedPriority,
      "dueDate": Timestamp.fromDate(selectedDate),

    });

    if (!mounted) return;

    // Display a success message after updating.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Task updated successfully"),
      ),
    );

    // Return to the previous screen.
    Navigator.pop(context);
  }

  // Builds one of the priority selection buttons.
  Widget priorityButton(String priority) {

    bool selected = selectedPriority == priority;

    return Expanded(
      child: GestureDetector(
        onTap: () {

          // Change the selected priority.
          setState(() {
            selectedPriority = priority;
          });

        },
        child: Container(
          height: 45,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? priorityColor(priority)
                : priorityColor(priority).withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: priorityColor(priority),
            ),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : priorityColor(priority),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),

     
      // App Bar
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Edit Task",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              
              // Title Field
              const Text("Title"),

              const SizedBox(height: 8),

              TextFormField(
                controller: titleController,

                // Ensure the title is not empty.
                validator: (value) =>
                    value!.isEmpty ? "Required" : null,

                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              
              // Description Field
              const Text("Description"),

              const SizedBox(height: 8),

              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 18),

             
              // Category Dropdown
              const Text("Category / Subject"),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: categories
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (value) {

                  // Update the selected category.
                  setState(() {
                    selectedCategory = value!;
                  });

                },
              ),

              const SizedBox(height: 18),

              
              // Priority Buttons
              const Text("Priority"),

              const SizedBox(height: 10),

              Row(
                children: [
                  priorityButton("Low"),
                  const SizedBox(width: 10),
                  priorityButton("Medium"),
                  const SizedBox(width: 10),
                  priorityButton("High"),
                ],
              ),

              const SizedBox(height: 20),

              
              // Due Date Picker
              const Text("Due Date"),

              const SizedBox(height: 8),

              TextFormField(
                readOnly: true,
                controller: TextEditingController(
                  text: formatDate(selectedDate),
                ),
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Open the date picker when tapped.
                onTap: pickDate,
              ),

              const SizedBox(height: 20),

              
              // Reminder Dropdown
              const Text("Remind Me"),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: reminder,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: reminders
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: (value) {

                  // Update the selected reminder.
                  setState(() {
                    reminder = value!;
                  });

                },
              ),

              const SizedBox(height: 35),

            
              // Update Task Button
              // Saves the edited task to Firestore.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: updateTask,
                  child: const Text(
                    "Update Task",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}