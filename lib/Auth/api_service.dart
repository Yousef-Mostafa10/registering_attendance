// api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://supergm-001-site1.ntempurl.com/api';

  // Account activation
  static Future<Map<String, dynamic>> activateAccount({
    required String universityEmail,
    required String universityCode,
    required String newPassword,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/activate'),
      headers: {
        'accept': '*/*',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "universityEmail": universityEmail,
        "universityCode": universityCode,
        "newPassword": newPassword,
        "deviceId": deviceId,
      }),
    );

    return {
      'statusCode': response.statusCode,
      'body': response.body,
    };
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/Login'),
      headers: {
        'accept': '*/*',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "email": email,
        "password": password,
        "deviceId": deviceId,
      }),
    );

    return {
      'statusCode': response.statusCode,
      'body': response.body,
    };
  }
}