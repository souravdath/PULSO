import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import at the top
import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'navigation/app_router.dart';

// 1. Define the Global Supabase Client
final supabase = Supabase.instance.client;

Future<void> main() async {
  // 2. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Initialize Supabase
  await Supabase.initialize(
    url: 'https://ccijzpdtkuxpnwkfrogz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjaWp6cGR0a3V4cG53a2Zyb2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNDYyOTEsImV4cCI6MjA4MjcyMjI5MX0.0NWEp951xowuoCX9nNMaCckp_XtPhVXHeQsGuTsYBPM',
  );

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const PulsoApp(),
    ),
  );
}

class PulsoApp extends StatelessWidget {
  const PulsoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ThemeProvider is already provided at the root in main()
        Provider(create: (_) => Object()), 
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Pulso',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}