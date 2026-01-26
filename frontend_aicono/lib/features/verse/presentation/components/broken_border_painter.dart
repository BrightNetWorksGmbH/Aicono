import 'package:flutter/material.dart';

class BrokenBorderPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double dashLength;
  final double dashSpace;

  BrokenBorderPainter({
    this.borderColor = Colors.grey,
    this.borderWidth = 1.0,
    this.dashLength = 8.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    double currentLength = 0;
    bool draw = true;

    // Top border
    while (currentLength < size.width) {
      if (draw) {
        path.moveTo(currentLength, 0);
        path.lineTo(
          (currentLength + dashLength > size.width)
              ? size.width
              : currentLength + dashLength,
          0,
        );
      }
      currentLength += draw ? dashLength : dashSpace;
      draw = !draw;
    }

    // Right border
    currentLength = 0;
    draw = true;
    while (currentLength < size.height) {
      if (draw) {
        path.moveTo(size.width, currentLength);
        path.lineTo(
          size.width,
          (currentLength + dashLength > size.height)
              ? size.height
              : currentLength + dashLength,
        );
      }
      currentLength += draw ? dashLength : dashSpace;
      draw = !draw;
    }

    // Bottom border
    currentLength = 0;
    draw = true;
    while (currentLength < size.width) {
      if (draw) {
        path.moveTo(size.width - currentLength, size.height);
        path.lineTo(
          (size.width - currentLength - dashLength < 0)
              ? 0
              : size.width - currentLength - dashLength,
          size.height,
        );
      }
      currentLength += draw ? dashLength : dashSpace;
      draw = !draw;
    }

    // Left border
    currentLength = 0;
    draw = true;
    while (currentLength < size.height) {
      if (draw) {
        path.moveTo(0, size.height - currentLength);
        path.lineTo(
          0,
          (size.height - currentLength - dashLength < 0)
              ? 0
              : size.height - currentLength - dashLength,
        );
      }
      currentLength += draw ? dashLength : dashSpace;
      draw = !draw;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
