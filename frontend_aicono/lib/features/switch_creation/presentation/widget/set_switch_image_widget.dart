import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

class SetSwitchImageWidget extends StatefulWidget {
  final String? userName;
  final String? organizationName;
  final XFile? selectedImageFile;
  final bool skipLogo;
  final bool isUploading;
  final VoidCallback onLanguageChanged;
  final ValueChanged<XFile?>? onImageSelected;
  final ValueChanged<bool>? onSkipLogoChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onVerseChange;
  final VoidCallback? onBack;

  const SetSwitchImageWidget({
    super.key,
    this.userName,
    this.organizationName,
    this.selectedImageFile,
    this.skipLogo = false,
    this.isUploading = false,
    required this.onLanguageChanged,
    this.onImageSelected,
    this.onSkipLogoChanged,
    this.onContinue,
    this.onVerseChange,
    this.onBack,
  });

  @override
  State<SetSwitchImageWidget> createState() => _SetSwitchImageWidgetState();
}

class _SetSwitchImageWidgetState extends State<SetSwitchImageWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _skipLogo = false;
  Uint8List? _selectedImageBytes; // For displaying the image

  @override
  void initState() {
    super.initState();
    // Sync local state with widget prop
    _skipLogo = widget.skipLogo;
    // Load image bytes if selectedImageFile is provided
    _loadImageBytes();
  }

  Future<void> _loadImageBytes() async {
    if (widget.selectedImageFile != null) {
      try {
        final bytes = await widget.selectedImageFile!.readAsBytes();
        if (mounted) {
          setState(() {
            _selectedImageBytes = bytes;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _selectedImageBytes = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedImageBytes = null;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        // Read bytes for display
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
        // Notify parent with XFile
        widget.onImageSelected?.call(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  @override
  void didUpdateWidget(SetSwitchImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local state with widget prop when it changes
    if (widget.skipLogo != oldWidget.skipLogo) {
      setState(() {
        _skipLogo = widget.skipLogo;
      });
    }
    // Update image bytes when selectedImageFile changes
    if (widget.selectedImageFile != oldWidget.selectedImageFile) {
      _loadImageBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        height: (screenSize.height * 0.95) + 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              TopHeader(
                onLanguageChanged: widget.onLanguageChanged,
                containerWidth: screenSize.width,
              ),
              if (widget.onBack != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 50),
              SizedBox(
                width: screenSize.width < 600
                    ? screenSize.width * 0.95
                    : screenSize.width < 1200
                    ? screenSize.width * 0.5
                    : screenSize.width * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'set_switch_image.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _pickImage,
                      child: _DashedBorder(
                        borderColor: Colors.black54,
                        strokeWidth: 2,
                        dashLength: 3,
                        gapLength: 3,
                        borderRadius: 4,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: widget.onVerseChange,
                                child: Text(
                                  'set_switch_image.change_verse'.tr(),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    decoration: TextDecoration.underline,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              if (_selectedImageBytes != null)
                                Image.memory(
                                  _selectedImageBytes!,
                                  height: 80,
                                  fit: BoxFit.contain,
                                )
                              else
                                const Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.black54,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'set_switch_image.tip'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        XCheckBox(
                          value: _skipLogo,
                          onChanged: (value) {
                            // Update local state immediately for responsive UI
                            setState(() {
                              _skipLogo = value ?? false;
                            });
                            // Notify parent
                            widget.onSkipLogoChanged?.call(value ?? false);
                            if (value == true) {
                              widget.onImageSelected?.call(null);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'set_switch_image.skip_logo'.tr(),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    PrimaryOutlineButton(
                      label: widget.isUploading
                          ? 'set_switch_image.uploading'.tr()
                          : 'set_switch_image.button_text'.tr(),
                      width: 260,
                      enabled:
                          !widget.isUploading &&
                          (widget.selectedImageFile != null || _skipLogo),
                      onPressed:
                          (widget.isUploading ||
                              (widget.selectedImageFile == null && !_skipLogo))
                          ? null
                          : widget.onContinue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rectangular border where each side starts its dash pattern
/// from the corner so that the breaks align cleanly at 90°.
class _DashedBorder extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  const _DashedBorder({
    required this.child,
    required this.borderColor,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _DashedRectPainter(
            color: borderColor,
            strokeWidth: strokeWidth,
            dashLength: dashLength,
            gapLength: gapLength,
            radius: borderRadius,
          ),
          child: child,
        );
      },
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Draw each side separately so dash pattern starts fresh at every corner,
    // using the exact rectangle corners for sharp 90° joins.
    _drawDashedLine(canvas, paint, rect.topLeft, rect.topRight);
    _drawDashedLine(canvas, paint, rect.topRight, rect.bottomRight);
    _drawDashedLine(canvas, paint, rect.bottomRight, rect.bottomLeft);
    _drawDashedLine(canvas, paint, rect.bottomLeft, rect.topLeft);
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double distance = 0;

    while (distance < totalLength) {
      final currentStart = start + direction * distance;
      final currentEnd =
          start + direction * (distance + dashLength).clamp(0, totalLength);
      canvas.drawLine(currentStart, currentEnd, paint);
      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
