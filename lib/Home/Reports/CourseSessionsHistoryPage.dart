import 'package:flutter/material.dart';
import '../../Auth/colors.dart';

/// Placeholder for Session History — To be implemented by another developer
class CourseSessionsHistoryPage extends StatefulWidget {
  final String courseId;

  const CourseSessionsHistoryPage({
    Key? key,
    required this.courseId,
  }) : super(key: key);

  @override
  State<CourseSessionsHistoryPage> createState() => _CourseSessionsHistoryPageState();
}

class _CourseSessionsHistoryPageState extends State<CourseSessionsHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Session History Feature',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This screen will display past sessions once implemented.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
