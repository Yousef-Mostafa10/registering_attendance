import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/colors.dart';

class BulkCourseEnrollmentPage extends StatefulWidget {
  const BulkCourseEnrollmentPage({Key? key}) : super(key: key);

  @override
  _BulkCourseEnrollmentPageState createState() => _BulkCourseEnrollmentPageState();
}

class _BulkCourseEnrollmentPageState extends State<BulkCourseEnrollmentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _courseIdController = TextEditingController();
  final TextEditingController _studentCodesController = TextEditingController();

  bool _isLoading = false;
  String? _authToken;

  static const String _apiUrl = 'http://supergm-001-site1.ntempurl.com/api/Course/enroll-bulk';

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  @override
  void dispose() {
    _courseIdController.dispose();
    _studentCodesController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
  }

  String? _validateCourseId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Course ID is required';
    }
    final courseId = int.tryParse(value);
    if (courseId == null || courseId <= 0) {
      return 'Please enter a valid Course ID number';
    }
    return null;
  }

  String? _validateStudentCodes(String? value) {
    if (value == null || value.isEmpty) {
      return 'Student codes are required';
    }

    final codes = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (codes.isEmpty) {
      return 'Please enter at least one student code';
    }

    if (codes.any((code) => code.length < 3)) {
      return 'Each code must be at least 3 characters';
    }

    return null;
  }

  Future<void> _enrollStudentsBulk() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Authentication token not found'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // تحويل الـ courseId إلى integer
      final courseId = int.parse(_courseIdController.text.trim());

      // تحويل الـ student codes إلى List
      final studentCodes = _studentCodesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // إعداد البيانات المطلوبة
      final enrollmentData = {
        "courseId": courseId,
        "studentCodes": studentCodes,
      };

      // استدعاء الـ API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(enrollmentData),
      );

      if (response.statusCode == 200 || response.statusCode == 207) {
        final responseData = jsonDecode(response.body);

        _studentCodesController.clear();

        // Show the Result Dialog
        _showResultDialog(
          responseData['added'] != null ? List<String>.from(responseData['added']) : [],
          responseData['skipped'] != null ? List<String>.from(responseData['skipped']) : [],
          responseData['notFound'] != null ? List<String>.from(responseData['notFound']) : [],
          responseData['message'] ?? 'Enrollment process completed',
        );

      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to enroll students: ${response.statusCode}');
      }
      } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResultDialog(List<String> added, List<String> skipped, List<String> notFound, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Enrollment Results', style: TextStyle(color: AppColors.darkColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isNotEmpty) Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (added.isNotEmpty) ...[
                  const Text('Added successfully:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Wrap(spacing: 8, children: added.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.green.withOpacity(0.2))).toList()),
                  const SizedBox(height: 10),
                ],
                if (skipped.isNotEmpty) ...[
                  const Text('Skipped (Already Enrolled):', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Wrap(spacing: 8, children: skipped.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.orange.withOpacity(0.2))).toList()),
                  const SizedBox(height: 10),
                ],
                if (notFound.isNotEmpty) ...[
                  const Text('Not Found:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Wrap(spacing: 8, children: notFound.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.red)).toList()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
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
                children: [
                  const Text(
                    'Bulk Course Enrollment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.lightColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_add,
                          color: AppColors.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bulk Enroll Students',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enroll multiple students in a course at once using their university codes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.darkColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Course ID Field
                        _buildTextField(
                          controller: _courseIdController,
                          label: 'Course ID',
                          hint: 'Enter course ID number',
                          prefixIcon: Icons.book,
                          keyboardType: TextInputType.number,
                          validator: _validateCourseId,
                        ),
                        const SizedBox(height: 24),

                        // Student Codes Field
                        _buildTextAreaField(
                          controller: _studentCodesController,
                          label: 'Student University Codes',
                          hint: 'Enter student codes separated by commas',
                          validator: _validateStudentCodes,
                        ),
                        const SizedBox(height: 12),
                        _buildCharCounter(),
                        const SizedBox(height: 12),
                        _buildFormatInfo(),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _enrollStudentsBulk,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_add, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Enroll Students',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.darkColor.withOpacity(0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.errorColor,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.errorColor,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                prefixIcon,
                color: AppColors.darkColor.withOpacity(0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              color: AppColors.darkColor,
              fontSize: 16,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.darkColor.withOpacity(0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.errorColor,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.errorColor,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(
              color: AppColors.darkColor,
              fontSize: 16,
            ),
            validator: validator,
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCharCounter() {
    final codes = _studentCodesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${codes.length} student(s)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.darkColor.withOpacity(0.7),
          ),
        ),
        if (codes.isNotEmpty)
          Text(
            '${_studentCodesController.text.length} characters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkColor.withOpacity(0.7),
            ),
          ),
      ],
    );
  }

  Widget _buildFormatInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Separate student codes with commas (e.g., 20205522, 20210001, 20210002)',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.darkColor.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}