import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Encode, base64Decode, utf8, jsonEncode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:xml/xml.dart' as xml;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io' show File;
import 'package:image_picker/image_picker.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_bloc.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_event.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_state.dart';
import '../../../../../core/routing/routeLists.dart';
import '../../../../../core/widgets/page_header_row.dart';
import '../../../../../core/widgets/primary_outline_button.dart';
import '../../pages/steps/building_floor_plan_step.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum DrawingMode { none, rectangle, polygon }

enum _ShapeTool { polygon, rectangle, triangle, circle }

class Room {
  final String id;
  Path path;
  Color fillColor;
  String name;
  double area;

  Room({
    required this.id,
    required this.path,
    Color? fillColor,
    String? name,
    double? area,
  }) : fillColor = fillColor ?? const Color(0xFFF5F5DC),
       name = name ?? 'Room',
       area = area ?? 0.0;
}

// Rectangle creation helper
Path createRectangle(Offset start, Offset end) {
  final rect = Rect.fromPoints(start, end);
  return Path()
    ..moveTo(rect.left, rect.top)
    ..lineTo(rect.right, rect.top)
    ..lineTo(rect.right, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();
}

Path createTriangle(Offset o, {double width = 100, double height = 90}) {
  // Isosceles triangle pointing up
  return Path()
    ..moveTo(o.dx + (width / 2), o.dy) // top
    ..lineTo(o.dx + width, o.dy + height) // bottom right
    ..lineTo(o.dx, o.dy + height) // bottom left
    ..close();
}

Path createCircle(Offset center, {double radius = 50}) {
  return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
}

class FloorPlanActivationWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final Uint8List? initialImageBytes;
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingSize;
  final int? numberOfRooms;
  final String? constructionYear;
  final String? floorName;
  final String buildingId;
  final String siteId;
  final String? fromDashboard;
  const FloorPlanActivationWidget({
    super.key,
    this.onComplete,
    this.onSkip,
    this.initialImageBytes,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingSize,
    this.numberOfRooms,
    this.constructionYear,
    this.floorName,
    required this.buildingId,
    required this.siteId,
    this.fromDashboard,
  });

  @override
  State<FloorPlanActivationWidget> createState() =>
      _FloorPlanActivationWidgetState();
}

/// State snapshot for undo/redo functionality
class _FloorPlanState {
  final List<Room> rooms;
  final int roomCounter;

  _FloorPlanState({required this.rooms, required this.roomCounter});

  // Deep copy constructor
  _FloorPlanState copy() {
    return _FloorPlanState(
      rooms: rooms
          .map(
            (room) => Room(
              id: room.id,
              path: Path.from(room.path),
              fillColor: room.fillColor,
              name: room.name,
              area: room.area,
            ),
          )
          .toList(),
      roomCounter: roomCounter,
    );
  }
}

class _FloorPlanActivationWidgetState extends State<FloorPlanActivationWidget> {
  final List<Room> rooms = [];
  Room? selectedRoom;
  // Image data for background
  Uint8List? _imageBytes;
  double? _backgroundImageWidth;
  double? _backgroundImageHeight;
  double _currentScaleX = 1.0;
  double _currentScaleY = 1.0;

  // Undo/Redo history
  final List<_FloorPlanState> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

  // Drawing mode
  DrawingMode _drawingMode = DrawingMode.none;
  _ShapeTool? _selectedShapeTool;

  // Rectangle creation state
  Offset? _rectangleStart;
  Rect? _currentRectangle;

  // Polygon creation state
  List<Offset> _polygonPoints = [];
  Offset? _polygonPreviewPosition; // Current cursor position for preview

  Color _roomColor = const Color(0xFFFFB74D); // Default light orange
  int _roomCounter = 1;

  // UI state
  bool _showDrawingMode =
      false; // Show rectangle/polygon buttons only after "Add room" is clicked
  final Map<String, TextEditingController> _roomControllers = {};

  // Move/Resize state
  Offset? _dragStart;
  Rect? _startBounds;
  bool _isMoving = false;
  bool _isResizing = false;
  int _resizeHandle = -1; // 0=topLeft, 1=topRight, 2=bottomRight, 3=bottomLeft
  Room? _roomAtPanStart; // Track which room was selected when pan started

  // Upload subscription
  StreamSubscription? _uploadSubscription;

  // Color palette matching the design
  static const List<Color> colorPalette = [
    Color(0xFFFFB74D), // Light orange
    Color(0xFFE57373), // Red
    Color(0xFFBA68C8), // Purple
    Color(0xFF64B5F6), // Blue
    // Color(0xFF4DD0E1), // Light blue
    Color(0xFF81C784), // Green
    // Color(0xFFFFD54F), // Yellow
    // Color(0xFFF5F5DC), // Beige (default)
  ];

  @override
  void initState() {
    super.initState();
    // If initial image is provided, load it immediately
    if (widget.initialImageBytes != null) {
      _loadImageBytes(widget.initialImageBytes!);
    } else {
      _loadDefaultFloorPlan();
    }
  }

  void _loadDefaultFloorPlan() {
    // Try to load from a default file or show upload prompt
  }

  void _clearPreviousFloorPlan() {
    // Clear all previous floor plan data
    setState(() {
      _imageBytes = null;
      _backgroundImageWidth = null;
      _backgroundImageHeight = null;
      rooms.clear();
      selectedRoom = null;
      _roomCounter = 1;
      _drawingMode = DrawingMode.none;
      _rectangleStart = null;
      _currentRectangle = null;
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      _isMoving = false;
      _isResizing = false;
      _dragStart = null;
      _startBounds = null;
      _resizeHandle = -1;
      _roomAtPanStart = null;
      _showDrawingMode = false;
      // Dispose all room controllers
      for (final controller in _roomControllers.values) {
        controller.dispose();
      }
      _roomControllers.clear();
    });
  }

  Future<void> _loadImageBytes(Uint8List bytes) async {
    // Clear previous floor plan before loading new one
    _clearPreviousFloorPlan();

    // Decode the image to get its dimensions
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final decodedImage = frame.image;

    // Update state with decoded image information
    setState(() {
      _imageBytes = bytes;
      _backgroundImageWidth = decodedImage.width.toDouble();
      _backgroundImageHeight = decodedImage.height.toDouble();
    });

    decodedImage.dispose();
  }

  Future<void> _uploadFloorPlan() async {
    try {
      FilePickerResult? result;

      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['svg', 'png', 'jpg', 'jpeg'],
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['svg', 'png', 'jpg', 'jpeg'],
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.extension == 'svg') {
          String svgContent;
          if (kIsWeb) {
            if (file.bytes != null) {
              svgContent = String.fromCharCodes(file.bytes!);
            } else {
              _showError('Error: Could not read file data');
              return;
            }
          } else {
            _showError('SVG upload is currently only available on web');
            return;
          }
          await _loadFromSVG(svgContent);
        } else if (file.extension == 'png' ||
            file.extension == 'jpg' ||
            file.extension == 'jpeg') {
          // Handle image files
          if (kIsWeb) {
            if (file.bytes != null) {
              await _loadImageBytes(file.bytes!);
            } else {
              _showError('Error: Could not read file data');
            }
          } else {
            // For non-web platforms, read file from path
            final filePath = file.path;
            if (filePath != null) {
              final fileData = await File(filePath).readAsBytes();
              await _loadImageBytes(fileData);
            } else {
              _showError('Error: Could not read file path');
            }
          }
        }
      }
    } catch (e) {
      _showError('Error uploading file: ${e.toString()}');
    }
  }

  Future<void> _loadFromSVG(String svgContent) async {
    // Clear previous floor plan before loading new one
    _clearPreviousFloorPlan();

    try {
      final document = xml.XmlDocument.parse(svgContent);
      final newRooms = <Room>[];

      // Extract background image from SVG if present
      final imageElements = document.findAllElements('image');
      for (final imageElement in imageElements) {
        final href =
            imageElement.getAttribute('href') ??
            imageElement.getAttribute('xlink:href');

        if (href != null && href.startsWith('data:image/')) {
          // Extract base64 data from data URL
          final base64Match = RegExp(
            r'data:image/[^;]+;base64,(.+)$',
          ).firstMatch(href);
          if (base64Match != null) {
            try {
              final base64Data = base64Match.group(1)!;
              final imageBytes = base64Decode(base64Data);

              // Get image dimensions from SVG attributes
              final widthAttr = imageElement.getAttribute('width');
              final heightAttr = imageElement.getAttribute('height');

              if (widthAttr != null && heightAttr != null) {
                final width = double.tryParse(widthAttr) ?? 0;
                final height = double.tryParse(heightAttr) ?? 0;

                if (width > 0 && height > 0) {
                  // Load the image bytes
                  await _loadImageBytes(imageBytes);
                  // Set dimensions explicitly
                  setState(() {
                    _backgroundImageWidth = width;
                    _backgroundImageHeight = height;
                  });
                  break; // Only use the first image found
                }
              } else {
                // If dimensions not in SVG, decode to get actual dimensions
                await _loadImageBytes(imageBytes);
                break;
              }
            } catch (e) {
              debugPrint('Error decoding base64 image: $e');
            }
          }
        }
      }

      // Get SVG dimensions from viewBox or width/height if no image was found
      if (_imageBytes == null) {
        final svgElement = document.rootElement;
        final viewBox = svgElement.getAttribute('viewBox');
        if (viewBox != null) {
          final parts = viewBox.split(' ');
          if (parts.length >= 4) {
            final width = double.tryParse(parts[2]) ?? 0;
            final height = double.tryParse(parts[3]) ?? 0;
            if (width > 0 && height > 0) {
              setState(() {
                _backgroundImageWidth = width;
                _backgroundImageHeight = height;
              });
            }
          }
        } else {
          final widthAttr = svgElement.getAttribute('width');
          final heightAttr = svgElement.getAttribute('height');
          if (widthAttr != null && heightAttr != null) {
            final width = double.tryParse(widthAttr) ?? 0;
            final height = double.tryParse(heightAttr) ?? 0;
            if (width > 0 && height > 0) {
              setState(() {
                _backgroundImageWidth = width;
                _backgroundImageHeight = height;
              });
            }
          }
        }
      }

      // Detect if this is our format by checking for specific markers
      // Our format has paths with fill-opacity="0.3" or stroke-width="3" for selected rooms
      bool isOurFormat = false;
      final pathElements = document.findAllElements('path');

      // Check if any path has our format markers
      for (final pathElement in pathElements) {
        final fillOpacity = pathElement.getAttribute('fill-opacity');
        final strokeWidth = pathElement.getAttribute('stroke-width');

        // Our format uses fill-opacity="0.3" and stroke-width="3" for selected rooms
        if (fillOpacity == '0.3' ||
            (strokeWidth != null && strokeWidth == '3')) {
          isOurFormat = true;
          break;
        }
      }

      // Also check if there are text elements with m² (our format includes area labels)
      if (!isOurFormat) {
        final textElements = document.findAllElements('text');
        for (final textElement in textElements) {
          final text = textElement.text.trim();
          if (text.contains('m²')) {
            isOurFormat = true;
            break;
          }
        }
      }

      // If it's NOT our format, only use the image as background
      // Don't parse paths as rooms - allow user to draw on top
      if (!isOurFormat && pathElements.isNotEmpty) {
        // This is an external SVG - use image as background only
        setState(() {
          // Clear existing rooms since this is not our format
          rooms.clear();
          selectedRoom = null;
          _roomCounter = 1;
        });
        return; // Exit early, just use the background image
      }

      // Parse rooms only if it's our format
      int roomIndex = 1;
      for (final pathElement in pathElements) {
        final pathData = pathElement.getAttribute('d');
        if (pathData == null || pathData.isEmpty) continue;

        final fill = pathElement.getAttribute('fill');
        final fillOpacity = pathElement.getAttribute('fill-opacity');

        // Only parse paths that are likely our rooms (have fill-opacity or fill attribute)
        if (fill != null || fillOpacity != null) {
          try {
            final roomPath = _parseSVGPath(pathData);
            if (roomPath.getBounds().isEmpty) continue; // Skip invalid paths

            final fillColor = fill == 'none' || fill == null
                ? const Color(0xFFF5F5DC) // Default color for transparent fills
                : (_hexToColor(fill) ?? const Color(0xFFF5F5DC));
            final area = _calculateArea(roomPath);

            newRooms.add(
              Room(
                id: 'room_$roomIndex',
                path: roomPath,
                fillColor: fillColor,
                name: 'Room $roomIndex',
                area: area,
              ),
            );
            roomIndex++;
          } catch (e) {
            // Skip paths that can't be parsed
            debugPrint('Error parsing path element: $e');
            continue;
          }
        }
      }

      // Find text elements for room names (skip area text like "123.45 m²")
      final textElements = document.findAllElements('text');
      final Map<int, String> roomNameMap = {}; // Map room index to name

      for (final textElement in textElements) {
        final text = textElement.text.trim();
        if (text.isEmpty) continue;

        // Skip text that looks like area (contains "m²" or matches area pattern)
        if (text.contains('m²') ||
            RegExp(r'^\d+\.?\d*\s*m²?$').hasMatch(text)) {
          continue;
        }

        final x = double.tryParse(textElement.getAttribute('x') ?? '') ?? 0;
        final y = double.tryParse(textElement.getAttribute('y') ?? '') ?? 0;
        final textPos = Offset(x, y);

        // Find nearest room to this text
        if (newRooms.isEmpty) continue;

        Room? nearestRoom;
        double minDistance = double.infinity;
        int nearestIndex = -1;

        for (int i = 0; i < newRooms.length; i++) {
          final room = newRooms[i];
          final bounds = room.path.getBounds();
          final center = bounds.center;
          final distance = (center - textPos).distance;

          if (distance < minDistance) {
            minDistance = distance;
            nearestRoom = room;
            nearestIndex = i;
          }
        }

        if (nearestRoom != null && nearestIndex != -1 && minDistance < 150) {
          // Store the first (closest) text for this room, or use the one with smaller y (higher on screen = name)
          if (!roomNameMap.containsKey(nearestIndex) ||
              (roomNameMap.containsKey(nearestIndex) &&
                  y < double.parse(textElement.getAttribute('y') ?? '999'))) {
            roomNameMap[nearestIndex] = text;
          }
        }
      }

      // Update room names from the map
      for (final entry in roomNameMap.entries) {
        final index = entry.key;
        final name = entry.value;
        if (index < newRooms.length) {
          final room = newRooms[index];
          newRooms[index] = Room(
            id: room.id,
            path: room.path,
            fillColor: room.fillColor,
            name: name,
            area: room.area,
          );
        }
      }

      setState(() {
        // rooms already cleared by _clearPreviousFloorPlan()
        rooms.addAll(newRooms);
        selectedRoom = null;
        // Reset room counter to continue from where we left off
        _roomCounter = newRooms.length + 1;
      });
    } catch (e) {
      _showError('Error parsing SVG: ${e.toString()}');
    }
  }

  Path _parseSVGPath(String pathData) {
    final path = Path();
    final commands = _parsePathCommands(pathData);

    double currentX = 0;
    double currentY = 0;

    for (final cmd in commands) {
      switch (cmd.command.toUpperCase()) {
        case 'M':
          if (cmd.coordinates.length >= 2) {
            currentX = cmd.coordinates[0];
            currentY = cmd.coordinates[1];
            path.moveTo(currentX, currentY);
          }
          break;
        case 'L':
          if (cmd.coordinates.length >= 2) {
            currentX = cmd.coordinates[0];
            currentY = cmd.coordinates[1];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'H':
          if (cmd.coordinates.isNotEmpty) {
            currentX = cmd.coordinates[0];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'V':
          if (cmd.coordinates.isNotEmpty) {
            currentY = cmd.coordinates[0];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'C':
          if (cmd.coordinates.length >= 6) {
            path.cubicTo(
              cmd.coordinates[0],
              cmd.coordinates[1],
              cmd.coordinates[2],
              cmd.coordinates[3],
              cmd.coordinates[4],
              cmd.coordinates[5],
            );
            currentX = cmd.coordinates[4];
            currentY = cmd.coordinates[5];
          }
          break;
        case 'Q':
          if (cmd.coordinates.length >= 4) {
            path.quadraticBezierTo(
              cmd.coordinates[0],
              cmd.coordinates[1],
              cmd.coordinates[2],
              cmd.coordinates[3],
            );
            currentX = cmd.coordinates[2];
            currentY = cmd.coordinates[3];
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  List<_PathCommand> _parsePathCommands(String pathData) {
    final commands = <_PathCommand>[];
    final regex = RegExp(r'([MmLlHhVvCcQqZz])\s*([-\d.e]+(?:\s+[-\d.e]+)*)?');

    for (final match in regex.allMatches(pathData)) {
      final command = match.group(1)!;
      final coordsStr = match.group(2);

      List<double> coordinates = [];
      if (coordsStr != null) {
        coordinates = coordsStr
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => double.tryParse(s.trim()) ?? 0)
            .toList();
      }

      commands.add(_PathCommand(command, coordinates));
    }

    return commands;
  }

  Color? _hexToColor(String hex) {
    try {
      hex = hex.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  double _calculateArea(Path path) {
    final bounds = path.getBounds();
    return (bounds.width * bounds.height) / 10000; // Convert to m²
  }

  // Convert Color to hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';
  }

  // Convert Path to SVG path data
  String _pathToSvgPathData(Path path) {
    final metrics = path.computeMetrics();
    final buffer = StringBuffer();
    bool isFirst = true;

    for (final metric in metrics) {
      final length = metric.length;
      final sampleCount = math.max(10, (length / 10).ceil());
      final step = length / sampleCount;

      for (int i = 0; i <= sampleCount; i++) {
        final distance = i * step;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final point = tangent.position;
          if (isFirst) {
            buffer.write(
              'M ${point.dx.toStringAsFixed(2)} ${point.dy.toStringAsFixed(2)} ',
            );
            isFirst = false;
          } else {
            buffer.write(
              'L ${point.dx.toStringAsFixed(2)} ${point.dy.toStringAsFixed(2)} ',
            );
          }
        }
      }

      // Close the path if it's closed
      if (path.getBounds().isEmpty == false) {
        final firstTangent = metric.getTangentForOffset(0);
        final lastTangent = metric.getTangentForOffset(length);
        if (firstTangent != null && lastTangent != null) {
          final firstPoint = firstTangent.position;
          final lastPoint = lastTangent.position;
          if ((firstPoint - lastPoint).distance < 1.0) {
            buffer.write('Z ');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  // Generate SVG content from rooms and background image
  Future<String> _generateSVG() async {
    // Use background image dimensions if available, otherwise calculate from rooms
    double width;
    double height;

    if (_imageBytes != null &&
        _backgroundImageWidth != null &&
        _backgroundImageHeight != null) {
      // Use exact background image dimensions
      width = _backgroundImageWidth!;
      height = _backgroundImageHeight!;
    } else {
      // Calculate overall bounds from rooms
      Rect? overallBounds;
      for (final room in rooms) {
        final bounds = room.path.getBounds();
        overallBounds = overallBounds == null
            ? bounds
            : overallBounds.expandToInclude(bounds);
      }

      if (overallBounds == null) {
        overallBounds = const Rect.fromLTWH(0, 0, 2000, 2000);
      }

      final padding = 50.0;
      width = overallBounds.width + (padding * 2);
      height = overallBounds.height + (padding * 2);
    }

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${width.toStringAsFixed(0)}" '
      'height="${height.toStringAsFixed(0)}" '
      'viewBox="0 0 $width $height">',
    );

    // Background - use image if available, otherwise use color
    if (_imageBytes != null) {
      // Convert image to base64
      final base64Image = base64Encode(_imageBytes!);

      // Determine image type
      String imageType = 'png';
      if (_imageBytes!.length >= 2) {
        if (_imageBytes![0] == 0xFF && _imageBytes![1] == 0xD8) {
          imageType = 'jpeg';
        } else if (_imageBytes![0] == 0x89 && _imageBytes![1] == 0x50) {
          imageType = 'png';
        }
      }

      // Add background image - positioned at (0,0) with exact dimensions
      buffer.writeln(
        '  <image x="0" y="0" width="$width" height="$height" '
        'href="data:image/$imageType;base64,$base64Image" '
        'preserveAspectRatio="none"/>',
      );
    } else {
      // Default background color
      buffer.writeln(
        '  <rect x="0" y="0" width="$width" height="$height" fill="#E3F2FD"/>',
      );
    }

    // Draw rooms (using original coordinates)
    for (final room in rooms) {
      final pathData = _pathToSvgPathData(room.path);
      final fillColorHex = _colorToHex(room.fillColor);
      // Use semi-transparent fill (opacity 0.3) so background image is visible
      buffer.writeln(
        '  <path d="$pathData" fill="$fillColorHex" fill-opacity="0.3" stroke="#424242" stroke-width="3"/>',
      );

      // Room name and area (as text)
      final bounds = room.path.getBounds();
      final center = bounds.center;
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy - 8}" '
        'text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000000">${room.name}</text>',
      );
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy + 12}" '
        'text-anchor="middle" font-family="Arial" font-size="14" fill="#000000">${room.area.toStringAsFixed(2)} m²</text>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  void _selectRoom(Offset localPos) {
    if (_drawingMode != DrawingMode.none)
      return; // Don't select rooms in drawing mode

    // Use local position directly (no transform needed when background image is used)
    for (final room in rooms.reversed) {
      if (room.path.contains(localPos)) {
        setState(() {
          selectedRoom = room;
        });
        return;
      }
    }
    setState(() {
      selectedRoom = null;
    });
  }

  void _createRoomFromRectangle(Rect rect) {
    if (rect.isEmpty || rect.width < 10 || rect.height < 10) return;

    _saveState();
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    final area = _calculateArea(path);
    final roomId = 'room_$_roomCounter';
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: _roomColor,
          name: roomName,
          area: area,
        ),
      );
      _roomCounter++;
      selectedRoom = rooms.last;
      _currentRectangle = null;
      _rectangleStart = null;
      _drawingMode = DrawingMode.none;
      _showDrawingMode = false;
      // Create controller for new room
      _roomControllers[roomId] = TextEditingController(text: roomName);
    });
  }

  void _handlePolygonClick(Offset position) {
    // Check if clicking near first point (close polygon)
    if (_polygonPoints.isNotEmpty) {
      final firstPoint = _polygonPoints[0];
      final distance = (position - firstPoint).distance;
      if (distance < 15.0 && _polygonPoints.length >= 2) {
        // Close polygon and create room
        _createRoomFromPolygon();
        return;
      }
    }

    setState(() {
      _polygonPoints.add(position);
      _polygonPreviewPosition = null; // Clear preview on new point
    });
  }

  void _addShapeToCanvas(Path Function() shapeCreator) {
    _saveState();
    final path = shapeCreator();
    final area = _calculateArea(path);
    final roomId = 'room_$_roomCounter';
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: _roomColor,
          name: roomName,
          area: area,
        ),
      );
      _roomCounter++;
      selectedRoom = rooms.last;
      _drawingMode = DrawingMode.none;
      _showDrawingMode = false;
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      // Create controller for new room
      _roomControllers[roomId] = TextEditingController(text: roomName);
    });
  }

  void _createRoomFromPolygon() {
    if (_polygonPoints.length < 3) {
      _showError('Polygon muss mindestens 3 Punkte haben');
      return;
    }

    final path = Path();
    path.moveTo(_polygonPoints[0].dx, _polygonPoints[0].dy);
    for (int i = 1; i < _polygonPoints.length; i++) {
      path.lineTo(_polygonPoints[i].dx, _polygonPoints[i].dy);
    }
    path.close();

    final area = _calculateArea(path);

    // Check if area is too small (minimum 0.5 m² to prevent accidental tiny polygons)
    if (area < 0.5) {
      _showError('Polygon ist zu klein (mindestens 0.5 m² erforderlich)');
      setState(() {
        _polygonPoints.clear();
        _polygonPreviewPosition = null;
      });
      return;
    }

    _saveState();
    final roomId = 'room_$_roomCounter';
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: _roomColor,
          name: roomName,
          area: area,
        ),
      );
      _roomCounter++;
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      _drawingMode = DrawingMode.none;
      _showDrawingMode = false;
      // Create controller for new room
      _roomControllers[roomId] = TextEditingController(text: roomName);
    });
  }

  void _cancelPolygon() {
    setState(() {
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      _drawingMode = DrawingMode.none;
    });
  }

  Future<void> _saveAndDownloadSVG() async {
    if (rooms.isEmpty) {
      _showError('No rooms to export');
      return;
    }

    try {
      final svgContent = await _generateSVG();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'floor_plan_$timestamp.svg';

      // Get verseId from LocalStorage, use default if not available
      final localStorage = sl<LocalStorage>();
      final verseId = localStorage.getSelectedVerseId() ?? 'default-verse-id';

      // Convert SVG string to XFile
      XFile svgFile;
      if (kIsWeb) {
        // For web, use XFile.fromData() to create from bytes directly
        final svgBytes = utf8.encode(svgContent);
        svgFile = XFile.fromData(
          svgBytes,
          mimeType: 'image/svg+xml',
          name: fileName,
        );
      } else {
        // For mobile/desktop, save to temp file first
        final directory = await getTemporaryDirectory();
        final filePath = path.join(directory.path, fileName);
        final file = File(filePath);
        await file.writeAsString(svgContent);
        svgFile = XFile(filePath, mimeType: 'image/svg+xml');
      }

      // Cancel any existing subscription
      await _uploadSubscription?.cancel();

      // Upload using UploadBloc
      final uploadBloc = sl<UploadBloc>();
      uploadBloc.add(
        UploadImageEvent(
          svgFile,
          verseId,
          'floor_plans', // folder path
        ),
      );

      // Listen to upload state and store subscription
      _uploadSubscription = uploadBloc.stream.listen((state) {
        if (state is UploadSuccess) {
          _showSuccess('SVG uploaded successfully');

          // Prepare rooms data for navigation
          final roomsData = rooms.map((room) {
            return {
              'id': room.id,
              'name': room.name,
              'color': room.fillColor.value.toString(),
              'area': room.area,
            };
          }).toList();

          // Navigate to building summary page
          if (mounted) {
            context.pushNamed(
              Routelists.buildingSummary,
              queryParameters: {
                if (widget.fromDashboard != null)
                  'fromDashboard': widget.fromDashboard!,
                'buildingId': widget.buildingId,
                'siteId': widget.siteId,
                if (widget.userName != null) 'userName': widget.userName!,
                if (widget.buildingAddress != null)
                  'buildingAddress': widget.buildingAddress!,
                if (widget.buildingName != null)
                  'buildingName': widget.buildingName!,
                if (widget.buildingSize != null)
                  'buildingSize': widget.buildingSize!,
                if (widget.numberOfRooms != null)
                  'numberOfRooms': widget.numberOfRooms.toString(),
                if (widget.constructionYear != null)
                  'constructionYear': widget.constructionYear!,
                if (widget.floorName != null) 'floorName': widget.floorName!,
                'floorPlanUrl': state.url,
                'rooms': Uri.encodeComponent(jsonEncode(roomsData)),
              },
            );
          }

          // Also call onComplete callback if provided (for backward compatibility)
          if (mounted && widget.onComplete != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                widget.onComplete!();
              }
            });
          }
        } else if (state is UploadFailure) {
          _showError('Upload failed: ${state.message}');
        }
      });
    } catch (e) {
      _showError('Error generating SVG: ${e.toString()}');
    }
  }

  void _deleteRoom(Room room) {
    _saveState();
    setState(() {
      rooms.remove(room);
      if (selectedRoom == room) {
        selectedRoom = null;
      }
      // Dispose and remove controller
      _roomControllers[room.id]?.dispose();
      _roomControllers.remove(room.id);
    });
  }

  // Check if a path is a rectangle (4 vertices forming a rectangle)
  bool _isRectangle(Path path) {
    try {
      final bounds = path.getBounds();
      if (bounds.isEmpty) return false;

      // Check if the path approximately matches a rectangle
      // by sampling points along the path
      final metrics = path.computeMetrics();
      if (metrics.isEmpty) return false;

      final metric = metrics.first;
      final sampleCount = 20;
      var matchesRect = true;

      for (int i = 0; i <= sampleCount; i++) {
        final t = i / sampleCount;
        final pos = metric.getTangentForOffset(metric.length * t)?.position;
        if (pos != null) {
          // Check if point is on the rectangle boundary (with some tolerance)
          final onLeft = (pos.dx - bounds.left).abs() < 2;
          final onRight = (pos.dx - bounds.right).abs() < 2;
          final onTop = (pos.dy - bounds.top).abs() < 2;
          final onBottom = (pos.dy - bounds.bottom).abs() < 2;

          if (!((onLeft || onRight) &&
                  (pos.dy >= bounds.top && pos.dy <= bounds.bottom)) &&
              !((onTop || onBottom) &&
                  (pos.dx >= bounds.left && pos.dx <= bounds.right))) {
            matchesRect = false;
            break;
          }
        }
      }

      return matchesRect;
    } catch (e) {
      return false;
    }
  }

  // Get resize handle index if position is near a corner of the selected room
  int? _getResizeHandle(Offset position, Rect bounds) {
    // Only allow resize for rectangles, not polygons
    if (selectedRoom != null && !_isRectangle(selectedRoom!.path)) {
      return null;
    }

    const handleSize = 15.0;
    final corners = [
      bounds.topLeft, // 0: topLeft
      bounds.topRight, // 1: topRight
      bounds.bottomRight, // 2: bottomRight
      bounds.bottomLeft, // 3: bottomLeft
    ];

    for (int i = 0; i < corners.length; i++) {
      if ((position - corners[i]).distance < handleSize) {
        return i;
      }
    }
    return null;
  }

  // Move selected room
  void _moveRoom(Offset delta) {
    if (selectedRoom == null) return;

    setState(() {
      selectedRoom!.path = selectedRoom!.path.shift(delta);
      // Update area after move
      selectedRoom!.area = _calculateArea(selectedRoom!.path);
    });
  }

  // Resize selected room
  void _resizeRoom(Offset delta, int handleIndex, Rect startBounds) {
    if (selectedRoom == null) return;

    final bounds = startBounds;
    double sx = 1, sy = 1;
    Offset anchor = bounds.center;

    // Calculate scale based on handle
    switch (handleIndex) {
      case 0: // topLeft
        sx = (bounds.width - delta.dx) / bounds.width;
        sy = (bounds.height - delta.dy) / bounds.height;
        anchor = bounds.bottomRight;
        break;
      case 1: // topRight
        sx = (bounds.width + delta.dx) / bounds.width;
        sy = (bounds.height - delta.dy) / bounds.height;
        anchor = bounds.bottomLeft;
        break;
      case 2: // bottomRight
        sx = (bounds.width + delta.dx) / bounds.width;
        sy = (bounds.height + delta.dy) / bounds.height;
        anchor = bounds.topLeft;
        break;
      case 3: // bottomLeft
        sx = (bounds.width - delta.dx) / bounds.width;
        sy = (bounds.height + delta.dy) / bounds.height;
        anchor = bounds.topRight;
        break;
    }

    // Minimum size constraint
    if (sx > 0.2 && sy > 0.2) {
      // Calculate new bounds based on anchor and scale
      final newWidth = bounds.width * sx;
      final newHeight = bounds.height * sy;

      // Calculate new corner positions based on anchor (which is the opposite corner)
      Rect newBounds;
      switch (handleIndex) {
        case 0: // topLeft - anchor is bottomRight
          newBounds = Rect.fromLTWH(
            anchor.dx - newWidth,
            anchor.dy - newHeight,
            newWidth,
            newHeight,
          );
          break;
        case 1: // topRight - anchor is bottomLeft
          newBounds = Rect.fromLTWH(
            anchor.dx,
            anchor.dy - newHeight,
            newWidth,
            newHeight,
          );
          break;
        case 2: // bottomRight - anchor is topLeft
          newBounds = Rect.fromLTWH(anchor.dx, anchor.dy, newWidth, newHeight);
          break;
        case 3: // bottomLeft - anchor is topRight
          newBounds = Rect.fromLTWH(
            anchor.dx - newWidth,
            anchor.dy,
            newWidth,
            newHeight,
          );
          break;
        default:
          newBounds = bounds;
      }

      // Create new path from resized bounds
      final newPath = Path()
        ..moveTo(newBounds.left, newBounds.top)
        ..lineTo(newBounds.right, newBounds.top)
        ..lineTo(newBounds.right, newBounds.bottom)
        ..lineTo(newBounds.left, newBounds.bottom)
        ..close();

      setState(() {
        selectedRoom!.path = newPath;
        selectedRoom!.area = _calculateArea(newPath);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PageHeaderRow(
          title: 'Grundriss aktivieren',
          showBackButton: true,
          onBack: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 20),
        // Rectangle mode toggle and color selector (show when image is loaded)
        if (_imageBytes != null && _showDrawingMode)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Drawing mode instructions
                if (_showDrawingMode) ...[
                  if (_drawingMode == DrawingMode.rectangle)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Ziehen Sie auf dem Bild, um Rechtecke zu erstellen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (_drawingMode == DrawingMode.polygon)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Klicken Sie auf Punkte, um ein Polygon zu erstellen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        // Upload button (show if no rooms and no image)
        if (rooms.isEmpty && _imageBytes == null)
          InkWell(
            onTap: _uploadFloorPlan,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                borderRadius: BorderRadius.circular(0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Grundriss hochladen',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Re-upload button (show if image or rooms exist)
        // if ((rooms.isNotEmpty || _imageBytes != null))
        //   Padding(
        //     padding: const EdgeInsets.only(bottom: 8),
        //     child: InkWell(
        //       onTap: _uploadFloorPlan,
        //       child: Container(
        //         padding: const EdgeInsets.symmetric(
        //           horizontal: 12,
        //           vertical: 8,
        //         ),
        //         decoration: BoxDecoration(
        //           border: Border.all(
        //             color: Colors.grey[300]!,
        //             style: BorderStyle.solid,
        //             width: 1,
        //           ),
        //           borderRadius: BorderRadius.circular(6),
        //         ),
        //         child: Row(
        //           mainAxisSize: MainAxisSize.min,
        //           children: [
        //             Icon(Icons.refresh, color: Colors.grey[700], size: 16),
        //             const SizedBox(width: 4),
        //             Text(
        //               'Neu hochladen',
        //               style: TextStyle(color: Colors.grey[700], fontSize: 12),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ),

        // const SizedBox(height: 16),
        // // Floor plan display area (expanded height)
        DottedBorderContainer(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 250, // Reduced height to prevent overflow
              minHeight: 250,
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: (rooms.isEmpty && _imageBytes == null)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Kein Grundriss geladen',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTapDown: (details) {
                            // Convert touch coordinates to image coordinates
                            final scaledPosition = Offset(
                              details.localPosition.dx / _currentScaleX,
                              details.localPosition.dy / _currentScaleY,
                            );
                            // Handle immediate selection on click (not drag)
                            if (_drawingMode == DrawingMode.none) {
                              _selectRoom(scaledPosition);
                            } else if (_drawingMode == DrawingMode.polygon) {
                              _handlePolygonClick(scaledPosition);
                            }
                          },
                          onPanStart: (details) {
                            // Convert touch coordinates to image coordinates
                            final scaledPosition = Offset(
                              details.localPosition.dx / _currentScaleX,
                              details.localPosition.dy / _currentScaleY,
                            );
                            if (_drawingMode == DrawingMode.rectangle) {
                              setState(() {
                                _rectangleStart = scaledPosition;
                                _currentRectangle = Rect.fromPoints(
                                  scaledPosition,
                                  scaledPosition,
                                );
                              });
                            } else if (_drawingMode == DrawingMode.polygon) {
                              // Polygon points are handled in onTapDown
                              setState(() {
                                _polygonPreviewPosition = scaledPosition;
                              });
                            } else {
                              // Select the room at this position (handles selection and deselection)
                              // Note: onTapDown may have already selected, but we do it here too for drag cases
                              _selectRoom(scaledPosition);

                              // Store which room was selected after selection (for move/resize tracking)
                              _roomAtPanStart = selectedRoom;

                              // Save state before move/resize operation
                              if (selectedRoom != null &&
                                  !_isMoving &&
                                  !_isResizing) {
                                _saveState();
                              }

                              // Store initial position for move/resize (in image coordinates)
                              _dragStart = scaledPosition;

                              // If we have a selected room, check if we clicked on resize handle
                              if (selectedRoom != null) {
                                final bounds = selectedRoom!.path.getBounds();
                                final handleIndex = _getResizeHandle(
                                  scaledPosition,
                                  bounds,
                                );

                                if (handleIndex != null) {
                                  // We'll start resize on drag
                                  _resizeHandle = handleIndex;
                                  _startBounds = bounds;
                                } else {
                                  // We'll start move on drag (if clicking inside the room)
                                  _startBounds = bounds;
                                }
                              }
                            }
                          },
                          onPanUpdate: (details) {
                            // Convert touch coordinates to image coordinates
                            final scaledPosition = Offset(
                              details.localPosition.dx / _currentScaleX,
                              details.localPosition.dy / _currentScaleY,
                            );
                            if (_drawingMode == DrawingMode.rectangle &&
                                _rectangleStart != null) {
                              setState(() {
                                _currentRectangle = Rect.fromPoints(
                                  _rectangleStart!,
                                  scaledPosition,
                                );
                              });
                            } else if (_drawingMode == DrawingMode.polygon) {
                              // Update preview position
                              setState(() {
                                _polygonPreviewPosition = scaledPosition;
                              });
                            } else if (_roomAtPanStart != null &&
                                _dragStart != null &&
                                selectedRoom == _roomAtPanStart) {
                              // Only move/resize if we're still on the same room we started with
                              final delta = scaledPosition - _dragStart!;

                              // Check if we moved enough to start an operation (threshold to distinguish click from drag)
                              if (delta.distance > 5.0) {
                                if (!_isMoving && !_isResizing) {
                                  // Determine if we should move or resize
                                  if (_resizeHandle != -1 &&
                                      _startBounds != null) {
                                    // Start resize
                                    setState(() {
                                      _isResizing = true;
                                    });
                                  } else if (_startBounds != null &&
                                      _startBounds!.contains(_dragStart!)) {
                                    // Start move
                                    setState(() {
                                      _isMoving = true;
                                    });
                                  }
                                }

                                // Perform the operation
                                if (_isResizing &&
                                    _resizeHandle != -1 &&
                                    _startBounds != null) {
                                  // Resize room
                                  _resizeRoom(
                                    delta,
                                    _resizeHandle,
                                    _startBounds!,
                                  );
                                  setState(() {
                                    _dragStart = details.localPosition;
                                    _startBounds = selectedRoom?.path
                                        .getBounds();
                                  });
                                } else if (_isMoving) {
                                  // Move room
                                  _moveRoom(delta);
                                  setState(() {
                                    _dragStart = details.localPosition;
                                  });
                                }
                              }
                            }
                          },
                          onPanEnd: (details) {
                            if (_drawingMode == DrawingMode.rectangle &&
                                _currentRectangle != null) {
                              _createRoomFromRectangle(_currentRectangle!);
                            }
                            // Reset move/resize state
                            setState(() {
                              _isMoving = false;
                              _isResizing = false;
                              _dragStart = null;
                              _startBounds = null;
                              _resizeHandle = -1;
                              _roomAtPanStart = null;
                            });
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // If we have background image dimensions, use them
                              if (_imageBytes != null &&
                                  _backgroundImageWidth != null &&
                                  _backgroundImageHeight != null) {
                                // Calculate scale to fit within constraints
                                final imageAspectRatio =
                                    _backgroundImageWidth! /
                                    _backgroundImageHeight!;
                                final displayAspectRatio =
                                    constraints.maxWidth /
                                    constraints.maxHeight;

                                double displayWidth, displayHeight;
                                double scaleX = 1.0, scaleY = 1.0;

                                if (imageAspectRatio > displayAspectRatio) {
                                  displayWidth = constraints.maxWidth;
                                  displayHeight =
                                      constraints.maxWidth / imageAspectRatio;
                                  scaleX =
                                      displayWidth / _backgroundImageWidth!;
                                  scaleY = scaleX;
                                } else {
                                  displayHeight = constraints.maxHeight;
                                  displayWidth =
                                      constraints.maxHeight * imageAspectRatio;
                                  scaleY =
                                      displayHeight / _backgroundImageHeight!;
                                  scaleX = scaleY;
                                }

                                // Store scale in state for touch coordinate conversion
                                _currentScaleX = scaleX;
                                _currentScaleY = scaleY;

                                return SizedBox(
                                  width: displayWidth,
                                  height: displayHeight,
                                  child: Stack(
                                    children: [
                                      // Show image background
                                      Positioned.fill(
                                        child: Image.memory(
                                          _imageBytes!,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.topLeft,
                                        ),
                                      ),
                                      // Show rooms overlay
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _FloorPlanPainter(
                                            rooms: rooms,
                                            selectedRoom: selectedRoom,
                                            imageBackground: true,
                                            currentRectangle: _currentRectangle,
                                            rectangleColor: _roomColor,
                                            polygonPoints: _polygonPoints,
                                            polygonPreviewPosition:
                                                _polygonPreviewPosition,
                                            polygonColor: _roomColor,
                                            scaleX: scaleX,
                                            scaleY: scaleY,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // No background image - use full available space
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: CustomPaint(
                                    painter: _FloorPlanPainter(
                                      rooms: rooms,
                                      selectedRoom: selectedRoom,
                                      imageBackground: false,
                                      currentRectangle: _currentRectangle,
                                      rectangleColor: _roomColor,
                                      polygonPoints: _polygonPoints,
                                      polygonPreviewPosition:
                                          _polygonPreviewPosition,
                                      polygonColor: _roomColor,
                                      scaleX: 1.0,
                                      scaleY: 1.0,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Polygon completion buttons (show only if in polygon mode with points)
        if (_drawingMode == DrawingMode.polygon && _polygonPoints.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_polygonPoints.length >= 3)
                  ElevatedButton.icon(
                    onPressed: _createRoomFromPolygon,
                    icon: const Icon(Icons.check),
                    label: const Text('Polygon abschließen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _cancelPolygon,
                  icon: const Icon(Icons.close),
                  label: const Text('Abbrechen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(),
            // Drawing mode buttons (shown only after "Add room" is clicked)
            if (_showDrawingMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shape buttons
                    _shapeOptionButton(
                      icon: 'assets/images/Pen.svg',
                      label: "Polygon",
                      onTap: () {
                        setState(() {
                          _selectedShapeTool = _ShapeTool.polygon;
                          if (_drawingMode == DrawingMode.polygon) {
                            _drawingMode = DrawingMode.none;
                            _polygonPoints.clear();
                            _polygonPreviewPosition = null;
                          } else {
                            _drawingMode = DrawingMode.polygon;
                            _rectangleStart = null;
                            _currentRectangle = null;
                          }
                          selectedRoom = null;
                        });
                      },
                      isSelected:
                          _drawingMode == DrawingMode.polygon ||
                          _selectedShapeTool == _ShapeTool.polygon,
                    ),
                    _shapeOptionButton(
                      icon: 'assets/images/Rectangle.svg',
                      label: "Rectangle",
                      onTap: () {
                        setState(() {
                          _selectedShapeTool = _ShapeTool.rectangle;
                          if (_drawingMode == DrawingMode.rectangle) {
                            _drawingMode = DrawingMode.none;
                          } else {
                            _drawingMode = DrawingMode.rectangle;
                            _polygonPoints.clear();
                            _polygonPreviewPosition = null;
                          }
                          _rectangleStart = null;
                          _currentRectangle = null;
                          selectedRoom = null;
                        });
                      },
                      isSelected:
                          _drawingMode == DrawingMode.rectangle ||
                          _selectedShapeTool == _ShapeTool.rectangle,
                    ),
                    _shapeOptionButton(
                      icon: 'assets/images/Triangle.svg',
                      label: "Triangle",
                      onTap: () {
                        setState(() {
                          _selectedShapeTool = _ShapeTool.triangle;
                          _drawingMode = DrawingMode.none;
                          _polygonPoints.clear();
                          _polygonPreviewPosition = null;
                        });
                        _addShapeToCanvas(
                          () => createTriangle(const Offset(200, 200)),
                        );
                      },
                      isSelected: _selectedShapeTool == _ShapeTool.triangle,
                    ),
                    _shapeOptionButton(
                      icon: 'assets/images/Ellipse.svg',
                      label: "Circle",
                      onTap: () {
                        setState(() {
                          _selectedShapeTool = _ShapeTool.circle;
                          _drawingMode = DrawingMode.none;
                          _polygonPoints.clear();
                          _polygonPreviewPosition = null;
                        });
                        _addShapeToCanvas(
                          () =>
                              createCircle(const Offset(200, 200), radius: 50),
                        );
                      },
                      isSelected: _selectedShapeTool == _ShapeTool.circle,
                    ),
                  ],
                ),
              ),
            ],
            // Undo/Redo buttons
            if (_showDrawingMode)
              Container(
                margin: const EdgeInsets.only(bottom: 16, left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(color: Colors.grey.shade100),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _canUndo ? _undo : null,
                      child: SvgPicture.asset(
                        'assets/images/Undo.svg',
                        color: _canUndo ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _canRedo ? _redo : null,
                      child: SvgPicture.asset(
                        'assets/images/Redo.svg',
                        color: _canRedo ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

            // const Spacer(),
            // // Room color selector (shown only when drawing mode is active)
            // if (_showDrawingMode)
            //   Row(
            //     children: [
            //       const Text(
            //         'Farbe:',
            //         style: TextStyle(
            //           fontSize: 14,
            //           color: Colors.grey,
            //         ),
            //       ),
            //       const SizedBox(width: 8),
            //       ...colorPalette.map((color) {
            //         final isSelected = _roomColor == color;
            //         return GestureDetector(
            //           onTap: () {
            //             setState(() {
            //               _roomColor = color;
            //             });
            //           },
            //           child: Container(
            //             margin: const EdgeInsets.only(left: 6),
            //             width: 28,
            //             height: 28,
            //             decoration: BoxDecoration(
            //               color: color,
            //               shape: BoxShape.circle,
            //               border: Border.all(
            //                 color: isSelected
            //                     ? Colors.black
            //                     : Colors.grey[400]!,
            //                 width: isSelected ? 2 : 1,
            //               ),
            //             ),
            //           ),
            //         );
            //       }).toList(),
            //     ],
            //   ),
          ],
        ),
        const SizedBox(height: 16),

        // List of all rooms with TextField and color selection in one row
        if (rooms.isNotEmpty)
          ...rooms.map((room) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(0),
                border: Border.all(
                  color: selectedRoom == room ? Colors.blue : Colors.grey[300]!,
                  width: selectedRoom == room ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // TextField for room name
                  Expanded(
                    child: TextField(
                      key: ValueKey(room.id),
                      controller: _roomControllers[room.id] ??=
                          TextEditingController(text: room.name),
                      decoration: InputDecoration(
                        hintText: 'Raumname / Label',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          room.name = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Color palette
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: colorPalette.map((color) {
                      final isSelected = room.fillColor == color;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            room.fillColor = color;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: color,
                            // shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[400]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.clear, size: 12, color: Colors.black)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    tooltip: 'Löschen',
                    onPressed: () => _deleteRoom(room),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
        // Add room button (always visible)
        InkWell(
          onTap: _showCreateRoomDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon(Icons.add_box_outlined, color: Colors.grey[700], size: 20),
                // const SizedBox(width: 8),
                Text(
                  '+ Raum anlegen',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        // Skip step link
        InkWell(
          onTap: widget.onSkip,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Schritt überspringen',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          ),
        ),
        // Save and Next button
        Center(
          child: PrimaryOutlineButton(
            label: _imageBytes != null ? 'Speichern & Weiter' : 'Das passt so',

            width: 260,
            onPressed: _imageBytes != null
                ? _saveAndDownloadSVG
                : widget.onComplete,
          ),
        ),

        // ElevatedButton(
        //   onPressed: _imageBytes != null
        //       ? _saveAndDownloadSVG
        //       : widget.onComplete,
        //   style: ElevatedButton.styleFrom(
        //     padding: const EdgeInsets.symmetric(vertical: 14),
        //     backgroundColor: Colors.blue[700],
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(8),
        //     ),
        //   ),
        //   child: Text(
        //     _imageBytes != null ? 'Speichern & Weiter' : 'Das passt so',
        //     style: const TextStyle(
        //       color: Colors.white,
        //       fontSize: 16,
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        // ),
        const SizedBox(height: 8), // Reduced from 16 to 8
      ],
    );
  }

  void _showCreateRoomDialog() {
    setState(() {
      _showDrawingMode = true;
      _drawingMode = DrawingMode.none; // Don't set a mode yet, let user choose
    });
  }

  Widget _shapeOptionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(0),
        ),
        child: SvgPicture.asset(
          icon,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  /* =======================
     UNDO/REDO
  ======================= */

  void _saveState() {
    // Remove any states after current index (when user does new action after undo)
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    // Create new state snapshot
    final state = _FloorPlanState(
      rooms: rooms
          .map(
            (room) => Room(
              id: room.id,
              path: Path.from(room.path),
              fillColor: room.fillColor,
              name: room.name,
              area: room.area,
            ),
          )
          .toList(),
      roomCounter: _roomCounter,
    );

    // Add to history
    _history.add(state);
    _historyIndex = _history.length - 1;

    // Limit history size
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _restoreState(_FloorPlanState state) {
    // Dispose all existing controllers
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();

    // Restore rooms
    rooms.clear();
    rooms.addAll(
      state.rooms.map(
        (room) => Room(
          id: room.id,
          path: Path.from(room.path),
          fillColor: room.fillColor,
          name: room.name,
          area: room.area,
        ),
      ),
    );

    // Restore controllers
    for (final room in rooms) {
      _roomControllers[room.id] = TextEditingController(text: room.name);
    }

    _roomCounter = state.roomCounter;
    selectedRoom = null;
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _restoreState(_history[_historyIndex]);
      setState(() {});
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _restoreState(_history[_historyIndex]);
      setState(() {});
    }
  }

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex < _history.length - 1;

  @override
  void dispose() {
    // Cancel upload subscription
    _uploadSubscription?.cancel();
    // Dispose all room controllers
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();
    super.dispose();
  }
}

class _PathCommand {
  final String command;
  final List<double> coordinates;

  _PathCommand(this.command, this.coordinates);
}

class _FloorPlanPainter extends CustomPainter {
  final List<Room> rooms;
  final Room? selectedRoom;
  final bool imageBackground;
  final Rect? currentRectangle;
  final Color rectangleColor;
  final List<Offset> polygonPoints;
  final Offset? polygonPreviewPosition;
  final Color polygonColor;
  final double scaleX;
  final double scaleY;

  _FloorPlanPainter({
    required this.rooms,
    this.selectedRoom,
    this.imageBackground = false,
    this.currentRectangle,
    this.rectangleColor = const Color(0xFFFFB74D),
    this.polygonPoints = const [],
    this.polygonPreviewPosition,
    this.polygonColor = const Color(0xFFFFB74D),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
  });

  // Check if a path is a rectangle (4 vertices forming a rectangle)
  bool _isRectangle(Path path) {
    try {
      final bounds = path.getBounds();
      if (bounds.isEmpty) return false;

      // Check if the path approximately matches a rectangle
      // by sampling points along the path
      final metrics = path.computeMetrics();
      if (metrics.isEmpty) return false;

      final metric = metrics.first;
      final sampleCount = 20;
      var matchesRect = true;

      for (int i = 0; i <= sampleCount; i++) {
        final t = i / sampleCount;
        final pos = metric.getTangentForOffset(metric.length * t)?.position;
        if (pos != null) {
          // Check if point is on the rectangle boundary (with some tolerance)
          final onLeft = (pos.dx - bounds.left).abs() < 2;
          final onRight = (pos.dx - bounds.right).abs() < 2;
          final onTop = (pos.dy - bounds.top).abs() < 2;
          final onBottom = (pos.dy - bounds.bottom).abs() < 2;

          if (!((onLeft || onRight) &&
                  (pos.dy >= bounds.top && pos.dy <= bounds.bottom)) &&
              !((onTop || onBottom) &&
                  (pos.dx >= bounds.left && pos.dx <= bounds.right))) {
            matchesRect = false;
            break;
          }
        }
      }

      return matchesRect;
    } catch (e) {
      return false;
    }
  }

  // Extract vertices from a polygon path by sampling and finding corner points
  List<Offset> _extractVertices(Path path) {
    final vertices = <Offset>[];
    try {
      final metrics = path.computeMetrics();
      if (metrics.isEmpty) return vertices;

      final metric = metrics.first;
      final length = metric.length;
      if (length == 0) return vertices;

      // Sample points along the path
      final sampleStep = math.max(
        length / 100,
        2.0,
      ); // Sample every 2 pixels or 100 samples
      final samples = <Offset>[];

      for (double distance = 0; distance <= length; distance += sampleStep) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          samples.add(tangent.position);
        }
      }

      if (samples.isEmpty) return vertices;

      // Find corner points by detecting significant direction changes
      vertices.add(samples.first); // Always include the first point

      for (int i = 1; i < samples.length - 1; i++) {
        final prev = samples[i - 1];
        final curr = samples[i];
        final next = samples[i + 1];

        // Calculate direction vectors
        final dir1 = curr - prev;
        final dir2 = next - curr;
        final dist1 = dir1.distance;
        final dist2 = dir2.distance;

        if (dist1 < 0.1 || dist2 < 0.1) continue; // Skip if too close

        // Normalize vectors
        final dir1Norm = Offset(dir1.dx / dist1, dir1.dy / dist1);
        final dir2Norm = Offset(dir2.dx / dist2, dir2.dy / dist2);

        // Calculate angle change (dot product of normalized vectors)
        final dotProduct =
            dir1Norm.dx * dir2Norm.dx + dir1Norm.dy * dir2Norm.dy;
        final angle = math.acos(dotProduct.clamp(-1.0, 1.0));

        // If angle change is significant (more than ~15 degrees), it's a corner
        if (angle > 0.26) {
          // ~15 degrees in radians
          // Check if this point is far enough from the last vertex
          if (vertices.isEmpty || (curr - vertices.last).distance > 5.0) {
            vertices.add(curr);
          }
        }
      }

      // Always include the last point if it's different from the first
      final lastPoint = samples.last;
      if (vertices.isEmpty || (lastPoint - vertices.first).distance > 5.0) {
        if (vertices.isEmpty || (lastPoint - vertices.last).distance > 5.0) {
          vertices.add(lastPoint);
        }
      }

      return vertices;
    } catch (e) {
      return vertices;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Apply scale transform to match image scaling
    // Only scale if scale values are valid (greater than 0)
    if (scaleX > 0 && scaleY > 0) {
      canvas.save();
      canvas.scale(scaleX, scaleY);
    }

    // Draw current rectangle preview (if in rectangle mode)
    if (currentRectangle != null) {
      final previewPaint = Paint()
        ..color = rectangleColor.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = rectangleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(currentRectangle!, previewPaint);
      canvas.drawRect(currentRectangle!, borderPaint);
    }

    // Draw polygon preview (if in polygon mode)
    if (polygonPoints.isNotEmpty) {
      final previewPath = Path();
      previewPath.moveTo(polygonPoints[0].dx, polygonPoints[0].dy);
      for (int i = 1; i < polygonPoints.length; i++) {
        previewPath.lineTo(polygonPoints[i].dx, polygonPoints[i].dy);
      }

      // Draw line to preview position if available
      if (polygonPreviewPosition != null) {
        previewPath.lineTo(
          polygonPreviewPosition!.dx,
          polygonPreviewPosition!.dy,
        );

        // Draw line back to first point if we have at least 2 points
        if (polygonPoints.length >= 2) {
          previewPath.lineTo(polygonPoints[0].dx, polygonPoints[0].dy);
        }
      }

      // Draw polygon preview fill and stroke
      final polygonPreviewPaint = Paint()
        ..color = polygonColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      final polygonBorderPaint = Paint()
        ..color = polygonColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawPath(previewPath, polygonPreviewPaint);
      canvas.drawPath(previewPath, polygonBorderPaint);

      // Draw vertices as circles
      final vertexPaint = Paint()
        ..color = polygonColor
        ..style = PaintingStyle.fill;
      final vertexBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Check if cursor is near any vertex to highlight it
      int? hoveredVertexIndex;
      if (polygonPreviewPosition != null) {
        const hoverDistance = 20.0; // Distance threshold for hover detection
        for (int i = 0; i < polygonPoints.length; i++) {
          if ((polygonPreviewPosition! - polygonPoints[i]).distance <
              hoverDistance) {
            hoveredVertexIndex = i;
            break;
          }
        }
      }

      // Draw all vertices, highlighting the hovered one
      for (int i = 0; i < polygonPoints.length; i++) {
        final point = polygonPoints[i];
        final isHovered = hoveredVertexIndex == i;
        final isFirst = i == 0 && polygonPoints.length >= 2;

        // Use different colors for different states
        Paint currentVertexPaint;
        Paint currentVertexBorderPaint;
        double vertexSize;

        if (isHovered) {
          // Highlight hovered vertex in blue
          currentVertexPaint = Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.fill;
          currentVertexBorderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
          vertexSize = 10.0;
        } else if (isFirst) {
          // First point is green (to show where to close)
          currentVertexPaint = Paint()
            ..color = Colors.green
            ..style = PaintingStyle.fill;
          currentVertexBorderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          vertexSize = 8.0;
        } else {
          // Regular vertices
          currentVertexPaint = vertexPaint;
          currentVertexBorderPaint = vertexBorderPaint;
          vertexSize = 6.0;
        }

        canvas.drawCircle(point, vertexSize, currentVertexPaint);
        canvas.drawCircle(point, vertexSize, currentVertexBorderPaint);
      }
    }

    // Draw rooms (using original coordinates - no scaling needed)
    for (final room in rooms) {
      // Room fill (semi-transparent if image background)
      final fillPaint = Paint()
        ..color = imageBackground
            ? room.fillColor.withOpacity(0.5)
            : room.fillColor
        ..style = PaintingStyle.fill;

      canvas.drawPath(room.path, fillPaint);

      // Only draw border if room is selected
      if (selectedRoom == room) {
        final borderPaint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawPath(room.path, borderPaint);
      }

      // Get bounds once for both resize handles and text
      final bounds = room.path.getBounds();
      final center = bounds.center;

      // Draw resize handles if this room is selected and it's a rectangle
      if (selectedRoom == room && _isRectangle(room.path)) {
        final corners = [
          bounds.topLeft, // 0: topLeft
          bounds.topRight, // 1: topRight
          bounds.bottomRight, // 2: bottomRight
          bounds.bottomLeft, // 3: bottomLeft
        ];

        final handlePaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;
        final handleBorderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        const handleSize = 8.0;
        for (final corner in corners) {
          canvas.drawCircle(corner, handleSize, handlePaint);
          canvas.drawCircle(corner, handleSize, handleBorderPaint);
        }
      }

      // Draw vertices/joints if this room is selected and it's a polygon (not a rectangle)
      if (selectedRoom == room && !_isRectangle(room.path)) {
        final vertices = _extractVertices(room.path);

        final vertexPaint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill;
        final vertexBorderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        const vertexSize = 6.0;
        for (final vertex in vertices) {
          canvas.drawCircle(vertex, vertexSize, vertexPaint);
          canvas.drawCircle(vertex, vertexSize, vertexBorderPaint);
        }
      }

      // Draw room name and area

      // Room name
      final namePainter = TextPainter(
        text: TextSpan(
          text: room.name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(
        canvas,
        center - Offset(namePainter.width / 2, namePainter.height / 2 - 8),
      );

      // Room area
      // final areaPainter = TextPainter(
      //   text: TextSpan(
      //     text: '${room.area.toStringAsFixed(2)} m²',
      //     style: const TextStyle(
      //       color: Colors.black87,
      //       fontSize: 12,
      //       fontWeight: FontWeight.w500,
      //     ),
      //   ),
      //   textDirection: TextDirection.ltr,
      // );

      // areaPainter.layout();
      // areaPainter.paint(
      //   canvas,
      //   center - Offset(areaPainter.width / 2, areaPainter.height / 2 + 8),
      // );
    }

    // Restore canvas after scaling (only if we saved it)
    if (scaleX > 0 && scaleY > 0) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FloorPlanPainter oldDelegate) {
    return rooms != oldDelegate.rooms ||
        selectedRoom != oldDelegate.selectedRoom ||
        imageBackground != oldDelegate.imageBackground ||
        currentRectangle != oldDelegate.currentRectangle ||
        rectangleColor != oldDelegate.rectangleColor ||
        polygonPoints != oldDelegate.polygonPoints ||
        polygonPreviewPosition != oldDelegate.polygonPreviewPosition ||
        scaleX != oldDelegate.scaleX ||
        scaleY != oldDelegate.scaleY;
  }
}
