import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditTaskController {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EditTaskController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> get categoriesStream {
    return _firestore
        .collection('categories')
        .orderBy('createdAt')
        .snapshots();
  }

  DateTime convertDueDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  String? validate({
    required String title,
    required String description,
    required String? category,
    required DateTime dueDateTime,
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

    if (dueDateTime.isBefore(DateTime.now())) {
      return 'Task date and time cannot be before the current time.';
    }

    return null;
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    required String description,
    required String category,
    required String priority,
    required String reminder,
    required DateTime dueDateTime,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please log in before updating a task.',
      );
    }

    final reference = _firestore.collection('tasks').doc(taskId);
    final snapshot = await reference.get();

    if (!snapshot.exists || snapshot.data()?['userId'] != user.uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'You can only update your own tasks.',
      );
    }

    await reference.update({
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority,
      'reminder': reminder,
      'dueDate': Timestamp.fromDate(dueDateTime),
      'status': 'Pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class EditTaskScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const EditTaskScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  @override
  State<EditTaskScreen> createState() =>
      _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final EditTaskController _controller = EditTaskController();

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController dueDateController;

  String? selectedCategory;
  String selectedPriority = 'Low';
  String selectedReminder = 'No reminder';
  DateTime selectedDateTime = DateTime.now();
  bool _isUpdating = false;

  final List<String> reminders = [
    'No reminder',
    '10 minutes before',
    '1 hour before',
    '1 day before',
  ];

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.taskData['title']?.toString() ?? '',
    );

    descriptionController = TextEditingController(
      text: widget.taskData['description']?.toString() ?? '',
    );

    final String savedCategory =
        widget.taskData['category']?.toString().trim() ?? '';

    selectedCategory =
        savedCategory.isEmpty ? null : savedCategory;

    final String savedPriority =
        widget.taskData['priority']?.toString().trim() ?? 'Low';

    selectedPriority = [
      'Low',
      'Medium',
      'High',
    ].contains(savedPriority)
        ? savedPriority
        : 'Low';

    final String savedReminder =
        widget.taskData['reminder']?.toString().trim() ??
            'No reminder';

    selectedReminder = reminders.contains(savedReminder)
        ? savedReminder
        : 'No reminder';

    selectedDateTime = _controller.convertDueDate(
      widget.taskData['dueDate'],
    );

    dueDateController = TextEditingController(
      text: _formatDateTime(selectedDateTime),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    dueDateController.dispose();
    super.dispose();
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return months[month - 1];
  }

  String _formatDateTime(DateTime date) {
    final int displayHour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${_monthName(date.month)} '
        '${date.year}, $displayHour:$minute $period';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickDateTime() async {
    if (_isUpdating) {
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime initialDate =
        selectedDateTime.isBefore(now)
            ? now
            : selectedDateTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      dueDateController.text =
          _formatDateTime(selectedDateTime);
    });
  }

  Future<void> _updateTask() async {
    if (_isUpdating) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? validationMessage = _controller.validate(
      title: titleController.text,
      description: descriptionController.text,
      category: selectedCategory,
      dueDateTime: selectedDateTime,
    );

    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await _controller.updateTask(
        taskId: widget.taskId,
        title: titleController.text,
        description: descriptionController.text,
        category: selectedCategory!,
        priority: selectedPriority,
        reminder: selectedReminder,
        dueDateTime: selectedDateTime,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Task updated successfully.');
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ?? 'Unable to update the task.',
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to update the task.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Widget _priorityButton(String priority) {
    final bool isSelected = selectedPriority == priority;
    final Color color = _priorityColor(priority);

    return Expanded(
      child: GestureDetector(
        onTap: _isUpdating
            ? null
            : () {
                setState(() {
                  selectedPriority = priority;
                });
              },
        child: Container(
          height: 45,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUpdating,
      child: Scaffold(
        backgroundColor: const Color(0xffF6F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xffF6F7FB),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            'Edit Task',
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
                const Text(
                  'Title',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleController,
                  enabled: !_isUpdating,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task title.';
                    }

                    return null;
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  enabled: !_isUpdating,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task description.';
                    }

                    return null;
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Category / Subject',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
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
                                  (document) => document
                                          .data()['name']
                                          ?.toString()
                                          .trim() ??
                                      '',
                                )
                                .where((name) => name.isNotEmpty)
                                .toList() ??
                            [];

                    final String? currentCategory =
                        selectedCategory;

                    if (currentCategory != null &&
                        currentCategory.isNotEmpty &&
                        !categoryNames.contains(currentCategory)) {
                      categoryNames.insert(0, currentCategory);
                    }

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
                      decoration: _inputDecoration(),
                      items: categoryNames.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: _isUpdating ||
                              categoryNames.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                            },
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Priority',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _priorityButton('Low'),
                    const SizedBox(width: 10),
                    _priorityButton('Medium'),
                    const SizedBox(width: 10),
                    _priorityButton('High'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Due Date & Time',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isUpdating ? null : _pickDateTime,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: dueDateController,
                      decoration: _inputDecoration().copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Remind Me',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: reminders.contains(selectedReminder)
                      ? selectedReminder
                      : 'No reminder',
                  decoration: _inputDecoration(),
                  items: reminders
                      .toSet()
                      .map(
                        (reminder) => DropdownMenuItem<String>(
                          value: reminder,
                          child: Text(reminder),
                        ),
                      )
                      .toList(),
                  onChanged: _isUpdating
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            selectedReminder = value;
                          });
                        },
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isUpdating ? null : _updateTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xff4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xffA5A1F5),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
