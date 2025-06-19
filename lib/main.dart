// main.dart - FIXED ROUTES and NULL SAFETY
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'theme_notifier.dart';
import 'landing_page.dart';
import 'admin_login_page_firebase.dart';
import 'admin_dashboard_firebase.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    await FirebaseService.initialize();
    print('✅ Firebase service initialized');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeNotifier _themeNotifier = ThemeNotifier();
  bool _isAppInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // FIXED: Better initialization handling
  Future<void> _initializeApp() async {
    try {
      await _themeNotifier.initialize();
      setState(() {
        _isAppInitialized = true;
      });
    } catch (e) {
      print('App initialization error: $e');
      // Even if there's an error, allow the app to start with defaults
      setState(() {
        _isAppInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Show loading screen until both theme and app are initialized
    if (!_isAppInitialized || !_themeNotifier.isInitialized) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF6366F1),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 4,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Lagu Advent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Loading app...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return AnimatedBuilder(
      animation: _themeNotifier,
      builder: (context, child) {
        // FIXED: Safe color scheme building with error handling
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        try {
          lightColorScheme = _themeNotifier.buildColorScheme(false);
          darkColorScheme = _themeNotifier.buildColorScheme(true);
        } catch (e) {
          print('Error building color schemes: $e');
          // Fallback to default color schemes
          lightColorScheme =
              ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1));
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'Lagu Advent',
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'SF Pro Display',
            colorScheme: lightColorScheme,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'SF Pro Display',
            colorScheme: darkColorScheme,
          ),
          themeMode:
              _themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          // FIXED: Better route handling with error catching
          onGenerateRoute: (settings) {
            try {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(
                    builder: (context) =>
                        LandingPage(themeNotifier: _themeNotifier),
                  );
                case '/admin-login':
                  return MaterialPageRoute(
                    builder: (context) => const AdminLoginPage(),
                  );
                case '/admin-dashboard':
                  return MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  );
                default:
                  // FIXED: Fallback route
                  return MaterialPageRoute(
                    builder: (context) =>
                        LandingPage(themeNotifier: _themeNotifier),
                  );
              }
            } catch (e) {
              print('Route generation error: $e');
              // Fallback to landing page
              return MaterialPageRoute(
                builder: (context) =>
                    LandingPage(themeNotifier: _themeNotifier),
              );
            }
          },
          // FIXED: Remove the static routes to prevent conflicts
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
