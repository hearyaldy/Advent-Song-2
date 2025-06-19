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
    print('❌ Firebase initialization failed: \$e');
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

  @override
  void initState() {
    super.initState();
    _themeNotifier.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeNotifier,
      builder: (context, child) {
        if (!_themeNotifier.isInitialized) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading app...'),
                  ],
                ),
              ),
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        final lightColorScheme = _themeNotifier.buildColorScheme(false);
        final darkColorScheme = _themeNotifier.buildColorScheme(true);

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
          routes: {
            '/': (context) => LandingPage(themeNotifier: _themeNotifier),
            '/admin-login': (context) => const AdminLoginPage(),
            '/admin-dashboard': (context) => const AdminDashboard(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
