import 'package:flutter/material.dart';

class AppColors {
  // Default Theme (BryteSpring)
  static const Color primaryColor = Color(0xFF0D1117);
  static const Color secondaryColor = Color(0xFFFF7F50); //Color(0xFFE44D2E);
  static const Color backgroundColor = Color(0xFF0D1117);
  static const Color surfaceColor = Color(0xFF161B22);
  static const Color textColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFF8B949E);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF238636);
  static const Color borderColor = Color(0xFF30363D);

  // Alternative themes can be added here
  // Example: White-label theme 1
  static const Map<String, Color> theme1 = {
    'primary': Color(0xFF007AFF),
    'secondary': Color(0xFF5856D6),
    'background': Color(0xFFF2F2F7),
    'surface': Color(0xFFFFFFFF),
    'text': Color(0xFF000000),
    'textSecondary': Color(0xFF8E8E93),
    'error': Color(0xFFFF3B30),
    'success': Color(0xFF34C759),
    'border': Color(0xFFC6C6C8),
  };

  // Example: White-label theme 2
  static const Map<String, Color> theme2 = {
    'primary': Color(0xFF4CAF50),
    'secondary': Color(0xFF8BC34A),
    'background': Color(0xFF121212),
    'surface': Color(0xFF1E1E1E),
    'text': Color(0xFFFFFFFF),
    'textSecondary': Color(0xFFBBBBBB),
    'error': Color(0xFFCF6679),
    'success': Color(0xFF03DAC6),
    'border': Color(0xFF333333),
  };
}

// Theme configuration class for white-labeling
class AppTheme {
  static Map<String, dynamic> currentTheme = {
    'name': 'default',
    'colors': {
      'primary': AppColors.primaryColor,
      'secondary': AppColors.secondaryColor,
      'background': AppColors.backgroundColor,
      'surface': AppColors.surfaceColor,
      'text': AppColors.textColor,
      'textSecondary': AppColors.textSecondaryColor,
      'error': AppColors.errorColor,
      'success': AppColors.successColor,
      'border': AppColors.borderColor,
    },
  };

  // Method to switch themes
  static void setTheme(String themeName) {
    switch (themeName) {
      case 'theme1':
        currentTheme = {'name': 'theme1', 'colors': AppColors.theme1};
        break;
      case 'theme2':
        currentTheme = {'name': 'theme2', 'colors': AppColors.theme2};
        break;
      default:
        currentTheme = {
          'name': 'default',
          'colors': {
            'primary': AppColors.primaryColor,
            'secondary': AppColors.secondaryColor,
            'background': AppColors.backgroundColor,
            'surface': AppColors.surfaceColor,
            'text': AppColors.textColor,
            'textSecondary': AppColors.textSecondaryColor,
            'error': AppColors.errorColor,
            'success': AppColors.successColor,
            'border': AppColors.borderColor,
          },
        };
    }
  }

  // Helper methods to access theme colors
  static Color get primary => currentTheme['colors']['primary'];
  static Color get secondary => currentTheme['colors']['secondary'];
  static Color get background => currentTheme['colors']['background'];
  static Color get surface => currentTheme['colors']['surface'];
  static Color get text => currentTheme['colors']['text'];
  static Color get textSecondary => currentTheme['colors']['textSecondary'];
  static Color get error => currentTheme['colors']['error'];
  static Color get success => currentTheme['colors']['success'];
  static Color get border => currentTheme['colors']['border'];
}
