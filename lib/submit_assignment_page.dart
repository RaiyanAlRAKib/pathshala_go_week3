import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'date_utils.dart';
import 'models/assignment.dart';
import 'models/assignment_submission.dart';
import 'submission_service.dart';
import 'widgets/loading_button.dart';

class SubmitAssignmentPage extends StatefulWidget {
  final Assignment assignment;
  final AssignmentSubmission? existing;

  const SubmitAssignmentPage({
    super.key,
    required this.assignment,
    this.existing,
  });

  @override
  State<SubmitAssignmentPage> createState() => _SubmitAssignmentPageState();
}

class _SubmitAssignmentPageState extends State<SubmitAssignmentPage> {
  static const _maxFileBytes = 20 * 1024 * 1024; // 20 MB

  final _service = SubmissionService();
  late final TextEditingController _textController;

  Uint8List? _newFileBytes;
  String? _newFileName;
  bool _isSaving = false;

  bool get _closed => widget.assignment.isOverdue;
  AssignmentSubmission? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _existing?.textAnswer ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty) return;

    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxFileBytes) {
      _showMessage('That file is too large. Maximum size is 20 MB.');
      return;
    }
    setState(() {
      _newFileBytes = bytes;
      _newFileName = file.name;
    });
  }

  Future<void> _openExistingFile() async {
    final path = _existing?.filePath;
    if (path == null) return;
    try {
      final url = await _service.signedUrl(path);
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showMessage('Could not open the file.');
    } catch (e) {
      _showMessage('Could not open the file.');
    }
  }

  Future<void> _submit() async {
    if (_closed) {
      _showMessage('This assignment is closed.');
      return;
    }
    final text = _textController.text.trim();
    final hasFile = _newFileBytes != null || _existing?.filePath != null;
    if (text.isEmpty && !hasFile) {
      _showMessage('Write an answer or attach a file before submitting.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.submit(
        assignmentId: widget.assignment.id,
        textAnswer: text,
        fileBytes: _newFileBytes,
        fileName: _newFileName,
        existingFilePath: _existing?.filePath,
        existingFileName: _existing?.fileName,
      );
      if (!mounted) return;
      _showMessage('Assignment submitted.');
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Failed to submit. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final existing = _existing;
    final currentFileName = _newFileName ?? existing?.fileName;

    return Scaffold(
      appBar: AppBar(title: const Text('Assignment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              assignment.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _closed
                  ? 'Closed ${formatDateTime(assignment.dueAt)}'
                  : 'Due ${formatDateTime(assignment.dueAt)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _closed ? Colors.red : AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(assignment.description, style: const TextStyle(height: 1.4)),
            const Divider(height: 36),
            if (existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Submitted ${formatDateTime(existing.submittedAt)}',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            if (_closed && existing == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('The due time has passed, so submissions are closed.'),
              )
            else ...[
              TextField(
                controller: _textController,
                enabled: !_closed,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Your answer',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentFileName ?? 'No file attached (PDF, Word or image, max 20 MB)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: currentFileName == null ? AppColors.textMuted : AppColors.textDark,
                        ),
                      ),
                    ),
                    if (_newFileBytes == null && existing?.filePath != null)
                      IconButton(
                        tooltip: 'Open',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: _openExistingFile,
                      ),
                    if (!_closed)
                      TextButton(
                        onPressed: _pickFile,
                        child: Text(currentFileName == null ? 'Choose' : 'Change'),
                      ),
                  ],
                ),
              ),
              if (!_closed) ...[
                const SizedBox(height: 24),
                LoadingButton(
                  label: existing == null ? 'Submit Assignment' : 'Update Submission',
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
                if (existing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'You can update your submission until the due time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}