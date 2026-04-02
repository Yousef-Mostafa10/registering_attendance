import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Auth/colors.dart';
import 'LectureReportPage.dart';
import 'SectionReportPage.dart';
import 'AbsenceWarningsPage.dart';
import 'CourseSessionsHistoryPage.dart';
import 'EnrolledStudentsPage.dart';
import '../../features/session/create_session_screen.dart';

class CourseDashboardPage extends StatefulWidget {
  final Map<String, dynamic> course;

  const CourseDashboardPage({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseDashboardPage> createState() => _CourseDashboardPageState();
}

class _CourseDashboardPageState extends State<CourseDashboardPage> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    if (mounted) setState(() => _userRole = role);
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.course['color'] ?? AppColors.primaryColor;
    final String courseId = widget.course['id'].toString();
    final String courseName = widget.course['name'] ?? 'Course';
    final String doctorName = widget.course['doctorName'] ?? '';
    final dynamic count = widget.course['studentCount'];
    final String studentCountLabel = count == null ? '—' : count.toString();
    final String courseCode = widget.course['code']?.toString() ?? '';

    final bool isDoctor = _userRole == 'Doctor' || _userRole == 'TA';
    final bool isAdmin = _userRole == 'Admin';

    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: color,
            elevation: 0,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: const Icon(Icons.class_, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      courseName,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, AppColors.darkColor],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, top: 70, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Course ID: ${widget.course['id']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                      if (doctorName.isNotEmpty)
                        Text('Dr. $doctorName',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _infoPill(Icons.people, '$studentCountLabel students'),
                        if (courseCode.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _infoPill(Icons.tag, courseCode),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ═══ Reports Section (مشترك للكل) ══════════════════════════
                  const Text('Reports & Analytics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                    children: [
                      _reportCard(
                        title: 'Lecture Report',
                        subtitle: 'Attendance insights',
                        icon: Icons.menu_book,
                        color: AppColors.primaryColor,
                        onTap: () => _goto(LectureReportPage(courseId: courseId)),
                      ),
                      _reportCard(
                        title: 'Section Report',
                        subtitle: 'Labs & Exercises',
                        icon: Icons.science,
                        color: const Color(0xFF2E7D32),
                        onTap: () => _goto(SectionReportPage(courseId: courseId)),
                      ),
                      _reportCard(
                        title: 'Session History',
                        subtitle: 'Past sessions',
                        icon: Icons.history_edu,
                        color: Colors.indigo,
                        onTap: () => _goto(CourseSessionsHistoryPage(courseId: courseId)),
                      ),
                      _reportCard(
                        title: 'Absence Warnings',
                        subtitle: 'At-risk students',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.errorColor,
                        onTap: () => _goto(AbsenceWarningsPage(courseId: courseId)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ═══ Doctor/TA — Session Management ═════════════════════════
                  if (isDoctor) ...[
                    const Text('Session Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
                    const SizedBox(height: 16),
                    _actionCard(
                      title: 'Start New Session',
                      subtitle: 'Create a Lecture or Section session with GPS',
                      icon: Icons.play_circle_fill,
                      color: AppColors.darkColor,
                      onTap: () => _goto(CreateSessionScreen(courseId: int.tryParse(courseId) ?? 0)),
                    ),
                    const SizedBox(height: 12),
                    _actionCard(
                      title: 'View All Sessions',
                      subtitle: 'Lectures & Sections history · Tap to see attendees',
                      icon: Icons.list_alt,
                      color: Colors.indigo,
                      onTap: () => _goto(CourseSessionsHistoryPage(courseId: courseId)),
                    ),
                  ],

                  // ═══ Admin — Course Management ═══════════════════════════════
                  if (isAdmin) ...[
                    const Text('Course Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
                    const SizedBox(height: 16),
                    _actionCard(
                      title: 'Enrolled Students',
                      subtitle: 'View and search enrolled students · Debounce search',
                      icon: Icons.group,
                      color: const Color(0xFF0277BD),
                      onTap: () => _goto(EnrolledStudentsPage(courseId: courseId)),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goto(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _infoPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]),
  );

  Widget _reportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.darkColor.withOpacity(0.5))),
          ]),
        ),
      );

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.darkColor.withOpacity(0.5))),
              ]),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkColor.withOpacity(0.3)),
          ]),
        ),
      );
}
