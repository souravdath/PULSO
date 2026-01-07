import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.monitor_heart, size: 80, color: AppColors.primary),
              const SizedBox(height: 20),
              Text(
                'Welcome to Pulso',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your personal heart health companion',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              
              // Sign Up Button
              ElevatedButton(
                onPressed: () => context.push('/signup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Sign Up', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              
              // Log In Button
              OutlinedButton(
                onPressed: () => context.push('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Log In', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              
              // Guest Button
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: Text(
                  'Continue as Guest',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
