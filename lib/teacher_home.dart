import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'course_service.dart';
import 'login_page.dart';
import 'models/course.dart';
import 'create_course_page.dart';
import 'course_detail_page.dart';
import 'payout_service.dart';
import 'payout_settings_page.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  final _courseService = CourseService();
  final _payoutService = PayoutService();
  late Future<List<Course>> _coursesFuture;

  // Starts as true so the red dot doesn't flash before we know.
  bool _hasPayoutNumber = true;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _courseService.fetchMyCourses();
    _loadPayoutStatus();
  }

  Future<void> _loadPayoutStatus() async {
    try {
      final number = await _payoutService.fetchBkashNumber();
      if (!mounted) return;
      setState(() => _hasPayoutNumber = number != null);
    } catch (_) {
      // Ignore: the dot just stays hidden.
    }
  }

  Future<void> _openPayoutSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PayoutSettingsPage()),
    );
    _loadPayoutStatus();
  }

  void _refresh() {
    setState(() {
      _coursesFuture = _courseService.fetchMyCourses();
    });
  }

  Future<void> _deleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this course?'),
        content: Text('"${course.title}" and all its videos and materials will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _courseService.deleteCourse(course.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete course.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            tooltip: 'Payout settings',
            icon: Badge(
              smallSize: 9,
              isLabelVisible: !_hasPayoutNumber,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            onPressed: _openPayoutSettings,
          ),
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
      body: FutureBuilder<List<Course>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No courses yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the + button to create your first course',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CourseDetailPage(course: course)),
                    );
                    _refresh();
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: course.thumbnailUrl != null
                            ? Image.network(course.thumbnailUrl!, fit: BoxFit.cover)
                            : Container(
                                color: AppColors.border,
                                child: const Icon(Icons.image_outlined),
                              ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                course.description,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '৳${course.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteCourse(course),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCoursePage()),
          );
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Course'),
      ),
    );
  }
}