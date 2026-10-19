class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String textAnswer;
  final String? filePath;
  final String? fileName;
  final DateTime submittedAt;

  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.textAnswer,
    required this.filePath,
    required this.fileName,
    required this.submittedAt,
  });

  factory AssignmentSubmission.fromMap(Map<String, dynamic> map) {
    return AssignmentSubmission(
      id: map['id'] as String,
      assignmentId: map['assignment_id'] as String,
      textAnswer: (map['text_answer'] as String?) ?? '',
      filePath: map['file_path'] as String?,
      fileName: map['file_name'] as String?,
      submittedAt: DateTime.parse(map['submitted_at'] as String).toLocal(),
    );
  }
}