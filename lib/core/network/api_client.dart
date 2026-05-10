import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../Auth/api_service.dart';
import '../../Auth/auth_storage.dart';
import '../app_router.dart';
import 'app_exception.dart';

/// Central HTTP client with unified error handling.
class ApiClient {
  static const String sessionExpiredMessage =
    'Your session has expired. Please log in again.';
  static const String noInternetMessage =
    'No internet connection. Check your network.';
  static const String timeoutMessage =
    'Request timed out. Please try again.';
  static const String serverErrorMessage =
    'Server error. Please try again later.';

  /// Creates an [ApiClient].
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sends a GET request.
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    return _send(
      method: 'GET',
      endpoint: endpoint,
      headers: headers,
    );
  }

  /// Sends a POST request.
  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _send(
      method: 'POST',
      endpoint: endpoint,
      headers: headers,
      body: body,
    );
  }

  /// Sends a PUT request.
  Future<dynamic> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _send(
      method: 'PUT',
      endpoint: endpoint,
      headers: headers,
      body: body,
    );
  }

  /// Sends a DELETE request.
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _send(
      method: 'DELETE',
      endpoint: endpoint,
      headers: headers,
      body: body,
    );
  }

  /// Sends a streaming GET request (SSE). Caller must close the stream.
  Future<http.StreamedResponse> streamGet(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    final request = http.Request('GET', uri);
    final token = await AuthStorage.getToken();
    request.headers.addAll(_buildHeaders(headers, token));
    request.headers.putIfAbsent('Accept', () => 'text/event-stream');

    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      _handleStreamResponse(response, endpoint);
      return response;
    } on SocketException {
      throw const AppException(
        message: noInternetMessage,
      );
    } on TimeoutException {
      throw const AppException(
        message: timeoutMessage,
      );
    } on FormatException {
      throw const AppException(
        message: 'Unexpected server response. Please try again.',
      );
    } catch (_) {
      throw const AppException(
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<dynamic> _send({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = _buildUri(endpoint);
    final token = await AuthStorage.getToken();
    final mergedHeaders = _buildHeaders(headers, token);

    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: mergedHeaders)
              .timeout(const Duration(seconds: 30));
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: mergedHeaders, body: body)
              .timeout(const Duration(seconds: 30));
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: mergedHeaders, body: body)
              .timeout(const Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: mergedHeaders, body: body)
              .timeout(const Duration(seconds: 30));
          break;
        default:
          throw const AppException(
            message: 'Something went wrong. Please try again.',
          );
      }

      return _handleResponse(response, endpoint);
    } on SocketException {
      throw const AppException(
        message: noInternetMessage,
      );
    } on TimeoutException {
      throw const AppException(
        message: timeoutMessage,
      );
    } on FormatException {
      throw const AppException(
        message: 'Unexpected server response. Please try again.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException(
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  Uri _buildUri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }
    return Uri.parse('${ApiService.baseUrl}$endpoint');
  }

  Map<String, String> _buildHeaders(
    Map<String, String>? headers,
    String? token,
  ) {
    final merged = <String, String>{
      'accept': '*/*',
    };
    if (headers != null) merged.addAll(headers);
    if (token != null && token.isNotEmpty) {
      merged['Authorization'] = 'Bearer $token';
    }
    return merged;
  }

  dynamic _handleResponse(http.Response response, String endpoint) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode <= 204) {
      if (response.body.isEmpty) return null;
      return _decodeBody(response.body);
    }

    if (statusCode == 401) {
      _handleAuthExpired();
      throw AppException(
        message: sessionExpiredMessage,
        statusCode: statusCode,
        endpoint: endpoint,
      );
    }

    final message = ApiClient.mapErrorMessage(statusCode, endpoint);
    throw AppException(
      message: message,
      statusCode: statusCode,
      endpoint: endpoint,
    );
  }

  void _handleStreamResponse(http.StreamedResponse response, String endpoint) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode <= 204) return;
    if (statusCode == 401) {
      _handleAuthExpired();
      throw AppException(
        message: sessionExpiredMessage,
        statusCode: statusCode,
        endpoint: endpoint,
      );
    }
    final message = ApiClient.mapErrorMessage(statusCode, endpoint);
    throw AppException(
      message: message,
      statusCode: statusCode,
      endpoint: endpoint,
    );
  }

  dynamic _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const AppException(
        message: 'Unexpected server response. Please try again.',
      );
    }
  }

  void _handleAuthExpired() {
    AuthStorage.clearUserData();
    final messenger = AppRouter.messengerKey.currentState;
    if (messenger != null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please log in again.'),
        ),
      );
    }
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
  }

  static String mapErrorMessage(int statusCode, String endpoint) {
    if (statusCode == 401) {
      return sessionExpiredMessage;
    }
    if (statusCode == 403) {
      return "You don't have permission to do this.";
    }
    if (statusCode == 429) {
      if (_isActivate(endpoint)) {
        return 'Too many activation attempts. Please wait.';
      }
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return serverErrorMessage;
    }

    if (statusCode == 400) {
      return _map400(endpoint);
    }
    if (statusCode == 404) {
      return _map404(endpoint);
    }

    return 'Something went wrong. Please try again.';
  }

  static String _map400(String endpoint) {
    if (_isLogin(endpoint)) {
      return 'Incorrect email or password, or account not activated yet.';
    }
    if (_isActivate(endpoint)) {
      return 'Invalid or expired activation link.';
    }
    if (_isSubmitAttendance(endpoint)) {
      return 'Cannot submit attendance — session may be closed or already submitted.';
    }
    if (_isManualAdd(endpoint)) {
      return 'Student is already marked present.';
    }
    if (_isCreateSession(endpoint)) {
      return 'A conflicting session already exists for this course.';
    }
    if (_isStopSession(endpoint)) {
      return 'This session is already stopped.';
    }
    if (_isResumeSession(endpoint)) {
      return 'This session is already active.';
    }
    if (_isAssignStaff(endpoint)) {
      return 'Staff member is already assigned or codes are invalid.';
    }
    if (_isEnrollStudent(endpoint)) {
      return 'Student is already enrolled in this course.';
    }
    if (_isBulkCreateStudents(endpoint)) {
      return 'Some student records failed validation. Check the data.';
    }
    return 'Invalid request. Please check your input and try again.';
  }

  static String _map404(String endpoint) {
    if (_isLogin(endpoint)) {
      return 'Account not found. Check your university code.';
    }
    if (_isActivate(endpoint)) {
      return 'Activation link is invalid or has expired.';
    }
    if (_isDeleteUser(endpoint)) {
      return 'User not found.';
    }
    if (_isDeleteCourse(endpoint)) {
      return 'Course not found.';
    }
    if (_isResetStudent(endpoint)) {
      return 'Student account not found.';
    }
    if (_isSessionEndpoint(endpoint)) {
      return 'Session not found.';
    }
    if (_isAttendanceEndpoint(endpoint)) {
      return 'Session or student not found.';
    }
    if (_isCourseEndpoint(endpoint)) {
      return 'Course not found.';
    }
    return 'The requested item was not found.';
  }

  static bool _isLogin(String endpoint) => endpoint.toLowerCase().contains('/auth/login');
  static bool _isActivate(String endpoint) => endpoint.toLowerCase().contains('/auth/activate');
  static bool _isSubmitAttendance(String endpoint) => endpoint.toLowerCase().contains('/attendance/submit');
  static bool _isManualAdd(String endpoint) => endpoint.toLowerCase().contains('/attendance/manual-add');
  static bool _isCreateSession(String endpoint) => endpoint.toLowerCase().contains('/session/create');
  static bool _isStopSession(String endpoint) => endpoint.toLowerCase().contains('/session/stop');
  static bool _isResumeSession(String endpoint) => endpoint.toLowerCase().contains('/session/resume');
  static bool _isAssignStaff(String endpoint) => endpoint.toLowerCase().contains('/admin/assign-staff');
  static bool _isEnrollStudent(String endpoint) => endpoint.toLowerCase().contains('/course/enroll') && !endpoint.toLowerCase().contains('bulk');
  static bool _isBulkCreateStudents(String endpoint) => endpoint.toLowerCase().contains('/admin/create-students-bulk');
  static bool _isDeleteUser(String endpoint) => endpoint.toLowerCase().contains('/admin/delete-user');
  static bool _isDeleteCourse(String endpoint) => endpoint.toLowerCase().contains('/admin/delete-course');
  static bool _isResetStudent(String endpoint) => endpoint.toLowerCase().contains('/admin/reset-student-account');
  static bool _isSessionEndpoint(String endpoint) => endpoint.toLowerCase().contains('/session/');
  static bool _isAttendanceEndpoint(String endpoint) => endpoint.toLowerCase().contains('/attendance/');
  static bool _isCourseEndpoint(String endpoint) => endpoint.toLowerCase().contains('/course/');
}
