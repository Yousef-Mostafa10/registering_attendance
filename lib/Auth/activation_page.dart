// activation_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'colors.dart';
import 'api_service.dart';
import 'auth_widgets.dart';

class ActivationPage extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  final String deviceId;
  final Function(String) onDeviceIdRefresh;

  const ActivationPage({
    Key? key,
    required this.onSwitchToLogin,
    required this.deviceId,
    required this.onDeviceIdRefresh,
  }) : super(key: key);

  @override
  _ActivationPageState createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _message = '';
  bool _isError = false;

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

  // التحقق من صحة كود الجامعة
  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'University code is required';
    }
    if (value.length < 3) {
      return 'Code must be at least 3 characters';
    }
    return null;
  }

  // التحقق من صحة كلمة المرور
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Account activation function
  Future<void> _activateAccount() async {
    if (!_formKey.currentState!.validate()) {
      AuthWidgets.showWarningSnackBar(context, 'Please fix the errors in the form');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final response = await ApiService.activateAccount(
        universityEmail: _emailController.text,
        universityCode: _codeController.text,
        newPassword: _passwordController.text,
        deviceId: widget.deviceId,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['statusCode'] == 200) {
        final data = jsonDecode(response['body']);
        
        // Show success message
        AuthWidgets.showSuccessSnackBar(context, 'Account activated successfully! You can now login.');

        // Switch to login page automatically after a small delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            widget.onSwitchToLogin();
          }
        });

      } else {
        String errorMessage = 'Activation failed. Please try again';
        if (response['statusCode'] == 400) {
          errorMessage = 'Invalid data. Please check your information';
        } else if (response['statusCode'] == 404) {
          errorMessage = 'Account not found. Please check your email';
        } else if (response['statusCode'] == 409) {
          errorMessage = 'Account already activated';
        }

        AuthWidgets.showErrorSnackBar(context, errorMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AuthWidgets.showErrorSnackBar(context, 'Connection error: $e');
    }
  }

  Widget _buildMessageContainer() {
    if (_message.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isError ? AppColors.errorColor.withOpacity(0.1) : AppColors.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isError ? AppColors.errorColor.withOpacity(0.3) : AppColors.successColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isError ? Icons.error_outline : Icons.check_circle_outline,
            color: _isError ? AppColors.errorColor : AppColors.successColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(
                color: _isError ? AppColors.errorColor : AppColors.successColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
            'Activate Account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter your details to activate your college attendance account',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 30),

          // University Email field
          AuthWidgets.buildTextField(
            controller: _emailController,
            label: 'University Email',
            hint: 'Enter your email',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            validator: _validateEmail,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_codeFocus);
            },
          ),
          const SizedBox(height: 20),

          // University Code field
          AuthWidgets.buildTextField(
            controller: _codeController,
            label: 'University Code',
            hint: 'Enter your code',
            prefixIcon: Icons.vpn_key,
            focusNode: _codeFocus,
            validator: _validateCode,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_passwordFocus);
            },
          ),
          const SizedBox(height: 20),

          // New Password field
          AuthWidgets.buildPasswordField(
            controller: _passwordController,
            label: 'New Password',
            hint: 'Enter a strong password (min. 6 characters)',
            obscureText: _obscurePassword,
            focusNode: _passwordFocus,
            validator: _validatePassword,
            onToggle: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          const SizedBox(height: 30),

          // Device ID display (read-only)
          AuthWidgets.buildDeviceIdDisplay(
              deviceId: widget.deviceId,
              onRefresh: () => widget.onDeviceIdRefresh('')
          ),

          const SizedBox(height: 30),

          // Activate button
          AuthWidgets.buildActionButton(
            text: 'Activate Account',
            onPressed: _activateAccount,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 20),

          // Switch to login link
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToLogin,
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.darkColor,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Login',
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

          // Message display
          _buildMessageContainer(),
        ],
      ),
    );
  }
}
