// theme_notifier.dart - FIXED NULL SAFETY VERSION
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  String _selectedColorTheme = 'default';
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  String get selectedColorTheme => _selectedColorTheme;
  bool get isInitialized => _isInitialized;

  // Color themes map - FIXED: Made this final and ensured it's always available
  static const Map<String, Map<String, Color>> _colorThemes = {
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
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;

      // FIXED: Validate theme exists before setting it
      final savedTheme = prefs.getString('colorTheme') ?? 'default';
      _selectedColorTheme =
          _colorThemes.containsKey(savedTheme) ? savedTheme : 'default';

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // FIXED: Handle initialization errors gracefully
      print('Theme initialization error: $e');
      _isDarkMode = false;
      _selectedColorTheme = 'default';
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> updateTheme(bool isDarkMode) async {
    try {
      _isDarkMode = isDarkMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode);
      notifyListeners();
    } catch (e) {
      print('Theme update error: $e');
    }
  }

  Future<void> updateColorTheme(String colorTheme) async {
    try {
      // FIXED: Validate theme exists before setting it
      if (_colorThemes.containsKey(colorTheme)) {
        _selectedColorTheme = colorTheme;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('colorTheme', colorTheme);
        notifyListeners();
      } else {
        print('Invalid color theme: $colorTheme');
      }
    } catch (e) {
      print('Color theme update error: $e');
    }
  }

  // FIXED: Added null safety and validation
  ColorScheme buildColorScheme(bool isDark) {
    // FIXED: Safely get theme colors with fallback
    final themeColors =
        _colorThemes[_selectedColorTheme] ?? _colorThemes['default']!;
    final primary = themeColors['primary'] ?? const Color(0xFF6366F1);
    final secondary = themeColors['secondary'] ?? const Color(0xFF8B5CF6);

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

  // FIXED: Added method to get available themes safely
  List<String> get availableThemes => _colorThemes.keys.toList();

  // FIXED: Added method to check if theme exists
  bool isValidTheme(String theme) => _colorThemes.containsKey(theme);

  // FIXED: Added method to get theme display name safely
  String getThemeDisplayName(String theme) {
    switch (theme) {
      case 'default':
        return 'Default Blue';
      case 'emerald':
        return 'Emerald Green';
      case 'rose':
        return 'Rose Pink';
      case 'amber':
        return 'Amber Orange';
      case 'violet':
        return 'Deep Violet';
      case 'teal':
        return 'Ocean Teal';
      case 'burgundy':
        return 'Burgundy Red';
      case 'forest':
        return 'Forest Green';
      default:
        return 'Default Blue';
    }
  }
}
