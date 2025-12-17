import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Example usage of the centralized theme system
class ThemeUsageExamples extends StatelessWidget {
  const ThemeUsageExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme Usage Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Styles Examples
            _buildSectionTitle(context, 'Text Styles (Onest Font)'),
            const SizedBox(height: 16),

            Text(
              'Display Large',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            Text(
              'Headline Medium',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text('Title Large', style: Theme.of(context).textTheme.titleLarge),
            Text('Body Large', style: Theme.of(context).textTheme.bodyLarge),
            Text('Body Medium', style: Theme.of(context).textTheme.bodyMedium),
            Text('Body Small', style: Theme.of(context).textTheme.bodySmall),

            const SizedBox(height: 24),

            // Custom Text Styles Examples
            _buildSectionTitle(context, 'Custom Text Styles (Onest Font)'),
            const SizedBox(height: 16),

            Text('Primary Text', style: context.primaryText),
            Text('Secondary Text', style: context.secondaryText),
            Text('Error Text', style: context.errorText),
            Text('Success Text', style: context.successText),

            const SizedBox(height: 24),

            // Button Examples
            _buildSectionTitle(context, 'Button Styles'),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: context.primaryButton,
                  child: const Text('Primary Button'),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: context.secondaryButton,
                  child: const Text('Secondary Button'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: context.dangerButton,
                  child: const Text('Danger Button'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: context.successButton,
                  child: const Text('Success Button'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Input Field Examples
            _buildSectionTitle(context, 'Input Field Styles'),
            const SizedBox(height: 16),

            TextField(
              decoration: InputDecoration(
                labelText: 'Standard Input',
                hintText: 'Enter text here',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              decoration: context.searchDecoration(hintText: 'Search...'),
            ),

            const SizedBox(height: 16),

            TextField(
              obscureText: true,
              decoration: context.passwordDecoration(
                hintText: 'Enter password',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              maxLines: 3,
              decoration: context.multilineDecoration(
                hintText: 'Enter multiline text',
              ),
            ),

            const SizedBox(height: 24),

            // Card Examples
            _buildSectionTitle(context, 'Card Styles'),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card Title', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Card subtitle with secondary text',
                      style: AppTextStyles.cardSubtitle,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This is the card content. It demonstrates how the card theme looks with the current color scheme.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Theme Colors Display
            _buildSectionTitle(context, 'Current Theme Colors'),
            const SizedBox(height: 16),

            _buildColorSwatch(
              context,
              'Primary',
              context.themeColors['primary']!,
            ),
            _buildColorSwatch(
              context,
              'Secondary',
              context.themeColors['secondary']!,
            ),
            _buildColorSwatch(
              context,
              'Background',
              context.themeColors['background']!,
            ),
            _buildColorSwatch(
              context,
              'Surface',
              context.themeColors['surface']!,
            ),
            _buildColorSwatch(context, 'Text', context.themeColors['text']!),
            _buildColorSwatch(
              context,
              'Text Secondary',
              context.themeColors['textSecondary']!,
            ),
            _buildColorSwatch(context, 'Error', context.themeColors['error']!),
            _buildColorSwatch(
              context,
              'Success',
              context.themeColors['success']!,
            ),
            _buildColorSwatch(
              context,
              'Border',
              context.themeColors['border']!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildColorSwatch(BuildContext context, String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 12),
          Text(name, style: context.primaryText),
          const SizedBox(width: 8),
          Text(
            '${color.value.toRadixString(16).toUpperCase()}',
            style: context.secondaryText,
          ),
        ],
      ),
    );
  }
}

/// Example of how to use the theme in a custom widget
class CustomThemedWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const CustomThemedWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.cardTitle.copyWith(
                  color: context.themeColors['text'],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.cardSubtitle.copyWith(
                  color: context.themeColors['textSecondary'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
