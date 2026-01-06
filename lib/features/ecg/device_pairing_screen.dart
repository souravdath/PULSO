import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this import
import '../../core/theme.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  bool _isScanning = false;
  final List<BluetoothDiscoveryResult> _discoveryResults = [];
  List<BluetoothDevice> _bondedDevices = [];
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    _discoveryStreamSubscription = null;
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    await _checkPermissions();
    await _getBondedDevices();
    _startDiscovery();
  }

  Future<void> _checkPermissions() async {
    try {
      // Request location permission (required for Bluetooth scanning on Android)
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Check if all permissions are granted
      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (!allGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to scan for Bluetooth devices'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Check if Bluetooth is enabled
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled == false) {
        bool? enableResult = await FlutterBluetoothSerial.instance.requestEnable();
        if (enableResult != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth must be enabled to scan for devices')),
          );
        }
      }
    } catch (error) {
      print("Error checking permissions: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission error: $error')),
        );
      }
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
    setState(() {
      _isScanning = true;
    });
    
    _discoveryStreamSubscription = FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen(
          (r) {
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
          },
          onError: (error) {
            print("Discovery error: $error");
            if (mounted) {
              setState(() {
                _isScanning = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scan error: $error')),
              );
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isScanning = false;
              });
            }
          },
          cancelOnError: false,
        );
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
                    ..._bondedDevices.map(
                      (device) => _buildDeviceTile(device, isPaired: true),
                    ),
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
                    ..._discoveryResults.map((r) => _buildDeviceTile(r.device)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          Icons.watch,
          color: isPaired ? AppColors.primary : AppColors.textLight,
        ),
        title: Text(
          deviceName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(device.address),
        trailing: ElevatedButton(
          onPressed: () => _onDeviceSelected(device),
          child: const Text("Select"),
        ),
      ),
    );
  }
}