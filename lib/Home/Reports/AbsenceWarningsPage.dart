import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Auth/api_service.dart';
import '../../Auth/colors.dart';

class AbsenceWarningsPage extends StatefulWidget {
  final String courseId;
  const AbsenceWarningsPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<AbsenceWarningsPage> createState() => _AbsenceWarningsPageState();
}

class _AbsenceWarningsPageState extends State<AbsenceWarningsPage> {
  bool _isLoading = false;
  String _errorMessage = '';
  List<dynamic> _warnings = [];
  int _totalLectures = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) throw Exception('Not authenticated');

      // URL الصحيح: GET /Attendance/absence-warnings/{courseId}
      final res = await ApiService.getAbsenceWarnings(courseId: widget.courseId, token: token);

      if (res['statusCode'] == 200) {
        final data = jsonDecode(res['body']);
        List<dynamic> list = [];
        int total = 0;
        if (data is List) {
          list = data;
        } else if (data is Map) {
          total = data['courseTotalLectures'] ?? data['totalLectures'] ?? 0;
          final raw = data['students'] ?? data[r'$values'] ?? data;
          if (raw is List) list = raw;
          else if (raw is Map && raw.containsKey(r'$values')) list = raw[r'$values'] ?? [];
        }
        setState(() { _warnings = list; _totalLectures = total; });
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
        title: const Text('Absence Warnings'),
        backgroundColor: AppColors.errorColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.errorColor))
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : _warnings.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
        ),
      ),
    );
  }

  Widget _buildError() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
    const SizedBox(height: 16),
    Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.errorColor)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _fetch, style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor), child: const Text('Retry')),
  ])));

  Widget _buildEmpty() {
    final bool notEnough = _totalLectures <= 3;
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(notEnough ? Icons.schedule : Icons.check_circle_outline,
          size: 80, color: notEnough ? Colors.orange : Colors.green),
      const SizedBox(height: 20),
      Text(
        notEnough
            ? 'No warnings yet — not enough lectures held'
            : 'No absence warnings!\nAll students are within limits.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    ])));
  }

  Widget _buildList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.errorColor.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text('${_warnings.length} student(s) at risk',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.errorColor)),
        ),
        Expanded(
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
                  childAspectRatio: cols == 3 ? 1.2 : 1.4,
                ),
                itemCount: _warnings.length,
                itemBuilder: (_, i) => _buildWarningCard(_warnings[i]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _warnings.length,
              itemBuilder: (_, i) => _buildWarningCard(_warnings[i]),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildWarningCard(dynamic w) {
    final String name = w['studentName'] ?? 'Unknown';
    final String code = w['universityCode'] ?? '—';
    final int attended = w['lectureAttended'] ?? w['attended'] ?? 0;
    final int absent = w['absenceInLectures'] ?? w['absent'] ?? 0;
    final int total = (attended + absent);
    final double pct = total > 0 ? (attended / total) * 100 : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.errorColor.withOpacity(0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.errorColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Code: $code', style: TextStyle(color: AppColors.darkColor.withOpacity(0.5), fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppColors.errorColor, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? attended / total : 0,
              backgroundColor: AppColors.errorColor.withOpacity(0.15),
              color: pct >= 75 ? Colors.green : (pct >= 50 ? Colors.orange : AppColors.errorColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Attended: $attended', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('Absent: $absent', style: const TextStyle(color: AppColors.errorColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
