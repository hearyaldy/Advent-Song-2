// main.dart - UPDATED TO USE THEME NOTIFIER
import 'package:flutter/material.dart';
import 'theme_notifier.dart'; // Import the new theme notifier
import 'landing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeNotifier _themeNotifier;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ThemeNotifier();
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
                child: CircularProgressIndicator(),
              ),
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        final lightColorScheme = _themeNotifier.buildColorScheme(false);
        final darkColorScheme = _themeNotifier.buildColorScheme(true);

        // Create a unique key for each theme combination to force complete rebuild
        final themeKey =
            '${_themeNotifier.selectedColorTheme}_${_themeNotifier.isDarkMode}_${DateTime.now().millisecondsSinceEpoch}';

        return MaterialApp(
          key: ValueKey(themeKey), // This forces complete rebuild every time
          title: 'Song Lyric App',
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'SF Pro Display',
            colorScheme: lightColorScheme,
            appBarTheme: AppBarTheme(
              backgroundColor: lightColorScheme.surface,
              foregroundColor: lightColorScheme.onSurface,
              elevation: 0,
            ),
            cardTheme: CardTheme(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: lightColorScheme.primary,
                foregroundColor: lightColorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: lightColorScheme.primary,
                side: BorderSide(color: lightColorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'SF Pro Display',
            colorScheme: darkColorScheme,
            appBarTheme: AppBarTheme(
              backgroundColor: darkColorScheme.surface,
              foregroundColor: darkColorScheme.onSurface,
              elevation: 0,
            ),
            cardTheme: CardTheme(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: darkColorScheme.primary,
                foregroundColor: darkColorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: darkColorScheme.primary,
                side: BorderSide(color: darkColorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          themeMode:
              _themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: LandingPage(
            key: ValueKey(themeKey), // Also key the home page
            themeNotifier: _themeNotifier, // Pass the notifier
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
