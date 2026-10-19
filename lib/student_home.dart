import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'explore_courses_tab.dart';
import 'login_page.dart';
import 'my_courses_tab.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  // Both tabs listen to this. Bumping it makes them reload their data.
  final _changeSignal = ValueNotifier<int>(0);
  int _index = 0;

  @override
  void dispose() {
    _changeSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Explore Courses' : 'My Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          ExploreCoursesTab(changeSignal: _changeSignal),
          MyCoursesTab(changeSignal: _changeSignal),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'My Courses',
          ),
        ],
      ),
    );
  }
}