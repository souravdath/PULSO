import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  bool _isScanning = false;
  List<ScanResult> _devices = [];
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    // Check if Bluetooth is supported and on
    if (await FlutterBluePlus.isSupported == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bluetooth is not supported on this device"),
          ),
        );
      }
      return;
    }

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _devices = results;
        });
      }
    });

    try {
      setState(() {
        _isScanning = true;
        _devices = []; // Clear previous results
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      // Wait for scan to finish (startScan is async but returns when *started* not finished in some versions,
      // but sticking to timeout logic).
      // Actually with timeout, it stops automatically.
      // We can listen to isScanning stream to update UI state properly.
    } catch (e) {
      print("Scan Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Scan Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await device.connect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connected to ${device.platformName}")),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Connection failed: $e")));
      }
    }
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
                  const Icon(Icons.bluetooth, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? "Searching for devices..." : "Scan Complete",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Make sure your device is turned on and nearby.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Device List
            Text(
              "Available Devices",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _devices.isEmpty && _isScanning
                  ? const Center(child: CircularProgressIndicator())
                  : _devices.isEmpty
                  ? Center(
                      child: Text(
                        "No devices found",
                        style: GoogleFonts.outfit(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index].device;
                        final deviceName = device.platformName.isNotEmpty
                            ? device.platformName
                            : "Unknown Device (${device.remoteId})";
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.watch,
                              color: AppColors.textLight,
                            ),
                            title: Text(
                              deviceName,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(device.remoteId.toString()),
                            trailing: ElevatedButton(
                              onPressed: () => _connect(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text("Connect"),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isScanning ? null : _startScan,
              child: const Text("Scan Again"),
            ),
          ],
        ),
      ),
    );
  }
}
