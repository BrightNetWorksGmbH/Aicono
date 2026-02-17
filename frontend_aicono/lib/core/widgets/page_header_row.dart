import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';

/// Reusable header row widget with optional back button, centered title, and right spacer.
/// 
/// This widget provides a consistent header layout across building pages:
/// - Optional back button on the left
/// - Centered title text
/// - Spacer on the right to balance the layout
class PageHeaderRow extends StatelessWidget {
  /// The title text to display (centered)
  final String title;
  
  /// Optional callback for back button. If provided, back button will be shown.
  /// If null and [showBackButton] is true, will use [context.pop()] as default.
  final VoidCallback? onBack;
  
  /// Whether to show the back button. Defaults to true if [onBack] is provided.
  final bool? showBackButton;
  
  /// The text style for the title. Defaults to bold 24px black87.
  final TextStyle? textStyle;
  
  /// The width of the right spacer. Defaults to 24 to match back button width.
  final double? spacerWidth;

  const PageHeaderRow({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton,
    this.textStyle,
    this.spacerWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bool shouldShowBack = showBackButton ?? (onBack != null);
    final double spacer = spacerWidth ?? 24;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (shouldShowBack) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack ?? () => context.pop(),
                borderRadius: BorderRadius.zero,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: textStyle ??
                const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
        ),
        Container(
          width: shouldShowBack ? spacer : 0,
        ),
      ],
    );
  }
}

