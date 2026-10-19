import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'assignment_service.dart';
import 'course_service.dart';
import 'date_utils.dart';
import 'live_class_service.dart';
import 'models/assignment.dart';
import 'models/assignment_submission.dart';
import 'models/course.dart';
import 'models/course_material.dart';
import 'models/course_video.dart';
import 'models/live_class.dart';
import 'submission_service.dart';
import 'submit_assignment_page.dart';
import 'video_player_page.dart';
import 'widgets/status_chip.dart';

/// Students can join a class this long before it starts...
const _joinEarly = Duration(minutes: 10);

/// ...and until this long after it starts (no end time is stored for a class).
const _classWindow = Duration(hours: 3);

enum _LiveState { upcoming, joinable, ended }

_LiveState _stateOf(LiveClass liveClass) {
  final now = DateTime.now();
  if (now.isBefore(liveClass.scheduledAt.subtract(_joinEarly))) {
    return _LiveState.upcoming;
  }
  if (now.isBefore(liveClass.scheduledAt.add(_classWindow))) {
    return _LiveState.joinable;
  }
  return _LiveState.ended;
}

/// Everything a student can do inside a course they own.
class StudentCoursePage extends StatefulWidget {
  final Course course;
  const StudentCoursePage({super.key, required this.course});

  @override
  State<StudentCoursePage> createState() => _StudentCoursePageState();
}

class _StudentCoursePageState extends State<StudentCoursePage> {
  final _courseService = CourseService();
  final _assignmentService = AssignmentService();
  final _liveClassService = LiveClassService();
  final _submissionService = SubmissionService();

  List<CourseVideo> _videos = [];
  List<CourseMaterial> _materials = [];
  List<Assignment> _assignments = [];
  List<LiveClass> _liveClasses = [];
  Map<String, AssignmentSubmission> _submissions = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _courseService.fetchVideos(widget.course.id),
        _courseService.fetchMaterials(widget.course.id),
        _assignmentService.fetchAssignments(widget.course.id),
        _liveClassService.fetchLiveClasses(widget.course.id),
      ]);
      final assignments = results[2] as List<Assignment>;
      final submissions = await _submissionService
          .fetchMySubmissions(assignments.map((a) => a.id).toList());
      if (!mounted) return;
      setState(() {
        _videos = results[0] as List<CourseVideo>;
        _materials = results[1] as List<CourseMaterial>;
        _assignments = assignments;
        _liveClasses = results[3] as List<LiveClass>;
        _submissions = submissions;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load this course. Check your internet connection.';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openExternal(String url, String failMessage) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage(failMessage);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showMessage(failMessage);
  }

  Future<void> _openAssignment(Assignment assignment) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SubmitAssignmentPage(
          assignment: assignment,
          existing: _submissions[assignment.id],
        ),
      ),
    );
    if (changed == true) _loadAll();
  }

  // ---------- Tabs ----------

  Widget _tabList({required List<Widget> children, required String emptyText, required IconData emptyIcon}) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: children.isEmpty
            ? [
                const SizedBox(height: 80),
                Icon(emptyIcon, size: 52, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Center(
                  child: Text(emptyText, style: TextStyle(color: AppColors.textMuted)),
                ),
              ]
            : children,
      ),
    );
  }

  Widget _videosTab() {
    return _tabList(
      emptyText: 'No videos yet',
      emptyIcon: Icons.play_circle_outline,
      children: _videos
          .map((video) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                  title: Text(video.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VideoPlayerPage(videoUrl: video.videoUrl, title: video.title),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _materialsTab() {
    return _tabList(
      emptyText: 'No PDF materials yet',
      emptyIcon: Icons.picture_as_pdf_outlined,
      children: _materials
          .map((material) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
                  title: Text(material.title),
                  subtitle: const Text('Tap to open or download'),
                  trailing: const Icon(Icons.download_outlined),
                  onTap: () => _openExternal(material.fileUrl, 'Could not open this file.'),
                ),
              ))
          .toList(),
    );
  }

  Widget _liveTab() {
    final sorted = [..._liveClasses]..sort((a, b) {
        final aEnded = _stateOf(a) == _LiveState.ended;
        final bEnded = _stateOf(b) == _LiveState.ended;
        if (aEnded != bEnded) return aEnded ? 1 : -1;
        return aEnded
            ? b.scheduledAt.compareTo(a.scheduledAt)
            : a.scheduledAt.compareTo(b.scheduledAt);
      });

    return _tabList(
      emptyText: 'No live classes scheduled',
      emptyIcon: Icons.videocam_outlined,
      children: sorted.map(_liveCard).toList(),
    );
  }

  Widget _liveCard(LiveClass liveClass) {
    final state = _stateOf(liveClass);
    final isLiveNow =
        state == _LiveState.joinable && !DateTime.now().isBefore(liveClass.scheduledAt);

    final String chipLabel;
    final Color chipColor;
    switch (state) {
      case _LiveState.upcoming:
        chipLabel = 'Upcoming';
        chipColor = AppColors.primary;
      case _LiveState.joinable:
        chipLabel = isLiveNow ? 'Live now' : 'Starting soon';
        chipColor = Colors.red;
      case _LiveState.ended:
        chipLabel = 'Ended';
        chipColor = AppColors.textMuted;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videocam_outlined, color: chipColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    liveClass.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                StatusChip(label: chipLabel, color: chipColor),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                formatDateTime(liveClass.scheduledAt),
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state == _LiveState.joinable
                    ? () => _openExternal(liveClass.meetLink, 'Could not open the Meet link.')
                    : null,
                icon: const Icon(Icons.login),
                label: Text(switch (state) {
                  _LiveState.joinable => 'Join Class',
                  _LiveState.upcoming => 'Opens 10 minutes before start',
                  _LiveState.ended => 'Class ended',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignmentsTab() {
    return _tabList(
      emptyText: 'No assignments yet',
      emptyIcon: Icons.assignment_outlined,
      children: _assignments.map(_assignmentCard).toList(),
    );
  }

  Widget _assignmentCard(Assignment assignment) {
    final submission = _submissions[assignment.id];
    final String label;
    final Color color;
    if (submission != null) {
      label = 'Submitted';
      color = Colors.green.shade700;
    } else if (assignment.isOverdue) {
      label = 'Missed';
      color = Colors.red;
    } else {
      label = 'Pending';
      color = Colors.orange.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.assignment_outlined,
          color: assignment.isOverdue && submission == null
              ? AppColors.textMuted
              : AppColors.primary,
        ),
        title: Text(assignment.title),
        subtitle: Text(
          assignment.isOverdue
              ? 'Closed ${formatDateTime(assignment.dueAt)}'
              : 'Due ${formatDateTime(assignment.dueAt)}',
        ),
        trailing: StatusChip(label: label, color: color),
        onTap: () => _openAssignment(assignment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.course.title),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Videos'),
              Tab(text: 'PDFs'),
              Tab(text: 'Live Classes'),
              Tab(text: 'Assignments'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _loadAll();
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _videosTab(),
                      _materialsTab(),
                      _liveTab(),
                      _assignmentsTab(),
                    ],
                  ),
      ),
    );
  }
}