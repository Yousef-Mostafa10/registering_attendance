// login_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'colors.dart';
import 'api_service.dart';
import 'auth_widgets.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onSwitchToActivation;
  final String deviceId;
  final Function(String) onDeviceIdRefresh;
  final Function(Map<String, dynamic>) onLoginSuccess;

  const LoginPage({
    Key? key,
    required this.onSwitchToActivation,
    required this.deviceId,
    required this.onDeviceIdRefresh,
    required this.onLoginSuccess,
  }) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // التحقق من صحة البريد الإلكتروني
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // التحقق من صحة كلمة المرور
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  // Login function
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      AuthWidgets.showWarningSnackBar(context, 'Please fix the errors in the form');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.login(
        email: _emailController.text,
        password: _passwordController.text,
        deviceId: widget.deviceId,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['statusCode'] == 200) {
        final data = jsonDecode(response['body']);

        if (data['isSuccess'] == true) {
          AuthWidgets.showSuccessSnackBar(context, 'Login successful!');

          // Pass user data to parent
          widget.onLoginSuccess({
            'token': data['token'] ?? '',
            'refreshToken': data['refreshToken'] ?? '',
            'role': data['role'] ?? '',
            'userName': data['userName'] ?? '',
            'email': _emailController.text,
            'deviceId': widget.deviceId,
          });
        } else {
          AuthWidgets.showErrorSnackBar(context, data['message'] ?? 'Login failed');
        }
      } else {
        AuthWidgets.showErrorSnackBar(context, 'Login failed. Status code: ${response['statusCode']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AuthWidgets.showErrorSnackBar(context, 'Login error: $e');
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.darkColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Login',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter your credentials to access the college attendance system',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 30),

          // Login email field
          AuthWidgets.buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'Enter your email',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            validator: _validateEmail,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_passwordFocus);
            },
          ),
          const SizedBox(height: 20),

          // Login password field
          AuthWidgets.buildPasswordField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your password',
            obscureText: _obscurePassword,
            focusNode: _passwordFocus,
            validator: _validatePassword,
            onToggle: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          const SizedBox(height: 20),

          // Device ID display (read-only)
          AuthWidgets.buildDeviceIdDisplay(
              deviceId: widget.deviceId,
              onRefresh: () => widget.onDeviceIdRefresh('')
          ),

          const SizedBox(height: 30),

          // Login button
          AuthWidgets.buildActionButton(
            text: 'Login',
            onPressed: _login,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 30),

          // Switch to activation link
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToActivation,
              child: RichText(
                text: TextSpan(
                  text: 'Don\'t have an account? ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.darkColor,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Activate Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
