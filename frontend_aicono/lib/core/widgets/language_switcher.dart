import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageSwitcher extends StatelessWidget {
  final VoidCallback? onLanguageChanged;

  const LanguageSwitcher({super.key, this.onLanguageChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.white),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'en', child: Text('English')),
        const PopupMenuItem<String>(value: 'de', child: Text('Deutsch')),
      ],
      onSelected: (String languageCode) async {
        // Set the locale using EasyLocalization
        await context.setLocale(Locale(languageCode));

        // Call the callback to force a rebuild of parent widgets
        onLanguageChanged?.call();
      },
    );
  }
}
