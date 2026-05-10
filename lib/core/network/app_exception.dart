/// A user-friendly exception for API errors.
class AppException implements Exception {
  /// Creates an [AppException] with a readable [message].
  const AppException({
    required this.message,
    this.statusCode,
    this.endpoint,
  });

  /// The user-facing error message.
  final String message;

  /// The HTTP status code, if available.
  final int? statusCode;

  /// The endpoint path that produced the error.
  final String? endpoint;

  @override
  String toString() => message;
}
