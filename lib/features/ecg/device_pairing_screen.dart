import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../core/theme.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  bool _isScanning = false;
  List<BluetoothDiscoveryResult> _discoveryResults = [];
  List<BluetoothDevice> _bondedDevices = [];
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _getBondedDevices();
    _startDiscovery();
  }

  @override
  void dispose() {
    _cancelDiscovery();
    super.dispose();
  }

  void _checkPermissions() async {
    // Bluetooth permissions are handled by Android Manifest,
    // but we can check if bluetooth is enabled.
    bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled == false) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  Future<void> _getBondedDevices() async {
    try {
      List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance
          .getBondedDevices();
      if (mounted) {
        setState(() {
          _bondedDevices = bonded;
        });
      }
    } catch (error) {
      print("Error getting bonded devices: $error");
    }
  }

  void _restartDiscovery() {
    setState(() {
      _discoveryResults.clear();
      _isScanning = true;
    });
    _startDiscovery();
  }

  void _startDiscovery() {
    _discoveryStreamSubscription = FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen((r) {
          if (mounted) {
            setState(() {
              // Avoid duplicates
              final existingIndex = _discoveryResults.indexWhere(
                (element) => element.device.address == r.device.address,
              );
              if (existingIndex >= 0) {
                _discoveryResults[existingIndex] = r;
              } else {
                _discoveryResults.add(r);
              }
            });
          }
        });

    _discoveryStreamSubscription!.onDone(() {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  void _cancelDiscovery() {
    _discoveryStreamSubscription?.cancel();
    _discoveryStreamSubscription = null;
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _onDeviceSelected(BluetoothDevice device) {
    // Stop scanning before returning
    _cancelDiscovery();
    context.pop(device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "Connect Device",
          style: GoogleFonts.outfit(color: AppColors.textLight),
        ),
        leading: const BackButton(color: AppColors.textLight),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? "Scanning for devices..." : "Scan Complete",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select your ESP32 device to start streaming ECG data.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scan Button
            if (!_isScanning)
              OutlinedButton(
                onPressed: _restartDiscovery,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text("Scan Again"),
              ),
            if (_isScanning)
              OutlinedButton(
                onPressed: _cancelDiscovery,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                ),
                child: const Text("Stop Scanning"),
              ),

            const SizedBox(height: 16),

            // Device List
            Expanded(
              child: ListView(
                children: [
                  if (_bondedDevices.isNotEmpty) ...[
                    Text(
                      "Paired Devices",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._bondedDevices
                        .map(
                          (device) => _buildDeviceTile(device, isPaired: true),
                        )
                        .toList(),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    "Available Devices",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_discoveryResults.isEmpty && _isScanning)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_discoveryResults.isEmpty && !_isScanning)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          "No new devices found",
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._discoveryResults
                        .map((r) => _buildDeviceTile(r.device))
                        .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device, {bool isPaired = false}) {
    final deviceName = device.name ?? "Unknown Device";
    final isConnected = device
        .isConnected; // Note: isConnected might not be reliable without active check

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          Icons.watch, // Or Icons.bluetooth
          color: isPaired ? AppColors.primary : AppColors.textLight,
        ),
        title: Text(
          deviceName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(device.address),
        trailing: ElevatedButton(
          onPressed: () => _onDeviceSelected(device),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text("Select"),
        ),
      ),
    );
  }
}
