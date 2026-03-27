import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:registering_attendance/Home/creatCourse.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/colors.dart';

class CoursesListPage extends StatefulWidget {
  const CoursesListPage({Key? key}) : super(key: key);

  @override
  _CoursesListPageState createState() => _CoursesListPageState();
}

class _CoursesListPageState extends State<CoursesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final StreamController<List<Map<String, dynamic>>> _coursesStreamController =
  StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, int>> _statsStreamController =
  StreamController<Map<String, int>>.broadcast();

  String _searchQuery = '';
  String? _authToken;
  Timer? _refreshTimer;

  static const String _apiUrl = 'http://supergm-001-site1.ntempurl.com/api/Admin/list-courses';
  static const String _coursesCountUrl = 'http://supergm-001-site1.ntempurl.com/api/Admin/number-of-courses';
  static const String _studentsCountUrl = 'http://supergm-001-site1.ntempurl.com/api/Admin/number-of-students';

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchData();
    _searchController.addListener(_onSearchChanged);

    // تحديث تلقائي كل 30 ثانية
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_authToken != null) {
        _fetchAllData();
      }
    });
  }

  @override
  void dispose() {
    _coursesStreamController.close();
    _statsStreamController.close();
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadTokenAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');

    if (_authToken == null) {
      _coursesStreamController.add([]);
      _statsStreamController.add({'courses': 0, 'students': 0});
      return;
    }

    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    if (_authToken == null) return;

    try {
      // جلب البيانات بالتوازي
      await Future.wait([
        _fetchCourses(),
        _fetchStatistics(),
      ]);
    } catch (e) {
      print('Error fetching all data: $e');
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> coursesData = jsonDecode(response.body);
        final courses = _processCoursesData(coursesData);
        _coursesStreamController.add(courses);
      } else if (response.statusCode == 401) {
        print('Unauthorized - Token may be expired');
        _coursesStreamController.add([]);
      } else {
        throw Exception('Failed to load courses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching courses: $e');
      _coursesStreamController.add([]);
    }
  }

  Future<void> _fetchStatistics() async {
    try {
      // جلب عدد الكورسات
      final coursesCountResponse = await http.get(
        Uri.parse(_coursesCountUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      // جلب عدد الطلاب
      final studentsCountResponse = await http.get(
        Uri.parse(_studentsCountUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      int coursesCount = 0;
      int studentsCount = 0;

      if (coursesCountResponse.statusCode == 200) {
        final data = jsonDecode(coursesCountResponse.body);
        coursesCount = data['count'] ?? 0;
      }

      if (studentsCountResponse.statusCode == 200) {
        final data = jsonDecode(studentsCountResponse.body);
        studentsCount = data['count'] ?? 0;
      }

      _statsStreamController.add({
        'courses': coursesCount,
        'students': studentsCount,
      });

    } catch (e) {
      print('Error fetching statistics: $e');
      _statsStreamController.add({'courses': 0, 'students': 0});
    }
  }

  List<Map<String, dynamic>> _processCoursesData(List<dynamic> coursesData) {
    List<Map<String, dynamic>> courses = [];

    // قائمة ألوان للكورسات
    final colors = [
      AppColors.primaryColor,
      AppColors.successColor,
      AppColors.accentColor,
      AppColors.secondaryColor,
      AppColors.warningColor,
      AppColors.errorColor,
    ];

    for (int i = 0; i < coursesData.length; i++) {
      var course = coursesData[i];

      Map<String, dynamic> courseMap = {
        'id': course['id'].toString(),
        'name': course['name'],
        'doctorName': course['doctorName'],
        'studentCount': course['studentCount'],
        'color': colors[i % colors.length],
      };

      courses.add(courseMap);
    }

    return courses;
  }

  List<Map<String, dynamic>> _filterCourses(List<Map<String, dynamic>> courses) {
    if (_searchQuery.isEmpty) return courses;

    return courses.where((course) {
      final name = course['name'].toString().toLowerCase();
      final doctor = course['doctorName'].toString().toLowerCase();
      final studentCount = course['studentCount'].toString();

      return name.contains(_searchQuery) ||
          doctor.contains(_searchQuery) ||
          studentCount.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.primaryColor,
              elevation: 4,
              shape: const ContinuousRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Courses List',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
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
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 16),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _coursesStreamController.stream,
                        builder: (context, snapshot) {
                          final courses = snapshot.data ?? [];
                          final filteredCourses = _filterCourses(courses);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${filteredCourses.length} course${filteredCourses.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Auto-refresh every 30 seconds',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.darkColor.withOpacity(0.5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search courses...',
                          hintStyle: TextStyle(
                            color: AppColors.darkColor.withOpacity(0.4),
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          color: AppColors.darkColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.clear,
                            size: 20,
                            color: AppColors.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Statistics
            StreamBuilder<Map<String, int>>(
              stream: _statsStreamController.stream,
              builder: (context, statsSnapshot) {
                final stats = statsSnapshot.data ?? {'courses': 0, 'students': 0};

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.book,
                        title: 'Total Courses',
                        value: stats['courses']?.toString() ?? '0',
                        color: AppColors.primaryColor,
                        isLoading: !statsSnapshot.hasData,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.people,
                        title: 'Total Students',
                        value: stats['students']?.toString() ?? '0',
                        color: AppColors.successColor,
                        isLoading: !statsSnapshot.hasData,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Courses List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _coursesStreamController.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildLoadingState();
                  }

                  final courses = snapshot.data!;
                  final filteredCourses = _filterCourses(courses);

                  if (courses.isEmpty) {
                    return _buildEmptyState();
                  }

                  return filteredCourses.isEmpty
                      ? _buildNoResultsState()
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = filteredCourses[index];
                      return _buildCourseCard(course);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCoursePage(),
            ),
          ).then((value) {
            // تحديث جميع البيانات بعد إضافة كورس جديد
            if (value == true) {
              _fetchAllData();
            }
          });
        },
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryColor,
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
            color: AppColors.darkColor.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No courses available',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.darkColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _fetchAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: AppColors.darkColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No courses found',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isLoading = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
              )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? '...' : value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkColor,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _showCourseDetails(course),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Course Color Indicator
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: course['color'],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),

                // Course Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (course['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: ${course['id']}',
                              style: TextStyle(
                                color: course['color'],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              '${course['studentCount']} student${course['studentCount'] != 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: AppColors.lightColor,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        course['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dr. ${course['doctorName']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.darkColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCourseDetails(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 60,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Course Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: (course['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: course['color'] as Color,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Course ID: ${course['id']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: (course['color'] as Color),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  '${course['studentCount']} student${course['studentCount'] != 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: (course['color'] as Color).withOpacity(0.2),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            course['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Details
                    const Text(
                      'Course Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDetailItem(
                      icon: Icons.person,
                      label: 'Instructor',
                      value: 'Dr. ${course['doctorName']}',
                    ),
                    _buildDetailItem(
                      icon: Icons.people,
                      label: 'Students',
                      value: '${course['studentCount']} student${course['studentCount'] != 1 ? 's' : ''}',
                    ),

                    const SizedBox(height: 32),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.lightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.darkColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
    }
}
