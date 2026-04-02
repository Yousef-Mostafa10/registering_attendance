import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../Auth/auth_storage.dart';
import 'session_models.dart';

class SessionService {
  static const String baseUrl = 'http://supergm-001-site1.ntempurl.com/api';

  Future<String> _getToken() async {
    final token = await AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      return token;
    }
    throw Exception('Authentication token not found');
  }

  Future<CreateSessionResponse> createSession(CreateSessionDto dto) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/Session/create');
      
      print('POST $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(dto.toJson()),
      );

      print('Status Code: ${response.statusCode}');
      print('=== CREATE SESSION RAW RESPONSE ===');
      print(response.body);
      print('===================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        print('Decoded keys: ${decoded.keys.toList()}');
        print('sessionId value: ${decoded['sessionId']}');
        print('id value: ${decoded['id']}');
        return CreateSessionResponse.fromJson(decoded);
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  Future<RotateQrResponse> rotateQr(int sessionId) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/Session/rotateqr/$sessionId');
      
      print('POST $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status Code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return RotateQrResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception('Failed to rotate QR: $e');
    }
  }

  Future<void> stopSession(int sessionId) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/Session/stop/$sessionId');
      
      print('PUT $url');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status Code: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception('Failed to stop session: $e');
    }
  }

  Future<CreateSessionResponse> resumeSession(int sessionId) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/Session/resume/$sessionId');
      
      print('PUT $url');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status Code: ${response.statusCode}');
      print('=== RESUME SESSION RAW RESPONSE ===');
      print(response.body);
      print('===================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        print('Decoded keys: ${decoded.keys.toList()}');
        return CreateSessionResponse.fromJson(decoded);
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception('Failed to resume session: $e');
    }
  }

  Future<void> updateRadius(int sessionId, int radius) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/Session/updateradius/$sessionId');
      
      print('PUT $url');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: radius.toString(), // Note: body as string "50"
      );

      print('Status Code: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception('Failed to update radius: $e');
    }
  }
}

/*
void main() async {
  final service = SessionService();
  
  try {
    final dto = CreateSessionDto(
      courseId: 1,
      title: 'Math Lecture 1',
      sessionType: 'Lecture',
      latitude: 30.0444,
      longitude: 31.2357,
      allowRadius: 50,
    );
    
    final response = await service.createSession(dto);
    print('Session message: \${response.message}');
    print('Session ID: \${response.sessionId}');
  } catch (e) {
    print('Error: \$e');
  }
}
*/
