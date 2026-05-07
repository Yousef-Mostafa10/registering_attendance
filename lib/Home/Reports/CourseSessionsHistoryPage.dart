import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:registering_attendance/core/http_interceptor.dart' as http;
import '../../Auth/colors.dart';
import '../../Auth/api_service.dart';
import '../../Auth/auth_storage.dart';
import 'SessionAttendeesPage.dart';

class CourseSessionsHistoryPage extends StatefulWidget {
  final String courseId;

  const CourseSessionsHistoryPage({
    Key? key,
    required this.courseId,
  }) : super(key: key);

  @override
  State<CourseSessionsHistoryPage> createState() => _CourseSessionsHistoryPageState();
}

class _CourseSessionsHistoryPageState extends State<CourseSessionsHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _lectures = [];
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken() ?? '';
      
      final lecturesResponseFuture = http.get(
        Uri.parse('${ApiService.baseUrl}/Session/course-sessions/${widget.courseId}/Lecture'),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );
      
      final sectionsResponseFuture = http.get(
        Uri.parse('${ApiService.baseUrl}/Session/course-sessions/${widget.courseId}/Section'),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      final results = await Future.wait([lecturesResponseFuture, sectionsResponseFuture]);
      final lecturesResponse = results[0];
      final sectionsResponse = results[1];

      if (lecturesResponse.statusCode == 200 && sectionsResponse.statusCode == 200) {
        final parsedLectures = _extractList(jsonDecode(lecturesResponse.body));
        final parsedSections = _extractList(jsonDecode(sectionsResponse.body));
        
        setState(() {
          _lectures = parsedLectures.reversed.toList();
          _sections = parsedSections.reversed.toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load sessions. Server returned code ${lecturesResponse.statusCode}.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    } else if (data is Map && data.containsKey('\$values')) {
      return data['\$values'];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: const Text('Session History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: 'Lectures', icon: Icon(Icons.school)),
            Tab(text: 'Sections', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSessionList(_lectures, 'Lecture'),
                    _buildSessionList(_sections, 'Section'),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.errorColor)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchSessions,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(List<dynamic> sessions, String type) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.indigo.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No $type sessions found.', style: TextStyle(fontSize: 18, color: Colors.indigo.withOpacity(0.5))),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 900 ? 3 : w >= 600 ? 2 : 1;
          if (cols > 1) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 3 ? 2.5 : 3.0,
              ),
              itemCount: sessions.length,
              itemBuilder: (context, index) => _buildSessionCard(sessions[index], type),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) => _buildSessionCard(sessions[index], type),
          );
        }),
      ),
    );
  }

  Widget _buildSessionCard(dynamic session, String type) {
    final sessionId = session['id']?.toString() ?? session['sessionId']?.toString() ?? '0';
    final title = session['title'] ?? '$type #$sessionId';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionAttendeesPage(
                sessionId: sessionId,
                sessionTitle: title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.class_, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: #$sessionId',
                      style: TextStyle(color: AppColors.darkColor.withOpacity(0.5), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
