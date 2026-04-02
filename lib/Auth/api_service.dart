// api_service.dart — All Developer 2 endpoints with correct URLs from Swagger
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://supergm-001-site1.ntempurl.com/api';

  // ─── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> activateAccount({
    required String universityEmail,
    required String universityCode,
    required String newPassword,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/activate'),
      headers: {'accept': '*/*', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "universityEmail": universityEmail,
        "universityCode": universityCode,
        "newPassword": newPassword,
        "deviceId": deviceId,
      }),
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/Login'),
      headers: {'accept': '*/*', 'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password, "deviceId": deviceId}),
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  // ─── Course — Developer 2 ──────────────────────────────────────────────────

  /// GET /Course/number-of-enrolled-students/{courseId}
  /// Doctor / TA / Admin
  static Future<Map<String, dynamic>> getEnrolledCount({
    required String courseId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/Course/number-of-enrolled-students/$courseId'),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  /// GET /Course/get-enrolled-students/{courseId}?search=
  /// Doctor / TA / Admin
  static Future<Map<String, dynamic>> getEnrolledStudents({
    required String courseId,
    required String token,
    String? search,
  }) async {
    String url = '$baseUrl/Course/get-enrolled-students/$courseId';
    if (search != null && search.isNotEmpty) url += '?search=${Uri.encodeComponent(search)}';
    final response = await http.get(
      Uri.parse(url),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  // ─── Attendance Reports — Developer 2 ─────────────────────────────────────

  /// GET /Attendance/lecture-report/{courseId}?totalMarks=
  /// Doctor only
  static Future<Map<String, dynamic>> getLectureReport({
    required String courseId,
    required String token,
    String? totalMarks,
  }) async {
    String url = '$baseUrl/Attendance/lecture-report/$courseId';
    if (totalMarks != null && totalMarks.isNotEmpty) url += '?totalMarks=$totalMarks';
    final response = await http.get(
      Uri.parse(url),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  /// GET /Attendance/section-report/{courseId}?totalMarks=
  /// Doctor or TA
  static Future<Map<String, dynamic>> getSectionReport({
    required String courseId,
    required String token,
    String? totalMarks,
  }) async {
    String url = '$baseUrl/Attendance/section-report/$courseId';
    if (totalMarks != null && totalMarks.isNotEmpty) url += '?totalMarks=$totalMarks';
    final response = await http.get(
      Uri.parse(url),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  /// GET /Attendance/absence-warnings/{courseId}
  /// Doctor only
  static Future<Map<String, dynamic>> getAbsenceWarnings({
    required String courseId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/Attendance/absence-warnings/$courseId'),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  /// GET /Attendance/session-attendees/{sessionId}?search=
  /// Doctor / TA / Admin
  static Future<Map<String, dynamic>> getSessionAttendees({
    required String sessionId,
    required String token,
    String? search,
  }) async {
    String url = '$baseUrl/Attendance/session-attendees/$sessionId';
    if (search != null && search.isNotEmpty) url += '?search=${Uri.encodeComponent(search)}';
    final response = await http.get(
      Uri.parse(url),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  // ─── Session History — Developer 2 ────────────────────────────────────────

  /// GET /Session/course-sessions/{courseId}/{type}
  /// type = "Lecture" | "Section"
  static Future<Map<String, dynamic>> getCourseSessions({
    required String courseId,
    required String token,
    required String type, // "Lecture" or "Section"
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/Session/course-sessions/$courseId/$type'),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  // ─── Session Management — Doctor/TA ───────────────────────────────────────

  /// POST /Session/create
  static Future<Map<String, dynamic>> createSession({
    required String token,
    required int courseId,
    required String title,
    required String sessionType, // "Lecture" | "Section"
    required double latitude,
    required double longitude,
    int allowRadius = 50,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Session/create'),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "courseId": courseId,
        "title": title,
        "sessionType": sessionType,
        "latitude": latitude,
        "longitude": longitude,
        "allowRadius": allowRadius,
      }),
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  /// PUT /Session/stop/{sessionId}
  static Future<Map<String, dynamic>> stopSession({
    required String token,
    required String sessionId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/Session/stop/$sessionId'),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }

  /// PUT /Session/resume/{sessionId}
  static Future<Map<String, dynamic>> resumeSession({
    required String token,
    required String sessionId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/Session/resume/$sessionId'),
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );
    return {'statusCode': response.statusCode, 'body': response.body};
  }
}