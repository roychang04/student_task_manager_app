import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() =>
      _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String selectedFilter = 'All';
  String searchQuery = '';

  Timer? _reminderRefreshTimer;

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

    // Refresh the task list regularly so that a task
    // becomes highlighted when its reminder time arrives.
    _reminderRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _reminderRefreshTimer?.cancel();
    super.dispose();
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
      final cleanedDate =
          dateText.trim().replaceAll(',', '');

      final parts =
          cleanedDate.split(RegExp(r'\s+'));

      if (parts.length < 3) {
        return null;
      }

      final day = int.parse(parts[0]);
      final month = _monthNumber(parts[1]);
      final year = int.parse(parts[2]);

      if (month == null) {
        return null;
      }

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
      debugPrint(
        'Unable to parse due date "$dateText": $error',
      );

      return null;
    }
  }

  DateTime? _convertDueDate(dynamic dueDateData) {
    if (dueDateData is Timestamp) {
      return dueDateData.toDate();
    }

    if (dueDateData is DateTime) {
      return dueDateData;
    }

    if (dueDateData is String) {
      return _parseStringDate(dueDateData);
    }

    return null;
  }

  DateTime? _getReminderTime({
    required DateTime dueDate,
    required String reminder,
  }) {
    switch (reminder.trim().toLowerCase()) {
      case '10 minutes before':
        return dueDate.subtract(
          const Duration(minutes: 10),
        );

      case '1 hour before':
        return dueDate.subtract(
          const Duration(hours: 1),
        );

      case '1 day before':
        return dueDate.subtract(
          const Duration(days: 1),
        );

      default:
        return null;
    }
  }

  bool _isReminderActive(
    Map<String, dynamic> taskData,
  ) {
    final String status =
        taskData['status']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'pending';

    final String reminder =
        taskData['reminder']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'no reminder';

    // Completed tasks must not be highlighted.
    if (status == 'completed') {
      return false;
    }

    // Tasks without reminders must not be highlighted.
    if (reminder.isEmpty ||
        reminder == 'no reminder') {
      return false;
    }

    final DateTime? dueDate = _convertDueDate(
      taskData['dueDate'],
    );

    if (dueDate == null) {
      return false;
    }

    final DateTime? reminderTime =
        _getReminderTime(
      dueDate: dueDate,
      reminder: reminder,
    );

    if (reminderTime == null) {
      return false;
    }

    final DateTime now = DateTime.now();

    return now.isAtSameMomentAs(reminderTime) ||
        now.isAfter(reminderTime);
  }

  DateTime _createdAtValue(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final dynamic createdAt =
        document.data()['createdAt'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    if (createdAt is DateTime) {
      return createdAt;
    }

    if (createdAt is String) {
      return DateTime.tryParse(createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _sortTasks(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    documents.sort((first, second) {
      final bool firstHasReminder =
          _isReminderActive(first.data());

      final bool secondHasReminder =
          _isReminderActive(second.data());

      // Active reminder tasks appear first.
      if (firstHasReminder &&
          !secondHasReminder) {
        return -1;
      }

      if (!firstHasReminder &&
          secondHasReminder) {
        return 1;
      }

      // When both have active reminders,
      // show the nearest due task first.
      if (firstHasReminder &&
          secondHasReminder) {
        final DateTime? firstDueDate =
            _convertDueDate(
          first.data()['dueDate'],
        );

        final DateTime? secondDueDate =
            _convertDueDate(
          second.data()['dueDate'],
        );

        if (firstDueDate != null &&
            secondDueDate != null) {
          return firstDueDate.compareTo(
            secondDueDate,
          );
        }
      }

      // Other tasks remain ordered by newest first.
      return _createdAtValue(second).compareTo(
        _createdAtValue(first),
      );
    });
  }

  String _formatDateTime(DateTime date) {
    final int hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final String minute =
        date.minute.toString().padLeft(2, '0');

    final String period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} '
        '${_monthName(date.month)} '
        '${date.year}, '
        '$hour:$minute $period';
  }

  Future<void> _checkOverdueTasks() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('tasks')
              .where(
                'status',
                isEqualTo: 'Pending',
              )
              .get();

      final DateTime now = DateTime.now();

      final WriteBatch batch =
          FirebaseFirestore.instance.batch();

      bool hasUpdates = false;

      for (final document in snapshot.docs) {
        final data = document.data();

        final DateTime? dueDate =
            _convertDueDate(
          data['dueDate'],
        );

        if (dueDate != null &&
            now.isAfter(dueDate)) {
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
      debugPrint(
        'Error checking overdue tasks: $error',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to check overdue tasks',
          ),
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

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance
            .collection('tasks')
            .orderBy(
              'createdAt',
              descending: true,
            );

    return Scaffold(
      backgroundColor:
          const Color(0xffF6F7FB),
      appBar: AppBar(
        backgroundColor:
            const Color(0xffF6F7FB),
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
                  searchQuery =
                      value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText:
                    'Search by title or category...',
                prefixIcon:
                    const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final bool isSelected =
                      selectedFilter == filter;

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      right: 8,
                    ),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          selectedFilter =
                              filter;
                        });
                      },
                      selectedColor:
                          const Color(
                        0xff4F46E5,
                      ),
                      backgroundColor:
                          Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 12,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8,
                        ),
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
                  QuerySnapshot<
                      Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong: '
                        '${snapshot.error}',
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  final documents =
                      snapshot.data!.docs.where(
                    (document) {
                      final data =
                          document.data();

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
                          data['status']
                                  ?.toString() ??
                              'Pending';

                      final bool matchesStatus =
                          selectedFilter == 'All' ||
                              status ==
                                  selectedFilter;

                      final bool matchesSearch =
                          searchQuery.isEmpty ||
                              title.contains(
                                searchQuery,
                              ) ||
                              category.contains(
                                searchQuery,
                              );

                      return matchesStatus &&
                          matchesSearch;
                    },
                  ).toList();

                  _sortTasks(documents);

                  if (documents.isEmpty) {
                    return RefreshIndicator(
                      onRefresh:
                          _checkOverdueTasks,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: Text(
                              'No tasks found',
                            ),
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
                      itemCount:
                          documents.length,
                      itemBuilder:
                          (context, index) {
                        final document =
                            documents[index];

                        final data =
                            document.data();

                        final String title =
                            data['title']
                                    ?.toString() ??
                                '';

                        final String description =
                            data['description']
                                    ?.toString() ??
                                '';

                        final String priority =
                            data['priority']
                                    ?.toString() ??
                                'Low';

                        final String status =
                            data['status']
                                    ?.toString() ??
                                'Pending';

                        final bool
                            hasActiveReminder =
                            _isReminderActive(
                          data,
                        );

                        String dueDate = '';

                        final dynamic
                            dueDateData =
                            data['dueDate'];

                        if (dueDateData
                            is Timestamp) {
                          dueDate =
                              _formatDateTime(
                            dueDateData.toDate(),
                          );
                        } else if (dueDateData
                            is String) {
                          dueDate =
                              dueDateData;
                        }

                        return MouseRegion(
                          cursor:
                              SystemMouseCursors
                                  .click,
                          child: GestureDetector(
                            onTap: () {
                              _openTaskDetails(
                                taskId:
                                    document.id,
                                taskData: data,
                              );
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 12,
                              ),
                              padding:
                                  const EdgeInsets
                                      .all(14),
                              decoration:
                                  BoxDecoration(
                                color:
                                    hasActiveReminder
                                        ? const Color(
                                            0xffF5F3FF,
                                          )
                                        : Colors.white,
                                borderRadius:
                                    BorderRadius
                                        .circular(14),
                                border:
                                    hasActiveReminder
                                        ? Border.all(
                                            color:
                                                const Color(
                                              0xff4F46E5,
                                            ),
                                            width: 2.5,
                                          )
                                        : Border(
                                            left:
                                                BorderSide(
                                              color:
                                                  _priorityColor(
                                                priority,
                                              ),
                                              width: 5,
                                            ),
                                          ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        hasActiveReminder
                                            ? const Color(
                                                0xff4F46E5,
                                              ).withOpacity(
                                                0.20,
                                              )
                                            : Colors
                                                .black
                                                .withOpacity(
                                                  0.05,
                                                ),
                                    blurRadius:
                                        hasActiveReminder
                                            ? 14
                                            : 8,
                                    spreadRadius:
                                        hasActiveReminder
                                            ? 1
                                            : 0,
                                    offset:
                                        const Offset(
                                      0,
                                      3,
                                    ),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  if (hasActiveReminder)
                                    ...[
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              const Color(
                                            0xff4F46E5,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            8,
                                          ),
                                        ),
                                        child:
                                            const Row(
                                          mainAxisSize:
                                              MainAxisSize
                                                  .min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .notifications_active,
                                              color:
                                                  Colors
                                                      .white,
                                              size: 14,
                                            ),
                                            SizedBox(
                                              width: 4,
                                            ),
                                            Text(
                                              'Reminder',
                                              style:
                                                  TextStyle(
                                                color:
                                                    Colors
                                                        .white,
                                                fontSize:
                                                    11,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 8,
                                      ),
                                    ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                hasActiveReminder
                                                    ? FontWeight
                                                        .w800
                                                    : FontWeight
                                                        .bold,
                                            fontSize:
                                                hasActiveReminder
                                                    ? 16
                                                    : 15,
                                            color:
                                                hasActiveReminder
                                                    ? const Color(
                                                        0xff312E81,
                                                      )
                                                    : Colors
                                                        .black,
                                          ),
                                        ),
                                      ),
                                      Tooltip(
                                        message:
                                            'View task details',
                                        child:
                                            IconButton(
                                          mouseCursor:
                                              SystemMouseCursors
                                                  .click,
                                          hoverColor:
                                              const Color(
                                            0xffEEF2FF,
                                          ),
                                          splashColor:
                                              const Color(
                                            0xffC7D2FE,
                                          ),
                                          highlightColor:
                                              const Color(
                                            0xffE0E7FF,
                                          ),
                                          visualDensity:
                                              VisualDensity
                                                  .compact,
                                          icon: Icon(
                                            Icons
                                                .more_vert,
                                            color:
                                                hasActiveReminder
                                                    ? const Color(
                                                        0xff4F46E5,
                                                      )
                                                    : Colors
                                                        .black87,
                                          ),
                                          onPressed: () {
                                            _openTaskDetails(
                                              taskId:
                                                  document
                                                      .id,
                                              taskData:
                                                  data,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color:
                                          hasActiveReminder
                                              ? const Color(
                                                  0xff4338CA,
                                                )
                                              : Colors.grey
                                                  .shade700,
                                      fontSize: 12,
                                      fontWeight:
                                          hasActiveReminder
                                              ? FontWeight
                                                  .w600
                                              : FontWeight
                                                  .normal,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons
                                            .calendar_today,
                                        size: 14,
                                        color:
                                            hasActiveReminder
                                                ? const Color(
                                                    0xff4F46E5,
                                                  )
                                                : Colors
                                                    .grey
                                                    .shade600,
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Expanded(
                                        child: Text(
                                          dueDate,
                                          style:
                                              TextStyle(
                                            fontSize: 12,
                                            color:
                                                hasActiveReminder
                                                    ? const Color(
                                                        0xff4338CA,
                                                      )
                                                    : Colors
                                                        .grey
                                                        .shade600,
                                            fontWeight:
                                                hasActiveReminder
                                                    ? FontWeight
                                                        .bold
                                                    : FontWeight
                                                        .normal,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              _statusColor(
                                            status,
                                          ).withOpacity(
                                            0.15,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style:
                                              TextStyle(
                                            color:
                                                _statusColor(
                                              status,
                                            ),
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
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
      floatingActionButton:
          FloatingActionButton(
        backgroundColor:
            const Color(0xff4F46E5),
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AddTaskScreen(),
            ),
          );

          await _checkOverdueTasks();

          if (mounted) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}