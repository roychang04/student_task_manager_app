import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String selectedFilter = 'All';

  final List<String> filters = ['All', 'Pending', 'Completed', 'Overdue'];

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

  // ===========================
  // ADD THIS FUNCTION
  // ===========================
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

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('tasks')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      appBar: AppBar(
  backgroundColor: const Color(0xffF6F7FB),
  elevation: 0,
  centerTitle: true,
  automaticallyImplyLeading: false, // Prevents Flutter from adding a back button
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
              decoration: InputDecoration(
                hintText: 'Search tasks...',
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
      final isSelected = selectedFilter == filter;

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
            color: isSelected ? Colors.white : Colors.black87,
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
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Something went wrong'),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    if (selectedFilter == 'All') return true;

                    return data['status'] == selectedFilter;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No tasks found'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;

                      final title = data['title'] ?? '';
                      final description =
                          data['description'] ?? '';

                      // ===========================
                      // UPDATED DUE DATE
                      // ===========================
                      String dueDate = '';

                      final dueDateData = data['dueDate'];

                      if (dueDateData is Timestamp) {
                        final date = dueDateData.toDate();

                        dueDate =
                            '${date.day} ${_monthName(date.month)} ${date.year}';
                      } else if (dueDateData is String) {
                        dueDate = dueDateData;
                      }

                      final priority =
                          data['priority'] ?? 'Low';
                      final status =
                          data['status'] ?? 'Pending';

                      return Container(
                        margin:
                            const EdgeInsets.only(bottom: 12),
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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.more_vert,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(description),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(dueDate),
                                const Spacer(),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: _statusColor(
                                            status)
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color:
                                          _statusColor(status),
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4F46E5),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTaskScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}