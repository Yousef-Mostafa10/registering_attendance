import 'package:flutter/material.dart';
import '../../Auth/colors.dart';

/// Placeholder for Session Attendees — To be implemented by another developer
class SessionAttendeesPage extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;

  const SessionAttendeesPage({
    Key? key,
    required this.sessionId,
    required this.sessionTitle,
  }) : super(key: key);

  @override
  State<SessionAttendeesPage> createState() => _SessionAttendeesPageState();
}

class _SessionAttendeesPageState extends State<SessionAttendeesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: Text(widget.sessionTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Session Attendees List',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This screen will show students who attended this session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              'Session ID: ${widget.sessionId}',
              style: TextStyle(color: Colors.grey.withOpacity(0.8), fontSize: 13),
            ),
            const SizedBox(height: 32),
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
