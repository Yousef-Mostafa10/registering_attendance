import 'package:flutter/material.dart';

/// Global navigation keys for app-wide routing and snackbars.
class AppRouter {
  /// Global navigator key for navigation without context.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Global scaffold messenger key for snackbars without context.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
}
