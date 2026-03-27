import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:registering_attendance/Home/creatDoctorOrTA.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../Auth/colors.dart';

class DoctorsListPage extends StatefulWidget {
  const DoctorsListPage({Key? key}) : super(key: key);

  @override
  _DoctorsListPageState createState() => _DoctorsListPageState();
}

class _DoctorsListPageState extends State<DoctorsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final StreamController<List<Map<String, dynamic>>> _doctorsStreamController =
  StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<int> _statsStreamController = StreamController<int>.broadcast();

  String _searchQuery = '';
  String? _authToken;
  Timer? _refreshTimer;

  static const String _doctorsUrl = 'http://supergm-001-site1.ntempurl.com/api/Admin/list-doctors';

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
    _doctorsStreamController.close();
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
      _doctorsStreamController.add([]);
      _statsStreamController.add(0);
      return;
    }

    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    if (_authToken == null) return;

    try {
      // جلب البيانات بالتوازي
      await Future.wait([
        _fetchDoctors(),
      ]);
    } catch (e) {
      print('Error fetching all data: $e');
    }
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await http.get(
        Uri.parse(_doctorsUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> doctorsData = jsonDecode(response.body);
        final doctors = _processDoctorsData(doctorsData);
        _doctorsStreamController.add(doctors);
        _statsStreamController.add(doctors.length);
      } else if (response.statusCode == 401) {
        print('Unauthorized - Token may be expired');
        _doctorsStreamController.add([]);
        _statsStreamController.add(0);
      } else {
        throw Exception('Failed to load doctors: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching doctors: $e');
      _doctorsStreamController.add([]);
      _statsStreamController.add(0);
    }
  }

  List<Map<String, dynamic>> _processDoctorsData(List<dynamic> doctorsData) {
    List<Map<String, dynamic>> doctors = [];

    // قائمة ألوان للبطاقات
    final colors = [
      AppColors.primaryColor,
      AppColors.successColor,
      AppColors.accentColor,
      AppColors.secondaryColor,
      AppColors.warningColor,
      AppColors.errorColor,
    ];

    for (int i = 0; i < doctorsData.length; i++) {
      var doctor = doctorsData[i];

      Map<String, dynamic> doctorMap = {
        'id': doctor['id']?.toString() ?? '0',
        'name': doctor['name']?.toString() ?? 'Unknown',
        'email': doctor['email']?.toString() ?? 'No email',
        'universityCode': doctor['universityCode']?.toString() ?? 'No code',
        'avatar': _getAvatarInitials(doctor['name']?.toString() ?? '?'),
        'color': colors[i % colors.length],
      };

      doctors.add(doctorMap);
    }

    return doctors;
  }

  String _getAvatarInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  List<Map<String, dynamic>> _filterDoctors(List<Map<String, dynamic>> doctors) {
    if (_searchQuery.isEmpty) return doctors;

    return doctors.where((doctor) {
      final name = doctor['name'].toString().toLowerCase();
      final email = doctor['email'].toString().toLowerCase();
      final code = doctor['universityCode'].toString().toLowerCase();

      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          code.contains(_searchQuery);
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
                    'Doctors List',
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
                        stream: _doctorsStreamController.stream,
                        builder: (context, snapshot) {
                          final doctors = snapshot.data ?? [];
                          final filteredDoctors = _filterDoctors(doctors);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${filteredDoctors.length} doctor${filteredDoctors.length != 1 ? 's' : ''}',
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
                          hintText: 'Search doctors...',
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
            StreamBuilder<int>(
              stream: _statsStreamController.stream,
              builder: (context, statsSnapshot) {
                final doctorsCount = statsSnapshot.data ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.person,
                        title: 'Doctors',
                        value: doctorsCount.toString(),
                        color: AppColors.primaryColor,
                        isLoading: !statsSnapshot.hasData,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Doctors List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _doctorsStreamController.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildLoadingState();
                  }

                  final doctors = snapshot.data!;
                  final filteredDoctors = _filterDoctors(doctors);

                  if (doctors.isEmpty) {
                    return _buildEmptyState();
                  }

                  return filteredDoctors.isEmpty
                      ? _buildNoResultsState()
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = filteredDoctors[index];
                      return _buildDoctorCard(doctor);
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
              builder: (context) => const CreateAccountPage(),
            ),
          ).then((value) {
            // تحديث جميع البيانات بعد إضافة دكتور جديد
            if (value == true) {
              _fetchAllData();
            }
          });
        },
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.person_add, color: Colors.white),
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
            Icons.people_outline,
            size: 80,
            color: AppColors.darkColor.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No doctors available',
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
            'No doctors found',
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

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _showDoctorDetails(doctor),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: (doctor['color'] as Color).withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    doctor['avatar'],
                    style: TextStyle(
                      color: doctor['color'] as Color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Doctor Info
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
                              color: (doctor['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: ${doctor['id']}',
                              style: TextStyle(
                                color: doctor['color'] as Color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        doctor['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: AppColors.darkColor.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              doctor['email'],
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.darkColor.withOpacity(0.7),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.code,
                            size: 14,
                            color: AppColors.darkColor.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doctor['universityCode'],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkColor.withOpacity(0.7),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (doctor['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Doctor',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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

  void _showDoctorDetails(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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

            // Doctor Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Avatar
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: (doctor['color'] as Color).withOpacity(0.1),
                            radius: 40,
                            child: Text(
                              doctor['avatar'],
                              style: TextStyle(
                                color: doctor['color'] as Color,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            doctor['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (doctor['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: doctor['color'] as Color,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Doctor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: doctor['color'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Details
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDetailItem(
                      icon: Icons.person_outline,
                      label: 'Doctor ID',
                      value: '#${doctor['id']}',
                      color: doctor['color'] as Color,
                    ),
                    _buildDetailItem(
                      icon: Icons.code,
                      label: 'University Code',
                      value: doctor['universityCode'],
                      color: doctor['color'] as Color,
                    ),
                    _buildDetailItem(
                      icon: Icons.email,
                      label: 'Email',
                      value: doctor['email'],
                      color: doctor['color'] as Color,
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: AppColors.primaryColor),
                            ),
                            child: Text(
                              'Close',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Edit ${doctor['name']}'),
                                  backgroundColor: AppColors.primaryColor,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
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
      ),
    );
  }
}