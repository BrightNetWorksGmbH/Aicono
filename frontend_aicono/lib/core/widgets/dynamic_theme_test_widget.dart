import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/dynamic_theme_service.dart';

/// Test widget to demonstrate dynamic theme functionality
class DynamicThemeTestWidget extends StatefulWidget {
  const DynamicThemeTestWidget({super.key});

  @override
  State<DynamicThemeTestWidget> createState() => _DynamicThemeTestWidgetState();
}

class _DynamicThemeTestWidgetState extends State<DynamicThemeTestWidget> {
  late DynamicThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = sl<DynamicThemeService>();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.getCurrentSurfaceColor(),
      appBar: AppBar(
        title: const Text('Dynamic Theme Test'),
        backgroundColor: _themeService.getCurrentSurfaceColor(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Theme Status',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: _themeService.getCurrentSurfaceColor(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Status: ${_themeService.hasJoinedVerse ? "Logged In" : "Not Logged In"}',
                      style: TextStyle(color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Has Joined Verse: ${_themeService.hasJoinedVerse}',
                      style: TextStyle(color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current Verse: ${"None"}',
                      style: TextStyle(color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Surface Color: ${_themeService.getCurrentSurfaceColor().toHex()}',
                      style: TextStyle(color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Theme Initialized: ${_themeService.isInitialized}',
                      style: TextStyle(color: AppTheme.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _themeService.refreshTheme();
              },
              child: const Text('Refresh Theme'),
            ),
            const SizedBox(height: 16),
            Text(
              'Instructions:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• If user is logged in and has joined verses, the surface color will be based on the verse branding\n'
              '• If user is not logged in or has no joined verses, the surface color will be black\n'
              '• The theme automatically updates when user logs in/out\n'
              '• Press "Refresh Theme" to manually update the theme',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
