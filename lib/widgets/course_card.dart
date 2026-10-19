import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/course.dart';
import 'status_chip.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final bool isEnrolled;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.isEnrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: course.thumbnailUrl != null
                  ? Image.network(
                      course.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.border,
                        child: const Icon(Icons.image_outlined),
                      ),
                    )
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
                    if (isEnrolled)
                      const StatusChip(label: 'Enrolled', color: AppColors.primary)
                    else
                      Text(
                        course.price == 0 ? 'Free' : '৳${course.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}