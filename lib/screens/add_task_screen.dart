import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? selectedCategory;
  String selectedPriority = 'Low';
  String selectedReminder = 'No reminder';
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final List<String> categories = [
    'Assignment',
    'Quiz',
    'Project',
    'Homework',
    'Exam',
  ];

  final List<String> reminders = [
    'No reminder',
    '10 minutes before',
    '1 hour before',
    '1 day before',
  ];

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      selectedDate = pickedDate;
      selectedTime = pickedTime;
    });
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty ||
        selectedCategory == null ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    final selectedDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task date and time cannot be before current time'),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('tasks').add({
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': selectedCategory,
      'priority': selectedPriority,
      'dueDate': Timestamp.fromDate(selectedDateTime),
      'reminder': selectedReminder,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return months[month - 1];
  }

  String _displayDateTime() {
    if (selectedDate == null || selectedTime == null) {
      return 'Select date and time';
    }

    return '${selectedDate!.day} ${_monthName(selectedDate!.month)} ${selectedDate!.year}, ${selectedTime!.format(context)}';
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _priorityButton(String text, Color color) {
    final isSelected = selectedPriority == text;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPriority = text;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.18) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 9, color: color),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7FB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Add Task',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputLabel('Title'),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration('Enter task title'),
            ),

            const SizedBox(height: 16),

            _inputLabel('Description'),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDecoration('Enter task description'),
            ),

            const SizedBox(height: 16),

            _inputLabel('Category / Subject'),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              hint: const Text('Select category'),
              decoration: _inputDecoration(''),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 16),

            _inputLabel('Priority'),
            Row(
              children: [
                _priorityButton('Low', Colors.green),
                _priorityButton('Medium', Colors.orange),
                _priorityButton('High', Colors.red),
              ],
            ),

            const SizedBox(height: 16),

            _inputLabel('Due Date & Time'),
            GestureDetector(
              onTap: _pickDateTime,
              child: AbsorbPointer(
                child: TextField(
                  decoration: _inputDecoration(_displayDateTime()).copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _inputLabel('Remind me'),
            DropdownButtonFormField<String>(
              value: selectedReminder,
              decoration: _inputDecoration(''),
              items: reminders.map((reminder) {
                return DropdownMenuItem(
                  value: reminder,
                  child: Text(reminder),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedReminder = value!;
                });
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save Task',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}