// settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  final Function(String)? onColorThemeChanged;

  const SettingsPage({
    super.key,
    this.onThemeChanged,
    this.onColorThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _fontSize = 16.0;
  String _fontFamily = 'Roboto';
  TextAlign _textAlign = TextAlign.left;
  bool _isDarkMode = false;
  String _selectedColorTheme = 'default';
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  // Available color themes
  final Map<String, Map<String, dynamic>> _colorThemes = {
    'default': {
      'name': 'Default Blue',
      'primary': Color(0xFF6366F1),
      'secondary': Color(0xFF8B5CF6),
    },
    'emerald': {
      'name': 'Emerald Green',
      'primary': Color(0xFF059669),
      'secondary': Color(0xFF10B981),
    },
    'rose': {
      'name': 'Rose Pink',
      'primary': Color(0xFFE11D48),
      'secondary': Color(0xFFF43F5E),
    },
    'amber': {
      'name': 'Amber Orange',
      'primary': Color(0xFFF59E0B),
      'secondary': Color(0xFFFBBF24),
    },
    'violet': {
      'name': 'Deep Violet',
      'primary': Color(0xFF7C3AED),
      'secondary': Color(0xFF8B5CF6),
    },
    'teal': {
      'name': 'Ocean Teal',
      'primary': Color(0xFF0D9488),
      'secondary': Color(0xFF14B8A6),
    },
    'burgundy': {
      'name': 'Burgundy Red',
      'primary': Color(0xFF991B1B),
      'secondary': Color(0xFFDC2626),
    },
    'forest': {
      'name': 'Forest Green',
      'primary': Color(0xFF166534),
      'secondary': Color(0xFF15803D),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 16.0;
      _fontFamily = prefs.getString('fontFamily') ?? 'Roboto';
      _textAlign = TextAlign.values[prefs.getInt('textAlign') ?? 0];
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _selectedColorTheme = prefs.getString('colorTheme') ?? 'default';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setInt('textAlign', _textAlign.index);
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setString('colorTheme', _selectedColorTheme);

    setState(() {
      _hasUnsavedChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fontSize');
    await prefs.remove('fontFamily');
    await prefs.remove('textAlign');
    await prefs.remove('isDarkMode');
    await prefs.remove('colorTheme');

    setState(() {
      _fontSize = 16.0;
      _fontFamily = 'Roboto';
      _textAlign = TextAlign.left;
      _isDarkMode = false;
      _selectedColorTheme = 'default';
      _hasUnsavedChanges = true;
    });

    await _saveSettings();
  }

  void _onSettingChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () async {
              await _saveSettings();
              if (mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          actions: [
            if (_hasUnsavedChanges)
              TextButton(
                onPressed: _saveSettings,
                child: const Text('Save'),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'reset':
                    _showResetDialog();
                    break;
                  case 'about':
                    _showAboutDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Reset to Defaults'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('About Settings'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Text Settings Section
            _buildSectionCard(
              title: 'Text Display',
              icon: Icons.text_fields,
              children: [
                _buildFontSizeSlider(),
                const Divider(),
                _buildFontFamilySelector(),
                const Divider(),
                _buildTextAlignmentSelector(),
              ],
            ),

            const SizedBox(height: 16),

            // Theme Settings Section
            _buildSectionCard(
              title: 'Appearance',
              icon: Icons.palette,
              children: [
                _buildDarkModeSwitch(),
                const Divider(),
                _buildColorThemeSelector(),
              ],
            ),

            const SizedBox(height: 16),

            // Preview Section
            _buildPreviewCard(),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showResetDialog,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset to Defaults'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _hasUnsavedChanges ? _saveSettings : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Font Size'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_fontSize.toInt()}px',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _fontSize,
          min: 12.0,
          max: 28.0,
          divisions: 16,
          onChanged: (value) {
            setState(() {
              _fontSize = value;
            });
            _onSettingChanged();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '12px',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '28px',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFontFamilySelector() {
    final fontFamilies = [
      'Roboto',
      'SF Pro Display',
      'Arial',
      'Georgia',
      'Times New Roman',
      'Courier New',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Font Family'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: fontFamilies.map((font) {
            final isSelected = _fontFamily == font;
            return ChoiceChip(
              label: Text(
                font,
                style: TextStyle(fontFamily: font),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _fontFamily = font;
                  });
                  _onSettingChanged();
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextAlignmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Text Alignment'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAlignmentChip(
                TextAlign.left, Icons.format_align_left, 'Left'),
            _buildAlignmentChip(
                TextAlign.center, Icons.format_align_center, 'Center'),
            _buildAlignmentChip(
                TextAlign.right, Icons.format_align_right, 'Right'),
            _buildAlignmentChip(
                TextAlign.justify, Icons.format_align_justify, 'Justify'),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignmentChip(TextAlign alignment, IconData icon, String label) {
    final isSelected = _textAlign == alignment;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    isSelected ? Theme.of(context).colorScheme.onPrimary : null,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _textAlign = alignment;
              });
              _onSettingChanged();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDarkModeSwitch() {
    return SwitchListTile(
      secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
      title: const Text('Dark Mode'),
      subtitle:
          Text(_isDarkMode ? 'Dark theme enabled' : 'Light theme enabled'),
      value: _isDarkMode,
      onChanged: (value) async {
        setState(() {
          _isDarkMode = value;
        });
        _onSettingChanged();

        // Save immediately and notify app
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isDarkMode', value);
        widget.onThemeChanged?.call(value);
      },
    );
  }

  Widget _buildColorThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color Theme'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.5,
          ),
          itemCount: _colorThemes.length,
          itemBuilder: (context, index) {
            final themeKey = _colorThemes.keys.elementAt(index);
            final themeData = _colorThemes[themeKey]!;
            final isSelected = _selectedColorTheme == themeKey;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? themeData['primary'] as Color
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? (themeData['primary'] as Color).withOpacity(0.1)
                    : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _selectedColorTheme = themeKey;
                  });
                  _onSettingChanged();

                  // Notify app immediately for preview
                  widget.onColorThemeChanged?.call(themeKey);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Color preview circles
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: themeData['primary'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: themeData['secondary'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Theme name
                      Expanded(
                        child: Text(
                          themeData['name'].toString(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? themeData['primary'] as Color
                                        : null,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: themeData['primary'] as Color,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final selectedTheme = _colorThemes[_selectedColorTheme]!;
    final primaryColor = selectedTheme['primary'] as Color;
    final secondaryColor = selectedTheme['secondary'] as Color;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedTheme['name'].toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.grey[800]
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Verse 1',
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This is how your song lyrics will appear with the current settings. You can adjust the font size, style, alignment, and color theme to match your reading preferences.',
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontFamily: _fontFamily,
                      color: _isDarkMode ? Colors.white : Colors.black,
                      height: 1.6,
                    ),
                    textAlign: _textAlign,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: secondaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Korus',
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chorus text appears in italic style with secondary color to distinguish it from regular verses.',
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontFamily: _fontFamily,
                      fontStyle: FontStyle.italic,
                      color: _isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.6,
                    ),
                    textAlign: _textAlign,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSettings();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('These settings control how song lyrics are displayed:'),
            SizedBox(height: 12),
            Text('• Font Size: Adjusts text size for better readability'),
            Text('• Font Family: Changes the typeface used for lyrics'),
            Text('• Text Alignment: Controls how text is aligned on screen'),
            Text('• Dark Mode: Switches between light and dark themes'),
            Text('• Color Theme: Choose your preferred color scheme'),
            SizedBox(height: 12),
            Text(
                'All settings are automatically saved and will persist between app launches.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
