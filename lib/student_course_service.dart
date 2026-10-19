import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/course.dart';

class StudentCourseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Every course available in the app (for browsing/searching).
  Future<List<Course>> fetchAllCourses() async {
    final data = await _client
        .from('courses')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((row) => Course.fromMap(row)).toList();
  }

  /// Courses the logged-in student has bought.
  Future<List<Course>> fetchEnrolledCourses() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('enrollments')
        .select('created_at, course:courses(*)')
        .eq('student_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .where((row) => row['course'] != null)
        .map((row) => Course.fromMap(row['course'] as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> fetchEnrolledCourseIds() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('enrollments')
        .select('course_id')
        .eq('student_id', userId);
    return (data as List).map((row) => row['course_id'] as String).toSet();
  }
}