import 'dart:convert';
import 'package:flutter/material.dart';
import '../Auth/colors.dart';
import '../Auth/auth_storage.dart';
import '../Auth/api_service.dart';
import '../widgets/AppInstructionsCard.dart';

class ResetStudentsForNewYearPage extends StatefulWidget {
  final bool isTab;
  const ResetStudentsForNewYearPage({Key? key, this.isTab = false}) : super(key: key);
  @override
  _ResetStudentsForNewYearPageState createState() =>
      _ResetStudentsForNewYearPageState();
}

class _ResetStudentsForNewYearPageState extends State<ResetStudentsForNewYearPage> {
  bool _isLoading = false;
  String? _apiResponse;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
  }

  // ── Full system reset ─────────────────────────────────────────
  Future<void> _systemReset() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (!mounted) return;
      _snack('Authentication token not found', Colors.red);
      return;
    }

    final ok = await _showConfirm(
        'Reset entire system?',
        '⚠️ This resets ALL student data system-wide to prepare for a new academic year.\nCannot be undone!',
        'Yes, Reset System');
    if (!ok) return;

    if (!mounted) return;
    setState(() { _isLoading = true; _apiResponse = null; _isSuccess = false; });
    try {
      final response = await ApiService.resetSystemForNewYear(
        token: token,
      );

      final statusCode = response['statusCode'] as int;
      final responseBody = response['body'] as String;

      if (statusCode == 200) {
        String msg = '✅ System reset for new year successfully!';
        try { final d = jsonDecode(responseBody); if (d['message'] != null) msg = '✅ ${d['message']}'; } catch (_) {}
        
        if (!mounted) return;
        setState(() { _apiResponse = msg; _isSuccess = true; });
        _snack(msg, Colors.green);
      } else {
        throw Exception('Failed ($statusCode)');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _apiResponse = 'Error: $e'; _isSuccess = false; });
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  Future<bool> _showConfirm(String title, String body, String label) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, color: Colors.red))),
        ]),
        content: Text(body, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(label),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Widget _buildResponseCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _isSuccess ? Colors.green : Colors.red),
    ),
    child: Row(children: [
      Icon(_isSuccess ? Icons.check_circle : Icons.error,
          color: _isSuccess ? Colors.green : Colors.red, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(_apiResponse!, style: TextStyle(color: AppColors.darkColor, fontSize: 14))),
      GestureDetector(onTap: () => setState(() => _apiResponse = null),
          child: const Icon(Icons.close, size: 14, color: Colors.grey)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      body: CustomScrollView(slivers: [
        if (!widget.isTab)
          SliverAppBar(
            expandedHeight: 120, collapsedHeight: 80,
            pinned: true, floating: true,
            backgroundColor: AppColors.errorColor, elevation: 8,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40))),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text('Reset For New Year',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.errorColor, const Color(0xFFD65F51)]))),
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full System Reset',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Resets the entire system for the new academic year.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.darkColor.withOpacity(0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _systemReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorColor, // Use the orange/red app color
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: _isLoading 
                            ? const SizedBox.shrink() 
                            : const Icon(Icons.autorenew, size: 22),
                        label: _isLoading
                            ? const SizedBox(
                                width: 24, 
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Reset Entire System',
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
