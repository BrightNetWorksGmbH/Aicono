// Floor plan editor widgets extracted from dashboard_main_content.
// Depends on: FloorPlan (Room, Door), DottedBorderContainer, shared components, Loxone dialog.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode, base64Encode;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/features/FloorPlan/presentation/pages/floor_plan_backup.dart'
    show Room, Door, FloorPainter;
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart'
    show DottedBorderContainer;
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';

import 'dashboard_shared_components.dart';
import 'loxone_room_selection_dialog.dart';
// Floor Plan Editor Wrapper Widget - Shows only canvas and room list
class FloorPlanEditorWrapper extends StatefulWidget {
  final String floorId;
  final String floorName;
  final String? initialFloorPlanUrl;
  final Function(String?) onSave;
  final VoidCallback onCancel;
  final GlobalKey<SimplifiedFloorPlanEditorState>? editorKey;

  const FloorPlanEditorWrapper({
    required this.floorId,
    required this.floorName,
    this.initialFloorPlanUrl,
    required this.onSave,
    required this.onCancel,
    this.editorKey,
  });

  @override
  State<FloorPlanEditorWrapper> createState() => _FloorPlanEditorWrapperState();
}

class _FloorPlanEditorWrapperState extends State<FloorPlanEditorWrapper> {
  @override
  Widget build(BuildContext context) {
    // Use the simplified floor plan editor that shows only canvas and room list
    return SimplifiedFloorPlanEditor(
      key: widget.editorKey,
      floorId: widget.floorId,
      initialFloorPlanUrl: widget.initialFloorPlanUrl,
      onSave: widget.onSave,
      onCancel: widget.onCancel,
    );
  }
}

// Simplified Floor Plan Editor - Shows only canvas (with dotted border) and room list
// This extracts the canvas and room list UI from FloorPlanBackupPage
class SimplifiedFloorPlanEditor extends StatefulWidget {
  final String floorId;
  final String? initialFloorPlanUrl;
  final Function(String?) onSave;
  final VoidCallback onCancel;

  const SimplifiedFloorPlanEditor({
    super.key,
    required this.floorId,
    this.initialFloorPlanUrl,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<SimplifiedFloorPlanEditor> createState() =>
      SimplifiedFloorPlanEditorState();
}

// Reuse enums and classes from floor_plan_backup.dart
enum DrawingMode { none, rectangle, polygon }

enum _ShapeTool { polygon, rectangle, triangle, circle }

enum ResizeHandle { topLeft, topRight, bottomLeft, bottomRight }

/// State snapshot for undo/redo functionality
class _FloorPlanState {
  final List<Room> rooms;
  final List<Door> doors;
  final int roomCounter;

  _FloorPlanState({
    required this.rooms,
    required this.doors,
    required this.roomCounter,
  });

  // Deep copy constructor
  _FloorPlanState copy() {
    return _FloorPlanState(
      rooms: rooms
          .map(
            (room) => Room(
              id: room.id,
              path: Path.from(room.path),
              doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
              fillColor: room.fillColor,
              name: room.name,
            ),
          )
          .toList(),
      doors: doors
          .map(
            (door) => Door(
              id: door.id,
              path: Path.from(door.path),
              rotation: door.rotation,
              roomId: door.roomId,
              edge: door.edge,
            ),
          )
          .toList(),
      roomCounter: roomCounter,
    );
  }
}

class SimplifiedFloorPlanEditorState extends State<SimplifiedFloorPlanEditor> {
  // Floor plan state - reuse from FloorPlanBackupPage
  final List<Room> rooms = [];
  final List<Door> doors = [];
  Room? selectedRoom;
  Door? selectedDoor;

  Path? drawingPath;
  bool pencilMode = false;
  bool doorPlacementMode = false;
  bool polygonMode = false;
  _ShapeTool? _selectedShapeTool;

  // Drawing mode for rectangle/polygon creation
  DrawingMode _drawingMode = DrawingMode.none;

  // Rectangle creation state
  Offset? _rectangleStart;
  Rect? _currentRectangle;

  List<Offset> _polygonPoints = [];
  Offset? _polygonPreviewPosition;

  Offset? lastPanPosition;
  ResizeHandle? activeHandle;
  Rect? startBounds;

  Color? selectedColor;
  int _roomCounter = 1;
  Size _canvasSize = const Size(4000, 4000);
  final TransformationController _transformationController =
      TransformationController();
  Size? _viewportSize;

  // Background image from SVG URL
  Uint8List? _backgroundImageBytes;
  double? _backgroundImageWidth;
  double? _backgroundImageHeight;

  // Undo/Redo history
  final List<_FloorPlanState> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

  bool _showShapeOptions = false;
  final Map<String, TextEditingController> _roomControllers = {};

  // Backend room tracking: maps room.id to backend room ID
  final Map<String, String> _backendRoomIds = {};
  final Map<String, String?> _loxoneRoomIds =
      {}; // Maps room.id to loxone_room_id
  final DioClient _dioClient = sl<DioClient>();
  bool _isLoadingBackendRooms = false;
  String? _buildingId; // Store buildingId from floor data

  // Color palette
  static const List<Color> colorPalette = [
    Color(0xFFFFB74D), // Light orange
    Color(0xFFE57373), // Red
    Color(0xFFBA68C8), // Purple
    Color(0xFF64B5F6), // Blue
    Color(0xFF81C784), // Green
  ];

  @override
  void initState() {
    super.initState();
    _saveState();
    if (widget.initialFloorPlanUrl != null &&
        widget.initialFloorPlanUrl!.isNotEmpty) {
      _loadFloorPlanFromUrl();
    }
    // Fetch rooms from backend
    _fetchRoomsFromBackend();
  }

  // Public method to generate SVG - can be called from parent
  Future<String> generateSVG() async {
    // Use background image dimensions if available, otherwise calculate from rooms
    double width;
    double height;

    if (_backgroundImageBytes != null &&
        _backgroundImageWidth != null &&
        _backgroundImageHeight != null) {
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
    if (_backgroundImageBytes != null) {
      // Convert image to base64
      final base64Image = base64Encode(_backgroundImageBytes!);

      // Determine image type
      String imageType = 'png';
      if (_backgroundImageBytes!.length >= 2) {
        if (_backgroundImageBytes![0] == 0xFF &&
            _backgroundImageBytes![1] == 0xD8) {
          imageType = 'jpeg';
        } else if (_backgroundImageBytes![0] == 0x89 &&
            _backgroundImageBytes![1] == 0x50) {
          imageType = 'png';
        }
      }

      // Add background image
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

    // Draw rooms
    for (final room in rooms) {
      final pathData = _pathToSvgPathData(room.path);
      final fillColorHex = _colorToHex(room.fillColor);
      buffer.writeln(
        '  <path d="$pathData" fill="$fillColorHex" fill-opacity="0.3" stroke="#424242" stroke-width="3"/>',
      );

      // Room name and area
      final bounds = room.path.getBounds();
      final center = bounds.center;
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy - 8}" '
        'text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000000">${room.name}</text>',
      );
      final area = _calculateArea(room.path);
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy + 12}" '
        'text-anchor="middle" font-family="Arial" font-size="14" fill="#000000">${area.toStringAsFixed(2)} m²</text>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  // Helper methods for SVG generation
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

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';
  }

  double _calculateArea(Path path) {
    final bounds = path.getBounds();
    return (bounds.width * bounds.height) / 10000; // Convert to m²
  }

  @override
  void dispose() {
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorPlanFromUrl() async {
    if (widget.initialFloorPlanUrl == null ||
        widget.initialFloorPlanUrl!.isEmpty) {
      return;
    }

    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.get(widget.initialFloorPlanUrl!);

      if (response.statusCode == 200 && mounted) {
        String svgContent;
        if (response.data is String) {
          svgContent = response.data as String;
        } else {
          svgContent = response.data.toString();
        }

        // Try to load as background image first
        // If it's an SVG, we can display it directly
        // For now, parse it to load rooms
        _loadFromSVG(svgContent);
      }
    } catch (e) {
      debugPrint('Error loading floor plan from URL: $e');
    }
  }

  void _loadFromSVG(String svgContent) {
    try {
      final document = xml.XmlDocument.parse(svgContent);
      final newRooms = <Room>[];
      final newDoors = <Door>[];

      // Check if there's an image element (background image)
      final imageElements = document.findAllElements('image');
      if (imageElements.isNotEmpty) {
        // Try to load background image from base64 or URL
        final imageElement = imageElements.first;
        final href =
            imageElement.getAttribute('xlink:href') ??
            imageElement.getAttribute('href');
        if (href != null && href.startsWith('data:image')) {
          // Extract base64 image
          final base64String = href.split(',')[1];
          final imageBytes = base64Decode(base64String);
          // Decode to get dimensions
          _decodeImageDimensions(imageBytes);
        }
      }

      // Find all path elements (rooms)
      final pathElements = document.findAllElements('path');
      int roomIndex = 1;

      for (final pathElement in pathElements) {
        final pathData = pathElement.getAttribute('d');
        if (pathData == null || pathData.isEmpty) continue;

        final fill = pathElement.getAttribute('fill');
        if (fill != null && fill != 'none') {
          final roomPath = _parseSVGPath(pathData);
          final fillColor = _hexToColor(fill);

          String roomName = 'Room $roomIndex';
          roomIndex++;

          newRooms.add(
            Room(
              id: UniqueKey().toString(),
              path: roomPath,
              fillColor: fillColor ?? colorPalette[0],
              name: roomName,
            ),
          );
        }
      }

      // Find text elements for room names
      final textElements = document.findAllElements('text');
      final textItems = <Map<String, dynamic>>[];
      for (final textElement in textElements) {
        final text = textElement.text.trim();
        if (text.isEmpty) continue;

        final x = double.tryParse(textElement.getAttribute('x') ?? '') ?? 0;
        final y = double.tryParse(textElement.getAttribute('y') ?? '') ?? 0;

        final normalizedText = text
            .toLowerCase()
            .replaceAll('mâ²', 'm²')
            .replaceAll('mÂ²', 'm²')
            .replaceAll('m2', 'm²');
        final isAreaText = RegExp(
          r'^\d+\.?\d*\s*m²\s*$',
          caseSensitive: false,
        ).hasMatch(normalizedText);

        textItems.add({
          'text': text,
          'position': Offset(x, y),
          'isArea': isAreaText,
        });
      }

      // Match non-area text elements to rooms
      for (final textItem in textItems) {
        if (textItem['isArea'] == true) continue;

        final text = textItem['text'] as String;
        final textPos = textItem['position'] as Offset;

        if (newRooms.isEmpty) continue;

        Room? nearestRoom;
        double minDistance = double.infinity;
        int nearestIndex = -1;

        for (int i = 0; i < newRooms.length; i++) {
          final room = newRooms[i];
          final bounds = room.path.getBounds();
          final center = bounds.center;
          final distance = (center - textPos).distance;

          final yOffset = textPos.dy - center.dy;
          final adjustedDistance = distance + (yOffset > 0 ? 50 : 0);

          if (adjustedDistance < minDistance) {
            minDistance = adjustedDistance;
            nearestRoom = room;
            nearestIndex = i;
          }
        }

        if (nearestRoom != null && nearestIndex != -1 && minDistance < 150) {
          final normalizedText = text
              .toLowerCase()
              .replaceAll('mâ²', 'm²')
              .replaceAll('mÂ²', 'm²')
              .replaceAll('m2', 'm²');
          final looksLikeArea = RegExp(
            r'^\d+\.?\d*\s*m²\s*$',
            caseSensitive: false,
          ).hasMatch(normalizedText);

          if (looksLikeArea) continue;

          if (nearestRoom.name.startsWith('Room ') ||
              (textPos.dy < nearestRoom.path.getBounds().center.dy)) {
            newRooms[nearestIndex] = Room(
              id: nearestRoom.id,
              path: nearestRoom.path,
              doorOpenings: nearestRoom.doorOpenings,
              fillColor: nearestRoom.fillColor,
              name: text,
            );
          }
        }
      }

      setState(() {
        for (final controller in _roomControllers.values) {
          controller.dispose();
        }
        _roomControllers.clear();

        rooms.clear();
        doors.clear();
        rooms.addAll(newRooms);
        doors.addAll(newDoors);
        for (final room in newRooms) {
          _roomControllers[room.id] = TextEditingController(text: room.name);
        }
        selectedRoom = null;
        selectedDoor = null;
        _roomCounter = roomIndex;
        _updateCanvasSize();
      });

      // After loading SVG, fetch and match backend rooms
      _fetchRoomsFromBackend();
    } catch (e) {
      debugPrint('Error parsing SVG: $e');
    }
  }

  Future<void> _fetchRoomsFromBackend() async {
    if (_isLoadingBackendRooms) return;

    setState(() {
      _isLoadingBackendRooms = true;
    });

    try {
      final response = await _dioClient.get('/api/v1/floors/${widget.floorId}');

      if (response.statusCode == 200 && response.data != null && mounted) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final floorData = data['data'] as Map<String, dynamic>;

          // Store buildingId from floor data
          if (floorData['building_id'] != null) {
            _buildingId = floorData['building_id'].toString();
          }

          // Get rooms from floor data
          List<dynamic> backendRooms = [];
          if (floorData['rooms'] != null && floorData['rooms'] is List) {
            backendRooms = floorData['rooms'] as List;
          }

          // Match backend rooms with SVG rooms by name
          if (rooms.isNotEmpty) {
            _matchBackendRoomsWithSVGRooms(backendRooms);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching rooms from backend: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBackendRooms = false;
        });
      }
    }
  }

  void _matchBackendRoomsWithSVGRooms(List<dynamic> backendRooms) {
    setState(() {
      for (var backendRoom in backendRooms) {
        final backendRoomId =
            backendRoom['_id']?.toString() ??
            backendRoom['id']?.toString() ??
            '';
        final backendRoomName = backendRoom['name']?.toString() ?? '';
        final loxoneRoomId = backendRoom['loxone_room_id']?.toString();

        if (backendRoomId.isEmpty || backendRoomName.isEmpty) continue;

        // Find matching room by name (case-insensitive)
        // Match against the room name from SVG, not backend name
        final matchingRoomIndex = rooms.indexWhere(
          (room) =>
              room.name.toLowerCase().trim() ==
              backendRoomName.toLowerCase().trim(),
        );

        if (matchingRoomIndex != -1) {
          final room = rooms[matchingRoomIndex];

          // Don't update the SVG room - keep it as is
          // Just store backend room ID mapping for edit/delete operations
          _backendRoomIds[room.id] = backendRoomId;
          if (loxoneRoomId != null && loxoneRoomId.isNotEmpty) {
            _loxoneRoomIds[room.id] = loxoneRoomId;
          }

          // Keep the SVG room name and color as they are
          // Don't update controller with backend name
        }
      }
    });
  }

  Future<void> _decodeImageDimensions(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      setState(() {
        _backgroundImageBytes = imageBytes;
        _backgroundImageWidth = image.width.toDouble();
        _backgroundImageHeight = image.height.toDouble();
        _updateCanvasSize();
      });

      image.dispose();
    } catch (e) {
      debugPrint('Error decoding image: $e');
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

  void _showEditRoomDialog(Room room) {
    final backendRoomId = _backendRoomIds[room.id];
    if (backendRoomId == null) return;

    final nameController = TextEditingController(text: room.name);
    Color selectedColor = room.fillColor;
    bool isLoading = false;
    String? selectedLoxoneRoomId = _loxoneRoomIds[room.id];
    String? selectedLoxoneRoomName;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Function to show Loxone room selector
          Future<void> showLoxoneRoomSelector() async {
            if (_buildingId == null || _buildingId!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Building ID is required to select Loxone room',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            final result = await showDialog<Map<String, String>?>(
              context: context,
              barrierDismissible: true,
              builder: (loxoneDialogContext) => BlocProvider(
                create: (_) => sl<GetLoxoneRoomsBloc>(),
                child: LoxoneRoomSelectionDialog(
                  selectedRoomName: nameController.text,
                  roomColor: selectedColor,
                  buildingId: _buildingId!,
                ),
              ),
            );

            if (result != null && mounted) {
              setDialogState(() {
                selectedLoxoneRoomId = result['id'];
                selectedLoxoneRoomName = result['name'];
              });
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            title: const Text('Edit Room'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room name field
                  const Text(
                    'Room Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'Room Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Color selection
                  const Text(
                    'Color:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorPalette.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Loxone Room Selection
                  const Text(
                    'Loxone Room',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: showLoxoneRoomSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54, width: 2),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          if (selectedLoxoneRoomName != null) ...[
                            Text(
                              selectedLoxoneRoomName!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Select Loxone room',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              StatefulBuilder(
                builder: (context, setButtonState) => isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PrimaryOutlineButton(
                        label: "Save",
                        width: 100,
                        onPressed: isLoading
                            ? null
                            : () async {
                                setButtonState(() {
                                  isLoading = true;
                                });

                                try {
                                  await _updateRoomInBackend(
                                    backendRoomId,
                                    nameController.text.trim(),
                                    selectedColor,
                                    loxoneRoomId: selectedLoxoneRoomId,
                                  );

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      // Update room in local state
                                      final roomIndex = rooms.indexWhere(
                                        (r) => r.id == room.id,
                                      );
                                      if (roomIndex != -1) {
                                        rooms[roomIndex] = Room(
                                          id: room.id,
                                          path: room.path,
                                          doorOpenings: room.doorOpenings,
                                          fillColor: selectedColor,
                                          name: nameController.text.trim(),
                                        );
                                        if (_roomControllers.containsKey(
                                          room.id,
                                        )) {
                                          _roomControllers[room.id]!.text =
                                              nameController.text.trim();
                                        }
                                        // Update Loxone room ID mapping
                                        if (selectedLoxoneRoomId != null) {
                                          _loxoneRoomIds[room.id] =
                                              selectedLoxoneRoomId;
                                        }
                                      }
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error updating room: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setButtonState(() {
                                      isLoading = false;
                                    });
                                  }
                                }
                              },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateRoomInBackend(
    String backendRoomId,
    String name,
    Color color, {
    String? loxoneRoomId,
  }) async {
    try {
      final requestBody = {
        'name': name,
        'color': _colorToHex(color),
        if (loxoneRoomId != null) 'loxone_room_id': loxoneRoomId,
      };

      final response = await _dioClient.dio.patch(
        '/api/v1/floors/rooms/$backendRoomId',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update room: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error updating room: $e');
      rethrow;
    }
  }

  Future<void> _showLinkToLoxoneDialog(Room room) async {
    if (_buildingId == null || _buildingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building ID is required to select Loxone room'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BlocProvider(
        create: (_) => sl<GetLoxoneRoomsBloc>(),
        child: LoxoneRoomSelectionDialog(
          selectedRoomName: room.name,
          roomColor: room.fillColor,
          buildingId: _buildingId!,
        ),
      ),
    );

    if (result != null && mounted) {
      final loxoneRoomId = result['id'];
      if (loxoneRoomId != null && loxoneRoomId.isNotEmpty) {
        setState(() {
          _loxoneRoomIds[room.id] = loxoneRoomId;
        });

        // Update room in backend with loxone_room_id
        final backendRoomId = _backendRoomIds[room.id];
        if (backendRoomId != null) {
          _updateRoomLoxoneIdInBackend(backendRoomId, loxoneRoomId);
        }
      }
    }
  }

  Future<void> _updateRoomLoxoneIdInBackend(
    String backendRoomId,
    String loxoneRoomId,
  ) async {
    try {
      final requestBody = {'loxone_room_id': loxoneRoomId};

      final response = await _dioClient.dio.patch(
        '/api/v1/floors/rooms/$backendRoomId',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room linked to Loxone successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to link room: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error linking room to Loxone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoomFromBackend(Room room) async {
    final backendRoomId = _backendRoomIds[room.id];
    if (backendRoomId == null) return;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "${room.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final response = await _dioClient.dio.delete(
        '/api/v1/floors/rooms/$backendRoomId',
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            _roomControllers[room.id]?.dispose();
            _roomControllers.remove(room.id);
            _backendRoomIds.remove(room.id);
            _loxoneRoomIds.remove(room.id);
            doors.removeWhere((door) => door.roomId == room.id);
            rooms.remove(room);
            if (selectedRoom == room) {
              selectedRoom = null;
            }
            _updateCanvasSize();
          });
        } else {
          throw Exception('Failed to delete room: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createRoomInBackend(
    Room room, {
    bool showSuccessMessage = true,
  }) async {
    // Check if room already exists in backend
    if (_backendRoomIds.containsKey(room.id)) {
      return; // Already exists, skip
    }

    try {
      final requestBody = {
        'name': room.name,
        'color': _colorToHex(room.fillColor),
        if (_loxoneRoomIds[room.id] != null)
          'loxone_room_id': _loxoneRoomIds[room.id],
      };

      final response = await _dioClient.dio.post(
        '/api/v1/floors/${widget.floorId}/rooms',
        data: requestBody,
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = response.data;
          String? newBackendRoomId;

          if (responseData is Map<String, dynamic>) {
            if (responseData['data'] != null) {
              final roomData = responseData['data'] as Map<String, dynamic>;
              newBackendRoomId =
                  roomData['_id']?.toString() ?? roomData['id']?.toString();
            } else {
              newBackendRoomId =
                  responseData['_id']?.toString() ??
                  responseData['id']?.toString();
            }
          }

          if (newBackendRoomId != null && newBackendRoomId.isNotEmpty) {
            setState(() {
              _backendRoomIds[room.id] = newBackendRoomId!;
            });
          }

          if (showSuccessMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Room created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to create room: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  /// Public method to create all new rooms in the backend
  /// Called when saving the floor plan
  Future<void> createNewRoomsInBackend() async {
    final newRooms = rooms
        .where((room) => !_backendRoomIds.containsKey(room.id))
        .toList();

    if (newRooms.isEmpty) {
      return; // No new rooms to create
    }

    int successCount = 0;
    int failureCount = 0;

    for (final room in newRooms) {
      try {
        // Don't show individual success messages when creating multiple rooms
        await _createRoomInBackend(room, showSuccessMessage: false);
        successCount++;
      } catch (e) {
        debugPrint('Failed to create room ${room.name}: $e');
        failureCount++;
        // Continue with other rooms even if one fails
      }
    }

    // Show summary message
    if (mounted) {
      if (failureCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 1
                  ? '$successCount rooms created successfully'
                  : 'Room created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created $successCount room(s), failed to create $failureCount room(s)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _updateCanvasSize() {
    if (_backgroundImageBytes != null &&
        _backgroundImageWidth != null &&
        _backgroundImageHeight != null) {
      _canvasSize = Size(_backgroundImageWidth!, _backgroundImageHeight!);
      return;
    }

    if (rooms.isEmpty && doors.isEmpty) {
      _canvasSize = const Size(4000, 4000);
      return;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final room in rooms) {
      final bounds = room.path.getBounds();
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }

    for (final door in doors) {
      final bounds = door.path.getBounds();
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }

    const padding = 200.0;
    final width = (maxX - minX + padding * 2).clamp(2000.0, 20000.0);
    final height = (maxY - minY + padding * 2).clamp(2000.0, 20000.0);

    _canvasSize = Size(math.max(width, 4000), math.max(height, 4000));
  }

  void _saveState() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    final state = _FloorPlanState(
      rooms: rooms
          .map(
            (room) => Room(
              id: room.id,
              path: Path.from(room.path),
              doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
              fillColor: room.fillColor,
              name: room.name,
            ),
          )
          .toList(),
      doors: doors
          .map(
            (door) => Door(
              id: door.id,
              path: Path.from(door.path),
              rotation: door.rotation,
              roomId: door.roomId,
              edge: door.edge,
            ),
          )
          .toList(),
      roomCounter: _roomCounter,
    );

    _history.add(state);
    _historyIndex = _history.length - 1;

    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _restoreState(_FloorPlanState state) {
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();

    rooms.clear();
    doors.clear();

    for (final room in state.rooms) {
      final restoredRoom = Room(
        id: room.id,
        path: Path.from(room.path),
        doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
        fillColor: room.fillColor,
        name: room.name,
      );
      rooms.add(restoredRoom);
      _roomControllers[restoredRoom.id] = TextEditingController(
        text: restoredRoom.name,
      );
    }

    for (final door in state.doors) {
      doors.add(
        Door(
          id: door.id,
          path: Path.from(door.path),
          rotation: door.rotation,
          roomId: door.roomId,
          edge: door.edge,
        ),
      );
    }

    _roomCounter = state.roomCounter;
    selectedRoom = null;
    selectedDoor = null;
    _updateCanvasSize();
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

  // Shape creation methods (reuse from FloorPlanBackupPage)
  // Helper to check if background image exists
  bool get _hasBackgroundImage =>
      _backgroundImageBytes != null ||
      (widget.initialFloorPlanUrl != null &&
          widget.initialFloorPlanUrl!.isNotEmpty);

  Path createRectangle(Offset o, {double width = 100, double height = 75}) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + width, o.dy)
      ..lineTo(o.dx + width, o.dy + height)
      ..lineTo(o.dx, o.dy + height)
      ..close();
  }

  // Create rectangle from two points (for drawing mode)
  Path createRectangleFromPoints(Offset start, Offset end) {
    final rect = Rect.fromPoints(start, end);
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  Path createTriangle(Offset o, {double width = 100, double height = 90}) {
    return Path()
      ..moveTo(o.dx + (width / 2), o.dy)
      ..lineTo(o.dx + width, o.dy + height)
      ..lineTo(o.dx, o.dy + height)
      ..close();
  }

  Path createCircle(Offset center, {double radius = 50}) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  void _addShapeToCanvas(Path Function() shapeCreator) {
    _saveState();
    setState(() {
      final newPath = shapeCreator();
      final newRoom = Room(
        id: UniqueKey().toString(),
        path: newPath,
        fillColor: selectedColor ?? colorPalette[0],
        name: 'Room $_roomCounter',
      );
      rooms.add(newRoom);
      _roomControllers[newRoom.id] = TextEditingController(text: newRoom.name);
      _roomCounter++;
      _updateCanvasSize();
    });
  }

  void selectRoom(Offset pos) {
    if (polygonMode) return;

    for (final d in doors.reversed) {
      if (d.path.contains(pos)) {
        setState(() {
          selectedDoor = d;
          selectedRoom = null;
          activeHandle = null;
        });
        return;
      }
    }

    for (final r in rooms.reversed) {
      if (r.path.contains(pos)) {
        setState(() {
          selectedRoom = r;
          selectedDoor = null;
          activeHandle = null;
        });
        return;
      }
    }
    setState(() {
      selectedRoom = null;
      selectedDoor = null;
      activeHandle = null;
    });
  }

  void moveSelected(Offset delta) {
    if (selectedRoom != null) {
      setState(() {
        selectedRoom!.path = selectedRoom!.path.shift(delta);
        for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
          selectedRoom!.doorOpenings[i] = selectedRoom!.doorOpenings[i].shift(
            delta,
          );
        }
        for (final door in doors) {
          if (door.roomId == selectedRoom!.id) {
            door.path = door.path.shift(delta);
          }
        }
      });
    } else if (selectedDoor != null) {
      setState(() {
        selectedDoor!.path = selectedDoor!.path.shift(delta);
      });
    }
  }

  ResizeHandle? hitTestHandle(Offset pos, Rect bounds) {
    const size = 12.0;
    final handles = {
      ResizeHandle.topLeft: Rect.fromLTWH(
        bounds.left - size,
        bounds.top - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.topRight: Rect.fromLTWH(
        bounds.right - size,
        bounds.top - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.bottomLeft: Rect.fromLTWH(
        bounds.left - size,
        bounds.bottom - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.bottomRight: Rect.fromLTWH(
        bounds.right - size,
        bounds.bottom - size,
        size * 2,
        size * 2,
      ),
    };

    for (final e in handles.entries) {
      if (e.value.contains(pos)) return e.key;
    }
    return null;
  }

  Path scalePath(Path path, double sx, double sy, Offset anchor) {
    final matrix = Matrix4.identity()
      ..translate(anchor.dx, anchor.dy)
      ..scale(sx, sy)
      ..translate(-anchor.dx, -anchor.dy);
    return path.transform(matrix.storage);
  }

  void resizeRoom(Offset delta) {
    if (selectedRoom == null || activeHandle == null || startBounds == null)
      return;

    final bounds = startBounds!;

    double sx = 1, sy = 1;
    Offset anchor = bounds.center;

    if (activeHandle == ResizeHandle.bottomRight) {
      sx = (bounds.width + delta.dx) / bounds.width;
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topLeft;
    } else if (activeHandle == ResizeHandle.topLeft) {
      sx = (bounds.width - delta.dx) / bounds.width;
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomRight;
    } else if (activeHandle == ResizeHandle.topRight) {
      sx = (bounds.width + delta.dx) / bounds.width;
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomLeft;
    } else if (activeHandle == ResizeHandle.bottomLeft) {
      sx = (bounds.width - delta.dx) / bounds.width;
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topRight;
    }

    if (sx > 0.2 && sy > 0.2) {
      selectedRoom!.path = scalePath(selectedRoom!.path, sx, sy, anchor);

      for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
        selectedRoom!.doorOpenings[i] = scalePath(
          selectedRoom!.doorOpenings[i],
          sx,
          sy,
          anchor,
        );
      }

      for (final door in doors) {
        if (door.roomId == selectedRoom!.id) {
          door.path = scalePath(door.path, sx, sy, anchor);
        }
      }
    }

    setState(() {});
  }

  void _handlePolygonClick(Offset position) {
    if (_polygonPoints.isNotEmpty) {
      final firstPoint = _polygonPoints[0];
      final distance = (position - firstPoint).distance;
      if (distance < 15.0 && _polygonPoints.length >= 2) {
        _createRoomFromPolygon();
        return;
      }
    }

    setState(() {
      _polygonPoints.add(position);
      _polygonPreviewPosition = null;
    });
  }

  void _createRoomFromPolygon() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Polygon must have at least 3 points'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final path = Path();
    path.moveTo(_polygonPoints[0].dx, _polygonPoints[0].dy);
    for (int i = 1; i < _polygonPoints.length; i++) {
      path.lineTo(_polygonPoints[i].dx, _polygonPoints[i].dy);
    }
    path.close();

    _saveState();
    final roomId = UniqueKey().toString();
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: selectedColor ?? colorPalette[0],
          name: roomName,
        ),
      );
      _roomCounter++;
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      polygonMode = false;
      _showShapeOptions = false;
      _roomControllers[roomId] = TextEditingController(text: roomName);
      _updateCanvasSize();
    });
  }

  void _cancelPolygon() {
    setState(() {
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      polygonMode = false;
      _drawingMode = DrawingMode.none;
    });
  }

  void _createRoomFromRectangle(Rect rect) {
    if (rect.isEmpty || rect.width < 10 || rect.height < 10) return;

    _saveState();
    final path = createRectangleFromPoints(rect.topLeft, rect.bottomRight);
    final roomId = UniqueKey().toString();
    final roomName = 'Room $_roomCounter';

    setState(() {
      rooms.add(
        Room(
          id: roomId,
          path: path,
          fillColor: selectedColor ?? colorPalette[0],
          name: roomName,
        ),
      );
      _roomCounter++;
      selectedRoom = rooms.last;
      _currentRectangle = null;
      _rectangleStart = null;
      _updateCanvasSize();
      // Create controller for new room
      _roomControllers[roomId] = TextEditingController(text: roomName);
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

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.1,
          maxScale: 4,
          child: Stack(
            children: [
              // Background SVG image if available
              if (widget.initialFloorPlanUrl != null &&
                  widget.initialFloorPlanUrl!.isNotEmpty &&
                  _backgroundImageBytes == null)
                Positioned.fill(
                  child: SvgPicture.network(
                    widget.initialFloorPlanUrl!,
                    fit: BoxFit.contain,
                    placeholderBuilder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              // Background image from bytes
              if (_backgroundImageBytes != null &&
                  _backgroundImageWidth != null &&
                  _backgroundImageHeight != null)
                Positioned(
                  left: 0,
                  top: 0,
                  width: _backgroundImageWidth,
                  height: _backgroundImageHeight,
                  child: Image.memory(
                    _backgroundImageBytes!,
                    fit: BoxFit.none,
                    alignment: Alignment.topLeft,
                  ),
                ),
              // Canvas with rooms and doors
              GestureDetector(
                onTapDown: (d) {
                  if (_drawingMode == DrawingMode.polygon || polygonMode) {
                    _handlePolygonClick(d.localPosition);
                  } else if (_drawingMode == DrawingMode.rectangle) {
                    // Rectangle drawing will be handled in onPanStart
                  } else if (!pencilMode) {
                    selectRoom(d.localPosition);
                  }
                },
                onPanStart: (d) {
                  lastPanPosition = d.localPosition;
                  if (_drawingMode == DrawingMode.rectangle) {
                    // Start rectangle drawing
                    setState(() {
                      _rectangleStart = d.localPosition;
                      _currentRectangle = Rect.fromPoints(
                        d.localPosition,
                        d.localPosition,
                      );
                    });
                  } else if (pencilMode) {
                    drawingPath = Path()
                      ..moveTo(d.localPosition.dx, d.localPosition.dy);
                  } else if (polygonMode ||
                      _drawingMode == DrawingMode.polygon) {
                    setState(() {
                      _polygonPreviewPosition = d.localPosition;
                    });
                  } else {
                    final bounds = selectedRoom?.path.getBounds();
                    if (bounds != null) {
                      activeHandle = hitTestHandle(d.localPosition, bounds);
                      startBounds = bounds;
                    }
                  }
                },
                onPanUpdate: (d) {
                  if (_drawingMode == DrawingMode.rectangle &&
                      _rectangleStart != null) {
                    // Update rectangle preview
                    setState(() {
                      _currentRectangle = Rect.fromPoints(
                        _rectangleStart!,
                        d.localPosition,
                      );
                    });
                  } else if (pencilMode) {
                    setState(() {
                      drawingPath!.lineTo(
                        d.localPosition.dx,
                        d.localPosition.dy,
                      );
                    });
                  } else if (polygonMode ||
                      _drawingMode == DrawingMode.polygon) {
                    setState(() {
                      _polygonPreviewPosition = d.localPosition;
                    });
                  } else if (activeHandle != null) {
                    resizeRoom(d.delta);
                  } else if (selectedRoom != null || selectedDoor != null) {
                    moveSelected(d.delta);
                  }
                },
                onPanEnd: (d) {
                  if (_drawingMode == DrawingMode.rectangle &&
                      _currentRectangle != null) {
                    // Create room from rectangle
                    _createRoomFromRectangle(_currentRectangle!);
                    setState(() {
                      _rectangleStart = null;
                      _currentRectangle = null;
                      _drawingMode = DrawingMode.none;
                    });
                  } else {
                    final hadActiveOperation =
                        activeHandle != null ||
                        (selectedRoom != null && lastPanPosition != null) ||
                        (selectedDoor != null && lastPanPosition != null);
                    if (!pencilMode && hadActiveOperation) {
                      _saveState();
                    }
                    activeHandle = null;
                    startBounds = null;
                    lastPanPosition = null;
                    if (pencilMode && drawingPath != null) {
                      setState(() {
                        final closedPath = Path.from(drawingPath!)..close();
                        final newRoom = Room(
                          id: UniqueKey().toString(),
                          path: closedPath,
                          fillColor: selectedColor ?? colorPalette[0],
                          name: 'Room $_roomCounter',
                        );
                        rooms.add(newRoom);
                        _roomControllers[newRoom.id] = TextEditingController(
                          text: newRoom.name,
                        );
                        _roomCounter++;
                        drawingPath = null;
                        _updateCanvasSize();
                      });
                    }
                  }
                },
                child: CustomPaint(
                  size: _canvasSize,
                  painter: FloorPainter(
                    rooms: rooms,
                    doors: doors,
                    selectedRoom: selectedRoom,
                    selectedDoor: selectedDoor,
                    previewPath: drawingPath,
                    hasBackgroundImage:
                        _backgroundImageBytes != null ||
                        (widget.initialFloorPlanUrl != null &&
                            widget.initialFloorPlanUrl!.isNotEmpty),
                    polygonPoints: _polygonPoints,
                    polygonPreviewPosition: _polygonPreviewPosition,
                    polygonColor: selectedColor ?? colorPalette[0],
                    currentRectangle: _currentRectangle,
                    rectangleColor: selectedColor ?? colorPalette[0],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Canvas Area with dotted border (from floor_plan_backup.dart lines 1169-1222)
        DottedBorderContainer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child:
                      (rooms.isEmpty &&
                          _backgroundImageBytes == null &&
                          widget.initialFloorPlanUrl == null &&
                          !polygonMode &&
                          !pencilMode)
                      ? const Center()
                      : _buildCanvas(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Shape Options (shown when Add Room is clicked)
        if (_showShapeOptions) _shapeOptionsBar(),
        // Polygon completion buttons
        if (polygonMode && _polygonPoints.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16, top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_polygonPoints.length >= 3)
                  ElevatedButton.icon(
                    onPressed: _createRoomFromPolygon,
                    icon: const Icon(Icons.check),
                    label: const Text('Complete Polygon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (_polygonPoints.length >= 3) const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _cancelPolygon,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        // Add Room Button
        InkWell(
          onTap: () {
            setState(() {
              _showShapeOptions = !_showShapeOptions;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '+ Add Room',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Room List with TextField and Color Palette (from floor_plan_backup.dart lines 1311-1456)
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
                      readOnly: _backendRoomIds.containsKey(room.id),
                      controller: _roomControllers[room.id] ??=
                          TextEditingController(text: room.name),
                      decoration: const InputDecoration(
                        hintText: 'Room name',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
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
                          if (!_backendRoomIds.containsKey(room.id)) {
                            _saveState();
                            setState(() {
                              room.fillColor = color;
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[400]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.clear,
                                  size: 12,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                  // Edit button (only for rooms with backend ID)
                  (_backendRoomIds.containsKey(room.id))
                      ? IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          tooltip: 'Edit',
                          onPressed: () {
                            _showEditRoomDialog(room);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : InkWell(
                          onTap: () {
                            _showLinkToLoxoneDialog(room);
                          },
                          child: buildDashboardSvgIcon(
                            assetRoom,
                            color: Color(0xFF00897B),
                          ),
                        ),

                  const SizedBox(width: 4),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    onPressed: () {
                      if (_backendRoomIds.containsKey(room.id)) {
                        // Delete from backend
                        _deleteRoomFromBackend(room);
                      } else {
                        // Just remove from local state
                        _saveState();
                        setState(() {
                          _roomControllers[room.id]?.dispose();
                          _roomControllers.remove(room.id);
                          _backendRoomIds.remove(room.id);
                          _loxoneRoomIds.remove(room.id);
                          doors.removeWhere((door) => door.roomId == room.id);
                          rooms.remove(room);
                          if (selectedRoom == room) {
                            selectedRoom = null;
                          }
                          _updateCanvasSize();
                        });
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _shapeOptionsBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(),
          Row(
            children: [
              _shapeOptionButton(
                icon: 'assets/images/Pen.svg',
                label: "Polygon",
                onTap: () {
                  setState(() {
                    _selectedShapeTool = _ShapeTool.polygon;
                    if (_hasBackgroundImage) {
                      // Use drawing mode when background image exists
                      if (_drawingMode == DrawingMode.polygon) {
                        _drawingMode = DrawingMode.none;
                        polygonMode = false;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      } else {
                        _drawingMode = DrawingMode.polygon;
                        polygonMode = true;
                        pencilMode = false;
                        drawingPath = null;
                        doorPlacementMode = false;
                        _rectangleStart = null;
                        _currentRectangle = null;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      }
                    } else {
                      // Toggle polygon mode (original behavior)
                      polygonMode = !polygonMode;
                      if (polygonMode) {
                        pencilMode = false;
                        drawingPath = null;
                        doorPlacementMode = false;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      } else {
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      }
                    }
                    selectedRoom = null;
                  });
                },
                isSelected:
                    polygonMode ||
                    _drawingMode == DrawingMode.polygon ||
                    _selectedShapeTool == _ShapeTool.polygon,
              ),
              _shapeOptionButton(
                icon: 'assets/images/Rectangle.svg',
                label: "Rectangle",
                onTap: () {
                  if (_hasBackgroundImage) {
                    // Use drawing mode when background image exists
                    setState(() {
                      _selectedShapeTool = _ShapeTool.rectangle;
                      if (_drawingMode == DrawingMode.rectangle) {
                        _drawingMode = DrawingMode.none;
                      } else {
                        _drawingMode = DrawingMode.rectangle;
                        polygonMode = false;
                        _polygonPoints.clear();
                        _polygonPreviewPosition = null;
                      }
                      _rectangleStart = null;
                      _currentRectangle = null;
                      selectedRoom = null;
                    });
                  } else {
                    // Create immediately when no background image
                    setState(() {
                      _selectedShapeTool = _ShapeTool.rectangle;
                      polygonMode = false;
                      _drawingMode = DrawingMode.none;
                    });
                    _addShapeToCanvas(
                      () => createRectangle(const Offset(200, 200)),
                    );
                  }
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
                    polygonMode = false;
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
                    polygonMode = false;
                    _drawingMode = DrawingMode.none;
                    _polygonPoints.clear();
                    _polygonPreviewPosition = null;
                  });
                  _addShapeToCanvas(
                    () => createCircle(const Offset(200, 200), radius: 50),
                  );
                },
                isSelected: _selectedShapeTool == _ShapeTool.circle,
              ),
              const SizedBox(width: 8),
            ],
          ),
          // Undo/Redo buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
        ],
      ),
    );
  }
}

// Helper class for parsing SVG path commands
class _PathCommand {
  final String command;
  final List<double> coordinates;

  _PathCommand(this.command, this.coordinates);
}
