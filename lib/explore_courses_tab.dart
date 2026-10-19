import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'course_overview_page.dart';
import 'models/course.dart';
import 'student_course_page.dart';
import 'student_course_service.dart';
import 'widgets/course_card.dart';

class ExploreCoursesTab extends StatefulWidget {
  /// Bumped whenever the student's enrollments change (e.g. after a purchase).
  final ValueNotifier<int> changeSignal;
  const ExploreCoursesTab({super.key, required this.changeSignal});

  @override
  State<ExploreCoursesTab> createState() => _ExploreCoursesTabState();
}

class _ExploreCoursesTabState extends State<ExploreCoursesTab> {
  final _service = StudentCourseService();
  final _searchController = TextEditingController();

  List<Course> _courses = [];
  Set<String> _enrolledIds = {};
  bool _isLoading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    widget.changeSignal.addListener(_load);
  }

  @override
  void dispose() {
    widget.changeSignal.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchAllCourses(),
        _service.fetchEnrolledCourseIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _courses = results[0] as List<Course>;
        _enrolledIds = results[1] as Set<String>;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load courses. Check your internet connection.';
      });
    }
  }

  Future<void> _openCourse(Course course) async {
    final enrolled = _enrolledIds.contains(course.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => enrolled
            ? StudentCoursePage(course: course)
            : CourseOverviewPage(
                course: course,
                onEnrolled: () => widget.changeSignal.value++,
              ),
      ),
    );
    _load();
  }

  List<Course> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _courses;
    return _courses
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q))
        .toList();
  }

  Widget _message(IconData icon, String text, {VoidCallback? onRetry}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        if (onRetry != null)
          Center(
            child: TextButton(onPressed: onRetry, child: const Text('Try again')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = _filtered;

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _message(Icons.wifi_off_outlined, _error!, onRetry: _load);
    } else if (courses.isEmpty) {
      body = _message(
        Icons.search_off_outlined,
        _query.isEmpty ? 'No courses available yet' : 'No courses match "$_query"',
      );
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final course = courses[index];
          return CourseCard(
            course: course,
            isEnrolled: _enrolledIds.contains(course.id),
            onTap: () => _openCourse(course),
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search courses',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: _load, child: body),
        ),
      ],
    );
  }
}