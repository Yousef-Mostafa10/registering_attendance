import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as native_http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/auth_storage.dart';
import '../Auth/api_service.dart';
import 'app_router.dart';

const String _sessionExpiredMessage =
    'Your session has expired. Please log in again.';
const String _noInternetMessage = 'No internet connection. Check your network.';
const String _timeoutMessage = 'Request timed out. Please try again.';
const String _serverErrorMessage = 'Server error. Please try again later.';

native_http.Response _offlineResponse() {
  return native_http.Response(
    jsonEncode({"message": _noInternetMessage}),
    503,
  );
}

native_http.Response _timeoutResponse() {
  return native_http.Response(
    jsonEncode({"message": _timeoutMessage}),
    504,
  );
}

native_http.Response _serverErrorResponse() {
  return native_http.Response(
    jsonEncode({"message": _serverErrorMessage}),
    502,
  );
}

native_http.Response _sessionExpiredResponse() {
  return native_http.Response(
    jsonEncode({"message": _sessionExpiredMessage}),
    401,
  );
}

native_http.Response _normalizeResponse(native_http.Response res) {
  if (res.statusCode >= 500 && res.statusCode <= 599) {
    return _serverErrorResponse();
  }
  return res;
}

Future<native_http.Response> _withAuthRefresh(
  Future<native_http.Response> Function() request,
  Map<String, String>? headers,
) async {
  final res = await request();
  if (res.statusCode == 401) {
    final refreshed = await _attemptRefresh();
    if (refreshed && headers != null && headers.containsKey('Authorization')) {
      final newToken = await AuthStorage.getToken();
      headers['Authorization'] = 'Bearer $newToken';
      return _normalizeResponse(await request());
    }
    _handleAuthExpired();
    return _sessionExpiredResponse();
  }
  return _normalizeResponse(res);
}

Future<native_http.Response> get(Uri url, {Map<String, String>? headers}) async {
  try {
    return await _withAuthRefresh(
      () => native_http.get(url, headers: headers)
          .timeout(const Duration(seconds: 30)),
      headers,
    );
  } on SocketException {
    return _offlineResponse();
  } on TimeoutException {
    return _timeoutResponse();
  } catch (e) {
    return _timeoutResponse();
  }
}

Future<native_http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  try {
    return await _withAuthRefresh(
      () => native_http.post(url, headers: headers, body: body, encoding: encoding)
          .timeout(const Duration(seconds: 30)),
      headers,
    );
  } on SocketException {
    return _offlineResponse();
  } on TimeoutException {
    return _timeoutResponse();
  } catch (e) {
    return _timeoutResponse();
  }
}

Future<native_http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  try {
    return await _withAuthRefresh(
      () => native_http.put(url, headers: headers, body: body, encoding: encoding)
          .timeout(const Duration(seconds: 30)),
      headers,
    );
  } on SocketException {
    return _offlineResponse();
  } on TimeoutException {
    return _timeoutResponse();
  } catch (e) {
    return _timeoutResponse();
  }
}

Future<native_http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  try {
    return await _withAuthRefresh(
      () => native_http.delete(url, headers: headers, body: body, encoding: encoding)
          .timeout(const Duration(seconds: 30)),
      headers,
    );
  } on SocketException {
    return _offlineResponse();
  } on TimeoutException {
    return _timeoutResponse();
  } catch (e) {
    return _timeoutResponse();
  }
}

void _handleAuthExpired() {
  AuthStorage.clearUserData();
  final messenger = AppRouter.messengerKey.currentState;
  if (messenger != null) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(_sessionExpiredMessage),
      ),
    );
  }
  final navigator = AppRouter.navigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushNamedAndRemoveUntil('/', (route) => false);
}

bool _isRefreshing = false;

Future<bool> _attemptRefresh() async {
  if (_isRefreshing) return false;
  _isRefreshing = true;

  try {
    final userData = await AuthStorage.getUserData();
    if (userData == null) return false;

    final currentToken = userData['token'];
    final currentRefresh = userData['refreshToken'];
    final deviceId = userData['deviceId'];

    if (currentToken == null || currentRefresh == null || deviceId == null) return false;

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
         await AuthStorage.updateTokens(newToken, newRefresh);
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
