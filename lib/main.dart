// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isDarkMode = false;
  String _selectedColorTheme = 'default';
  bool _isLoading = true;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Color themes map
  final Map<String, Map<String, Color>> _colorThemes = {
    'default': {
      'primary': Color(0xFF6366F1),
      'secondary': Color(0xFF8B5CF6),
    },
    'emerald': {
      'primary': Color(0xFF059669),
      'secondary': Color(0xFF10B981),
    },
    'rose': {
      'primary': Color(0xFFE11D48),
      'secondary': Color(0xFFF43F5E),
    },
    'amber': {
      'primary': Color(0xFFF59E0B),
      'secondary': Color(0xFFFBBF24),
    },
    'violet': {
      'primary': Color(0xFF7C3AED),
      'secondary': Color(0xFF8B5CF6),
    },
    'teal': {
      'primary': Color(0xFF0D9488),
      'secondary': Color(0xFF14B8A6),
    },
    'burgundy': {
      'primary': Color(0xFF991B1B),
      'secondary': Color(0xFFDC2626),
    },
    'forest': {
      'primary': Color(0xFF166534),
      'secondary': Color(0xFF15803D),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _selectedColorTheme = prefs.getString('colorTheme') ?? 'default';
      _isLoading = false;
    });
  }

  void _updateTheme(bool isDarkMode) async {
    setState(() {
      _isDarkMode = isDarkMode;
    });
    // Also save immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  void _updateColorTheme(String colorTheme) async {
    setState(() {
      _selectedColorTheme = colorTheme;
      // Force navigator rebuild
      _navigatorKey = GlobalKey<NavigatorState>();
    });
    // Also save immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorTheme', colorTheme);
  }

  ColorScheme _buildColorScheme(bool isDark) {
    final themeColors = _colorThemes[_selectedColorTheme]!;
    final primary = themeColors['primary']!;
    final secondary = themeColors['secondary']!;

    if (isDark) {
      return ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFF1E293B),
        onSurface: const Color(0xFFE2E8F0),
        surfaceVariant: const Color(0xFF334155),
        onSurfaceVariant: const Color(0xFFCBD5E1),
        outline: const Color(0xFF64748B),
        background: const Color(0xFF0F172A),
        onBackground: const Color(0xFFE2E8F0),
      );
    } else {
      return ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1E293B),
        surfaceVariant: const Color(0xFFF8FAFC),
        onSurfaceVariant: const Color(0xFF475569),
        outline: const Color(0xFFCBD5E1),
        background: const Color(0xFFFAFAFA),
        onBackground: const Color(0xFF1E293B),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    final lightColorScheme = _buildColorScheme(false);
    final darkColorScheme = _buildColorScheme(true);

    return MaterialApp(
      key: ValueKey(
          '${_selectedColorTheme}_${_isDarkMode}'), // Force rebuild on theme change
      navigatorKey: _navigatorKey,
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
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: LandingPage(
        onThemeChanged: _updateTheme,
        onColorThemeChanged: _updateColorTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
