// import 'package:flutter/material.dart';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:frontend_aicono/core/constant.dart';
// import 'package:frontend_aicono/core/widgets/theme_switcher.dart';
// import 'package:frontend_aicono/core/widgets/language_switcher.dart';

// class LoginHeader extends StatefulWidget {
//   final VoidCallback onLanguageChanged;
//   const LoginHeader({super.key, required this.onLanguageChanged});

//   @override
//   State<LoginHeader> createState() => _LoginHeaderState();
// }

// class _LoginHeaderState extends State<LoginHeader> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
//       decoration: BoxDecoration(
       
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(24),
//           topRight: Radius.circular(24),
//         ),
//       ),
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           Positioned(
//             top: 0,
//             right: 0,
//             child: Row(
//               children: [
//                 Text(
//                   'login_screen.menu'.tr(),
//                   style: TextStyle(color: AppTheme.text, fontSize: 12),
//                 ),
//                 const SizedBox(width: 8),
//                 const ThemeSwitcher(),
//                 const SizedBox(width: 4),
//                 LanguageSwitcher(
//                   onLanguageChanged: () {
//                     // Force a rebuild by updating state
//                     widget.onLanguageChanged?.call();
//                   },
//                 ),
//               ],
//             ),
//           ),
         
//         ],
//       ),
//     );
//   }
// }
