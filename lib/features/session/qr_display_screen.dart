import 'dart:async';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'session_service.dart';
import '../../Auth/colors.dart';

class QrDisplayScreen extends StatefulWidget {
  final int sessionId;
  final String initialQrContent;
  final String initialPinCode;

  const QrDisplayScreen({
    Key? key,
    required this.sessionId,
    required this.initialQrContent,
    required this.initialPinCode,
  }) : super(key: key);

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  late String qrContent;
  late String pinCode;
  bool isSessionActive = true;
  bool isLoading = false;
  int _countdown = 10;
  int attendeeCount = 0;
  Timer? _qrTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    qrContent = widget.initialQrContent;
    pinCode = widget.initialPinCode;

    print('QR SCREEN sessionId received: ${widget.sessionId}');
    print('=== QR SCREEN LOADED ===');
    print('Session ID: ${widget.sessionId}');
    print('Session ID is zero? ${widget.sessionId == 0}');
    print('Initial QR: $qrContent');
    print('Initial PIN: $pinCode');

    if (widget.sessionId == 0) {
      print('⚠️  WARNING: sessionId is 0 — check createSession API response JSON field names');
    }

    _startTimers();
  }

  void _startTimers() {
    _qrTimer?.cancel();
    _countdownTimer?.cancel();

    _qrTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final result = await SessionService().rotateQr(widget.sessionId);
        if (mounted) {
          setState(() {
            qrContent = result.newQr;
            pinCode = result.newPin;
            _countdown = 10;
          });
        }
        print('QR rotated at: ${DateTime.now()} — new PIN: $pinCode');
      } catch (e) {
        print('Error rotating QR: $e');
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _countdown = 10;
          }
        });
      }
    });
  }

  void _stopTimers() {
    _qrTimer?.cancel();
    _countdownTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  Future<void> _stopSession() async {
    setState(() => isLoading = true);
    try {
      print('Attempting to stop session ${widget.sessionId}...');
      // Cancel timers FIRST before the async call
      _stopTimers();
      await SessionService().stopSession(widget.sessionId);
      print('Session ${widget.sessionId} stopped ✓');
      if (mounted) {
        setState(() {
          isSessionActive = false;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Stop session error: $e');
      // If stop failed, restart timers
      if (isSessionActive) _startTimers();
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping session: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _resumeSession() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await SessionService().resumeSession(widget.sessionId);
      if (mounted) {
        setState(() {
          isSessionActive = true;
          qrContent = response.qrContent;
          pinCode = response.pinCode;
          _countdown = 10;
        });
      }
      _startTimers();
      print('Session ${widget.sessionId} resumed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming session: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.liveAttendance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Session ID: ${widget.sessionId}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSessionActive ? AppColors.successColor.withOpacity(0.1) : AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSessionActive ? AppColors.successColor.withOpacity(0.5) : AppColors.errorColor.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSessionActive ? Icons.check_circle : Icons.cancel,
                      color: isSessionActive ? AppColors.successColor : AppColors.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSessionActive ? 'Active — Students scanning' : 'Session Stopped',
                      style: TextStyle(
                        color: isSessionActive ? AppColors.darkColor : AppColors.errorColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // QR Code Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkColor.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (isSessionActive)
                      QrImageView(
                        data: qrContent,
                        size: 220,
                        backgroundColor: Colors.white,
                      )
                    else
                      Container(
                        width: 220,
                        height: 220,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('QR Unavailable', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      ),
                    const Divider(height: 48),
                    // PIN Code Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pin,
                          color: isSessionActive ? AppColors.primaryColor : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSessionActive ? pinCode : '----',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: isSessionActive ? AppColors.darkColor : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manual Entry PIN',
                      style: TextStyle(fontSize: 14, color: AppColors.darkColor.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Countdown & Attendees Info
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.timer_outlined,
                      title: 'Refresh In',
                      value: isSessionActive ? '${_countdown}s' : '--',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.people_alt_outlined,
                      title: 'Attendees',
                      value: '$attendeeCount',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : (isSessionActive ? _stopSession : _resumeSession),
                  icon: isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isSessionActive ? Icons.stop_circle : Icons.play_circle_fill, size: 24),
                  label: Text(
                    isSessionActive ? 'STOP SESSION' : 'RESUME SESSION',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSessionActive ? AppColors.errorColor : AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryColor.withOpacity(0.7), size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.darkColor.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
