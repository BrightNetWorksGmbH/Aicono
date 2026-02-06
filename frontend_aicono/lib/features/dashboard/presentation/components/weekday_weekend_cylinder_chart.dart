import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

/// A custom 3D cyclic (cylinder) bar chart for comparing Weekend vs Weekday energy usage.
/// Each bar is drawn as a 3D cylinder with an elliptical top cap and depth shading.
class WeekdayWeekendCylinderChart extends StatelessWidget {
  final double weekendValue;
  final double weekdayValue;
  final Color weekendColor;
  final Color weekdayColor;

  const WeekdayWeekendCylinderChart({
    super.key,
    required this.weekendValue,
    required this.weekdayValue,
    this.weekendColor = const Color(0xFF8BC34A),
    this.weekdayColor = const Color(0xFF26A69A),
  });

  @override
  Widget build(BuildContext context) {
    final total = weekendValue + weekdayValue;
    final weekendPct = total > 0 ? (weekendValue / total * 100).round() : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Cylinder3DBar(
          value: weekendValue,
          label: 'Weekend ($weekendPct%)',
          color: weekendColor,
          maxVal: total > 0 ? total : 1,
        ),
        _Cylinder3DBar(
          value: weekdayValue,
          label: 'Weekday',
          color: weekdayColor,
          maxVal: total > 0 ? total : 1,
        ),
      ],
    );
  }
}

/// A single 3D cylinder bar with elliptical top cap and depth shading.
class _Cylinder3DBar extends StatelessWidget {
  final double value;
  final String label;
  final Color color;
  final double maxVal;

  const _Cylinder3DBar({
    required this.value,
    required this.label,
    required this.color,
    required this.maxVal,
  });

  @override
  Widget build(BuildContext context) {
    const barHeight = 140.0;
    const barWidth = 64.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: barWidth,
          height: barHeight,
          child: CustomPaint(
            painter: _Cylinder3DPainter(
              value: value,
              maxVal: maxVal,
              color: color,
              barWidth: barWidth,
              barHeight: barHeight,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Custom painter that draws a 3D cylinder with elliptical top cap.
/// The cylinder is viewed at a slight angle so the top appears as an ellipse.
class _Cylinder3DPainter extends CustomPainter {
  final double value;
  final double maxVal;
  final Color color;
  final double barWidth;
  final double barHeight;

  _Cylinder3DPainter({
    required this.value,
    required this.maxVal,
    required this.color,
    required this.barWidth,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillHeight = maxVal > 0
        ? (value / maxVal * barHeight).clamp(28.0, barHeight)
        : 28.0;

    // Cylinder dimensions - ellipse at top gives 3D cyclic look
    const ellipseHeight = 14.0; // Height of the elliptical top cap
    const ellipseFlatten = 0.35; // 0=circle, 1=flat line (perspective)
    final cylinderBodyHeight = fillHeight - ellipseHeight;
    final cx = size.width / 2;

    // 1. Draw empty cylinder background (grey tube)
    _drawCylinderBackground(canvas, size, ellipseHeight, ellipseFlatten, cx);

    // 2. Draw filled 3D cylinder
    if (cylinderBodyHeight > 0) {
      _drawFilledCylinder(
        canvas,
        size,
        cylinderBodyHeight,
        ellipseHeight,
        ellipseFlatten,
        cx,
      );
    }
  }

  void _drawCylinderBackground(
    Canvas canvas,
    Size size,
    double ellipseHeight,
    double ellipseFlatten,
    double cx,
  ) {
    final path = Path();
    final bottom = size.height;
    final top = 0.0;
    final rx = (barWidth / 2) * (1 - ellipseFlatten);

    // Top ellipse (cyclic shape - cylinder viewed at angle)
    final topEllipseRect = Rect.fromCenter(
      center: Offset(cx, top + ellipseHeight / 2),
      width: rx * 2,
      height: ellipseHeight,
    );
    // Front arc of ellipse (top half, right to left) then sides down to base
    path.moveTo(cx + rx, top + ellipseHeight / 2);
    path.arcTo(topEllipseRect, 0, -math.pi, false);
    path.lineTo(cx - rx, bottom - 4);
    path.quadraticBezierTo(cx - rx, bottom, cx, bottom);
    path.quadraticBezierTo(cx + rx, bottom, cx + rx, bottom - 4);
    path.close();

    // Whole container filled with main color at ~0.3 transparency
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );

    // Top ellipse outline - subtle
    canvas.drawPath(
      Path()..addOval(topEllipseRect),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawFilledCylinder(
    Canvas canvas,
    Size size,
    double cylinderBodyHeight,
    double ellipseHeight,
    double ellipseFlatten,
    double cx,
  ) {
    final bottom = size.height;
    final top = 0.0;
    final rx = (barWidth / 2) * (1 - ellipseFlatten);

    // Fill indicator color (ellipse slices) - less transparent than body
    final sliceColor = color.withValues(alpha: 0.75);

    // Position middle slice based on value ratio (higher value -> slice higher)
    final fillRatio = maxVal > 0 ? (value / maxVal).clamp(0.0, 1.0) : 0.0;
    final usableHeight = size.height - (ellipseHeight * 2);
    final midCenterY =
        bottom - ellipseHeight - (usableHeight * fillRatio.clamp(0.0, 1.0));

    // Bottom ellipse (base)
    final bottomRect = Rect.fromCenter(
      center: Offset(cx, bottom - ellipseHeight / 2),
      width: rx * 2,
      height: ellipseHeight,
    );
    canvas.drawOval(
      bottomRect,
      Paint()
        ..color = sliceColor
        ..style = PaintingStyle.fill,
    );

    // Middle ellipse (level indicator)
    final midRect = Rect.fromCenter(
      center: Offset(cx, midCenterY),
      width: rx * 2,
      height: ellipseHeight,
    );
    canvas.drawOval(
      midRect,
      Paint()
        ..color = sliceColor
        ..style = PaintingStyle.fill,
    );

    // Top ellipse cap - solid main color with slight gradient, covering cylinder top
    final topRect = Rect.fromCenter(
      center: Offset(cx, top + ellipseHeight / 2),
      width: rx * 2,
      height: ellipseHeight,
    );
    final topGradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.yellow, 0.6) ?? color, color],
      ).createShader(topRect);
    canvas.drawOval(topRect, topGradientPaint);
  }

  @override
  bool shouldRepaint(covariant _Cylinder3DPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.color != color;
  }
}
