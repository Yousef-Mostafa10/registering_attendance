import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:registering_attendance/core/http_interceptor.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/colors.dart';
import '../widgets/AppInstructionsCard.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({Key? key}) : super(key: key);

  @override
  _CreateCoursePageState createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _doctorCodeController = TextEditingController();

  bool _isLoading = false;
  String? _apiResponse;
  bool _isSuccess = false;
  String? _authToken;

  static const String _apiUrl = 'http://msngroup-001-site1.ktempurl.com/api/Admin/create-course';

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _doctorCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Course name is required';
    }
    if (value.length < 2) {
      return 'Course name must be at least 2 characters';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Course code is required';
    }
    if (value.length < 2) {
      return 'Course code must be at least 2 characters';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Description is required';
    }
    if (value.length < 5) {
      return 'Description must be at least 5 characters';
    }
    return null;
  }

  String? _validateDoctorCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Doctor University Code is required';
    }
    if (value.trim().length < 2) {
      return 'Please enter a valid University Code (e.g., DR-1234)';
    }
    return null;
  }

  Future<void> _submitForm() async {
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
      _apiResponse = null;
      _isSuccess = false;
    });

    try {
      // استخدام University Code بدل الـ Integer ID

      // إعداد البيانات المطلوبة (doctorUniversityCode كـ string في الـ JSON)
      final courseData = {
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "courseCode": _codeController.text.trim(),
        "doctorUniversityCode": _doctorCodeController.text.trim(),
      };

      print('Sending data: $courseData');

      // استدعاء الـ API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(courseData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _apiResponse = responseData['message'] ?? 'Course created successfully!';
          _isSuccess = true;
        });

        // تنظيف الحقول بعد النجاح
        _nameController.clear();
        _codeController.clear();
        _descriptionController.clear();
        _doctorCodeController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiResponse!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // يمكنك اختيارياً إرجاع true للإشارة إلى أن الكورس تم إنشاؤه بنجاح
        // Navigator.pop(context, true);

      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Bad request: ${response.statusCode}');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token may be expired');
      } else {
        throw Exception('Failed to create course: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _apiResponse = 'Error: ${e.toString()}';
        _isSuccess = false;
      });

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
              title: const Text(
                    'Create New Course',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                          Icons.add_circle,
                          color: AppColors.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create New Course',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Fill in all required fields to create a new course',
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
                  const SizedBox(height: 24),
                  
                  const AppInstructionsCard(
                    title: 'Course Creation Steps',
                    instructions: [
                      'Enter a clear, descriptive name for the course.',
                      'Provide a unique Course Code (e.g., CS4710).',
                      'Enter the exact University Code of the Doctor assigned to this course.',
                      'Provide a brief description of the course contents.',
                      'Click "Create Course" to finalize.',
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Course Name Field
                        _buildTextField(
                          controller: _nameController,
                          label: 'Course Name',
                          hint: 'Enter course name (e.g., Database_Level2)',
                          prefixIcon: Icons.book,
                          validator: _validateName,
                        ),
                        const SizedBox(height: 24),

                        // Course Code Field
                        _buildTextField(
                          controller: _codeController,
                          label: 'Course Code',
                          hint: 'Enter course code (e.g., CS4710)',
                          prefixIcon: Icons.code,
                          validator: _validateCode,
                        ),
                        const SizedBox(height: 24),

                        // Doctor University Code Field
                        _buildTextField(
                          controller: _doctorCodeController,
                          label: 'Doctor University Code',
                          hint: 'Enter doctor university code (e.g., DR-1234)',
                          prefixIcon: Icons.badge,
                          keyboardType: TextInputType.text,
                          validator: _validateDoctorCode,
                        ),
                        const SizedBox(height: 24),

                        // Description Field
                        _buildDescriptionField(),
                        const SizedBox(height: 32),


                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
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
                                Icon(Icons.add_circle, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Create Course',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // API Response
                        if (_apiResponse != null)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _isSuccess
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isSuccess ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSuccess ? Icons.check_circle : Icons.error,
                                  color: _isSuccess ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _apiResponse!,
                                    style: TextStyle(
                                      color: AppColors.darkColor,
                                      fontSize: 14,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!_isSuccess)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _apiResponse = null;
                                      });
                                    },
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(left: 8),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
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

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course Description',
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
            controller: _descriptionController,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter course description',
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
            validator: _validateDescription,
          ),
        ),
      ],
    );
  }
}

