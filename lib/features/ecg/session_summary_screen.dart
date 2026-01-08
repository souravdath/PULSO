import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class SessionSummaryScreen extends StatelessWidget {
  /// Expects a Map<String, dynamic> with keys: 
  /// 'avgHr', 'maxHr', 'minHr', 'duration', 'report'
  final Map<String, dynamic> resultData;

  const SessionSummaryScreen({super.key, required this.resultData});

  @override
  Widget build(BuildContext context) {
    // Extract data with safe fallbacks
    final int duration = resultData['duration'] is int ? resultData['duration'] : 0;
    final double avgHr = resultData['avgHr'] is num ? (resultData['avgHr'] as num).toDouble() : 0.0;
    final double maxHr = resultData['maxHr'] is num ? (resultData['maxHr'] as num).toDouble() : 0.0;
    final double minHr = resultData['minHr'] is num ? (resultData['minHr'] as num).toDouble() : 0.0;
    final String? aiReport = resultData['report'] as String?;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text("Session Summary", style: GoogleFonts.outfit(color: AppColors.textLight)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textLight),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Icon
            const Center(
              child: Icon(Icons.check_circle, size: 80, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            Text(
              "Recording Complete",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Metrics Grid
            Row(
              children: [
                _buildMetricTile("Duration", "${duration}s"),
                const SizedBox(width: 16),
                _buildMetricTile("Avg HR", "${avgHr.round()} bpm"),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricTile("Max HR", "${maxHr.round()} bpm"),
                const SizedBox(width: 16),
                _buildMetricTile("Min HR", "${minHr.round()} bpm"),
              ],
            ),
             const SizedBox(height: 40),

            // AI Analysis Teaser
            if (aiReport != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          "AI Analysis Ready",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Our algorithms have analyzed your rhythm. Tap below to see the full report.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            const Spacer(),

            // Buttons
            if (aiReport != null) ...[
              ElevatedButton(
                onPressed: () {
                   // Pass the report to the Insights screen
                   context.go('/insights', extra: aiReport);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("View AI Report"),
              ),
              const SizedBox(height: 16),
            ],
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text("Return to Dashboard"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}