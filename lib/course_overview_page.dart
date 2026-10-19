import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models/course.dart';
import 'payment_gateway_page.dart';
import 'payment_service.dart';
import 'student_course_page.dart';

/// What a student sees before buying: details + the Buy button.
class CourseOverviewPage extends StatefulWidget {
  final Course course;
  final VoidCallback onEnrolled;

  const CourseOverviewPage({
    super.key,
    required this.course,
    required this.onEnrolled,
  });

  @override
  State<CourseOverviewPage> createState() => _CourseOverviewPageState();
}

class _CourseOverviewPageState extends State<CourseOverviewPage> {
  final _paymentService = PaymentService();
  bool _isWorking = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToCourse(String message) {
    widget.onEnrolled();
    _showMessage(message);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StudentCoursePage(course: widget.course)),
    );
  }

  Future<void> _buy() async {
    setState(() => _isWorking = true);
    try {
      final start = await _paymentService.startPayment(widget.course.id);
      if (!mounted) return;

      if (start.isFree) {
        _goToCourse('You are enrolled!');
        return;
      }

      final result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(builder: (_) => PaymentGatewayPage(start: start)),
      );
      if (!mounted) return;

      switch (result?.outcome ?? PaymentOutcome.cancelled) {
        case PaymentOutcome.success:
          _goToCourse('Payment successful. Welcome to the course!');
        case PaymentOutcome.failed:
          _showMessage(result?.message ?? 'Payment failed. Please try again.');
        case PaymentOutcome.cancelled:
          _showMessage('Payment cancelled.');
      }
    } on PaymentException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Something went wrong. Check your internet connection.');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isFree = course.price == 0;
    final priceText = isFree ? 'Free' : '৳${course.price.toStringAsFixed(0)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Course Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (course.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                course.thumbnailUrl!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: AppColors.border,
                  child: const Icon(Icons.image_outlined, size: 40),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            course.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            priceText,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'About this course',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(course.description, style: TextStyle(color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 18),
          const Text(
            'What you get',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _Perk(icon: Icons.play_circle_outline, text: 'Recorded video lessons'),
          const _Perk(icon: Icons.picture_as_pdf_outlined, text: 'Downloadable PDF materials'),
          const _Perk(icon: Icons.videocam_outlined, text: 'Live classes with your teacher'),
          const _Perk(icon: Icons.assignment_outlined, text: 'Assignments you can submit in the app'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isWorking ? null : _buy,
                  child: _isWorking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isFree ? 'Enroll for free' : 'Buy now · $priceText'),
                ),
              ),
              if (!isFree) ...[
                const SizedBox(height: 6),
                Text(
                  'Secure payment via SSLCommerz (bKash, cards and more)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Perk({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}