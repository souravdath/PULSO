import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/ecg_data.dart';
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
import '../features/ecg/pre_monitoring_questionnaire_screen.dart';

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
                    path: 'premonitoring',
                    parentNavigatorKey: _rootNavigatorKey, // Full screen
                    builder: (context, state) =>
                        const PreMonitoringQuestionnaireScreen(),
                  ),
                  GoRoute(
                    path: 'pairing',
                    parentNavigatorKey: _rootNavigatorKey, // Full screen
                    builder: (context, state) => const DevicePairingScreen(),
                  ),
                  GoRoute(
                    path: 'summary',
                    parentNavigatorKey: _rootNavigatorKey, // Full screen
                    builder: (context, state) {
                      final data = state.extra as Map<String, dynamic>? ?? {};
                      return SessionSummaryScreen(resultData: data);
                    },
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
                builder: (context, state) {
                  final readingId = state.extra as String?;
                  return InsightsScreen(readingId: readingId);
                },
                routes: [
                  GoRoute(
                    path: 'report',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final session = state.extra as ECGSession;
                      return DetailedReportScreen(session: session);
                    },
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
