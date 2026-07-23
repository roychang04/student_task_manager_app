import 'dart:async';

import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_task_screen.dart';
import 'task_detail_screen.dart';


class TaskListController {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  TaskListController({
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService();

  Stream<QuerySnapshot<Map<String, dynamic>>> get tasksStream {
    final userId = _authService.currentUserId;

    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get settingsStream {
    final user = _authService.currentUser;
    if (user == null) {
      return null;
    }

    return _firestore
        .collection('userdata')
        .doc(user.uid)
        .snapshots();
  }
}

class TaskListScreen extends StatefulWidget {
  final String initialFilter;

  const TaskListScreen({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<TaskListScreen> createState() =>
      _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskListController _controller = TaskListController();

  late String selectedFilter;
  String searchQuery = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tasksStream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    _settingsSubscription;

  Timer? _minuteRefreshTimer;
  DateTime _now = DateTime.now();

  bool notificationsEnabled = true;
  String defaultSorting = 'Due Date';

  final List<String> filters = [
    'All',
    'Pending',
    'Completed',
    'Overdue',
  ];

  void _listenToUserSettings() {
    final settingsStream = _controller.settingsStream;

    if (settingsStream == null) {
      return;
    }

    _settingsSubscription = settingsStream.listen((snapshot) {
      if (!mounted) {
        return;
      }

      final data = snapshot.data();
      final loadedSorting =
          data?['defaultTaskSorting']?.toString() ?? 'Due Date';

      setState(() {
        notificationsEnabled =
            data?['notificationsEnabled'] as bool? ?? true;

        defaultSorting = [
          'Due Date',
          'Priority',
          'Status',
          'Category',
        ].contains(loadedSorting)
            ? loadedSorting
            : 'Due Date';
      });
    });
  }

  @override
  void initState() {
    super.initState();

    selectedFilter = widget.initialFilter;

    _tasksStream = _controller.tasksStream;

    _listenToUserSettings();

    _scheduleNextMinuteUpdate();
  }

  void _scheduleNextMinuteUpdate() {
    _minuteRefreshTimer?.cancel();

    final now = DateTime.now();

    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );

    final delay = nextMinute.difference(now);

    _minuteRefreshTimer = Timer(delay, () {
      if (!mounted) return;

      setState(() {
        _now = DateTime.now();
      });

      _scheduleNextMinuteUpdate();
    });
  }

  @override
  void didUpdateWidget(covariant TaskListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter) {
      selectedFilter = widget.initialFilter;
      searchQuery = '';
      _now = DateTime.now();
    }
  }

  @override
  void dispose() {
    _minuteRefreshTimer?.cancel();
    _settingsSubscription?.cancel();
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

  String _currentStatus(Map<String, dynamic> data) {
    final String storedStatus =
        data['status']?.toString() ?? 'Pending';

    if (storedStatus == 'Completed') {
      return 'Completed';
    }

    final DateTime? dueDate = _convertDueDate(
      data['dueDate'],
    );

    if (dueDate != null &&
        (_now.isAfter(dueDate) ||
            _now.isAtSameMomentAs(dueDate))) {
      return 'Overdue';
    }

    return 'Pending';
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
    if (!notificationsEnabled) {
      return false;
    }

    final String status =
      _currentStatus(taskData).toLowerCase();

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

    return _now.isAtSameMomentAs(reminderTime) ||
      _now.isAfter(reminderTime);
  }

  // DateTime _createdAtValue(
  //   QueryDocumentSnapshot<Map<String, dynamic>>
  //       document,
  // ) {
  //   final dynamic createdAt =
  //       document.data()['createdAt'];

  //   if (createdAt is Timestamp) {
  //     return createdAt.toDate();
  //   }

  //   if (createdAt is DateTime) {
  //     return createdAt;
  //   }

  //   if (createdAt is String) {
  //     return DateTime.tryParse(createdAt) ??
  //         DateTime.fromMillisecondsSinceEpoch(0);
  //   }

  //   return DateTime.fromMillisecondsSinceEpoch(0);
  // }

  int _priorityRank(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }

  int _statusRank(String status) {
    switch (status.trim().toLowerCase()) {
      case 'overdue':
        return 0;
      case 'pending':
        return 1;
      case 'completed':
        return 2;
      default:
        return 3;
    }
  }

  DateTime _dueDateValue(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return _convertDueDate(document.data()['dueDate']) ??
        DateTime(9999);
  }

  void _sortTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    documents.sort((first, second) {
      final firstData = first.data();
      final secondData = second.data();

      final bool firstHasReminder =
          _isReminderActive(firstData);

      final bool secondHasReminder =
          _isReminderActive(secondData);

      // Keep active reminder tasks at the top.
      if (firstHasReminder && !secondHasReminder) {
        return -1;
      }

      if (!firstHasReminder && secondHasReminder) {
        return 1;
      }

      // After reminder priority, follow user's default sorting.
      switch (defaultSorting) {
        case 'Priority':
          final firstPriority =
              _priorityRank(firstData['priority']?.toString() ?? 'Low');

          final secondPriority =
              _priorityRank(secondData['priority']?.toString() ?? 'Low');

          if (firstPriority != secondPriority) {
            return firstPriority.compareTo(secondPriority);
          }

          return _dueDateValue(first).compareTo(
            _dueDateValue(second),
          );

        case 'Status':
          final firstStatus = _statusRank(
            _currentStatus(firstData),
          );

          final secondStatus = _statusRank(
            _currentStatus(secondData),
          );

          if (firstStatus != secondStatus) {
            return firstStatus.compareTo(secondStatus);
          }

          return _dueDateValue(first).compareTo(
            _dueDateValue(second),
          );

        case 'Category':
          final firstCategory =
              firstData['category']?.toString().toLowerCase() ?? '';

          final secondCategory =
              secondData['category']?.toString().toLowerCase() ?? '';

          final categoryCompare =
              firstCategory.compareTo(secondCategory);

          if (categoryCompare != 0) {
            return categoryCompare;
          }

          return _dueDateValue(first).compareTo(
            _dueDateValue(second),
          );

        case 'Due Date':
        default:
          return _dueDateValue(first).compareTo(
            _dueDateValue(second),
          );
      }
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

  Future<void> _refreshTaskTimes() async {
    if (!mounted) return;

    setState(() {
      _now = DateTime.now();
    });
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

    if (mounted) {
      setState(() {
        _now = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                stream: _tasksStream,
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

                      final String status = _currentStatus(data);

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
                      onRefresh: _refreshTaskTimes,
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
                    onRefresh: _refreshTaskTimes,
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

                        final String status = _currentStatus(data);

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
                                taskId: document.id,
                                taskData: {
                                  ...data,
                                  'status': _currentStatus(data),
                                },
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
                                              ).withValues(
                                                alpha: 0.20,
                                              )
                                            : Colors
                                                .black
                                                .withValues(
                                                  alpha: 0.05,
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
                                              taskId: document.id,
                                              taskData: {
                                                ...data,
                                                'status': _currentStatus(data),
                                              },
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
                                          ).withValues(
                                            alpha: 0.15,
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

          if (mounted) {
            setState(() {
              _now = DateTime.now();
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}