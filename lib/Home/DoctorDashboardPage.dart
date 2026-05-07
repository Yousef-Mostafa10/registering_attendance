import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:registering_attendance/core/http_interceptor.dart' as http;
import '../core/responsive.dart';
import '../Auth/auth_storage.dart';
import '../Auth/colors.dart';
import '../Auth/api_service.dart';
import 'Reports/CourseDashboardPage.dart';
// import 'creatCourse.dart'; // Removed as unused

/// الشاشة الرئيسية للدكتور / TA بعد تسجيل الدخول
class DoctorDashboardPage extends StatefulWidget {
  final String userName;
  final String email;
  final String role;
  final String token;

  const DoctorDashboardPage({
    Key? key,
    required this.userName,
    required this.email,
    required this.role,
    required this.token,
  }) : super(key: key);

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _allCourses = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  int _totalStudents = 0;

  static const String _myCoursesUrl =
      '${ApiService.baseUrl}/Course/my-courses';

  final List<Color> _colors = [
    const Color(0xFF1A9E8F),
    const Color(0xFF2E7D32),
    const Color(0xFF1565C0),
    const Color(0xFF6A1B9A),
    const Color(0xFFE65100),
    const Color(0xFF880E4F),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _loadAndFetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  Future<void> _loadAndFetch() async {
    await _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final response = await http.get(
        Uri.parse(_myCoursesUrl),
        headers: {'accept': '*/*', 'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        List<dynamic> raw = decoded is List ? decoded
            : (decoded is Map && decoded.containsKey(r'$values'))
                ? decoded[r'$values'] ?? []
                : [];

        List<Map<String, dynamic>> courses = [];
        for (int i = 0; i < raw.length; i++) {
          var c = raw[i];
          courses.add({
            'id': c['id']?.toString() ?? '',
            'name': c['name'] ?? 'Unknown',
            'doctorName': c['doctorName'] ?? '',
            'studentCount': null,
            'role': c['role'],
            'staff': c['staff'],
            'code': c['code'] ?? '',
            'color': _colors[i % _colors.length],
          });
        }

        // جلب عدد الطلاب لكل كورس
        await _fetchEnrolledCounts(courses);

        int total = 0;
        for (var c in courses) total += (c['studentCount'] as int? ?? 0);

        if (mounted) {
          setState(() {
            _allCourses = courses;
            _totalStudents = total;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        // انتهت الجلسة - تسجيل خروج تلقائي
        _handleAutoLogout();
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error ${response.statusCode}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  Future<void> _fetchEnrolledCounts(List<Map<String, dynamic>> courses) async {
    await Future.wait(courses.map((c) async {
      try {
        final res = await ApiService.getEnrolledCount(courseId: c['id'], token: widget.token);
        if (res['statusCode'] == 200) {
          final data = jsonDecode(res['body']);
          c['studentCount'] = data is int ? data : (int.tryParse(data['count']?.toString() ?? '') ?? 0);
        }
      } catch (_) {}
    }));
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _allCourses;
    return _allCourses.where((c) =>
        c['name'].toString().toLowerCase().contains(_searchQuery) ||
        c['id'].toString().contains(_searchQuery)).toList();
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.errorColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Logout',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to logout from your account?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.darkColor),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      await _handleAutoLogout();
    }
  }

  Future<void> _handleAutoLogout() async {
    if (!mounted) return;
    await AuthStorage.clearUserData();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: CustomScrollView(
        slivers: [

          // ── 1. Header (نفس شكل AdminDashboard) ────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            collapsedHeight: 80,
            pinned: true,
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primaryColor,
            elevation: 8,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
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
                    backgroundColor: Colors.white.withOpacity(0.2),
                    radius: Responsive.isDesktop(context) ? 20 : 16,
                    child: Icon(Icons.school, color: Colors.white, size: Responsive.isDesktop(context) ? 24 : 20),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.role} Dashboard',
                          style: TextStyle(color: Colors.white, fontSize: Responsive.isDesktop(context) ? 20 : 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.userName,
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: Responsive.isDesktop(context) ? 14 : 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryColor, AppColors.darkColor],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, size: 22, color: Colors.white),
                ),
                onPressed: _logout,
              ),
              const SizedBox(width: 10),
            ],
          ),

          // ── 2. Welcome Card (نفس شكل AdminDashboard) ──────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4))],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.lightColor, Colors.white],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: Responsive.isDesktop(context) ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Container(
                          width: Responsive.isDesktop(context) ? 80 : 60,
                          height: Responsive.isDesktop(context) ? 80 : 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppColors.secondaryColor, AppColors.accentColor]),
                            boxShadow: [BoxShadow(color: AppColors.secondaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Icon(Icons.verified_user, color: Colors.white, size: Responsive.isDesktop(context) ? 40 : 30),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: Responsive.isDesktop(context) ? CrossAxisAlignment.start : CrossAxisAlignment.start,
                          children: [
                            Text('Welcome ${widget.role},',
                                style: TextStyle(fontSize: Responsive.isDesktop(context) ? 18 : 16, color: AppColors.darkColor.withOpacity(0.7))),
                            Text(widget.userName,
                                style: TextStyle(fontSize: Responsive.isDesktop(context) ? 28 : 22, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
                            Text(widget.email,
                                style: TextStyle(fontSize: Responsive.isDesktop(context) ? 16 : 13, color: AppColors.darkColor.withOpacity(0.5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 3. Quick Actions: Add Course + inline Search ───────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar — always visible
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search, color: AppColors.primaryColor.withOpacity(0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search courses...',
                            hintStyle: TextStyle(color: AppColors.darkColor.withOpacity(0.4)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: AppColors.darkColor.withOpacity(0.4), size: 20),
                          onPressed: () => _searchCtrl.clear(),
                        ),
                      const SizedBox(width: 4),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.isDesktop(context) ? 40 : 20, vertical: 20),
              child: Builder(builder: (context) {
                final w = MediaQuery.of(context).size.width;
                final available = w > 1400 ? 1400.0 : w;
                final cardW = w >= 1100 ? (available - 100) / 2 : w >= 850 ? (available - 60) / 2 : (w - 52) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: cardW,
                      child: _statCard(Icons.book, 'Total Courses', _isLoading ? '...' : _allCourses.length.toString(), AppColors.primaryColor),
                    ),
                    SizedBox(
                      width: cardW,
                      child: _statCard(Icons.people, 'Total Students', _isLoading ? '...' : _totalStudents.toString(), AppColors.successColor),
                    ),
                  ],
                );
              }),
            ),
          ),

          // ── 5. Courses Label ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('My Courses',
                  textAlign: Responsive.isDesktop(context) ? TextAlign.center : TextAlign.start,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
            ),
          ),

          // ── 6. Course List ─────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)))
          else if (_errorMessage.isNotEmpty)
            SliverFillRemaining(child: _buildError())
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            Builder(builder: (context) {
              final w = MediaQuery.of(context).size.width;
              final cols = w >= 1100 ? 3 : w >= 850 ? 2 : 1;
              if (cols > 1) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: cols == 3 ? 1.6 : 1.9,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _courseCard(_filtered[i]),
                      childCount: _filtered.length,
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _courseCard(_filtered[i]),
                  ),
                  childCount: _filtered.length,
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
  }



  Widget _statCard(IconData icon, String title, String value, Color color) => Container(
    padding: EdgeInsets.all(Responsive.isDesktop(context) ? 24 : 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(
      children: [
        Container(
          width: Responsive.isDesktop(context) ? 80 : 56,
          height: Responsive.isDesktop(context) ? 80 : 56,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: Responsive.isDesktop(context) ? 40 : 28),
        ),
        SizedBox(width: Responsive.isDesktop(context) ? 24 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: Responsive.isDesktop(context) ? 36 : 24, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
              Text(title, style: TextStyle(fontSize: Responsive.isDesktop(context) ? 18 : 14, color: AppColors.darkColor.withOpacity(0.6))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _courseCard(Map<String, dynamic> course) {
    final Color color = course['color'] as Color;
    final String? role = course['role']?.toString();
    final dynamic count = course['studentCount'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CourseDashboardPage(course: course),
        )),
        child: Padding(
          padding: EdgeInsets.all(Responsive.isDesktop(context) ? 24 : 16),
          child: Row(children: [
            Container(width: Responsive.isDesktop(context) ? 8 : 4, height: Responsive.isDesktop(context) ? 120 : 70, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            SizedBox(width: Responsive.isDesktop(context) ? 24 : 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.isDesktop(context) ? 14 : 8, vertical: Responsive.isDesktop(context) ? 8 : 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('ID: ${course['id']}', style: TextStyle(color: color, fontSize: Responsive.isDesktop(context) ? 16 : 12, fontWeight: FontWeight.bold)),
                  ),
                  Chip(
                    label: Text(
                      count == null ? '— students' : '$count student${count == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: Responsive.isDesktop(context) ? 14 : 11),
                    ),
                    backgroundColor: AppColors.lightColor,
                    visualDensity: VisualDensity.compact,
                    padding: Responsive.isDesktop(context) ? const EdgeInsets.all(6) : null,
                  ),
                ]),
                SizedBox(height: Responsive.isDesktop(context) ? 16 : 8),
                Text(course['name'], style: TextStyle(fontSize: Responsive.isDesktop(context) ? 26 : 16, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
                if (role != null) ...[
                  SizedBox(height: Responsive.isDesktop(context) ? 16 : 8),
                  Chip(
                    label: Text(role, style: TextStyle(color: Colors.white, fontSize: Responsive.isDesktop(context) ? 14 : 12)),
                    backgroundColor: role.toLowerCase().contains('main') ? Colors.blue : Colors.grey,
                    visualDensity: VisualDensity.compact,
                    padding: Responsive.isDesktop(context) ? const EdgeInsets.all(6) : null,
                  ),
                ],
              ]),
            ),
            SizedBox(width: Responsive.isDesktop(context) ? 16 : 8),
            Icon(Icons.arrow_forward_ios, size: Responsive.isDesktop(context) ? 24 : 16, color: AppColors.darkColor.withOpacity(0.3)),
          ]),
        ),
      ),
    );
  }

  Widget _buildError() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
    const SizedBox(height: 16),
    Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.errorColor)),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: _fetchCourses, icon: const Icon(Icons.refresh), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor)),
  ])));

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.book_outlined, size: 80, color: AppColors.darkColor.withOpacity(0.2)),
    const SizedBox(height: 16),
    Text(_searchQuery.isEmpty ? 'No courses assigned yet' : 'No courses match your search',
        style: TextStyle(fontSize: 16, color: AppColors.darkColor.withOpacity(0.5))),
  ]));
}

