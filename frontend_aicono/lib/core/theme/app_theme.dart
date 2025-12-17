import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend_aicono/core/constant.dart';

// Text Styles
class AppTextStyles {
  // Private constructor to prevent instantiation
  AppTextStyles._();

  // Display styles
  static TextStyle get displayLarge => GoogleFonts.onest(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
  );

  static TextStyle get displayMedium => GoogleFonts.onest(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get displaySmall => GoogleFonts.onest(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // Headline styles
  static TextStyle get headlineLarge => GoogleFonts.onest(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get headlineMedium => GoogleFonts.onest(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get headlineSmall => GoogleFonts.onest(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // Title styles
  static TextStyle get titleLarge => GoogleFonts.onest(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle get appTitle => GoogleFonts.onest(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static TextStyle get titleMedium => GoogleFonts.onest(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static TextStyle get titleSmall => GoogleFonts.onest(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Body styles
  static TextStyle get bodyLarge => GoogleFonts.onest(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.onest(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static TextStyle get bodySmall => GoogleFonts.onest(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // Label styles
  static TextStyle get labelLarge => GoogleFonts.onest(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.onest(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.onest(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // Custom text styles for specific use cases
  static TextStyle get buttonText => GoogleFonts.onest(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle get caption => GoogleFonts.onest(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  static TextStyle get overline => GoogleFonts.onest(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
  );

  // Custom styles for specific components
  static TextStyle get cardTitle => GoogleFonts.onest(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle get cardSubtitle => GoogleFonts.onest(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static TextStyle get navigationLabel => GoogleFonts.onest(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextStyle get errorTextStyle => GoogleFonts.onest(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  static TextStyle get successTextStyle => GoogleFonts.onest(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // Build text theme with colors
  static TextTheme textTheme(Map<String, Color> colors) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: colors['text']),
      displayMedium: displayMedium.copyWith(color: colors['text']),
      displaySmall: displaySmall.copyWith(color: colors['text']),
      headlineLarge: headlineLarge.copyWith(color: colors['text']),
      headlineMedium: headlineMedium.copyWith(color: colors['text']),
      headlineSmall: headlineSmall.copyWith(color: colors['text']),
      titleLarge: titleLarge.copyWith(color: colors['text']),
      titleMedium: titleMedium.copyWith(color: colors['text']),
      titleSmall: titleSmall.copyWith(color: colors['text']),
      bodyLarge: bodyLarge.copyWith(color: colors['text']),
      bodyMedium: bodyMedium.copyWith(color: colors['text']),
      bodySmall: bodySmall.copyWith(color: colors['textSecondary']),
      labelLarge: labelLarge.copyWith(color: colors['text']),
      labelMedium: labelMedium.copyWith(color: colors['textSecondary']),
      labelSmall: labelSmall.copyWith(color: colors['textSecondary']),
    );
  }

  // Helper methods for styled text
  static TextStyle primaryText(Map<String, Color> colors) =>
      bodyMedium.copyWith(color: colors['text']);

  static TextStyle secondaryText(Map<String, Color> colors) =>
      bodySmall.copyWith(color: colors['textSecondary']);

  static TextStyle errorText(Map<String, Color> colors) =>
      errorTextStyle.copyWith(color: colors['error']);

  static TextStyle successText(Map<String, Color> colors) =>
      successTextStyle.copyWith(color: colors['success']);
}

// Input Decoration Styles
class AppInputStyles {
  // Private constructor to prevent instantiation
  AppInputStyles._();

  // Base input decoration theme
  static InputDecorationTheme inputDecorationTheme(Map<String, Color> colors) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colors['surface'],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['border']!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['border']!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['primary']!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['error']!, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['error']!, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: colors['border']!.withOpacity(0.5),
          width: 1,
        ),
      ),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: colors['textSecondary'],
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: colors['textSecondary'],
      ),
      errorStyle: AppTextStyles.errorTextStyle.copyWith(color: colors['error']),
      helperStyle: AppTextStyles.caption.copyWith(
        color: colors['textSecondary'],
      ),
    );
  }

  // Custom input decoration for search fields
  static InputDecoration searchDecoration(
    Map<String, Color> colors, {
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText ?? 'Search...',
      prefixIcon: Icon(Icons.search, color: colors['textSecondary']),
      suffixIcon: Icon(Icons.clear, color: colors['textSecondary']),
      filled: true,
      fillColor: colors['surface'],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colors['primary']!, width: 2),
      ),
    );
  }

  // Custom input decoration for password fields
  static InputDecoration passwordDecoration(
    Map<String, Color> colors, {
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText ?? 'Password',
      prefixIcon: Icon(Icons.lock_outline, color: colors['textSecondary']),
      filled: true,
      fillColor: colors['surface'],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['border']!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['border']!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['primary']!, width: 2),
      ),
    );
  }

  // Custom input decoration for multiline text fields
  static InputDecoration multilineDecoration(
    Map<String, Color> colors, {
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: colors['surface'],
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['border']!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['border']!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors['primary']!, width: 2),
      ),
      alignLabelWithHint: true,
    );
  }
}

// Button Styles
class AppButtonStyles {
  // Private constructor to prevent instantiation
  AppButtonStyles._();

  // Elevated Button Theme
  static ElevatedButtonThemeData elevatedButtonTheme(
    Map<String, Color> colors,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: colors['primary']!.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: AppTextStyles.buttonText,
        minimumSize: const Size(120, 48),
      ),
    );
  }

  // Text Button Theme
  static TextButtonThemeData textButtonTheme(Map<String, Color> colors) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors['primary'],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: AppTextStyles.buttonText,
        minimumSize: const Size(80, 40),
      ),
    );
  }

  // Outlined Button Theme
  static OutlinedButtonThemeData outlinedButtonTheme(
    Map<String, Color> colors,
  ) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors['primary'],
        side: BorderSide(color: colors['primary']!, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: AppTextStyles.buttonText,
        minimumSize: const Size(120, 48),
      ),
    );
  }

  // Custom button styles for specific use cases
  static ButtonStyle primaryButton(Map<String, Color> colors) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors['primary'],
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: colors['primary']!.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      textStyle: AppTextStyles.buttonText.copyWith(fontSize: 16),
      minimumSize: const Size(140, 56),
    );
  }

  static ButtonStyle secondaryButton(Map<String, Color> colors) {
    return OutlinedButton.styleFrom(
      foregroundColor: colors['primary'],
      side: BorderSide(color: colors['primary']!, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      textStyle: AppTextStyles.buttonText.copyWith(fontSize: 16),
      minimumSize: const Size(140, 56),
    );
  }

  static ButtonStyle dangerButton(Map<String, Color> colors) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors['error'],
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: AppTextStyles.buttonText,
      minimumSize: const Size(120, 48),
    );
  }

  static ButtonStyle successButton(Map<String, Color> colors) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors['success'],
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: AppTextStyles.buttonText,
      minimumSize: const Size(120, 48),
    );
  }

  static ButtonStyle iconButton(Map<String, Color> colors) {
    return IconButton.styleFrom(
      foregroundColor: colors['text'],
      backgroundColor: colors['surface'],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      minimumSize: const Size(48, 48),
    );
  }

  static FloatingActionButtonThemeData floatingActionButton(
    Map<String, Color> colors,
  ) {
    return FloatingActionButtonThemeData(
      backgroundColor: colors['primary'],
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// Extension methods for easy access to theme styles
extension ThemeExtension on BuildContext {
  Map<String, Color> get themeColors => AppTheme.currentTheme['colors'];

  TextStyle get primaryText => AppTextStyles.primaryText(themeColors);
  TextStyle get secondaryText => AppTextStyles.secondaryText(themeColors);
  TextStyle get errorText => AppTextStyles.errorText(themeColors);
  TextStyle get successText => AppTextStyles.successText(themeColors);

  InputDecoration searchDecoration({String? hintText}) =>
      AppInputStyles.searchDecoration(themeColors, hintText: hintText);
  InputDecoration passwordDecoration({String? hintText}) =>
      AppInputStyles.passwordDecoration(themeColors, hintText: hintText);
  InputDecoration multilineDecoration({String? hintText}) =>
      AppInputStyles.multilineDecoration(themeColors, hintText: hintText);

  ButtonStyle get primaryButton => AppButtonStyles.primaryButton(themeColors);
  ButtonStyle get secondaryButton =>
      AppButtonStyles.secondaryButton(themeColors);
  ButtonStyle get dangerButton => AppButtonStyles.dangerButton(themeColors);
  ButtonStyle get successButton => AppButtonStyles.successButton(themeColors);
  ButtonStyle get iconButton => AppButtonStyles.iconButton(themeColors);
  FloatingActionButtonThemeData get floatingActionButton =>
      AppButtonStyles.floatingActionButton(themeColors);
}
