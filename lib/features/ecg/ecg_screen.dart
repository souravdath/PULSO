import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../core/theme.dart';

class ECGScreen extends StatefulWidget {
  const ECGScreen({super.key});

  @override
  State<ECGScreen> createState() => _ECGScreenState();
}

class _ECGScreenState extends State<ECGScreen> {
  final List<FlSpot> _spots = [];
  double _xValue = 0;
  bool _isConnected = false;

  BluetoothConnection? _connection;
  String _messageBuffer = '';

  // Chart configuration
  final int _windowSize = 300; // Number of points to show
  // ADS1115 typically 0-32767 for positive single-ended,
  // or +/- 32767 for differential. User mentioned "18000\n", suggesting positive values.
  // We will auto-scale or fix range. Let's start with auto-scaling behavior by not fixing minY/maxY strictly
  // or strictly defined based on user preference "Min 0, Max 32000".
  final double _minY = 0;
  final double _maxY = 35000;

  @override
  void initState() {
    super.initState();
    // Initialize with empty data
    for (int i = 0; i < _windowSize; i++) {
      _spots.add(FlSpot(i.toDouble(), 0));
    }
    _xValue = _windowSize.toDouble();
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      // Disconnect
      _connection?.dispose();
      _connection = null;
      setState(() {
        _isConnected = false;
      });
    } else {
      // Navigate to pairing
      final BluetoothDevice? device = await context.push('/ecg/pairing');
      if (device != null) {
        _connectToDevice(device);
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot connect, exception occurred: $e')),
        );
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    // Decode data to string
    String chunk = ascii.decode(data);
    _messageBuffer += chunk;

    // Process complete lines
    while (_messageBuffer.contains('\n')) {
      int index = _messageBuffer.indexOf('\n');
      String line = _messageBuffer.substring(0, index).trim();
      _messageBuffer = _messageBuffer.substring(index + 1);

      if (line.isNotEmpty) {
        _parseAndAddPoint(line);
      }
    }
  }

  void _parseAndAddPoint(String dataString) {
    try {
      double value = double.parse(dataString);

      setState(() {
        _xValue++;
        _spots.add(FlSpot(_xValue, value));

        // Keep window size constant
        if (_spots.length > _windowSize) {
          _spots.removeAt(0);
        }
      });
    } catch (e) {
      // Ignore parse errors (e.g. partial data or noise)
      // print("Error parsing: $dataString");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "Live ECG",
          style: GoogleFonts.outfit(color: AppColors.textLight),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: _isConnected ? AppColors.success : AppColors.error,
            ),
            onPressed: _toggleConnection,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Metrics
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      "Heart Rate",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                    Text(
                      _isConnected
                          ? "--"
                          : "--", // Rate calculation would go here
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("bpm", style: GoogleFonts.outfit(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "Status",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                    Text(
                      _isConnected ? "Streaming" : "Disconnected",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isConnected
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Waveform
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.green.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: Colors.green.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    // Dynamic X window
                    minX: _xValue - _windowSize,
                    maxX: _xValue,
                    // Fixed Y range for ECG typical values if sensor is consistent,
                    // else remove minY/maxY for auto-scaling
                    minY: _minY,
                    maxY: _maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spots,
                        isCurved:
                            false, // False for better performance on high freq data
                        color: AppColors.secondary,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Controls
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  heroTag: "ecg_btn",
                  backgroundColor: _isConnected
                      ? AppColors.error
                      : AppColors.primary,
                  onPressed: _toggleConnection,
                  child: Icon(
                    _isConnected ? Icons.stop : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
