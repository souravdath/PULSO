import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';

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

  // Configuration
  // Tuned for 7000-16000 range as requested
  final double _minY = 0;
  final double _maxY = 26000;
  final int _maxPoints = 300;

  // Metrics (Simple calculation placeholders)
  int _currentHeartRate = 0;

  @override
  void initState() {
    super.initState();
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
      _disconnect();
    } else {
      final BluetoothDevice? device = await context.push('/ecg/pairing');
      if (device != null) {
        _connectToDevice(device);
      }
    }
  }

  void _disconnect() {
    _connection?.dispose();
    _connection = null;
    setState(() {
      _isConnected = false;
      _dataBuffer = "";
    });
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
      double voltage = double.parse(packet);

      if (mounted) {
        setState(() {
          _spots.add(FlSpot(_xValue, voltage));
          _xValue++;
          if (_spots.length > _maxPoints) {
            _spots.removeAt(0);
          }

          // Simple visualization of 'activity' for heart rate (mock logic for UI)
          // In real app, implement QRS detection here
          if (voltage > 12000) {
            _currentHeartRate =
                72 + (_xValue % 5).toInt(); // Just to show life in UI
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
                    // Main Chart
                    Padding(
                      padding: const EdgeInsets.all(24.0),
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
                          lineBarsData: [
                            LineChartBarData(
                              spots: _spots,
                              isCurved: true,
                              curveSmoothness: 0.2,
                              color: AppColors.secondary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
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
                        _currentHeartRate > 0 ? "$_currentHeartRate" : "--",
                        Icons.monitor_heart,
                        Colors.red,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      _buildMetric(
                        "Signal Value",
                        _spots.isNotEmpty ? "${_spots.last.y.toInt()}" : "--",
                        Icons.electric_bolt,
                        AppColors.primary,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      _buildMetric(
                        "Queue Size",
                        _spots.length.toString(),
                        Icons.storage,
                        Colors.orange,
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
