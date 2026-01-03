import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final data = await AuthService().fetchCurrentUserProfile();
    if (mounted) {
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final user = _profileData?['user'];
    final medical = _profileData?['medical'];
    final name = user?['name'] ?? 'User';
    final age = medical?['age_at_record']?.toString() ?? '--';
    final gender = medical?['gender'] ?? '--';
    final conditions = medical?['existing_conditions'] ?? 'None';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "Profile",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.textLight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textLight),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "$gender, $age yrs",
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Settings Sections
            _buildSectionHeader("Medical Profile"),
            _buildSettingItem("Known Conditions", conditions),
            _buildSettingItem("Medications", "None"), // Placeholder for now
             _buildSettingItem("Emergency Contact", "+1 555-0123"), // Placeholder

            const SizedBox(height: 24),
            _buildSectionHeader("App Settings"),
            _buildSwitchItem("Notifications", true),
            _buildSwitchItem("Dark Mode", false), // Logic to be implemented
            _buildActionItem("Privacy & Security", Icons.lock_outline),
            _buildActionItem("Help & Support", Icons.help_outline),
            
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text("Log Out"),
            ),
             const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            value, 
            style: GoogleFonts.outfit(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

   Widget _buildSwitchItem(String title, bool value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        value: value,
        onChanged: (v) {},
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionItem(String title, IconData icon) {
     return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textLight),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
