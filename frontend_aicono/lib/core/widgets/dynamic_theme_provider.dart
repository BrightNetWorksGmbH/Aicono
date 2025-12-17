// import 'package:flutter/material.dart';
// import 'package:mobile/core/constant.dart';
// import 'package:mobile/core/injection_container.dart';
// import 'package:mobile/core/services/dynamic_theme_service.dart';

// /// Provider widget that manages dynamic theme changes
// class DynamicThemeProvider extends StatefulWidget {
//   final Widget child;

//   const DynamicThemeProvider({super.key, required this.child});

//   @override
//   State<DynamicThemeProvider> createState() => _DynamicThemeProviderState();
// }

// class _DynamicThemeProviderState extends State<DynamicThemeProvider> {
//   late DynamicThemeService _themeService;

//   @override
//   void initState() {
//     super.initState();
//     _themeService = sl<DynamicThemeService>();
//     _themeService.addListener(_onThemeChanged);

//     // Initialize theme service
//     _themeService.initialize();
//   }

//   @override
//   void dispose() {
//     _themeService.removeListener(_onThemeChanged);
//     super.dispose();
//   }

//   void _onThemeChanged() {
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _themeService,
//       builder: (context, child) {
//         return MaterialApp(
//           title: 'BryteSpring',
//           theme: ThemeData(
//             primarySwatch: _createMaterialColor(AppTheme.primary),
//             scaffoldBackgroundColor: _themeService.getCurrentSurfaceColor(),
//             appBarTheme: AppBarTheme(
//               backgroundColor: _themeService.getCurrentSurfaceColor(),
//               foregroundColor: AppTheme.text,
//             ),
//             cardTheme: CardThemeData(
//               color: _themeService.getCurrentSurfaceColor(),
//               elevation: 2,
//             ),
//             elevatedButtonTheme: ElevatedButtonThemeData(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppTheme.primary,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//             textTheme: TextTheme(
//               bodyLarge: TextStyle(color: AppTheme.text),
//               bodyMedium: TextStyle(color: AppTheme.text),
//               bodySmall: TextStyle(color: AppTheme.textSecondary),
//             ),
//           ),
//           home: widget.child,
//         );
//       },
//     );
//   }

//   /// Create MaterialColor from Color
//   MaterialColor _createMaterialColor(Color color) {
//     List strengths = <double>[.05];
//     Map<int, Color> swatch = {};
//     final int r = color.red, g = color.green, b = color.blue;

//     for (int i = 1; i < 10; i++) {
//       strengths.add(0.1 * i);
//     }
//     for (var strength in strengths) {
//       final double ds = 0.5 - strength;
//       swatch[(strength * 1000).round()] = Color.fromRGBO(
//         r + ((ds < 0 ? r : (255 - r)) * ds).round(),
//         g + ((ds < 0 ? g : (255 - g)) * ds).round(),
//         b + ((ds < 0 ? b : (255 - b)) * ds).round(),
//         1,
//       );
//     }
//     return MaterialColor(color.value, swatch);
//   }
// }
