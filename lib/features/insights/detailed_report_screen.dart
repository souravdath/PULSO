import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/ecg_data.dart'; // Ensure import

class DetailedReportScreen extends StatelessWidget {
  final ECGSession session;

  const DetailedReportScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // Basic heuristics for display (Real app would store these fields)
    final bool isNormal = session.averageHeartRate != null && 
                          session.averageHeartRate! > 60 && 
                          session.averageHeartRate! < 100;
    
    final statusColor = isNormal ? AppColors.success : AppColors.warning;
    final statusText = isNormal ? "Normal Sinus Rhythm" : "Check Findings";
    final statusDesc = isNormal ? "No irregularities detected" : "Consult a physician";

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text("Detailed Report", style: GoogleFonts.outfit(color: AppColors.textLight)),
        leading: const BackButton(color: AppColors.textLight),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diagnosis Banner
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                border: Border.all(color: statusColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(isNormal ? Icons.check_circle : Icons.warning, color: statusColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    style: GoogleFonts.outfit(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                   Text(
                    statusDesc,
                    style: GoogleFonts.outfit(color: statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Findings
            Text(
              "Session Metrics",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFindingItem("Recorded Date", "${session.startTime.toLocal()}".split('.')[0]),
            _buildFindingItem("Duration", "${session.durationSeconds} seconds"),
            _buildFindingItem("Average Heart Rate", "${session.averageHeartRate?.round() ?? '--'} bpm"),
            _buildFindingItem("Max Heart Rate", "${session.maxHeartRate?.round() ?? '--'} bpm"),
            _buildFindingItem("Min Heart Rate", "${session.minHeartRate?.round() ?? '--'} bpm"),
            _buildFindingItem("Beats Detected", "${session.totalRPeaks ?? '--'}"),

            const SizedBox(height: 24),

            // Advice
            Text(
              "Context",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "This report is based on a ${session.durationSeconds}-second single-lead ECG recording. "
                "Heart rate data was consistent with ${isNormal ? 'normal' : 'elevated/low'} resting rates.",
                style: GoogleFonts.outfit(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fiber_manual_record, size: 12, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.outfit(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}