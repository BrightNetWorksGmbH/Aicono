import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

/// Reusable primary action button used across onboarding / switch creation flows.
///
/// By default this renders as a fixed–height, outline–style button that
/// matches the BryteSwitch design (thick dark border, neutral background).
class PrimaryOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final bool enabled;

  const PrimaryOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.textStyle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Text(
          label,
          style: effectiveTextStyle,
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (!enabled || onPressed == null) {
      return Opacity(opacity: enabled ? 1.0 : 0.5, child: button);
    }

    return InkWell(onTap: onPressed, child: button);
  }
}
