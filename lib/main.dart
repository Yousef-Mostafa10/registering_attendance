// main.dart
import 'package:flutter/material.dart';

import 'Auth/main_file.dart';


void main() {
  runApp(const CollegeAttendanceApp());
}

class CollegeAttendanceApp extends StatelessWidget {
  const CollegeAttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'College Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2A9D8F),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFE9C46A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F1DE),
      ),
      home: const ActivationLoginPage(showLogin: true),
    );
  }
}