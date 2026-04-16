import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:registering_attendance/core/http_interceptor.dart' as intercepted_http;
import 'package:http/http.dart' as http;
import '../../Auth/colors.dart';
import '../../Auth/api_service.dart';
import '../../Auth/auth_storage.dart';

class LiveDashboardPage extends StatefulWidget {
  final int sessionId;
  final String courseName;
  final String initialQr;
  final String initialPin;
  final bool isResumed;

  const LiveDashboardPage({
    Key? key,
    required this.sessionId,
    required this.courseName,
    required this.initialQr,
    required this.initialPin,
    required this.isResumed,
  }) : super(key: key);

  @override
  State<LiveDashboardPage> createState() => _LiveDashboardPageState();
}

class _LiveDashboardPageState extends State<LiveDashboardPage> with SingleTickerProviderStateMixin {
  late String _currentQr;
  late String _currentPin;
  bool _isSessionActive = true;
  int _attendeeCount = 0;
  int _qrInterval = 10;

  Timer? _qrTimer;
  http.Client? _sseClient;

  // Animation for the pulsing effect when new student joins
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentQr = widget.initialQr;
    _currentPin = widget.initialPin;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _startQrRotation();
    _startSseStream();
  }

  void _startQrRotation() {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(Duration(seconds: _qrInterval), (timer) async {
      if (!_isSessionActive) {
        timer.cancel();
        return;
      }
      try {
        final token = await AuthStorage.getToken() ?? '';
        final response = await intercepted_http.post(
          Uri.parse('${ApiService.baseUrl}/Session/rotate-qr/${widget.sessionId}'),
          headers: {
            'accept': '*/*',
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _currentQr = decoded['newQr'] ?? _currentQr;
              _currentPin = decoded['newPin'] ?? _currentPin;
            });
          }
        }
      } catch (e) {
        // Silently ignore if QR rotation fails temporarily
      }
    });
  }

  Future<void> _startSseStream() async {
    _sseClient?.close();
    _sseClient = http.Client();
    
    final token = await AuthStorage.getToken() ?? '';
    final request = http.Request('GET', Uri.parse('${ApiService.baseUrl}/Session/live-dashboard/${widget.sessionId}'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';

    try {
      final response = await _sseClient!.send(request);
      
      response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.startsWith('data:')) {
            final dataStr = line.substring(5).trim();
            if (dataStr.isNotEmpty) {
              try {
                final event = jsonDecode(dataStr);
                
                if (event['status'] == 'closed') {
                  if (mounted) {
                    setState(() => _isSessionActive = false);
                  }
                  _qrTimer?.cancel();
                  _sseClient?.close();
                } else {
                  if (mounted) {
                    final newCount = int.tryParse(event['count']?.toString() ?? '0') ?? 0;
                    if (newCount > _attendeeCount) {
                      _pulseController.forward(from: 0.0); // Trigger visual feedback
                    }
                    setState(() {
                      _attendeeCount = newCount;
                    });
                  }
                }
              } catch (_) {}
            }
          }
        },
        onError: (err) {
          // Attempt reconnection if stream drops while active
          if (_isSessionActive) {
            Future.delayed(const Duration(seconds: 3), _startSseStream);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (_isSessionActive) {
        Future.delayed(const Duration(seconds: 3), _startSseStream);
      }
    }
  }

  Future<void> _toggleSessionState() async {
    final token = await AuthStorage.getToken() ?? '';
    final isStopping = _isSessionActive;
    
    final endpoint = isStopping ? 'stop' : 'resume';
    try {
      final response = await intercepted_http.put(
        Uri.parse('${ApiService.baseUrl}/Session/$endpoint/${widget.sessionId}'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (isStopping) {
          setState(() => _isSessionActive = false);
          _qrTimer?.cancel();
          _sseClient?.close();
        } else {
          setState(() => _isSessionActive = true);
          _startQrRotation();
          _startSseStream();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action failed: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error')),
        );
      }
    }
  }

  Future<void> _showUpdateRadiusDialog() async {
    double tempRadius = 50.0;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Update Radius', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Change the allowed scanning distance for students (in meters).'),
                  const SizedBox(height: 16),
                  Text('${tempRadius.toInt()} meters', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                  Slider(
                    value: tempRadius,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    activeColor: Colors.indigo,
                    onChanged: (val) {
                      setStateBuilder(() => tempRadius = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final token = await AuthStorage.getToken() ?? '';
                    try {
                      final response = await intercepted_http.put(
                        Uri.parse('${ApiService.baseUrl}/Session/update-radius/${widget.sessionId}'),
                        headers: {
                          'accept': '*/*',
                          'Authorization': 'Bearer $token',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode(tempRadius.toInt()),
                      );
                      if (response.statusCode == 200 && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Radius updated successfully!'), backgroundColor: AppColors.successColor),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: AppColors.errorColor),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Network error'), backgroundColor: AppColors.errorColor),
                        );
                      }
                    }
                  },
                  child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _sseClient?.close();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Live Session', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkColor,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                _isSessionActive ? 'Active' : 'Closed',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _isSessionActive ? AppColors.successColor : Colors.grey,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Stats
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.lightColor2,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Text(widget.courseName, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Session ID: #${widget.sessionId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.darkColor)),
                      const SizedBox(width: 8),
                      if (_isSessionActive)
                        IconButton(
                          onPressed: _showUpdateRadiusDialog,
                          icon: const Icon(Icons.architecture, color: Colors.indigo),
                          tooltip: 'Update Radius',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people, size: 32, color: AppColors.primaryColor),
                          const SizedBox(height: 8),
                          Text(
                            '$_attendeeCount',
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Live Attendees Count', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Dynamic QR Section
            if (_isSessionActive) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Scan using Student App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _qrInterval,
                    icon: const Icon(Icons.timer, size: 18, color: Colors.indigo),
                    underline: const SizedBox(),
                    items: [10, 20, 30, 60].map((int val) {
                      return DropdownMenuItem<int>(
                        value: val,
                        child: Text('${val}s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) {
                        setState(() {
                          _qrInterval = newVal;
                        });
                        _startQrRotation();
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('QR Code interval changed to $newVal seconds'), backgroundColor: Colors.indigo),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo.withOpacity(0.3), width: 2),
                    ),
                    child: QrImageView(
                      data: jsonEncode({
                        "sessionId": widget.sessionId,
                        "qrContent": _currentQr
                      }),
                      version: QrVersions.auto,
                      size: 250.0,
                      gapless: false,
                    ),
                  ),
                  // Lock overlay if closed, though we remove the QR entirely above, this is for future proofing
                ],
              ),
              const SizedBox(height: 24),

              // PIN Code
              const Text('OR ENTER PIN', style: TextStyle(color: Colors.grey, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Text(
                  _currentPin,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 8),
              Text('PIN and QR automatically change every $_qrInterval seconds', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ] else ...[
              // Closed State UI
              const Icon(Icons.lock, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Attendance is Closed', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],

            const SizedBox(height: 48),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _toggleSessionState,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSessionActive ? AppColors.errorColor : AppColors.successColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(_isSessionActive ? Icons.stop_circle : Icons.play_circle, color: Colors.white),
                  label: Text(
                    _isSessionActive ? 'Stop Session' : 'Resume Session',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
