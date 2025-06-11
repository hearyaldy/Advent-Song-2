// theme_notifier.dart - CREATE THIS NEW FILE
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  String _selectedColorTheme = 'default';
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  String get selectedColorTheme => _selectedColorTheme;
  bool get isInitialized => _isInitialized;

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

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _selectedColorTheme = prefs.getString('colorTheme') ?? 'default';
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updateTheme(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  Future<void> updateColorTheme(String colorTheme) async {
    _selectedColorTheme = colorTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorTheme', colorTheme);
    notifyListeners();
  }

  ColorScheme buildColorScheme(bool isDark) {
    final themeColors = _colorThemes[_selectedColorTheme]!;
    final primary = themeColors['primary']!;
    final secondary = themeColors['secondary']!;

    if (isDark) {
      return ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFF1E293B),
        onSurface: const Color(0xFFE2E8F0),
        surfaceContainerHighest: const Color(0xFF334155),
        onSurfaceVariant: const Color(0xFFCBD5E1),
        outline: const Color(0xFF64748B),
      );
    } else {
      return ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1E293B),
        surfaceContainerHighest: const Color(0xFFF8FAFC),
        onSurfaceVariant: const Color(0xFF475569),
        outline: const Color(0xFFCBD5E1),
      );
    }
  }
}
