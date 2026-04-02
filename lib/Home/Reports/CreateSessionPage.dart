import 'package:flutter/material.dart';
import '../../Auth/colors.dart';

/// Placeholder for Session Creation — To be implemented by another developer
class CreateSessionPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CreateSessionPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: Text('New Session · ${widget.courseName}'),
        backgroundColor: AppColors.darkColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Session Creation Feature',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This feature will be implemented soon.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement session creation logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Implementation pending...')),
                  );
                },
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Start Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
