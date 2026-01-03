import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/ecg/ecg_screen.dart';
import '../features/ecg/device_pairing_screen.dart';
import '../features/ecg/session_summary_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/insights/detailed_report_screen.dart';
import '../features/history/history_screen.dart';
import '../features/profile/profile_screen.dart';
import 'shell_screen.dart';
import '../screens/questionnaire_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // Entry Flow (No Shell)
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      GoRoute(
        path: '/questionnaire',
        builder: (context, state) =>
            const QuestionnaireScreen(), // Or whatever your class name is
      ),

      // Authenticated Shell Flow
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Live ECG
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ecg',
                builder: (context, state) => const ECGScreen(),
                routes: [
                  GoRoute(
                    path: 'pairing',
                    parentNavigatorKey: _rootNavigatorKey, // Full screen
                    builder: (context, state) => const DevicePairingScreen(),
                  ),
                  GoRoute(
                    path: 'summary',
                    parentNavigatorKey: _rootNavigatorKey, // Full screen
                    builder: (context, state) => const SessionSummaryScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Insights
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                builder: (context, state) => const InsightsScreen(),
                routes: [
                  GoRoute(
                    path: 'report',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const DetailedReportScreen(),
                  ),
                ],
              ),
            ],
          ),

          // History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),

          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
