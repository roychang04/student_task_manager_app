import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final CollectionReference<Map<String, dynamic>>
    _categoryCollection =
    FirebaseFirestore.instance.collection('categories');

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  String? selectedCategory;
  String selectedPriority = 'Low';
  String selectedReminder = 'No reminder';

  DateTime selectedDateTime = DateTime.now();

  bool _isUpdating = false;

  // Must match AddTaskScreen exactly.
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

    final dynamic dueDate = widget.taskData['dueDate'];

    if (dueDate is Timestamp) {
      selectedDateTime = dueDate.toDate();
    } else if (dueDate is DateTime) {
      selectedDateTime = dueDate;
    } else if (dueDate is String) {
      selectedDateTime =
          DateTime.tryParse(dueDate) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
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

  String _formatDateTime(DateTime date) {
    final int displayHour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final String minute =
        date.minute.toString().padLeft(2, '0');

    final String period =
        date.hour >= 12 ? 'PM' : 'AM';

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
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        selectedDateTime,
      ),
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
    });
  }

  Future<void> _updateTask() async {
    if (_isUpdating) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category.'),
        ),
      );

      return;
    }

    if (selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Task date and time cannot be before the current time.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
        'title': titleController.text.trim(),
        'description':
            descriptionController.text.trim(),
        'category': selectedCategory,
        'priority': selectedPriority,
        'reminder': selectedReminder,
        'dueDate': Timestamp.fromDate(
          selectedDateTime,
        ),
        'status': 'Pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Task updated successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Unable to update the task.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update the task.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Widget _priorityButton(String priority) {
    final bool isSelected =
        selectedPriority == priority;

    final Color color =
        _priorityColor(priority);

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
                : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color,
            ),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color:
                  isSelected ? Colors.white : color,
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
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
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
          iconTheme: const IconThemeData(
            color: Colors.black,
          ),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Title',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleController,
                  enabled: !_isUpdating,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter a task title.';
                    }

                    return null;
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  enabled: !_isUpdating,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter a task description.';
                    }

                    return null;
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Category / Subject',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoryCollection
                      .orderBy('createdAt')
                      .snapshots(),
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

                    final String? currentCategory =
                        selectedCategory;

                    /*
                    * Older tasks may still contain hardcoded category
                    * values such as Quiz or Assignment. I included the saved
                    * value temporarily so the edit screen can display it.
                    */
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
                      value: validSelectedCategory,
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
                      onChanged: _isUpdating || categoryNames.isEmpty
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap:
                      _isUpdating ? null : _pickDateTime,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: TextEditingController(
                        text: _formatDateTime(
                          selectedDateTime,
                        ),
                      ),
                      decoration:
                          _inputDecoration().copyWith(
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value:
                      reminders.contains(selectedReminder)
                          ? selectedReminder
                          : 'No reminder',
                  decoration: _inputDecoration(),
                  items: reminders
                      .toSet()
                      .map(
                        (reminder) =>
                            DropdownMenuItem<String>(
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
                      disabledForegroundColor:
                          Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
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