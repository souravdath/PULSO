import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/ecg_data.dart'; // Ensure this model exists
import '../../services/ecg_storage_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  ECGSession? _latestSession;
  List<ECGSession> _recentSessions = [];
  double? _calculatedHRV;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final sessions = await ECGStorageService().getRecentSessions(user.id, limit: 3);
      
      setState(() {
        _recentSessions = sessions;
        if (sessions.isNotEmpty) {
          _latestSession = sessions.first;
          _calculatedHRV = _calculateSDNN(_latestSession!.rPeaks);
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // Simple HRV Calculation (SDNN)
  double? _calculateSDNN(List<RPeak> rPeaks) {
    if (rPeaks.length < 2) return null;
    
    // Extract RR intervals (in ms)
    // Assuming rrInterval in RPeak is in seconds, convert to ms. 
    // If it's already in seconds, multiply by 1000.
    // Based on standard storage, usually seconds.
    final rrIntervals = rPeaks.map((e) => e.rrInterval * 1000).toList();
    
    final meanRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    final variance = rrIntervals.map((rr) => pow(rr - meanRR, 2)).reduce((a, b) => a + b) / (rrIntervals.length - 1);
    
    return sqrt(variance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Dashboard",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              _buildStatusCard(),
              const SizedBox(height: 16),

              // Connection Card (Keep static until Bluetooth is implemented)
              _buildConnectionCard(context),
              const SizedBox(height: 16),

              // Metrics Strip
              _buildMetricsStrip(),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                "Quick Actions",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 32),

              // Recent Insights
              Text(
                "Recent Insights",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentInsights(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_isLoading) {
       return const Card(
         child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
       );
    }

    if (_latestSession == null) {
      return Card(
        color: AppColors.surfaceHighlight,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "No Data Available",
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Start your first ECG recording to see your heart health status.",
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine status text
    // Note: A real medical status requires complex analysis. 
    // We use neutral language here unless we have specific analysis flags.
    final String statusText = "Analysis Complete"; 
    final String subText = "Recording successfully saved.";

    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Latest",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.check_circle_outline, color: Colors.white),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subText, // Use dynamic message
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
             Text(
              "Recorded: ${_formatDate(_latestSession!.startTime)}",
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_searching,
                color: Theme.of(context).iconTheme.color,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Device Pairing",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  "Connect to capture new data",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: () {}, // TODO: Open Pairing
              child: Text(
                "Connect",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsStrip() {
    String hrValue = "--";
    String hrvValue = "--";
    String stressValue = "--";

    if (_latestSession != null) {
      if (_latestSession!.averageHeartRate != null) {
        hrValue = "${_latestSession!.averageHeartRate!.toStringAsFixed(0)} bpm";
      }
      
      if (_calculatedHRV != null) {
        hrvValue = "${_calculatedHRV!.toStringAsFixed(0)} ms";
        
        // Very basic stress heuristic for display purposes
        if (_calculatedHRV! < 50) {
          stressValue = "Elevated"; 
        } else {
          stressValue = "Normal";
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricItem("Heart Rate", hrValue, Icons.favorite),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricItem("HRV", hrvValue, Icons.graphic_eq)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricItem("Stress", stressValue, Icons.sentiment_satisfied),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _buildActionButton(
          context,
          "Start ECG",
          Icons.play_arrow,
          AppColors.primary,
          () => context.go('/ecg'),
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          context,
          "Consult AI",
          Icons.auto_awesome,
          AppColors.secondary,
          () => context.go('/insights'),
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          context,
          "History",
          Icons.history,
          AppColors.secondary,
          () => context.go('/history'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentInsights() {
    if (_recentSessions.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No recent insights available.",
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentSessions.length,
      itemBuilder: (context, index) {
        final session = _recentSessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: const Icon(Icons.bolt, color: AppColors.primary, size: 20),
            ),
            title: Text(
              "ECG Recording", // Generic title unless analyzed
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _formatDate(session.startTime),
              style: GoogleFonts.inter(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to details if implemented
            }, 
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    // Simple formatter, you can use intl package for better formatting
    return "${date.day}/${date.month} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}