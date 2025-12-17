# Centralized Theme System

This directory contains a comprehensive centralized theme system for the BryteSpring Flutter app. The theme system provides consistent styling for text, text fields, buttons, and other UI components across the entire application.

## Prerequisites

Before using this theme system, make sure you have the `google_fonts` package installed:

```bash
flutter pub add google_fonts
```

Or add it manually to your `pubspec.yaml`:

```yaml
dependencies:
  google_fonts: ^6.2.1
```

Then run:

```bash
flutter pub get
```

## Files Overview

- `app_theme.dart` - Complete theme system including text styles, input decorations, button styles, and theme data
- `theme_usage_examples.dart` - Examples showing how to use the theme system
- `index.dart` - Exports all theme-related classes

## Key Features

### 1. Text Styles (`AppTextStyles`)

Comprehensive text styles following Material Design 3 guidelines with **Onest font family**:

- **Display styles**: `displayLarge`, `displayMedium`, `displaySmall`
- **Headline styles**: `headlineLarge`, `headlineMedium`, `headlineSmall`
- **Title styles**: `titleLarge`, `titleMedium`, `titleSmall`
- **Body styles**: `bodyLarge`, `bodyMedium`, `bodySmall`
- **Label styles**: `labelLarge`, `labelMedium`, `labelSmall`
- **Custom styles**: `buttonText`, `caption`, `overline`, `cardTitle`, `cardSubtitle`, etc.

**All text styles use the Onest font family via Google Fonts.**

### 2. Input Field Styles (`AppInputStyles`)

Predefined input decoration themes for different use cases:

- **Standard input**: Basic text field styling
- **Search input**: Rounded search field with search icon
- **Password input**: Password field with lock icon
- **Multiline input**: Text area for longer text input

### 3. Button Styles (`AppButtonStyles`)

Comprehensive button styling for various button types:

- **Primary button**: Main action buttons with elevated style
- **Secondary button**: Outlined buttons for secondary actions
- **Danger button**: Red buttons for destructive actions
- **Success button**: Green buttons for positive actions
- **Icon button**: Buttons with icons
- **Floating action button**: FAB styling

### 4. Theme Data (`AppTheme`)

Centralized theme data that integrates with your existing `AppTheme` system:

- Uses the current theme colors from `AppTheme.currentTheme`
- Provides complete `ThemeData` for Material Design 3
- Integrates with existing color definitions and theme switching mechanism

## Usage Examples

### Using Text Styles

```dart
// Using Material Design text styles
Text('Title', style: Theme.of(context).textTheme.headlineMedium)

// Using custom text styles
Text('Card Title', style: AppTextStyles.cardTitle)

// Using context extensions
Text('Primary Text', style: context.primaryText)
Text('Secondary Text', style: context.secondaryText)
Text('Error Text', style: context.errorText)
```

### Using Input Field Styles

```dart
// Standard text field
TextField(
  decoration: InputDecoration(
    labelText: 'Standard Input',
    hintText: 'Enter text here',
  ),
)

// Search field
TextField(
  decoration: context.searchDecoration(hintText: 'Search...'),
)

// Password field
TextField(
  obscureText: true,
  decoration: context.passwordDecoration(hintText: 'Enter password'),
)

// Multiline field
TextField(
  maxLines: 3,
  decoration: context.multilineDecoration(hintText: 'Enter multiline text'),
)
```

### Using Button Styles

```dart
// Primary button
ElevatedButton(
  onPressed: () {},
  style: context.primaryButton,
  child: const Text('Primary Button'),
)

// Secondary button
OutlinedButton(
  onPressed: () {},
  style: context.secondaryButton,
  child: const Text('Secondary Button'),
)

// Danger button
ElevatedButton(
  onPressed: () {},
  style: context.dangerButton,
  child: const Text('Delete'),
)

// Success button
ElevatedButton(
  onPressed: () {},
  style: context.successButton,
  child: const Text('Save'),
)
```

### Using Theme Colors

```dart
// Access theme colors through context extension
Container(
  color: context.themeColors['primary'],
  child: Text(
    'Colored Text',
    style: TextStyle(color: context.themeColors['text']),
  ),
)

// Or directly from AppTheme
Container(
  color: AppTheme.primary,
  child: Text(
    'Colored Text',
    style: TextStyle(color: AppTheme.text),
  ),
)
```

### Using Theme Data in MaterialApp

```dart
MaterialApp(
  theme: AppTheme.currentTheme,
  home: MyHomePage(),
)
```

## Integration with Existing Theme System

The centralized theme system integrates seamlessly with the existing `AppTheme` class in `constant.dart`:

1. **Color Management**: Uses the existing color definitions and theme switching mechanism
2. **Dynamic Themes**: Works with the `DynamicThemeService` for verse-based theming
3. **Theme Switching**: Leverages the existing `AppTheme.setTheme()` method

## Best Practices

1. **Consistency**: Always use the predefined styles instead of creating custom ones
2. **Context Extensions**: Use the context extensions for easy access to theme styles
3. **Theme Colors**: Access colors through `context.themeColors` or `AppTheme` static properties
4. **Responsive Design**: Use appropriate text styles for different screen sizes
5. **Accessibility**: Ensure sufficient contrast ratios between text and background colors

## Migration Guide

When migrating existing components to use the centralized theme:

1. Replace hardcoded colors with theme color references
2. Replace custom text styles with predefined `AppTextStyles`
3. Replace custom button styles with predefined `AppButtonStyles`
4. Replace custom input decorations with predefined `AppInputStyles`
5. Use context extensions for easier theme access

## Architecture

The theme system is designed to be:

- **Static**: No theme switching complexity - uses the current theme from `AppTheme`
- **Centralized**: All styles defined in one place (`app_theme.dart`)
- **Consistent**: Follows Material Design 3 guidelines
- **Extensible**: Easy to add new styles or modify existing ones
- **Integrated**: Works seamlessly with existing theme infrastructure

This centralized theme system ensures consistency across the app while maintaining simplicity and easy maintenance.
