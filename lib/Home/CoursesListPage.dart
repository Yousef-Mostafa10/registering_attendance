import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_toggle_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:registering_attendance/core/http_interceptor.dart' as http;
import 'package:registering_attendance/Home/creatCourse.dart';
import 'package:registering_attendance/Home/QRScannerPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/auth_storage.dart';
import '../Auth/colors.dart';
import '../Auth/api_service.dart';
import 'Reports/CourseDashboardPage.dart';
import 'Reports/StudentSessionsHistoryPage.dart';
import 'package:registering_attendance/Home/CourseEnrollmentPage.dart';
import 'package:registering_attendance/Home/BulkCourseEnrollmentPage.dart';
import '../core/responsive.dart';

class CoursesListPage extends StatefulWidget {
  const CoursesListPage({Key? key}) : super(key: key);

  @override
  _CoursesListPageState createState() => _CoursesListPageState();
}

class _CoursesListPageState extends State<CoursesListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _allCourses = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  int _totalCourses = 0;
  int _totalStudents = 0;

  String? _authToken;
  String? _userRole;
  String _userName = '';
  String _email = '';

  static const String _adminCoursesUrl =
      'http://msngroup-001-site1.ktempurl.com/api/Admin/list-courses';
  static const String _studentCoursesUrl =
      'http://msngroup-001-site1.ktempurl.com/api/Course/student-courses';
  static const String _myCoursesUrl =
      'http://msngroup-001-site1.ktempurl.com/api/Course/my-courses';

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
    _searchController.addListener(_onSearchChanged);
    _loadAndFetch();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_authToken != null) _fetchCourses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _userRole = prefs.getString('user_role');

    final userData = await AuthStorage.getUserData();
    if (userData != null) {
      _userName = userData['userName'] ?? 'Student';
      _email = userData['email'] ?? '';
    }

    if (_authToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }
    await _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // اختيار الـ URL المناسب بناءً على الدور
      String url;
      if (_userRole == 'Admin') {
        url = _adminCoursesUrl;
      } else if (_userRole == 'Doctor' || _userRole == 'TA') {
        url = _myCoursesUrl;
      } else {
        url = _studentCoursesUrl;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        List<dynamic> rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map && decoded.containsKey(r'$values')) {
          rawList = decoded[r'$values'] ?? [];
        }

        List<Map<String, dynamic>> courses = [];
        for (int i = 0; i < rawList.length; i++) {
          var c = rawList[i];
          int? studentCount = c['studentCount'] != null
              ? int.tryParse(c['studentCount'].toString())
              : null;

          courses.add({
            'id': c['id']?.toString() ?? c['courseId']?.toString() ?? '',
            'name': c['name'] ?? c['courseName'] ?? 'Unknown',
            'doctorName': c['doctorName'] ?? c['instructorName'] ?? '',
            'studentCount': studentCount,
            'role': c['role'], // Doctor/TA chip
            'staff': c['staff'], // Student avatars
            'code': c['code'] ?? '',
            'color': _colors[i % _colors.length],
          });
        }

        // للدكتور: جلب عدد الطلاب لكل كورس من endpoint منفصل
        if ((_userRole == 'Doctor' || _userRole == 'TA') &&
            courses.isNotEmpty) {
          await _fetchEnrolledCountsForCourses(courses);
        }

        int totalStudents = 0;
        for (var c in courses) {
          totalStudents += (c['studentCount'] as int? ?? 0);
        }

        if (mounted) {
          setState(() {
            _allCourses = courses;
            _totalCourses = courses.length;
            _totalStudents = totalStudents;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Session expired. Please login again.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _deleteCourseDirectly(String courseId, String courseName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.confirmDeletion, style: const TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('${AppLocalizations.of(context)!.confirmDeletion} "$courseName"?\n\n${AppLocalizations.of(context)!.thisActionCannotBeUndone}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final deleteUrl = 'http://msngroup-001-site1.ktempurl.com/api/Admin/delete-course/$courseId';
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course deleted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchCourses();
      } else {
        var errorMsg = 'Failed to delete course';
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) errorMsg = data['message'];
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// جلب عدد الطلاب لكل كورس للدكتور/TA من /Course/number-of-enrolled-students/{id}
  Future<void> _fetchEnrolledCountsForCourses(
    List<Map<String, dynamic>> courses,
  ) async {
    final futures = courses.map((course) async {
      try {
        final res = await ApiService.getEnrolledCount(
          courseId: course['id'].toString(),
          token: _authToken!,
        );
        if (res['statusCode'] == 200) {
          final data = jsonDecode(res['body']);
          // الـ API ممكن يرجع { "count": 5 } أو مجرد رقم
          int count = 0;
          if (data is int) {
            count = data;
          } else if (data is Map) {
            count = int.tryParse(data['count']?.toString() ?? '0') ?? 0;
          }
          course['studentCount'] = count;
        }
      } catch (_) {
        // تجاهل الخطأ — الرقم سيبقى null
      }
    }).toList();

    await Future.wait(futures);
  }

  List<Map<String, dynamic>> get _filteredCourses {
    if (_searchQuery.isEmpty) return _allCourses;
    return _allCourses.where((c) {
      return c['name'].toString().toLowerCase().contains(_searchQuery) ||
          c['doctorName'].toString().toLowerCase().contains(_searchQuery) ||
          c['id'].toString().contains(_searchQuery);
    }).toList();
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
                    child: Text(AppLocalizations.of(context)!.logout, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      await AuthStorage.clearUserData();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: _userRole == 'Student' ? 140 : null,
            collapsedHeight: _userRole == 'Student' ? 80 : null,
            pinned: _userRole == 'Student' ? true : false,
            floating: true,
            snap: _userRole != 'Student',
            backgroundColor: AppColors.primaryColor,
            elevation: _userRole == 'Student' ? 8 : 4,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            automaticallyImplyLeading: false,
            leading: _userRole == 'Student' ? null : IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: _userRole == 'Student' ? FlexibleSpaceBar(
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
                          'Student Dashboard',
                          style: TextStyle(color: Colors.white, fontSize: Responsive.isDesktop(context) ? 20 : 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _userName,
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
            ) : null,
            title: _userRole == 'Student' ? null : Row(
              children: [
                CircleAvatar(
                  radius: Responsive.isDesktop(context) ? 20 : 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.school, color: Colors.white, size: Responsive.isDesktop(context) ? 22 : 18),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _userRole == 'Doctor' || _userRole == 'TA'
                        ? 'My Courses'
                        : 'Courses List',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.isDesktop(context) ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              LanguageToggleButton(),
              if (_userRole == 'Admin' || _userRole == 'Doctor')
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateCoursePage()),
                  ),
                ),
              if (_userRole != 'Student')
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _fetchCourses,
                ),
              if (_userRole == 'Student')
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
            bottom: _userRole == 'Student' ? null : PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  top: 4,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.searchByNameCode,
                            hintStyle: const TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () => _searchController.clear(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
          children: [
            if (_userRole == 'Student')
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome Student,',
                                    style: TextStyle(fontSize: Responsive.isDesktop(context) ? 18 : 16, color: AppColors.darkColor.withOpacity(0.7))),
                                Text(_userName,
                                    style: TextStyle(fontSize: Responsive.isDesktop(context) ? 28 : 22, fontWeight: FontWeight.bold, color: AppColors.darkColor)),
                                Text(_email,
                                    style: TextStyle(fontSize: Responsive.isDesktop(context) ? 16 : 13, color: AppColors.darkColor.withOpacity(0.5))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_userRole != 'Student')
              Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(builder: (context) {
                  final w = MediaQuery.of(context).size.width;
                  if (w >= 850) {
                    final available = w > 1400 ? 1400.0 : w;
                    final cardW = (available - 80) / 2;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: cardW,
                          child: _buildStatCard(
                            icon: Icons.book,
                            title: 'Total Courses',
                            value: _isLoading ? '...' : _totalCourses.toString(),
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: cardW,
                          child: _buildStatCard(
                            icon: Icons.people,
                            title: 'Total Students',
                            value: _isLoading ? '...' : _totalStudents.toString(),
                            color: AppColors.successColor,
                          ),
                        ),
                      ],
                    );
                  }
                  // mobile: full-width side by side
                  return Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.book,
                        title: 'Total Courses',
                        value: _isLoading ? '...' : _totalCourses.toString(),
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.people,
                        title: 'Total Students',
                        value: _isLoading ? '...' : _totalStudents.toString(),
                        color: AppColors.successColor,
                      ),
                    ],
                  );
                }),
              ),

            // Content
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 4,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    )
                  : _errorMessage.isNotEmpty
                  ? _buildErrorState()
                  : _filteredCourses.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchCourses,
                      color: AppColors.primaryColor,
                      child: Builder(builder: (context) {
                        final w = MediaQuery.of(context).size.width;
                        final cols = w >= 1100 ? 3 : w >= 850 ? 2 : 1;
                        if (cols > 1) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: cols == 3 ? 1.6 : 1.9,
                            ),
                            itemCount: _filteredCourses.length,
                            itemBuilder: (_, i) => _buildCourseCard(_filteredCourses[i]),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredCourses.length,
                          itemBuilder: (_, i) =>
                              _buildCourseCard(_filteredCourses[i]),
                        );
                      }),
                    ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Responsive.isDesktop(context) ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.isDesktop(context) ? 64 : 48,
              height: Responsive.isDesktop(context) ? 64 : 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: Responsive.isDesktop(context) ? 32 : 24),
            ),
            SizedBox(width: Responsive.isDesktop(context) ? 20 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: Responsive.isDesktop(context) ? 28 : 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkColor,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.isDesktop(context) ? 14 : 12,
                      color: AppColors.darkColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final Color color = course['color'] as Color;
    final String? role = course['role']?.toString(); // Doctor/TA chip
    final dynamic staffList = course['staff']; // Student role avatars

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // جميع الأدوار (Admin/Doctor/TA) يفتحون نفس Course Dashboard
            if (_userRole == 'Admin' ||
                _userRole == 'Doctor' ||
                _userRole == 'TA') {
              _showCourseOptions(course);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentSessionsHistoryPage(
                    courseId: course['id'].toString(),
                    courseName: course['name'].toString(),
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Color Indicator
                Container(
                  width: 4,
                  height: 70,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),

                // Course Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: ID + Student Count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: ${course['id']}',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final count = course['studentCount'];
                              return Chip(
                                label: Text(
                                  count == null
                                      ? '— students'
                                      : '$count student${count == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: AppColors.lightColor,
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Course Name
                      Text(
                        course['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkColor,
                        ),
                      ),

                      // Doctor Name (للأدمن والطالب فقط)
                      if (course['doctorName']?.toString().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dr. ${course['doctorName']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.darkColor.withOpacity(0.65),
                          ),
                        ),
                      ],

                      // Role Chip (للدكتور/TA فقط — Main Doctor = أزرق / Assistant = رمادي)
                      if (role != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            role,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: role.toLowerCase().contains('main')
                              ? Colors.blue
                              : Colors.grey,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],

                      // Staff Avatars (للطالب فقط)
                      if (staffList != null &&
                          staffList is List &&
                          staffList.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: (staffList).take(4).map<Widget>((s) {
                            final name = s['name']?.toString() ?? '?';
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.primaryColor
                                    .withOpacity(0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_userRole == 'Admin')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteCourseDirectly(course['id'].toString(), course['name'].toString()),
                    tooltip: 'Delete Course',
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.darkColor.withOpacity(0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCourseOptions(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                course['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.darkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Course ID: ${course['id']}',
                style: TextStyle(
                  color: AppColors.darkColor.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionTile(
                icon: Icons.dashboard_outlined,
                title: 'View Dashboard',
                subtitle: 'Analytics and session management',
                color: AppColors.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CourseDashboardPage(course: course)),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Enroll Student',
                subtitle: 'Single student manual registration',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseEnrollmentPage(initialCourseId: course['id'].toString()),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.group_add_outlined,
                title: 'Bulk Enroll',
                subtitle: 'Excel import or multiple codes',
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BulkCourseEnrollmentPage(initialCourseId: course['id'].toString()),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.darkColor.withOpacity(0.5)),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCourses,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: AppColors.darkColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No courses available',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.darkColor.withOpacity(0.5),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.darkColor.withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
