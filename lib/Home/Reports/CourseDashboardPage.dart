import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/responsive.dart';
import '../../Auth/colors.dart';
import 'LectureReportPage.dart';
import 'SectionReportPage.dart';
import 'AbsenceWarningsPage.dart';
import 'CourseSessionsHistoryPage.dart';
import 'EnrolledStudentsPage.dart';
import 'CreateSessionPage.dart';
import '../../features/session/session_service.dart';

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: CustomScrollView(
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
              centerTitle: Responsive.isDesktop(context),
              titlePadding: Responsive.isDesktop(context)
                  ? const EdgeInsets.only(bottom: 20)
                  : const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: Responsive.isDesktop(context) ? 18 : 14,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: Icon(
                      Icons.class_,
                      color: Colors.white,
                      size: Responsive.isDesktop(context) ? 20 : 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      courseName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.isDesktop(context) ? 18 : 15,
                        fontWeight: FontWeight.bold,
                      ),
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
                  padding: EdgeInsets.only(left: 24, top: Responsive.isDesktop(context) ? 60 : 70, right: 24),
                  child: Column(
                    crossAxisAlignment: Responsive.isDesktop(context) ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course ID: ${widget.course['id']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: Responsive.isDesktop(context) ? 15 : 13,
                        ),
                      ),
                      if (doctorName.isNotEmpty)
                        Text(
                          'Dr. $doctorName',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: Responsive.isDesktop(context) ? 15 : 13,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: Responsive.isDesktop(context) ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          _infoPill(
                            Icons.people,
                            '$studentCountLabel students',
                          ),
                          if (courseCode.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            _infoPill(Icons.tag, courseCode),
                          ],
                        ],
                      ),
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
                  // ═══ Reports Section (Doctor/TA only) ══════════════════════════
                  if (!isAdmin) ...[
                    Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: Responsive.isDesktop(context) ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      final w = MediaQuery.of(context).size.width;
                      final cols = w >= 1100 ? 4 : w >= 850 ? 3 : 2;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.1,
                        children: [
                          _reportCard(
                            title: 'Lecture Report',
                            subtitle: 'Attendance insights',
                            icon: Icons.menu_book,
                            color: AppColors.primaryColor,
                            onTap: () =>
                                _goto(LectureReportPage(courseId: courseId)),
                          ),
                          _reportCard(
                            title: 'Section Report',
                            subtitle: 'Labs & Exercises',
                            icon: Icons.science,
                            color: const Color(0xFF2E7D32),
                            onTap: () =>
                                _goto(SectionReportPage(courseId: courseId)),
                          ),
                          _reportCard(
                            title: 'Session History',
                            subtitle: 'Past sessions',
                            icon: Icons.history_edu,
                            color: Colors.indigo,
                            onTap: () => _goto(
                              CourseSessionsHistoryPage(courseId: courseId),
                            ),
                          ),
                          _reportCard(
                            title: 'Absence Warnings',
                            subtitle: 'At-risk students',
                            icon: Icons.warning_amber_rounded,
                            color: AppColors.errorColor,
                            onTap: () =>
                                _goto(AbsenceWarningsPage(courseId: courseId)),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 32),
                  ],

                  // ═══ Doctor/TA — Session Management ═════════════════════════
                  if (isDoctor) ...[
                    Text(
                      'Session Management',
                      style: TextStyle(
                        fontSize: Responsive.isDesktop(context) ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _actionCard(
                      title: 'Start New Session',
                      subtitle: 'Create a Lecture or Section session with GPS',
                      icon: Icons.play_circle_fill,
                      color: AppColors.darkColor,
                      onTap: () => _goto(
                        CreateSessionPage(
                          courseId: courseId,
                          courseName: courseName,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _actionCard(
                      title: 'Stop Active Session',
                      subtitle: 'Manually stop a running session by ID',
                      icon: Icons.stop_circle,
                      color: AppColors.errorColor,
                      onTap: _showStopSessionDialog,
                    ),
                    const SizedBox(height: 12),
                    _actionCard(
                      title: 'View All Sessions',
                      subtitle:
                          'Lectures & Sections history · Tap to see attendees',
                      icon: Icons.list_alt,
                      color: Colors.indigo,
                      onTap: () =>
                          _goto(CourseSessionsHistoryPage(courseId: courseId)),
                    ),
                  ],

                  // ═══ Admin — Course Management ═══════════════════════════════
                  if (isAdmin) ...[
                    Text(
                      'Course Management',
                      style: TextStyle(
                        fontSize: Responsive.isDesktop(context) ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _actionCard(
                      title: 'Enrolled Students',
                      subtitle:
                          'View and search enrolled students · Debounce search',
                      icon: Icons.group,
                      color: const Color(0xFF0277BD),
                      onTap: () =>
                          _goto(EnrolledStudentsPage(courseId: courseId)),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _goto(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _infoPill(IconData icon, String label) => Container(
    padding: EdgeInsets.symmetric(horizontal: Responsive.isDesktop(context) ? 14 : 10, vertical: Responsive.isDesktop(context) ? 6 : 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Responsive.isDesktop(context) ? 16 : 13, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white, fontSize: Responsive.isDesktop(context) ? 14 : 12)),
      ],
    ),
  );

  Widget _reportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: EdgeInsets.all(Responsive.isDesktop(context) ? 24 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.isDesktop(context) ? 18 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: Responsive.isDesktop(context) ? 40 : 26, color: color),
          ),
          SizedBox(height: Responsive.isDesktop(context) ? 18 : 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.isDesktop(context) ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.isDesktop(context) ? 14 : 10,
              color: AppColors.darkColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: EdgeInsets.all(Responsive.isDesktop(context) ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.isDesktop(context) ? 20 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: Responsive.isDesktop(context) ? 40 : 26, color: color),
          ),
          SizedBox(width: Responsive.isDesktop(context) ? 24 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.isDesktop(context) ? 20 : 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: Responsive.isDesktop(context) ? 16 : 12,
                    color: AppColors.darkColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: Responsive.isDesktop(context) ? 22 : 16,
            color: AppColors.darkColor.withOpacity(0.3),
          ),
        ],
      ),
    ),
  );

  Future<void> _showStopSessionDialog() async {
    final TextEditingController idController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Stop Active Session', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter the Session ID you wish to stop:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: idController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Session ID',
                      prefixIcon: const Icon(Icons.numbers, color: AppColors.primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(100, 45),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final idText = idController.text.trim();
                          if (idText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a Session ID')),
                            );
                            return;
                          }
                          final sessionId = int.tryParse(idText);
                          if (sessionId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid Session ID format')),
                            );
                            return;
                          }

                          setState(() => isSubmitting = true);

                          try {
                            await SessionService().stopSession(sessionId);
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Session $sessionId stopped successfully.'),
                                backgroundColor: AppColors.successColor,
                              ),
                            );
                          } catch (e) {
                            setState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error stopping session: $e'),
                                backgroundColor: AppColors.errorColor,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Stop Session', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
