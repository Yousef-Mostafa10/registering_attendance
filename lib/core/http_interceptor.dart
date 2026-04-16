import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as native_http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/auth_storage.dart';
import '../Auth/api_service.dart';

native_http.Response _offlineResponse() {
  return native_http.Response(
    jsonEncode({"message": "No Internet Connection - Please check your network."}),
    503,
  );
}

Future<native_http.Response> get(Uri url, {Map<String, String>? headers}) async {
  try {
    var res = await native_http.get(url, headers: headers);
    if (res.statusCode == 401) {
      bool refreshed = await _attemptRefresh();
      if (refreshed && headers != null && headers.containsKey('Authorization')) {
        final newToken = await AuthStorage.getToken();
        headers['Authorization'] = 'Bearer $newToken';
        return await native_http.get(url, headers: headers);
      }
    }
    return res;
  } on SocketException {
    return _offlineResponse();
  } catch (e) {
    return native_http.Response(jsonEncode({"message": "Network Timeout"}), 504);
  }
}

Future<native_http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  try {
    var res = await native_http.post(url, headers: headers, body: body, encoding: encoding);
    if (res.statusCode == 401) {
      bool refreshed = await _attemptRefresh();
      if (refreshed && headers != null && headers.containsKey('Authorization')) {
        final newToken = await AuthStorage.getToken();
        headers['Authorization'] = 'Bearer $newToken';
        return await native_http.post(url, headers: headers, body: body, encoding: encoding);
      }
    }
    return res;
  } on SocketException {
    return _offlineResponse();
  } catch (e) {
    return native_http.Response(jsonEncode({"message": "Network Timeout"}), 504);
  }
}

Future<native_http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  try {
    var res = await native_http.put(url, headers: headers, body: body, encoding: encoding);
    if (res.statusCode == 401) {
      bool refreshed = await _attemptRefresh();
      if (refreshed && headers != null && headers.containsKey('Authorization')) {
        final newToken = await AuthStorage.getToken();
        headers['Authorization'] = 'Bearer $newToken';
        return await native_http.put(url, headers: headers, body: body, encoding: encoding);
      }
    }
    return res;
  } on SocketException {
    return _offlineResponse();
  } catch (e) {
    return native_http.Response(jsonEncode({"message": "Network Timeout"}), 504);
  }
}

Future<native_http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  try {
    var res = await native_http.delete(url, headers: headers, body: body, encoding: encoding);
    if (res.statusCode == 401) {
      bool refreshed = await _attemptRefresh();
      if (refreshed && headers != null && headers.containsKey('Authorization')) {
        final newToken = await AuthStorage.getToken();
        headers['Authorization'] = 'Bearer $newToken';
        return await native_http.delete(url, headers: headers, body: body, encoding: encoding);
      }
    }
    return res;
  } on SocketException {
    return _offlineResponse();
  } catch (e) {
    return native_http.Response(jsonEncode({"message": "Network Timeout"}), 504);
  }
}

bool _isRefreshing = false;

Future<bool> _attemptRefresh() async {
  if (_isRefreshing) return false;
  _isRefreshing = true;

  try {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString('auth_token');
    final currentRefresh = prefs.getString('refresh_token');

    if (currentToken == null || currentRefresh == null) return false;

    final userData = await AuthStorage.getUserData();
    String deviceId = userData?['deviceId'] ?? 'error_device';

    final response = await native_http.post(
      Uri.parse('${ApiService.baseUrl}/Auth/refresh-token'),
      headers: {'accept': '*/*', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "token": currentToken,
        "refreshToken": currentRefresh,
        "deviceId": deviceId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newToken = data['token'];
      final newRefresh = data['refreshToken'];

      if (newToken != null && newRefresh != null) {
         await prefs.setString('auth_token', newToken);
         await prefs.setString('refresh_token', newRefresh);
         return true; // refresh success
      }
    }
    return false;
  } catch (e) {
    return false;
  } finally {
    _isRefreshing = false;
  }
}
