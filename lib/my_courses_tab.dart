import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models/course.dart';
import 'student_course_page.dart';
import 'student_course_service.dart';
import 'widgets/course_card.dart';

class MyCoursesTab extends StatefulWidget {
  final ValueNotifier<int> changeSignal;
  const MyCoursesTab({super.key, required this.changeSignal});

  @override
  State<MyCoursesTab> createState() => _MyCoursesTabState();
}

class _MyCoursesTabState extends State<MyCoursesTab> {
  final _service = StudentCourseService();

  List<Course> _courses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    widget.changeSignal.addListener(_load);
  }

  @override
  void dispose() {
    widget.changeSignal.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final courses = await _service.fetchEnrolledCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load your courses. Check your internet connection.';
      });
    }
  }

  Widget _message(IconData icon, String title, String subtitle, {VoidCallback? onRetry}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Center(
          child: Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        if (onRetry != null)
          Center(child: TextButton(onPressed: onRetry, child: const Text('Try again'))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _message(Icons.wifi_off_outlined, 'Something went wrong', _error!,
          onRetry: _load);
    } else if (_courses.isEmpty) {
      body = _message(
        Icons.school_outlined,
        'No courses yet',
        'Courses you buy will show up here. Head to Explore to find one.',
      );
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return CourseCard(
            course: course,
            isEnrolled: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StudentCoursePage(course: course)),
            ),
          );
        },
      );
    }
    return RefreshIndicator(onRefresh: _load, child: body);
  }
}