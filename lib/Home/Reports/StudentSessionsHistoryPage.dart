import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:registering_attendance/core/http_interceptor.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../Auth/api_service.dart';
import '../../Auth/auth_storage.dart';
import '../../Auth/colors.dart';
import '../QRScannerPage.dart';

class StudentSessionsHistoryPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudentSessionsHistoryPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<StudentSessionsHistoryPage> createState() =>
      _StudentSessionsHistoryPageState();
}

class _StudentSessionsHistoryPageState extends State<StudentSessionsHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _lectures = [];
  List<dynamic> _sections = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSessions();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken() ?? '';

      final lecturesResponseFuture = http.get(
        Uri.parse(
          '${ApiService.baseUrl}/Session/course-sessions/${widget.courseId}/Lecture',
        ),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      final sectionsResponseFuture = http.get(
        Uri.parse(
          '${ApiService.baseUrl}/Session/course-sessions/${widget.courseId}/Section',
        ),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      final results = await Future.wait([
        lecturesResponseFuture,
        sectionsResponseFuture,
      ]);
      final lecturesResponse = results[0];
      final sectionsResponse = results[1];

      if (lecturesResponse.statusCode == 200 &&
          sectionsResponse.statusCode == 200) {
        final parsedLectures = _extractList(jsonDecode(lecturesResponse.body));
        final parsedSections = _extractList(jsonDecode(sectionsResponse.body));

        if (mounted) {
          setState(() {
            _lectures = parsedLectures.reversed.toList();
            _sections = parsedSections.reversed.toList();
            _isLoading = false;
          });
        }
        _handlePolling();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load sessions.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handlePolling() {
    final hasActive =
        _hasActiveSession(_lectures) || _hasActiveSession(_sections);
    if (hasActive && _pollTimer == null) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _fetchSessions(),
      );
    } else if (!hasActive && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  bool _hasActiveSession(List<dynamic> sessions) {
    for (final session in sessions) {
      if (session is Map && (session['isActive'] == true)) {
        return true;
      }
    }
    return false;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    } else if (data is Map && data.containsKey(r'$values')) {
      return data[r'$values'] ?? [];
    }
    return [];
  }

  void _openActiveSession(Map<String, dynamic> session) {
    final sessionId =
        session['id']?.toString() ?? session['sessionId']?.toString() ?? '';
    if (sessionId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActiveSessionPage(
          sessionId: sessionId,
          sessionTitle: session['title']?.toString() ?? 'Active Session',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: Text(
          widget.courseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: 'Lectures', icon: Icon(Icons.school)),
            Tab(text: 'Sections', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSessionList(_lectures),
                _buildSessionList(_sections),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
            _errorMessage ?? 'Error',
            style: const TextStyle(color: AppColors.errorColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(List<dynamic> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 60,
              color: AppColors.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sessions found.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkColor.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = Map<String, dynamic>.from(sessions[index]);
        final sessionId =
            session['id']?.toString() ??
            session['sessionId']?.toString() ??
            '0';
        final title = session['title'] ?? 'Session #$sessionId';
        final isActive = session['isActive'] == true;

        return _ActiveGlowCard(
          isActive: isActive,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => isActive ? _openActiveSession(session) : null,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.successColor.withOpacity(0.15)
                            : AppColors.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.play_circle_fill : Icons.class_,
                        color: isActive
                            ? AppColors.successColor
                            : AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.darkColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: #$sessionId',
                            style: TextStyle(
                              color: AppColors.darkColor.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveGlowCard extends StatefulWidget {
  final Widget child;
  final bool isActive;

  const _ActiveGlowCard({required this.child, required this.isActive});

  @override
  State<_ActiveGlowCard> createState() => _ActiveGlowCardState();
}

class _ActiveGlowCardState extends State<_ActiveGlowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(
      begin: 0.2,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ActiveGlowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.successColor.withOpacity(_animation.value),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ActiveSessionPage extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;

  const _ActiveSessionPage({
    required this.sessionId,
    required this.sessionTitle,
  });

  @override
  State<_ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends State<_ActiveSessionPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    if (_isSubmitting) return;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userData = await AuthStorage.getUserData();
      final deviceId = userData?['deviceId'] ?? 'error_device';
      final token = await AuthStorage.getToken() ?? '';

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/Attendance/submit'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "sessionId": int.tryParse(widget.sessionId) ?? 0,
          "deviceId": deviceId,
          "studentLatitude": position.latitude,
          "studentLongitude": position.longitude,
          "scannedQrContent": null,
          "sessionPIN": pin,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance submitted!'),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.body}'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: Text(
          widget.sessionTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Session',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to check in.',
                    style: TextStyle(
                      color: AppColors.darkColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScannerPage()),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Scan QR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter PIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'PIN Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Submit PIN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
}
