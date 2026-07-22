import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AddTaskController {
  final FirebaseFirestore _firestore;

  AddTaskController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> get categoriesStream {
    return _firestore
        .collection('categories')
        .orderBy('createdAt')
        .snapshots();
  }

  String? validate({
    required String title,
    required String description,
    required String? category,
    required DateTime? dueDateTime,
  }) {
    if (title.trim().isEmpty) {
      return 'Please enter a task title.';
    }
    if (description.trim().isEmpty) {
      return 'Please enter a task description.';
    }
    if (category == null || category.trim().isEmpty) {
      return 'Please select a category.';
    }
    if (dueDateTime == null) {
      return 'Please select a due date and time.';
    }
    if (dueDateTime.isBefore(DateTime.now())) {
      return 'Task date and time cannot be before current time';
    }
    return null;
  }

  Future<void> saveTask({
    required String title,
    required String description,
    required String category,
    required String priority,
    required DateTime dueDateTime,
    required String reminder,
  }) async {
    await _firestore.collection('tasks').add({
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority,
      'dueDate': Timestamp.fromDate(dueDateTime),
      'reminder': reminder,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final AddTaskController _controller = AddTaskController();

  String? selectedCategory;
  String selectedPriority = 'Low';
  String selectedReminder = 'No reminder';

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  bool _isSaving = false;

  final List<String> reminders = [
    'No reminder',
    '10 minutes before',
    '1 hour before',
    '1 day before',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    if (_isSaving) return;

    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      selectedDate = pickedDate;
      selectedTime = pickedTime;
    });
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;

    final DateTime? selectedDateTime =
        selectedDate == null || selectedTime == null
            ? null
            : DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );

    final String? validationMessage = _controller.validate(
      title: _titleController.text,
      description: _descriptionController.text,
      category: selectedCategory,
      dueDateTime: selectedDateTime,
    );

    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationMessage)),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _controller.saveTask(
        title: _titleController.text,
        description: _descriptionController.text,
        category: selectedCategory!,
        priority: selectedPriority,
        dueDateTime: selectedDateTime!,
        reminder: selectedReminder,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to save task'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save task. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _monthName(int month) {
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

  String _displayDateTime() {
    if (selectedDate == null || selectedTime == null) {
      return 'Select date and time';
    }

    return '${selectedDate!.day} '
        '${_monthName(selectedDate!.month)} '
        '${selectedDate!.year}, '
        '${selectedTime!.format(context)}';
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

  Widget _priorityButton(
    String text,
    Color color,
  ) {
    final isSelected = selectedPriority == text;

    return Expanded(
      child: GestureDetector(
        onTap: _isSaving
            ? null
            : () {
                setState(() {
                  selectedPriority = text;
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.18)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.circle,
                size: 9,
                color: color,
              ),
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
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: const Color(0xffF6F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xffF6F7FB),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Add Task',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.black,
            ),
            onPressed: _isSaving
                ? null
                : () {
                    Navigator.pop(context);
                  },
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
                enabled: !_isSaving,
                decoration: _inputDecoration(
                  'Enter task title',
                ),
              ),

              const SizedBox(height: 16),

              _inputLabel('Description'),
              TextField(
                controller: _descriptionController,
                enabled: !_isSaving,
                maxLines: 4,
                decoration: _inputDecoration(
                  'Enter task description',
                ),
              ),

              const SizedBox(height: 16),

              _inputLabel('Category / Subject'),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _controller.categoriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Unable to load categories.',
                      style: TextStyle(color: Colors.red),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  final List<String> categoryNames =
                      snapshot.data?.docs
                              .map(
                                (document) =>
                                    document.data()['name']?.toString().trim() ??
                                    '',
                              )
                              .where((name) => name.isNotEmpty)
                              .toList() ??
                          [];

                  final String? validSelectedCategory =
                      categoryNames.contains(selectedCategory)
                          ? selectedCategory
                          : null;

                  return DropdownButtonFormField<String>(
                    initialValue: validSelectedCategory,
                    hint: Text(
                      categoryNames.isEmpty
                          ? 'No categories available'
                          : 'Select category',
                    ),
                    decoration: _inputDecoration(''),
                    items: categoryNames.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: _isSaving || categoryNames.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                  );
                },
              ),

              const SizedBox(height: 16),

              _inputLabel('Priority'),
              Row(
                children: [
                  _priorityButton(
                    'Low',
                    Colors.green,
                  ),
                  _priorityButton(
                    'Medium',
                    Colors.orange,
                  ),
                  _priorityButton(
                    'High',
                    Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _inputLabel('Due Date & Time'),
              GestureDetector(
                onTap: _isSaving ? null : _pickDateTime,
                child: AbsorbPointer(
                  child: TextField(
                    decoration: _inputDecoration(
                      _displayDateTime(),
                    ).copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_today,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _inputLabel('Remind me'),
              DropdownButtonFormField<String>(
                initialValue: selectedReminder,
                decoration: _inputDecoration(''),
                items: reminders.map((reminder) {
                  return DropdownMenuItem(
                    value: reminder,
                    child: Text(reminder),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          selectedReminder = value;
                        });
                      },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xffA5A1F5),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Task',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hintText,
  ) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
    );
  }
}