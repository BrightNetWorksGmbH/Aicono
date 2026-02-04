import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

class PrimaryOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final bool enabled;

  /// When true, shows a small loading indicator inside the button and
  /// visually disables it (no tap).
  final bool loading;

  const PrimaryOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.textStyle,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = enabled && !loading && onPressed != null;

    final effectiveTextStyle = (textStyle ?? AppTextStyles.bodyMedium).copyWith(
      color: enabled ? Colors.black : Colors.grey,
      fontWeight: FontWeight.w600,
    );

    final button = Container(
      width: width,
      height: 40,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: enabled ? const Color(0xFF636F57) : Colors.grey.shade400,
          width: 4,
        ),
      ),
      child: Center(
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: effectiveTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: effectiveTextStyle,
                textAlign: TextAlign.center,
              ),
      ),
    );

    if (!isInteractive) {
      return Opacity(opacity: enabled ? 1.0 : 0.5, child: button);
    }

    return InkWell(onTap: onPressed, child: button);
  }
}
