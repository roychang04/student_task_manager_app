import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/calendar_screen.dart';
import 'screens/task_list_screen.dart';
import 'widgets/student_bottom_nav_bar.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Student Task Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() {
    return _DashboardScreenState();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _taskListFilter = 'All';

  void _openTasksWithFilter(String filter) {
    setState(() {
      _taskListFilter = filter;
      _currentIndex = 1;
    });
  }
    
  void _changeScreen(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  List<Widget> get _screens {
    return [
      HomeScreen(
        onViewTasksByStatus: _openTasksWithFilter,
        onOpenProfile: () {
          _changeScreen(4);
        },
      ),
      TaskListScreen(
        initialFilter: _taskListFilter,
      ),
      const CalendarPage(),
      const Center(
        child: Text('Categories Screen'),
      ),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: StudentBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _changeScreen,
      ),
    );
  }
}

class UserDataScreen extends StatelessWidget {
  const UserDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('userdata')
            .snapshots(),
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

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No data found'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    data['username']?.toString() ??
                        'Unknown user',
                  ),
                  subtitle: Text(
                    'UID: ${data['uid']?.toString() ?? '-'}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}