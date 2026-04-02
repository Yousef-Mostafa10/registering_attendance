import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Auth/api_service.dart';
import '../../Auth/colors.dart';

class LectureReportPage extends StatefulWidget {
  final String courseId;
  const LectureReportPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<LectureReportPage> createState() => _LectureReportPageState();
}

class _LectureReportPageState extends State<LectureReportPage> {
  final TextEditingController _marksCtrl = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  int _totalLectures = 0;
  double? _marksAssigned;
  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({String? totalMarks}) async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) throw Exception('Not authenticated');

      // URL الصحيح: GET /Attendance/lecture-report/{courseId}?totalMarks=X
      final res = await ApiService.getLectureReport(
        courseId: widget.courseId,
        token: token,
        totalMarks: totalMarks,
      );

      if (res['statusCode'] == 200) {
        final data = jsonDecode(res['body']);
        List<dynamic> students = [];
        if (data['students'] is List) {
          students = data['students'];
        } else if (data['students'] is Map && data['students'].containsKey(r'$values')) {
          students = data['students'][r'$values'] ?? [];
        }

        setState(() {
          _totalLectures = data['courseTotalLectures'] ?? 0;
          _marksAssigned = data['totalMarksAssigned'] != null
              ? (data['totalMarksAssigned'] as num).toDouble()
              : null;
          _students = students;
        });
      } else if (res['statusCode'] == 403) {
        setState(() => _errorMessage = 'Forbidden: You are not assigned to this course.');
      } else {
        setState(() => _errorMessage = 'Error ${res['statusCode']}: ${res['body']}');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: const Text('Lecture Report'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _fetch(totalMarks: _marksCtrl.text.isNotEmpty ? _marksCtrl.text : null))],
      ),
      body: Column(
        children: [
          // ─ Marks Input ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _marksCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Marks (optional)',
                      hintText: 'e.g. 10',
                      prefixIcon: const Icon(Icons.grade, color: AppColors.primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _fetch(totalMarks: _marksCtrl.text.isNotEmpty ? _marksCtrl.text : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryColor,
                    foregroundColor: AppColors.darkColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),

          // ─ Summary ─────────────────────────────────────────────────────────
          if (!_isLoading && _errorMessage.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _pill(Icons.menu_book, 'Total Lectures: $_totalLectures', AppColors.primaryColor),
                  if (_marksAssigned != null) ...[
                    const SizedBox(width: 10),
                    _pill(Icons.star, 'Marks: ${_marksAssigned!.toStringAsFixed(1)}', AppColors.warningColor),
                  ],
                ],
              ),
            ),

          // ─ Body ────────────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    if (_errorMessage.isNotEmpty) return _errorState();
    if (_students.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (_, i) => _studentCard(_students[i]),
    );
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final String name = s['studentName'] ?? 'Unknown';
    final String code = s['universityCode'] ?? '—';
    final int attended = s['lectureAttended'] ?? 0;
    final int absent = s['absenceInLectures'] ?? 0;
    final double? marks = s['earnedMarks'] != null ? (s['earnedMarks'] as num).toDouble() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Code: $code', style: TextStyle(color: AppColors.darkColor.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ),
                if (marks != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${marks.toStringAsFixed(1)} pts', style: const TextStyle(color: AppColors.warningColor, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Attended', attended.toString(), Colors.green),
                _miniStat('Absent', absent.toString(), AppColors.errorColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() => Center(
    child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
        const SizedBox(height: 16),
        Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.errorColor)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () => _fetch(), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor), child: const Text('Retry')),
      ]),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.speaker_notes_off, size: 72, color: AppColors.darkColor.withOpacity(0.2)),
      const SizedBox(height: 16),
      Text('No attendance records found', style: TextStyle(fontSize: 16, color: AppColors.darkColor.withOpacity(0.5))),
    ]),
  );

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );

  Widget _miniStat(String label, String val, Color color) => Column(children: [
    Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
    Text(label, style: TextStyle(fontSize: 12, color: AppColors.darkColor.withOpacity(0.5))),
  ]);
}
