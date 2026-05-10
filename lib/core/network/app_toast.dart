import 'package:flutter/material.dart';
import '../../Auth/colors.dart';
import 'app_exception.dart';

/// Snackbar/toast helper for user-friendly messages.
class AppToast {
  /// Shows a floating error snackbar with a safe message.
  static void showError(BuildContext context, Object? error) {
    final message = _messageFromError(error);
    _showSnackBar(
      context,
      message: message,
      backgroundColor: AppColors.errorColor,
      icon: Icons.error_outline,
    );
  }

  /// Shows a floating success snackbar.
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: AppColors.successColor,
      icon: Icons.check_circle,
    );
  }

  static String _messageFromError(Object? error) {
    if (error is AppException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
