import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String selectedFilter = 'All';
  String searchQuery = '';

  final List<String> filters = [
    'All',
    'Pending',
    'Completed',
    'Overdue',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverdueTasks();
    });
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;

      case 'Overdue':
        return Colors.red;

      default:
        return Colors.orange;
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

  int? _monthNumber(String month) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    return months[month];
  }

  DateTime? _parseStringDate(String dateText) {
    try {
      final cleanedDate = dateText.trim().replaceAll(',', '');
      final parts = cleanedDate.split(RegExp(r'\s+'));

      if (parts.length < 3) {
        return null;
      }

      final day = int.parse(parts[0]);
      final month = _monthNumber(parts[1]);
      final year = int.parse(parts[2]);

      if (month == null) {
        return null;
      }

      // Old tasks that only contain a date become overdue
      // after the entire day has passed.
      if (parts.length == 3) {
        return DateTime(
          year,
          month,
          day,
          23,
          59,
          59,
        );
      }

      if (parts.length >= 5) {
        final timeParts = parts[3].split(':');

        if (timeParts.length != 2) {
          return DateTime(
            year,
            month,
            day,
            23,
            59,
            59,
          );
        }

        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final period = parts[4].toUpperCase();

        if (period == 'PM' && hour != 12) {
          hour += 12;
        }

        if (period == 'AM' && hour == 12) {
          hour = 0;
        }

        return DateTime(
          year,
          month,
          day,
          hour,
          minute,
        );
      }

      return DateTime(
        year,
        month,
        day,
        23,
        59,
        59,
      );
    } catch (error) {
      debugPrint('Unable to parse due date "$dateText": $error');
      return null;
    }
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${_monthName(date.month)} ${date.year}, '
        '$hour:$minute $period';
  }

  Future<void> _checkOverdueTasks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('status', isEqualTo: 'Pending')
          .get();

      final now = DateTime.now();
      final batch = FirebaseFirestore.instance.batch();

      bool hasUpdates = false;

      for (final document in snapshot.docs) {
        final data = document.data();
        final dueDateData = data['dueDate'];

        DateTime? dueDate;

        if (dueDateData is Timestamp) {
          dueDate = dueDateData.toDate();
        } else if (dueDateData is String) {
          dueDate = _parseStringDate(dueDateData);
        }

        if (dueDate != null && now.isAfter(dueDate)) {
          batch.update(
            document.reference,
            {
              'status': 'Overdue',
            },
          );

          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (error) {
      debugPrint('Error checking overdue tasks: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to check overdue tasks'),
        ),
      );
    }
  }

  Future<void> _openTaskDetails({
    required String taskId,
    required Map<String, dynamic> taskData,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: taskId,
          taskData: taskData,
        ),
      ),
    );

    await _checkOverdueTasks();
  }

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('tasks')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),

      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7FB),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Tasks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by title or category...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final bool isSelected = selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                      selectedColor: const Color(0xff4F46E5),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide.none,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong: ${snapshot.error}',
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final documents =
                      snapshot.data!.docs.where((document) {
                    final data = document.data();

                    final String title =
                        data['title']
                                ?.toString()
                                .toLowerCase() ??
                            '';

                    final String category =
                        data['category']
                                ?.toString()
                                .toLowerCase() ??
                            '';

                    final String status =
                        data['status']?.toString() ?? 'Pending';

                    final bool matchesStatus =
                        selectedFilter == 'All' ||
                            status == selectedFilter;

                    final bool matchesSearch =
                        searchQuery.isEmpty ||
                            title.contains(searchQuery) ||
                            category.contains(searchQuery);

                    return matchesStatus && matchesSearch;
                  }).toList();

                  if (documents.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _checkOverdueTasks,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: Text('No tasks found'),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _checkOverdueTasks,
                    child: ListView.builder(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final document = documents[index];
                        final data = document.data();

                        final String title =
                            data['title']?.toString() ?? '';

                        final String description =
                            data['description']?.toString() ?? '';

                        final String priority =
                            data['priority']?.toString() ?? 'Low';

                        final String status =
                            data['status']?.toString() ?? 'Pending';

                        String dueDate = '';

                        final dueDateData = data['dueDate'];

                        if (dueDateData is Timestamp) {
                          final date = dueDateData.toDate();
                          dueDate = _formatDateTime(date);
                        } else if (dueDateData is String) {
                          dueDate = dueDateData;
                        }

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              _openTaskDetails(
                                taskId: document.id,
                                taskData: data,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border(
                                  left: BorderSide(
                                    color:
                                        _priorityColor(priority),
                                    width: 5,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),

                                      Tooltip(
                                        message:
                                            'View task details',
                                        child: IconButton(
                                          mouseCursor:
                                              SystemMouseCursors
                                                  .click,
                                          hoverColor:
                                              const Color(
                                                  0xffEEF2FF),
                                          splashColor:
                                              const Color(
                                                  0xffC7D2FE),
                                          highlightColor:
                                              const Color(
                                                  0xffE0E7FF),
                                          visualDensity:
                                              VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color:
                                                Colors.black87,
                                          ),
                                          onPressed: () {
                                            _openTaskDetails(
                                              taskId: document.id,
                                              taskData: data,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 5),

                                  Text(
                                    description,
                                    style: TextStyle(
                                      color:
                                          Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color:
                                            Colors.grey.shade600,
                                      ),

                                      const SizedBox(width: 5),

                                      Expanded(
                                        child: Text(
                                          dueDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ),

                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _statusColor(status)
                                                  .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color:
                                                _statusColor(status),
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4F46E5),
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTaskScreen(),
            ),
          );

          await _checkOverdueTasks();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}