import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/ecg_processor.dart';
import '../../services/ecg_chart_capture_service.dart';
import '../../services/ecg_storage_service.dart';
import '../../models/ecg_data.dart';
import '../../models/session_context.dart';
import '../../services/session_context_service.dart';
import '../../services/gemini_service.dart';
import '../../models/ecg_summary.dart';

class ECGScreen extends StatefulWidget {
  const ECGScreen({super.key});

  @override
  State<ECGScreen> createState() => _ECGScreenState();
}

class _ECGScreenState extends State<ECGScreen> {
  // Chart Data
  final List<FlSpot> _spots = [];
  double _xValue = 0;

  // Bluetooth & Data Handling
  BluetoothConnection? _connection;
  bool _isConnected = false;
  String _dataBuffer = "";

  // Session Context
  SessionContext? _sessionContext;

  // Configuration
  // Tuned for 7000-16000 range as requested
  final double _minY = 0;
  final double _maxY = 26000;
  final int _maxPoints = 300;

  // Pan-Tompkins Processor
  late ECGProcessor _ecgProcessor;
  final List<int> _rPeakXPositions =
      []; // X-coordinates of R-peaks for visualization

  // Screenshot & Storage
  final ECGChartCaptureService _captureService = ECGChartCaptureService();
  final ECGStorageService _storageService = ECGStorageService();
  DateTime? _sessionStartTime;

  // Metrics
  double _currentHeartRate = 0;
  int _totalRPeaks = 0;

  @override
  void initState() {
    super.initState();
    // Initialize ECG Processor with ESP32 sampling rate
    _ecgProcessor = ECGProcessor(samplingRate: 860);
    _sessionStartTime = DateTime.now();

    // Initialize with some empty spots for smoother start
    for (int i = 0; i < _maxPoints; i++) {
      _spots.add(FlSpot(i.toDouble(), 0));
    }
    _xValue = _maxPoints.toDouble();
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _endSessionAndAnalyze();
    } else {
      // Step 1: Get pre-monitoring context first
      final SessionContext? sessionContext = await context.push(
        '/ecg/premonitoring',
      );

      if (sessionContext == null) {
        // User cancelled the questionnaire
        return;
      }

      // Store the session context
      setState(() {
        _sessionContext = sessionContext;
      });

      // Step 2: Now proceed to device pairing
      final BluetoothDevice? device = await context.push('/ecg/pairing');
      if (device != null) {
        _connectToDevice(device);
      } else {
        // User cancelled pairing, clear session context
        setState(() {
          _sessionContext = null;
        });
      }
    }
  }

  void _disconnect() {
    _connection?.dispose();
    _connection = null;
    if (mounted) {
      setState(() {
        _isConnected = false;
        _dataBuffer = "";
        _currentHeartRate = 0;
        _totalRPeaks = 0;
      });
    }
    // Reset processor for next session
    _ecgProcessor.reset();
    _rPeakXPositions.clear();
    _sessionStartTime = DateTime.now();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // 1. Request Android 12+ Permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothConnect] == PermissionStatus.denied) {
      if (mounted) _showSnackBar("Bluetooth Connect permission denied");
      return;
    }

    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(
        device.address,
      );
      setState(() {
        _connection = connection;
        _isConnected = true;
      });

      // Log session context when connection is established
      if (_sessionContext != null) {
        SessionContextService.logSessionContext(_sessionContext!);
        print('ECG Session started with metadata:');
        print(SessionContextService.toJsonString(_sessionContext!));
      }

      connection.input!.listen(_onDataReceived).onDone(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      });
    } catch (e) {
      if (mounted) _showSnackBar("Cannot connect: $e");
    }
  }

  void _onDataReceived(Uint8List data) {
    try {
      String incoming = ascii.decode(data);
      _dataBuffer += incoming;

      while (_dataBuffer.contains('\n')) {
        int index = _dataBuffer.indexOf('\n');
        String packet = _dataBuffer.substring(0, index).trim();
        _dataBuffer = _dataBuffer.substring(index + 1);

        if (packet.isNotEmpty) {
          _processPacket(packet);
        }
      }
    } catch (e) {
      // Handle decoding errors silently or log
    }
  }

  void _processPacket(String packet) {
    try {
      double rawValue = double.parse(packet);

      // Process through Pan-Tompkins algorithm
      final (filteredValue, isRPeak) = _ecgProcessor.processSample(rawValue);

      if (mounted) {
        setState(() {
          // Add raw ECG value to chart
          _spots.add(FlSpot(_xValue, rawValue));

          // If R-peak detected, store its position for visualization
          if (isRPeak) {
            _rPeakXPositions.add(_xValue.toInt());
            _totalRPeaks++;

            // Calculate real-time BPM from processor
            _currentHeartRate = _ecgProcessor.calculateBPM();
          }

          _xValue++;

          // Maintain sliding window
          if (_spots.length > _maxPoints) {
            _spots.removeAt(0);

            // Remove R-peak markers that are no longer visible
            final minVisibleX = _xValue - _maxPoints;
            _rPeakXPositions.removeWhere((x) => x < minVisibleX);
          }
        });
      }
    } catch (e) {
      // Ignore garbage data
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "Live ECG Monitor",
          style: GoogleFonts.outfit(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isConnected ? AppColors.success : AppColors.error,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _isConnected ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? "ONLINE" : "OFFLINE",
                  style: GoogleFonts.outfit(
                    color: _isConnected ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Chart Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Grid Background
                    Positioned.fill(child: CustomPaint(painter: GridPainter())),
                    // Main Chart wrapped with Screenshot
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Screenshot(
                        controller: _captureService.screenshotController,
                        child: LineChart(
                          LineChartData(
                            minY: _minY,
                            maxY: _maxY,
                            minX: _spots.isNotEmpty ? _spots.first.x : 0,
                            maxX: _spots.isNotEmpty ? _spots.last.x : 0,
                            gridData: FlGridData(
                              show: false,
                            ), // Using custom painter for cleaner look
                            titlesData: FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            // R-peak vertical line markers
                            extraLinesData: ExtraLinesData(
                              verticalLines: _rPeakXPositions.map((xPos) {
                                return VerticalLine(
                                  x: xPos.toDouble(),
                                  color: Colors.red.withOpacity(0.6),
                                  strokeWidth: 2,
                                  dashArray: [4, 4],
                                );
                              }).toList(),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _spots,
                                isCurved: true,
                                curveSmoothness: 0.2,
                                color: AppColors.secondary,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  checkToShowDot: (spot, barData) {
                                    // Show dots only at R-peaks
                                    return _rPeakXPositions.contains(
                                      spot.x.toInt(),
                                    );
                                  },
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 5,
                                          color: Colors.red,
                                          strokeWidth: 2,
                                          strokeColor: Colors.white,
                                        );
                                      },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary.withOpacity(0.2),
                                      AppColors.secondary.withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              enabled: false,
                            ), // Disable touch for performance
                          ),
                        ),
                      ), // Close Screenshot widget
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Metrics & Controls
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        "Heart Rate",
                        _currentHeartRate > 0
                            ? "${_currentHeartRate.toInt()}"
                            : "--",
                        Icons.monitor_heart,
                        Colors.red,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      _buildMetric(
                        "R-Peaks",
                        _totalRPeaks.toString(),
                        Icons.favorite,
                        Colors.red,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      _buildMetric(
                        "Signal Value",
                        _spots.isNotEmpty ? "${_spots.last.y.toInt()}" : "--",
                        Icons.electric_bolt,
                        AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _toggleConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConnected
                            ? AppColors.error
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isConnected ? "Stop Session" : "Start Monitoring",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _endSessionAndAnalyze() async {
    // 1. Prepare Summary Data
    final durationSeconds = (_xValue / 860).round();
    final double avgHr = durationSeconds > 0
        ? (_totalRPeaks / durationSeconds) * 60
        : 0;
    
    double totalSignal = 0;
    for (var spot in _spots) {
      totalSignal += spot.y;
    }
    final double avgSignal = _spots.isNotEmpty ? totalSignal / _spots.length : 0;

    final summary = EcgSummary(
      averageHeartRate: avgHr,
      totalRPeaks: _totalRPeaks,
      durationSeconds: durationSeconds,
      averageSignalValue: avgSignal,
    );

    final contextForAnalysis = _sessionContext;
    if (contextForAnalysis == null) {
      _disconnect();
      return;
    }

    // 2. Show Loading Dialog (Persistent)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Saving & Analyzing..."),
              ],
            ),
          ),
        ),
      ),
    );

    File? imageFile;
    try {
      // 3. Capture Chart Image
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        imageFile = await _captureService.captureChart(
          userId: userId,
          sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // 4. Save Session (Background)
      if (userId != null && imageFile != null) {
        final session = ECGSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          startTime: _sessionStartTime ?? DateTime.now(),
          endTime: DateTime.now(),
          durationSeconds: durationSeconds,
          samples: [],
          rPeaks: _ecgProcessor.getDetectedRPeaks(),
          averageHeartRate: avgHr,
          totalRPeaks: _totalRPeaks,
        );
        
        // Save without awaiting to speed up analysis UI? 
        // No, we should await to ensure data integrity before leaving.
        await _storageService.saveSessionWithImage(
          session: session,
          imageFile: imageFile,
        );
      }

      // 5. Generate Insights (with Image)
      final geminiService = GeminiService();
      final report = await geminiService.generateConsultation(
        contextForAnalysis,
        summary,
        chartImage: imageFile,
      );

      // 6. Navigate
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        context.push('/insights', extra: report);
      }
    } catch (e) {
      print("Error in analysis flow: $e");
      if (mounted) Navigator.of(context).pop(); // Close dialog on error
    } finally {
      // 7. Cleanup
      _disconnect();
      if (imageFile != null) {
        // Delay deletion slightly or ensure service is done
        await _captureService.deleteTemporaryImage(imageFile);
      }
    }
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.05)
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Draw horizontal lines
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
