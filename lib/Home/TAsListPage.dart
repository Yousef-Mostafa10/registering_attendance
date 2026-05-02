import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:registering_attendance/core/http_interceptor.dart' as http;
import 'package:registering_attendance/Home/creatDoctorOrTA.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../Auth/colors.dart';

class TAsListPage extends StatefulWidget {
  const TAsListPage({Key? key}) : super(key: key);

  @override
  _TAsListPageState createState() => _TAsListPageState();
}

class _TAsListPageState extends State<TAsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final StreamController<List<Map<String, dynamic>>> _tasStreamController =
  StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, int>> _statsStreamController =
  StreamController<Map<String, int>>.broadcast();

  String _searchQuery = '';
  String? _authToken;
  Timer? _refreshTimer;

  static const String _tasUrl = 'http://msngroup-001-site1.ktempurl.com/api/Admin/list-TAs';
  static const String _tasCountUrl = 'http://msngroup-001-site1.ktempurl.com/api/Admin/number-of-tas';

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
    _tasStreamController.close();
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
      _tasStreamController.add([]);
      _statsStreamController.add({'tas': 0});
      return;
    }

    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    if (_authToken == null) return;

    try {
      // جلب البيانات بالتوازي
      await Future.wait([
        _fetchTAs(),
        _fetchStatistics(),
      ]);
    } catch (e) {
      print('Error fetching all data: $e');
    }
  }

  Future<void> _fetchTAs() async {
    try {
      final response = await http.get(
        Uri.parse(_tasUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> tasData = jsonDecode(response.body);
        final tas = _processTAsData(tasData);
        _tasStreamController.add(tas);
      } else if (response.statusCode == 401) {
        print('Unauthorized - Token may be expired');
        _tasStreamController.add([]);
      } else {
        throw Exception('Failed to load TAs: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching TAs: $e');
      _tasStreamController.add([]);
      _statsStreamController.add({'total': 0, 'active': 0});
    }
  }

  Future<void> _deleteTADirectly(String universityCode, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Deletion', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('Are you sure you want to delete TA "$name"?\n\nThis will permanently remove their account and access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('http://msngroup-001-site1.ktempurl.com/api/Admin/delete-user/$universityCode'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TA deleted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAllData();
      } else if (response.statusCode == 500) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete this TA because they are currently assigned to one or more courses. Please unassign them first.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        var errorMsg = 'Failed to delete TA';
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
    }
  }

  Future<void> _fetchStatistics() async {
    try {
      // جلب عدد المعيدين
      final tasCountResponse = await http.get(
        Uri.parse(_tasCountUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
        },
      );

      int tasCount = 0;

      if (tasCountResponse.statusCode == 200) {
        final data = jsonDecode(tasCountResponse.body);
        tasCount = data['count'] ?? 0;
      }

      _statsStreamController.add({
        'tas': tasCount,
      });

    } catch (e) {
      print('Error fetching statistics: $e');
      _statsStreamController.add({'tas': 0});
    }
  }

  List<Map<String, dynamic>> _processTAsData(List<dynamic> tasData) {
    List<Map<String, dynamic>> tas = [];

    // قائمة ألوان للبطاقات
    final colors = [
      AppColors.primaryColor,
      AppColors.successColor,
      AppColors.accentColor,
      AppColors.secondaryColor,
      AppColors.warningColor,
      AppColors.errorColor,
    ];

    for (int i = 0; i < tasData.length; i++) {
      var ta = tasData[i];

      Map<String, dynamic> taMap = {
        'id': ta['id']?.toString() ?? '0',
        'name': ta['name']?.toString() ?? 'Unknown',
        'email': ta['email']?.toString() ?? 'No email',
        'universityCode': ta['universityCode']?.toString() ?? 'No code',
        'status': 'Active', // يمكنك إضافة status من الـ API إذا كان موجوداً
        'avatar': _getAvatarInitials(ta['name']?.toString() ?? '?'),
        'color': colors[i % colors.length],
      };

      tas.add(taMap);
    }

    return tas;
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

  List<Map<String, dynamic>> _filterTAs(List<Map<String, dynamic>> tas) {
    if (_searchQuery.isEmpty) return tas;

    return tas.where((ta) {
      final name = ta['name'].toString().toLowerCase();
      final email = ta['email'].toString().toLowerCase();
      final code = ta['universityCode'].toString().toLowerCase();

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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: AppColors.primaryColor,
              elevation: 4,
              shape: const ContinuousRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              title: const Text(
                    'Teaching Assistants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                        stream: _tasStreamController.stream,
                        builder: (context, snapshot) {
                          final tas = snapshot.data ?? [];
                          final filteredTAs = _filterTAs(tas);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${filteredTAs.length} TA${filteredTAs.length != 1 ? 's' : ''}',
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
                          hintText: 'Search TAs...',
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
                final stats = statsSnapshot.data ?? {'tas': 0};

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.school,
                        title: 'Teaching Assistants',
                        value: stats['tas']?.toString() ?? '0',
                        color: AppColors.primaryColor,
                        isLoading: !statsSnapshot.hasData,
                      ),
                    ],
                  ),
                );
              },
            ),

            // TAs List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _tasStreamController.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildLoadingState();
                  }

                  final tas = snapshot.data!;
                  final filteredTAs = _filterTAs(tas);

                  if (tas.isEmpty) {
                    return _buildEmptyState();
                  }

                  return filteredTAs.isEmpty
                      ? _buildNoResultsState()
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: filteredTAs.length,
                    itemBuilder: (context, index) {
                      final ta = filteredTAs[index];
                      return _buildTACard(ta);
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
              builder: (context) => const CreateAccountPage(), // إذا كان هناك باراميتر للتمييز
            ),
          ).then((value) {
            // تحديث جميع البيانات بعد إضافة معيد جديد
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
            Icons.school_outlined,
            size: 80,
            color: AppColors.darkColor.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No Teaching Assistants available',
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
            'No TAs found',
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

  Widget _buildTACard(Map<String, dynamic> ta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _showTADetails(ta),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: (ta['color'] as Color).withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    ta['avatar'],
                    style: TextStyle(
                      color: ta['color'] as Color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // TA Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (ta['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: ${ta['id']}',
                              style: TextStyle(
                                color: ta['color'] as Color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                      const SizedBox(height: 8),
                      Text(
                        ta['name'],
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
                              ta['email'],
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
                            ta['universityCode'],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkColor.withOpacity(0.7),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (ta['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TA',
                              style: TextStyle(
                                fontSize: 10,
                                color: ta['color'] as Color,
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

  void _showTADetails(Map<String, dynamic> ta) {
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

            // TA Details
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
                            backgroundColor: (ta['color'] as Color).withOpacity(0.1),
                            radius: 40,
                            child: Text(
                              ta['avatar'],
                              style: TextStyle(
                                color: ta['color'] as Color,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            ta['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ta['status'] == 'Active'
                                      ? AppColors.successColor.withOpacity(0.1)
                                      : AppColors.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: ta['status'] == 'Active'
                                        ? AppColors.successColor
                                        : AppColors.errorColor,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  ta['status'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ta['status'] == 'Active'
                                        ? AppColors.successColor
                                        : AppColors.errorColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (ta['color'] as Color).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: ta['color'] as Color,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Teaching Assistant',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ta['color'] as Color,
                                  ),
                                ),
                              ),
                            ],
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
                      label: 'TA ID',
                      value: '#${ta['id']}',
                      color: ta['color'] as Color,
                    ),
                    _buildDetailItem(
                      icon: Icons.code,
                      label: 'University Code',
                      value: ta['universityCode'],
                      color: ta['color'] as Color,
                    ),
                    _buildDetailItem(
                      icon: Icons.email,
                      label: 'Email',
                      value: ta['email'],
                      color: ta['color'] as Color,
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
                              Navigator.pop(context); // close bottom sheet
                              _deleteTADirectly(ta['universityCode'], ta['name']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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

