// admin_dashboard.dart مع إصلاح خطأ نوع البيانات وتحسين الأداء
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:registering_attendance/Home/BulkCourseEnrollmentPage.dart';
import 'package:registering_attendance/Home/CourseEnrollmentPage.dart';
import 'package:registering_attendance/Home/CoursesListPage.dart';
import 'package:registering_attendance/Home/CreateStudentsBulkPage.dart';
import 'package:registering_attendance/Home/DeleteCoursePage.dart';
import 'package:registering_attendance/Home/DeleteStudentsBulkPage.dart';
import 'package:registering_attendance/Home/DeleteUserPage.dart';
import 'package:registering_attendance/Home/DoctorsListPage.dart';
import 'package:registering_attendance/Home/ResetStudentAccountPage.dart';
import 'package:registering_attendance/Home/ResetStudentsForNewYearPage.dart';
import 'package:registering_attendance/Home/TAsListPage.dart';
import 'package:registering_attendance/Home/creatCourse.dart';
import 'package:registering_attendance/Home/creatDoctorOrTA.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/auth_storage.dart';
import '../Auth/colors.dart';

class AdminDashboard extends StatefulWidget {
  final String userName;
  final String email;
  final String role;
  final String token;

  const AdminDashboard({
    Key? key,
    required this.userName,
    required this.email,
    required this.role,
    required this.token,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final StreamController<Map<String, dynamic>> _statsStreamController =
  StreamController<Map<String, dynamic>>.broadcast();
  late Timer _refreshTimer;
  String? _authToken;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();

    // تحديث الإحصائيات كل 30 ثانية تلقائياً
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_authToken != null && _authToken!.isNotEmpty && _userRole == 'Admin') {
        _fetchStatistics();
      }
    });
  }

  @override
  void dispose() {
    _statsStreamController.close();
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadAuthTokenAndStartStream();
  }

  Future<void> _loadAuthTokenAndStartStream() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      _userRole = prefs.getString('user_role');

      if (_authToken != null && _authToken!.isNotEmpty) {
        // بيانات أولية أثناء التحميل
        _statsStreamController.add({
          'doctors': 0,
          'tas': 0,
          'students': 0,
          'courses': 0,
          'loading': true,
        });

        // جلب البيانات فقط للـ Admin
        if (_userRole == 'Admin') {
          await _fetchStatistics();
        } else {
          // للدكتور والـ TA - لا توجد إحصائيات Admin
          _statsStreamController.add({
            'doctors': 0,
            'tas': 0,
            'students': 0,
            'courses': 0,
            'error': 'non_admin',
          });
        }
      } else {
        print('⚠️ No token found in SharedPreferences');
        _statsStreamController.add({
          'doctors': 0,
          'tas': 0,
          'students': 0,
          'courses': 0,
          'error': 'no_token',
        });
      }
    } catch (e) {
      print('❌ Error loading token: $e');
      _statsStreamController.add({
        'doctors': 0,
        'tas': 0,
        'students': 0,
        'courses': 0,
        'error': 'load_error',
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      await AuthStorage.clearUserData();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _fetchStatistics() async {
    print('\n📊 Fetching Statistics...');

    if (_authToken == null || _authToken!.isEmpty) {
      print('❌ Auth token is null or empty!');

      // محاولة إعادة تحميل التوكن
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');

      if (_authToken == null || _authToken!.isEmpty) {
        print('❌ Still no token after reload');
        _statsStreamController.add({
          'doctors': 0,
          'tas': 0,
          'students': 0,
          'courses': 0,
          'error': 'no_token'
        });
        return;
      }
    }

    try {
      // قائمة endpoints - تأكد من مطابقتها تماماً مع الـ API
      final endpoints = [
        {'key': 'doctors', 'endpoint': 'number-of-doctors'},
        {'key': 'tas', 'endpoint': 'number-of-tas'},
        {'key': 'students', 'endpoint': 'number-of-students'},
        {'key': 'courses', 'endpoint': 'number-of-courses'},
      ];

      final results = await Future.wait(
          endpoints.map((item) => _fetchApiData(item['endpoint']!))
      );

      // معالجة النتائج
      final Map<String, dynamic> stats = {};
      bool hasError = false;

      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final key = endpoints[i]['key']!;

        if (result.containsKey('error')) {
          hasError = true;
          stats[key] = 0;
          print('⚠️ Error for $key: ${result['error']}');
        } else if (result.containsKey('count')) {
          final count = result['count'];
          stats[key] = _parseCount(count);
          print('✅ $key: ${stats[key]}');
        } else {
          stats[key] = 0;
          print('⚠️ No count for $key');
        }
      }

      if (hasError) {
        bool has403 = results.any((r) => r['error'] == 'api_403' || r['error'] == 'api_401' || r['error'] == 'api_404' && r['error'] != null);
        stats['error'] = has403 ? 'api_403' : 'partial_error';
      }

      print('📈 Final Stats: $stats');
      _statsStreamController.add(stats);

    } catch (e) {
      print('❌ Error in _fetchStatistics: $e');
      _statsStreamController.add({
        'doctors': 0,
        'tas': 0,
        'students': 0,
        'courses': 0,
        'error': 'fetch_error'
      });
    }
  }

  int _parseCount(dynamic count) {
    if (count is int) return count;
    if (count is String) return int.tryParse(count) ?? 0;
    if (count is double) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  Future<Map<String, dynamic>> _fetchApiData(String endpoint) async {
    if (_authToken == null || _authToken!.isEmpty) {
      return {'count': 0, 'error': 'no_token'};
    }

    try {
      final response = await http.get(
        Uri.parse('http://supergm-001-site1.ntempurl.com/api/Admin/$endpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        print('🔒 Unauthorized for $endpoint - Token may be expired');
        return {'count': 0, 'error': 'unauthorized'};
      } else {
        print('⚠️ API Error ${response.statusCode} for $endpoint');
        return {'count': 0, 'error': 'api_${response.statusCode}'};
      }
    } on TimeoutException {
      print('⏰ Timeout fetching $endpoint');
      return {'count': 0, 'error': 'timeout'};
    } catch (e) {
      print('❌ Exception fetching $endpoint: $e');
      return {'count': 0, 'error': 'exception'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: CustomScrollView(
        slivers: [
          // App Bar مع تأثير زجاجي (بدون زر refresh)
          SliverAppBar(
            expandedHeight: 140,
            collapsedHeight: 80,
            pinned: true,
            floating: true,
            backgroundColor: AppColors.primaryColor,
            elevation: 8,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 24,
                    ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                        Text(
                          widget.userName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryColor,
                      AppColors.darkColor,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // إزالة زر Refresh وإبقاء زر Logout فقط
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

          // Welcome Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.lightColor,
                      Colors.white,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondaryColor,
                            AppColors.accentColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondaryColor.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified_user,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome ${widget.role},',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.darkColor.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkColor,
                            ),
                          ),
                          Text(
                            widget.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkColor.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // إضافة مؤشر حالة التحميل
                          _isLoading
                              ? Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Loading statistics...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.darkColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          )
                              : StreamBuilder<Map<String, dynamic>>(
                            stream: _statsStreamController.stream,
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data!.containsKey('error') &&
                                  snapshot.data!['error'] != null) {
                                return Text(
                                  'Auto-refresh every 30 seconds',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.darkColor.withOpacity(0.5),
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Statistics Cards Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: StreamBuilder<Map<String, dynamic>>(
                stream: _statsStreamController.stream,
                builder: (context, snapshot) {
                  // عرض حالة التحميل
                  if (_isLoading) {
                    return _buildLoadingStatsGrid();
                  }

                  // عرض حالة الخطأ
                  if (snapshot.hasError) {
                    return _buildErrorStatsGrid(
                      message: 'Connection Error',
                      onRetry: _fetchStatistics,
                    );
                  }

                  // عرض حالة لا توجد بيانات
                  if (!snapshot.hasData) {
                    return _buildErrorStatsGrid(
                      message: 'No Data Available',
                      onRetry: _fetchStatistics,
                    );
                  }

                  final stats = snapshot.data!;

                  // التحقق من وجود أخطاء
                  if (stats.containsKey('error') && stats['error'] != null) {
                    if (stats['error'] == 'api_403' || widget.role != 'Admin') {
                      return _buildForbiddenStatsGrid(message: 'No Access Permission');
                    }
                    
                    String errorMessage = 'Network Error';
                    if (stats['error'] == 'no_token') {
                      errorMessage = 'Authentication Required';
                    } else if (stats['error'] == 'unauthorized') {
                      errorMessage = 'Session Expired';
                    }

                    return _buildErrorStatsGrid(
                      message: errorMessage,
                      onRetry: _fetchStatistics,
                    );
                  }

                  // عرض الإحصائيات العادية
                  final doctors = (stats['doctors'] as int?) ?? 0;
                  final tas = (stats['tas'] as int?) ?? 0;
                  final students = (stats['students'] as int?) ?? 0;
                  final courses = (stats['courses'] as int?) ?? 0;

                  return Column(
                    children: [
                      _buildStatsGrid(
                        doctors: doctors,
                        tas: tas,
                        students: students,
                        courses: courses,
                      ),
                      const SizedBox(height: 8),
                      // رسالة تلقائية للـ auto-refresh
                      Text(
                        'Updates automatically every 30 seconds',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.darkColor.withOpacity(0.4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // باقي الأقسام كما هي...
          // People Management Section - Admin Only
          if (widget.role == 'Admin')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 30, right: 20, bottom: 10),
                child: Text(
                  'People Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkColor,
                  ),
                ),
              ),
            ),

          // People Operations Grid - Admin Only
          if (widget.role == 'Admin')
            _buildOperationsGrid(
              context,
              operations: [
                {
                  'title': 'Create Dr,TA',
                  'icon': Icons.person_add,
                  'color': AppColors.primaryColor,
                  'page': () => CreateAccountPage(),
                },
                {
                  'title': 'List TAs',
                  'icon': Icons.list,
                  'color': AppColors.warningColor,
                  'page': () => TAsListPage(),
                },
                {
                  'title': 'List Doctors',
                  'icon': Icons.list,
                  'color': AppColors.primaryColor.withOpacity(0.8),
                  'page': () => DoctorsListPage(),
                },
                {
                  'title': 'Delete User',
                  'icon': Icons.person_remove,
                  'color': AppColors.errorColor,
                  'page': () =>  DeleteUserPage(),
                },
                {
                  'title': 'Reset Student Account',
                  'icon': Icons.restart_alt,
                  'color': AppColors.warningColor,
                  'page': () => ResetStudentAccountPage(),
                },
                {
                  'title': 'Reset for New Year',
                  'icon': Icons.autorenew,
                  'color': Colors.orange,
                  'page': () => ResetStudentsForNewYearPage(),
                },
              ],
            ),

          // Students Management Section - Admin Only
          if (widget.role == 'Admin')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 30, right: 20, bottom: 10),
                child: Text(
                  'Students Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkColor,
                  ),
                ),
              ),
            ),

          // Students Operations Grid - Admin Only
          if (widget.role == 'Admin')
            _buildOperationsGrid(
              context,
              operations: [
                {
                  'title': 'Bulk Create Students',
                  'icon': Icons.upload_file,
                  'color': AppColors.secondaryColor,
                  'page': () => CreateStudentsBulkPage(),
                },
                {
                  'title': 'Bulk Delete Students',
                  'icon': Icons.delete_forever,
                  'color': AppColors.errorColor,
                  'page': () =>  DeleteStudentsBulkPage(),
                },
              ],
            ),

          // Course Enrollment Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 30, right: 20, bottom: 10),
              child: Text(
                'Course Enrollment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkColor,
                ),
              ),
            ),
          ),

          // Course Enrollment Operations Grid
          _buildOperationsGrid(
            context,
            operations: [
              {
                'title': 'Enroll Student',
                'icon': Icons.person_add_alt,
                'color': Colors.blue,
                'page': () =>Navigator.push(context,MaterialPageRoute(builder: (context)=>CourseEnrollmentPage()))
              },
              {
                'title': 'Bulk Enroll',
                'icon': Icons.group_add,
                'color': Colors.teal,
                'page': () => Navigator.push(context,MaterialPageRoute(builder: (context)=>BulkCourseEnrollmentPage()))
              },
            ],
          ),

          // Courses Management Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 30, right: 20, bottom: 10),
              child: Text(
                'Courses Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkColor,
                ),
              ),
            ),
          ),

          // Courses Operations Grid
          _buildOperationsGrid(
            context,
            operations: [
              if (widget.role == 'Admin')
                {
                  'title': 'Create Course',
                  'icon': Icons.add_circle,
                  'color': AppColors.successColor,
                  'page': () => Navigator.push(context,MaterialPageRoute(builder: (context)=>CreateCoursePage()))
                },
              {
                'title': 'List Courses',
                'icon': Icons.library_books,
                'color': AppColors.successColor.withOpacity(0.8),
                'page': () => CoursesListPage(),
              },
              if (widget.role == 'Admin')
                {
                  'title': 'Delete Course',
                  'icon': Icons.delete,
                  'color': AppColors.errorColor,
                  'page': () => DeleteCoursePage(),
                },
            ],
          ),

          // Bottom Space
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStatsGrid() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
          children: List.generate(4, (index) => _buildCompactStatCard(
            icon: Icons.hourglass_empty,
            title: 'Loading...',
            count: '...',
            color: Colors.grey[400]!,
            isLoading: true,
          )),
        ),
        const SizedBox(height: 8),
        Text(
          'Loading statistics...',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkColor.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStatsGrid({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
          children: List.generate(4, (index) => _buildCompactStatCard(
            icon: Icons.error_outline,
            title: 'Error',
            count: '!',
            color: AppColors.errorColor,
          )),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                message,
                style: TextStyle(
                  color: AppColors.errorColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForbiddenStatsGrid({required String message}) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
          children: [
            _buildCompactStatCard(icon: Icons.groups, title: 'Doctors', count: '-', color: Colors.grey),
            _buildCompactStatCard(icon: Icons.school, title: 'TAs', count: '-', color: Colors.grey),
            _buildCompactStatCard(icon: Icons.people, title: 'Students', count: '-', color: Colors.grey),
            _buildCompactStatCard(icon: Icons.book_online, title: 'Courses', count: '-', color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid({
    required int doctors,
    required int tas,
    required int students,
    required int courses,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.7,
      children: [
        _buildCompactStatCard(
          icon: Icons.groups,
          title: 'Doctors',
          count: doctors.toString(),
          color: AppColors.primaryColor,
        ),
        _buildCompactStatCard(
          icon: Icons.school,
          title: 'TAs',
          count: tas.toString(),
          color: Colors.blueGrey,
        ),
        _buildCompactStatCard(
          icon: Icons.people,
          title: 'Students',
          count: students.toString(),
          color: AppColors.successColor,
        ),
        _buildCompactStatCard(
          icon: Icons.book_online,
          title: 'Courses',
          count: courses.toString(),
          color: AppColors.accentColor,
        ),
      ],
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required String title,
    required String count,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
                    : Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.darkColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  SliverGrid _buildOperationsGrid(BuildContext context, {
    required List<Map<String, dynamic>> operations,
  }) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final op = operations[index];
          return _buildSimpleOperationCard(
            title: op['title']!,
            icon: op['icon'] as IconData,
            color: op['color'] as Color,
            onTap: () {
              if (op.containsKey('page') && op['page'] != null) {
                if (op['page'] is Widget Function()) {
                  final pageBuilder = op['page'] as Widget Function();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => pageBuilder()),
                  );
                } else if (op['page'] is Function) {
                  (op['page'] as Function)();
                }
              }
            },
          );
        },
        childCount: operations.length,
      ),
    );
  }

  Widget _buildSimpleOperationCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: color.withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}