import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.palette),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'default',
          child: Text('Default Theme'),
        ),
        const PopupMenuItem<String>(
          value: 'theme1',
          child: Text('Theme 1 (Light)'),
        ),
        const PopupMenuItem<String>(
          value: 'theme2',
          child: Text('Theme 2 (Dark Green)'),
        ),
      ],
      onSelected: (String themeName) {
        AppTheme.setTheme(themeName);
        // Force rebuild by navigating or using state management
        // In a real app, you'd use a state management solution
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Theme changed to $themeName')));
      },
    );
  }
}
