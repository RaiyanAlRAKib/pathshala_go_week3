import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/assignment_submission.dart';

class SubmissionService {
  final SupabaseClient _client = Supabase.instance.client;
  static const _bucket = 'assignment-submissions';

  /// The logged-in student's submissions, keyed by assignment id.
  Future<Map<String, AssignmentSubmission>> fetchMySubmissions(
      List<String> assignmentIds) async {
    if (assignmentIds.isEmpty) return {};
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('assignment_submissions')
        .select()
        .eq('student_id', userId)
        .inFilter('assignment_id', assignmentIds);
    final list =
        (data as List).map((row) => AssignmentSubmission.fromMap(row)).toList();
    return {for (final s in list) s.assignmentId: s};
  }

  /// Creates a submission, or replaces the student's previous one.
  Future<void> submit({
    required String assignmentId,
    required String textAnswer,
    Uint8List? fileBytes,
    String? fileName,
    String? existingFilePath,
    String? existingFileName,
  }) async {
    final userId = _client.auth.currentUser!.id;
    String? filePath = existingFilePath;
    String? storedName = existingFileName;

    if (fileBytes != null && fileName != null) {
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '$userId/$assignmentId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(upsert: false),
          );
      if (existingFilePath != null) {
        try {
          await _client.storage.from(_bucket).remove([existingFilePath]);
        } catch (_) {
          // Old file cleanup is best-effort.
        }
      }
      filePath = path;
      storedName = fileName;
    }

    await _client.from('assignment_submissions').upsert(
      {
        'assignment_id': assignmentId,
        'student_id': userId,
        'text_answer': textAnswer,
        'file_path': filePath,
        'file_name': storedName,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'assignment_id,student_id',
    );
  }

  /// Temporary link (1 hour) to a submitted file, since the bucket is private.
  Future<String> signedUrl(String path) {
    return _client.storage.from(_bucket).createSignedUrl(path, 3600);
  }
}