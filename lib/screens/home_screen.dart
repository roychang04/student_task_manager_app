import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/auth_service.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<String>? onViewTasksByStatus;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    this.onViewTasksByStatus,
    this.onOpenProfile,
  });

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tasksStream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userSubscription;

  Timer? _timer;
  DateTime _now = DateTime.now();

  String username = 'User';

  void _listenToCurrentUser() {
    final userId = _authService.currentUserId;

    if (userId == null) {
      return;
    }

    _userSubscription = FirebaseFirestore.instance
        .collection('userdata')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();

      if (!mounted || data == null) {
        return;
      }

      setState(() {
        username = data['username']?.toString() ?? 'User';
      });
    });
  }

  @override
  void initState() {
    super.initState();

    final userId = _authService.currentUserId;

    _tasksStream = userId == null
        ? const Stream.empty()
        : FirebaseFirestore.instance
            .collection('tasks')
            .where('userId', isEqualTo: userId)
            .orderBy('dueDate')
            .snapshots();

    _listenToCurrentUser();

    _scheduleNextMinuteUpdate();
  }

  void _scheduleNextMinuteUpdate() {
    _timer?.cancel();

    final now = DateTime.now();

    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );

    final delay = nextMinute.difference(now);

    _timer = Timer(delay, () {
      if (!mounted) return;

      setState(() {
        _now = DateTime.now();
      });

      _scheduleNextMinuteUpdate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  // Colours
  static const Color backgroundColour = Color(0xffF6F7FB);
  static const Color primaryColour = Color(0xff4F46E5);
  static const Color cardColour = Colors.white;
  static const Color titleTextColour = Color(0xff111827);
  static const Color subtitleTextColour = Color(0xff6B7280);
  static const Color totalTaskColour = Color(0xff2563EB);
  
  static const Color orangeColour = Color(0xffF59E0B);
  static const Color greenColour = Color(0xff10B981);
  static const Color redColour = Color(0xffEF4444);

  static const Color addButtonColour = Color(0xff4F46E5);
  static const Color progressBarColour = Color(0xff4F46E5);

  String _formatDateTime(DateTime date) {
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

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '$hour:$minute $period';
  }

  String _currentStatus(TaskModel task, DateTime now) {
    if (task.status == 'Completed') {
      return 'Completed';
    }

    if (task.dueDate.isBefore(now)) {
      return 'Overdue';
    }

    return 'Pending';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Overdue':
        return redColour;
      default:
        return orangeColour;
    }
  }
  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Medium':
        return orangeColour;
      case 'High':
        return redColour;
      default:
        return greenColour;
    }
  }

  Future<void> _openTaskDetails(
    BuildContext context,
    TaskModel task,
    String status,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: task.id,
          taskData: {
            ...task.toFirestore(),
            'status': status,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColour,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _tasksStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load dashboard: ${snapshot.error}',
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final tasks = snapshot.data?.docs
                    .map(TaskModel.fromFirestore)
                    .toList() ?? [];

            final now = _now;

            final totalTasks = tasks.length;

            final completedTasks = tasks.where((task) {
              return task.status == 'Completed';
            }).length;

            final pendingTasks = tasks.where((task) {
              return task.status != 'Completed' &&
                  !task.dueDate.isBefore(now);
            }).length;

            final overdueTasks = tasks.where((task) {
              return task.status != 'Completed' &&
                  task.dueDate.isBefore(now);
            }).length;

            final overdueTaskList = tasks.where((task) {
              return task.status != 'Completed' &&
                  task.dueDate.isBefore(now);
            }).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

            final recentOverdueTasks = overdueTaskList.take(3).toList();

            final upcomingTasks = tasks.where((task) {
              return task.status != 'Completed' &&
                  !task.dueDate.isBefore(now);
            }).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));  // Sorts list and returns original object

            final recentUpcomingTasks = upcomingTasks.take(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 22),

                 Column(
                    children: [
                      _buildStatCard(
                        title: 'Total Tasks',
                        value: totalTasks,
                        icon: Icons.assignment_rounded,
                        color: totalTaskColour,
                      ),

                      const SizedBox(height: 12),

                      _buildStatCard(
                        title: 'Pending',
                        value: pendingTasks,
                        icon: Icons.access_time_rounded,
                        color: orangeColour,
                      ),

                      const SizedBox(height: 12),

                      _buildStatCard(
                        title: 'Overdue',
                        value: overdueTasks,
                        icon: Icons.warning_amber_rounded,
                        color: redColour,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildProgressCard(
                    completedTasks: completedTasks,
                    totalTasks: totalTasks,
                  ),

                  const SizedBox(height: 18),

                  _buildAddTaskButton(context),

                  const SizedBox(height: 24),

                  if (recentOverdueTasks.isNotEmpty) ...[
                    _buildOverdueHeader(),

                    const SizedBox(height: 12),

                    ...recentOverdueTasks.map((task) {
                      final status = _currentStatus(task, now);
                      final priority = task.priority;

                      return _buildDeadlineTile(
                        context: context,
                        task: task,
                        status: status,
                        priority: priority,
                      );
                    }),

                    const SizedBox(height: 24),
                  ],

                  _buildPendingHeader(),

                  const SizedBox(height: 12),

                  if (recentUpcomingTasks.isEmpty)
                    _buildEmptyCard()
                  else
                    ...recentUpcomingTasks.map((task) {
                      final status = _currentStatus(task, now);
                      final priority = task.priority;

                      return _buildDeadlineTile(
                        context: context,
                        task: task,
                        status: status,
                        priority: priority,
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String trimmedUsername = username.trim();

    final String displayName = trimmedUsername.length > 15
        ? '${trimmedUsername.substring(0, 14)}...'
        : trimmedUsername;

    final String firstLetter = trimmedUsername.isNotEmpty
        ? trimmedUsername[0].toUpperCase()
        : '?';

    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onOpenProfile,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: primaryColour.withValues(alpha: 0.15),
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColour,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleTextColour,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 20,
                  color: titleTextColour,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColour,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: subtitleTextColour,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required int completedTasks,
    required int totalTasks,
  }) {
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final progressPercent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColour,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completion Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: titleTextColour,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: progressBarColour.withValues(alpha: 0.12),
                    color: progressBarColour,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: progressBarColour,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$completedTasks of $totalTasks tasks completed',
            style: const TextStyle(
              color: subtitleTextColour,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTaskButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTaskScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: addButtonColour,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildOverdueHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Overdue Tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleTextColour,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            widget.onViewTasksByStatus?.call('Overdue');
          },
          child: const Text(
            'View All',
            style: TextStyle(
              color: primaryColour,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Pending Tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleTextColour,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            widget.onViewTasksByStatus?.call('Pending');
          },
          child: const Text(
            'View All',
            style: TextStyle(
              color: primaryColour,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColour,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No pending tasks',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: subtitleTextColour,
        ),
      ),
    );
  }

  Widget _buildDeadlineTile({
    required BuildContext context,
    required TaskModel task,
    required String status,
    required String priority,
  }) {
    final statusColour = _statusColor(status);
    final priorityColour = _priorityColor(priority);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _openTaskDetails(
            context,
            task,
            status,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: cardColour,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: priorityColour,
                width: 5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: titleTextColour,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: subtitleTextColour,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: subtitleTextColour,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDateTime(task.dueDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: subtitleTextColour,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColour,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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