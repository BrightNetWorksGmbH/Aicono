import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert' show base64Encode, utf8, jsonEncode;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;
import 'dart:io' show File;
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_bloc.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_event.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_state.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_floor_plan_step.dart'
    show DottedBorderContainer;

import '../../../../core/widgets/page_header_row.dart';
import '../../../../core/widgets/primary_outline_button.dart';

class Room {
  final String id;
  Path path;
  final List<Path> doorOpenings; // Store door openings for border rendering
  Color fillColor; // Room fill color
  String name; // Room name

  Room({
    required this.id,
    required this.path,
    List<Path>? doorOpenings,
    Color? fillColor,
    String? name,
  }) : doorOpenings = doorOpenings ?? [],
       fillColor = fillColor ?? const Color(0xFFF5F5DC), // Default light beige
       name = name ?? 'Room'; // Default name
}

class Door {
  final String id;
  Path path;
  double rotation;
  final String roomId; // Reference to the room this door belongs to
  String edge; // Which edge: 'top', 'bottom', 'left', 'right'

  Door({
    required this.id,
    required this.path,
    this.rotation = 0,
    required this.roomId,
    required this.edge,
  });
}

enum ResizeHandle { topLeft, topRight, bottomLeft, bottomRight }

enum _ShapeTool { polygon, rectangle, triangle, circle }

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

/* =======================
   MAIN PAGE
======================= */

class FloorPlanBackupPage extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const FloorPlanBackupPage({super.key, this.onComplete, this.onSkip});

  @override
  State<FloorPlanBackupPage> createState() => _FloorPlanBackupPageState();
}

class _FloorPlanBackupPageState extends State<FloorPlanBackupPage> {
  final List<Room> rooms = [];
  final List<Door> doors = [];
  Room? selectedRoom;
  Door? selectedDoor;

  Path? drawingPath;
  bool pencilMode = false;
  bool doorPlacementMode = false; // Mode for placing doors on borders
  bool polygonMode = false; // Mode for creating polygons by clicking points
  _ShapeTool? _selectedShapeTool;

  // Polygon creation state
  List<Offset> _polygonPoints = [];
  Offset? _polygonPreviewPosition; // Current cursor position for preview

  Offset? lastPanPosition;

  // Resize state
  ResizeHandle? activeHandle;
  Rect? startBounds;

  // Color selection
  Color? selectedColor;

  // Room counter for default names
  int _roomCounter = 1;

  // Canvas size - will be calculated dynamically
  Size _canvasSize = const Size(4000, 4000);

  // Transformation controller for InteractiveViewer
  final TransformationController _transformationController =
      TransformationController();

  // Viewport size for fit calculations
  Size? _viewportSize;

  // Background image
  Uint8List? _backgroundImageBytes;
  double? _backgroundImageWidth;
  double? _backgroundImageHeight;

  // Undo/Redo history
  final List<_FloorPlanState> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

  // Upload subscription
  StreamSubscription? _uploadSubscription;

  // UI state for showing shape options
  bool _showShapeOptions = false;

  // Room controllers for TextField management
  final Map<String, TextEditingController> _roomControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize history with empty state
    _saveState();
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    // Dispose all room controllers
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();
    super.dispose();
  }

  // Color palette matching the reference design
  static const List<Color> colorPalette = [
    Color(0xFFFFB74D), // Light orange
    Color(0xFFE57373), // Red
    Color(0xFFBA68C8), // Purple
    Color(0xFF64B5F6), // Blue
    Color(0xFF81C784), // Green
  ];

  /* =======================
     SHAPES
  ======================= */

  Path createLShape(Offset o) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + 100, o.dy)
      ..lineTo(o.dx + 100, o.dy + 25)
      ..lineTo(o.dx + 25, o.dy + 25)
      ..lineTo(o.dx + 25, o.dy + 100)
      ..lineTo(o.dx, o.dy + 100)
      ..close();
  }

  Path createUShape(Offset o) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + 100, o.dy)
      ..lineTo(o.dx + 100, o.dy + 100)
      ..lineTo(o.dx + 75, o.dy + 100)
      ..lineTo(o.dx + 75, o.dy + 25)
      ..lineTo(o.dx + 25, o.dy + 25)
      ..lineTo(o.dx + 25, o.dy + 100)
      ..lineTo(o.dx, o.dy + 100)
      ..close();
  }

  Path createTShape(Offset o) {
    return Path()
      ..moveTo(o.dx + 25, o.dy)
      ..lineTo(o.dx + 75, o.dy)
      ..lineTo(o.dx + 75, o.dy + 50)
      ..lineTo(o.dx + 100, o.dy + 50)
      ..lineTo(o.dx + 100, o.dy + 75)
      ..lineTo(o.dx, o.dy + 75)
      ..lineTo(o.dx, o.dy + 50)
      ..lineTo(o.dx + 25, o.dy + 50)
      ..close();
  }

  Path createRectangle(Offset o, {double width = 100, double height = 75}) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + width, o.dy)
      ..lineTo(o.dx + width, o.dy + height)
      ..lineTo(o.dx, o.dy + height)
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

  Path createDoor(Offset center, {double width = 50, double height = 12}) {
    // Door as a rectangle on the border
    return Path()
      ..addRect(Rect.fromCenter(center: center, width: width, height: height));
  }

  Path createDoorShape(Offset o, {double width = 80, double height = 200}) {
    // Door with arc opening (swing) - for standalone door shapes
    final path = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + width, o.dy)
      ..lineTo(o.dx + width, o.dy + height - 20)
      ..arcToPoint(
        Offset(o.dx, o.dy + height - 20),
        radius: Radius.circular(width),
        clockwise: false,
      )
      ..lineTo(o.dx, o.dy)
      ..close();
    return path;
  }

  /* =======================
     HELPERS
  ======================= */

  Path scalePath(Path path, double sx, double sy, Offset anchor) {
    final matrix = Matrix4.identity()
      ..translate(anchor.dx, anchor.dy)
      ..scale(sx, sy)
      ..translate(-anchor.dx, -anchor.dy);
    return path.transform(matrix.storage);
  }

  Path rotatePath(Path path, double deg, Offset center) {
    final rad = deg * math.pi / 180;
    final m = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateZ(rad)
      ..translate(-center.dx, -center.dy);
    return path.transform(m.storage);
  }

  Path cutDoorFromRoom(Path room, Path door) {
    return Path.combine(PathOperation.difference, room, door);
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
    // Dispose existing controllers
    for (final controller in _roomControllers.values) {
      controller.dispose();
    }
    _roomControllers.clear();

    rooms.clear();
    doors.clear();

    // Restore rooms
    for (final room in state.rooms) {
      final restoredRoom = Room(
        id: room.id,
        path: Path.from(room.path),
        doorOpenings: room.doorOpenings.map((p) => Path.from(p)).toList(),
        fillColor: room.fillColor,
        name: room.name,
      );
      rooms.add(restoredRoom);
      // Initialize controller for restored room
      _roomControllers[restoredRoom.id] = TextEditingController(
        text: restoredRoom.name,
      );
    }

    // Restore doors
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

  /* =======================
     CANVAS SIZE CALCULATION
  ======================= */

  void _fitToView() {
    if (rooms.isEmpty && doors.isEmpty || _viewportSize == null) {
      // Reset to default view
      _transformationController.value = Matrix4.identity();
      return;
    }

    // Calculate content bounds
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

    // Add padding
    const padding = 50.0;
    final contentWidth = maxX - minX + padding * 2;
    final contentHeight = maxY - minY + padding * 2;
    final contentCenterX = (minX + maxX) / 2;
    final contentCenterY = (minY + maxY) / 2;

    // Use actual viewport size
    final viewportWidth = _viewportSize!.width;
    final viewportHeight = _viewportSize!.height;

    // Calculate scale to fit content
    final scaleX = viewportWidth / contentWidth;
    final scaleY = viewportHeight / contentHeight;
    final scale = math.min(scaleX, scaleY).clamp(0.1, 2.0);

    // Calculate translation to center content
    final translateX = viewportWidth / 2 - contentCenterX * scale;
    final translateY = viewportHeight / 2 - contentCenterY * scale;

    // Apply transformation
    _transformationController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  void _updateCanvasSize() {
    // If background image is present, use its dimensions
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

    // Calculate bounds from all rooms
    for (final room in rooms) {
      final bounds = room.path.getBounds();
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }

    // Calculate bounds from all doors
    for (final door in doors) {
      final bounds = door.path.getBounds();
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }

    // Add padding around the content
    const padding = 200.0;
    final width = (maxX - minX + padding * 2).clamp(2000.0, 20000.0);
    final height = (maxY - minY + padding * 2).clamp(2000.0, 20000.0);

    // Adjust canvas size, ensuring it's at least 4000x4000 for new drawings
    _canvasSize = Size(math.max(width, 4000), math.max(height, 4000));
  }

  /* =======================
     INTERACTION
  ======================= */

  void selectRoom(Offset pos) {
    // Don't select rooms when in polygon mode
    if (polygonMode) return;
    // If in door placement mode and a room is selected, try to place door on border
    if (doorPlacementMode && selectedRoom != null) {
      final edge = _findNearestEdge(pos, selectedRoom!);
      if (edge != null) {
        addDoorToRoomAtEdge(selectedRoom!, edge, pos);
        setState(() {
          doorPlacementMode = false;
        });
        return;
      }
    }

    // Check doors first
    for (final d in doors.reversed) {
      if (d.path.contains(pos)) {
        setState(() {
          selectedDoor = d;
          selectedRoom = null;
          activeHandle = null;
          doorPlacementMode = false;
        });
        return;
      }
    }

    // Check rooms
    for (final r in rooms.reversed) {
      final bounds = r.path.getBounds();
      final handle = hitTestHandle(pos, bounds);
      if (handle != null) {
        selectedRoom = r;
        selectedDoor = null;
        activeHandle = handle;
        startBounds = bounds;
        doorPlacementMode = false;
        setState(() {});
        return;
      }
      if (r.path.contains(pos)) {
        selectedRoom = r;
        selectedDoor = null;
        activeHandle = null;
        doorPlacementMode = false;
        setState(() {});
        return;
      }
    }
    setState(() {
      selectedRoom = null;
      selectedDoor = null;
      activeHandle = null;
      doorPlacementMode = false;
    });
  }

  String? _findNearestEdge(Offset pos, Room room) {
    final bounds = room.path.getBounds();
    const threshold = 15.0; // Distance threshold to detect edge clicks

    // Check distance to each edge
    final distToTop = (pos.dy - bounds.top).abs();
    final distToBottom = (pos.dy - bounds.bottom).abs();
    final distToLeft = (pos.dx - bounds.left).abs();
    final distToRight = (pos.dx - bounds.right).abs();

    // Also check if point is within bounds horizontally/vertically
    final onTopEdge =
        distToTop < threshold &&
        pos.dx >= bounds.left &&
        pos.dx <= bounds.right;
    final onBottomEdge =
        distToBottom < threshold &&
        pos.dx >= bounds.left &&
        pos.dx <= bounds.right;
    final onLeftEdge =
        distToLeft < threshold &&
        pos.dy >= bounds.top &&
        pos.dy <= bounds.bottom;
    final onRightEdge =
        distToRight < threshold &&
        pos.dy >= bounds.top &&
        pos.dy <= bounds.bottom;

    if (onTopEdge &&
        distToTop <= distToBottom &&
        distToTop <= distToLeft &&
        distToTop <= distToRight) {
      return 'top';
    }
    if (onBottomEdge &&
        distToBottom <= distToTop &&
        distToBottom <= distToLeft &&
        distToBottom <= distToRight) {
      return 'bottom';
    }
    if (onLeftEdge &&
        distToLeft <= distToTop &&
        distToLeft <= distToBottom &&
        distToLeft <= distToRight) {
      return 'left';
    }
    if (onRightEdge &&
        distToRight <= distToTop &&
        distToRight <= distToBottom &&
        distToRight <= distToLeft) {
      return 'right';
    }

    return null;
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

      // Scale door openings with the room
      for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
        selectedRoom!.doorOpenings[i] = scalePath(
          selectedRoom!.doorOpenings[i],
          sx,
          sy,
          anchor,
        );
      }

      // Scale associated doors using roomId
      for (final door in doors) {
        if (door.roomId == selectedRoom!.id) {
          door.path = scalePath(door.path, sx, sy, anchor);
        }
      }
    }

    setState(() {});
  }

  void moveSelected(Offset delta) {
    if (selectedRoom != null) {
      setState(() {
        selectedRoom!.path = selectedRoom!.path.shift(delta);
        // Move door openings with the room
        for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
          selectedRoom!.doorOpenings[i] = selectedRoom!.doorOpenings[i].shift(
            delta,
          );
        }
        // Move associated doors using roomId
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

  void rotateSelected() {
    if (selectedRoom != null) {
      _saveState();
      final bounds = selectedRoom!.path.getBounds();
      final roomCenter = bounds.center;
      setState(() {
        selectedRoom!.path = rotatePath(selectedRoom!.path, 90, roomCenter);

        // Rotate door openings
        for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
          selectedRoom!.doorOpenings[i] = rotatePath(
            selectedRoom!.doorOpenings[i],
            90,
            roomCenter,
          );
        }

        // Get new bounds after rotation
        final newBounds = selectedRoom!.path.getBounds();

        // Rotate and realign associated doors using roomId
        for (final door in doors) {
          if (door.roomId == selectedRoom!.id) {
            // Update door edge after rotation (clockwise: top->right->bottom->left->top)
            final edgeMap = {
              'top': 'right',
              'right': 'bottom',
              'bottom': 'left',
              'left': 'top',
            };
            door.edge = edgeMap[door.edge] ?? door.edge;

            // Rotate door path around room center
            door.path = rotatePath(door.path, 90, roomCenter);
            door.rotation = (door.rotation + 90) % 360;

            // Realign door to the new edge position
            final doorBounds = door.path.getBounds();
            final doorCenter = doorBounds.center;
            Offset newDoorCenter;

            switch (door.edge) {
              case 'top':
                newDoorCenter = Offset(
                  doorCenter.dx.clamp(
                    newBounds.left + 25,
                    newBounds.right - 25,
                  ),
                  newBounds.top,
                );
                break;
              case 'bottom':
                newDoorCenter = Offset(
                  doorCenter.dx.clamp(
                    newBounds.left + 25,
                    newBounds.right - 25,
                  ),
                  newBounds.bottom,
                );
                break;
              case 'left':
                newDoorCenter = Offset(
                  newBounds.left,
                  doorCenter.dy.clamp(
                    newBounds.top + 25,
                    newBounds.bottom - 25,
                  ),
                );
                break;
              case 'right':
                newDoorCenter = Offset(
                  newBounds.right,
                  doorCenter.dy.clamp(
                    newBounds.top + 25,
                    newBounds.bottom - 25,
                  ),
                );
                break;
              default:
                continue;
            }

            // Adjust door position to align with new edge
            final adjustment = newDoorCenter - doorCenter;
            door.path = door.path.shift(adjustment);

            // Ensure door opening is also aligned
            Path? matchingOpening;
            double minDistance = double.infinity;
            final adjustedDoorCenter = door.path.getBounds().center;

            for (final opening in selectedRoom!.doorOpenings) {
              final openingCenter = opening.getBounds().center;
              final distance = (openingCenter - adjustedDoorCenter).distance;

              if (distance < minDistance) {
                minDistance = distance;
                matchingOpening = opening;
              }
            }

            // Fine-tune alignment with opening if close
            if (matchingOpening != null && minDistance < 30) {
              final openingCenter = matchingOpening.getBounds().center;
              final fineAdjustment = openingCenter - adjustedDoorCenter;
              door.path = door.path.shift(fineAdjustment);
            }
          }
        }
      });
    } else if (selectedDoor != null) {
      final bounds = selectedDoor!.path.getBounds();
      setState(() {
        selectedDoor!.path = rotatePath(selectedDoor!.path, 90, bounds.center);
        selectedDoor!.rotation = (selectedDoor!.rotation + 90) % 360;
      });
    }
  }

  void addDoorToRoom(Room room) {
    // Enter door placement mode
    setState(() {
      doorPlacementMode = true;
      selectedRoom = room;
    });
  }

  void addDoorToRoomAtEdge(Room room, String edge, Offset clickPos) {
    _saveState();
    final bounds = room.path.getBounds();
    Offset doorCenter;
    Path doorPath;

    switch (edge) {
      case 'top':
        doorCenter = Offset(
          clickPos.dx.clamp(bounds.left + 25, bounds.right - 25),
          bounds.top,
        );
        doorPath = createDoor(doorCenter, width: 50, height: 12);
        break;
      case 'bottom':
        doorCenter = Offset(
          clickPos.dx.clamp(bounds.left + 25, bounds.right - 25),
          bounds.bottom,
        );
        doorPath = createDoor(doorCenter, width: 50, height: 12);
        break;
      case 'left':
        doorCenter = Offset(
          bounds.left,
          clickPos.dy.clamp(bounds.top + 25, bounds.bottom - 25),
        );
        // Rotate door for vertical placement
        doorPath = createDoor(doorCenter, width: 12, height: 50);
        break;
      case 'right':
        doorCenter = Offset(
          bounds.right,
          clickPos.dy.clamp(bounds.top + 25, bounds.bottom - 25),
        );
        // Rotate door for vertical placement
        doorPath = createDoor(doorCenter, width: 12, height: 50);
        break;
      default:
        return;
    }

    setState(() {
      // Cut door opening from room
      room.path = cutDoorFromRoom(room.path, doorPath);
      room.doorOpenings.add(doorPath);
      // Add door with room reference
      doors.add(
        Door(
          id: UniqueKey().toString(),
          path: doorPath,
          roomId: room.id,
          edge: edge,
        ),
      );
      _updateCanvasSize();
    });
  }

  /* =======================
     UI
  ======================= */

  void _handleDelete() {
    if (selectedRoom != null || selectedDoor != null) {
      _saveState();
      setState(() {
        if (selectedRoom != null) {
          // Dispose controller
          _roomControllers[selectedRoom!.id]?.dispose();
          _roomControllers.remove(selectedRoom!.id);
          // Remove all doors associated with this room
          doors.removeWhere((door) => door.roomId == selectedRoom!.id);
          rooms.remove(selectedRoom);
          selectedRoom = null;
        } else if (selectedDoor != null) {
          doors.remove(selectedDoor);
          selectedDoor = null;
        }
        _updateCanvasSize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Undo: Ctrl+Z (or Cmd+Z on Mac)
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
            const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const UndoIntent(),
        // Redo: Ctrl+Y or Ctrl+Shift+Z (or Cmd+Shift+Z on Mac)
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): const RedoIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): const RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
            const RedoIntent(),
        // // Delete: Delete or Backspace
        // LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),
        // LogicalKeySet(LogicalKeyboardKey.backspace): const DeleteIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              if (_canUndo) {
                _undo();
              }
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              if (_canRedo) {
                _redo();
              }
              return null;
            },
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (_) {
              _handleDelete();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(10),
                // padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenSize = MediaQuery.of(context).size;
                    final containerWidth = screenSize.width < 600
                        ? screenSize.width * 0.95
                        : screenSize.width < 1200
                        ? screenSize.width * 0.5
                        : screenSize.width * 0.6;

                    return ListView(
                      children: [
                        // Header (full width, not constrained)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TopHeader(
                            onLanguageChanged: () {},
                            containerWidth: containerWidth,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Content with width constraint
                        Center(
                          child: Container(
                            width: containerWidth,
                            child: Column(
                              children: [
                                // Progress indicator
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Fast geschafft, Stephan!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: 0.7,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                const Color(
                                                  0xFF8B9A5B,
                                                ), // Muted green color
                                              ),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Main content
                                Container(
                                  // margin: const EdgeInsets.symmetric(
                                  //   horizontal: 16,
                                  // ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Title
                                        PageHeaderRow(
                                          title: 'Grundriss aktivieren',
                                          showBackButton: true,
                                        ),
                                        const SizedBox(height: 16),
                                        // Canvas Area with dotted border
                                        DottedBorderContainer(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 300,
                                              minHeight: 300,
                                            ),
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(0),
                                                  child:
                                                      (rooms.isEmpty &&
                                                          _backgroundImageBytes ==
                                                              null &&
                                                          !polygonMode &&
                                                          !pencilMode)
                                                      ? Center(
                                                          // child: Column(
                                                          //   mainAxisAlignment:
                                                          //       MainAxisAlignment
                                                          //           .center,
                                                          //   children: [
                                                          //     Icon(
                                                          //       Icons
                                                          //           .image_outlined,
                                                          //       size: 64,
                                                          //       color: Colors
                                                          //           .grey[400],
                                                          //     ),
                                                          //     const SizedBox(
                                                          //       height: 16,
                                                          //     ),
                                                          //     Text(
                                                          //       'Kein Grundriss geladen',
                                                          //       style: TextStyle(
                                                          //         color: Colors
                                                          //             .grey[600],
                                                          //         fontSize: 16,
                                                          //       ),
                                                          //     ),
                                                          //   ],
                                                          // ),
                                                        )
                                                      : _buildCanvas(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Shape Options (shown when Add Room is clicked)
                                        if (_showShapeOptions)
                                          _shapeOptionsBar(),
                                        // Polygon completion buttons (show only if in polygon mode with points)
                                        if (polygonMode &&
                                            _polygonPoints.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                              top: 16,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_polygonPoints.length >= 3)
                                                  ElevatedButton.icon(
                                                    onPressed:
                                                        _createRoomFromPolygon,
                                                    icon: const Icon(
                                                      Icons.check,
                                                    ),
                                                    label: const Text(
                                                      'Polygon abschließen',
                                                    ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.green,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                  ),
                                                if (_polygonPoints.length >= 3)
                                                  const SizedBox(width: 16),
                                                ElevatedButton.icon(
                                                  onPressed: _cancelPolygon,
                                                  icon: const Icon(Icons.close),
                                                  label: const Text(
                                                    'Abbrechen',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        foregroundColor:
                                                            Colors.white,
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
                                              _showShapeOptions =
                                                  !_showShapeOptions;
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // Icon(
                                                //   Icons.add_box_outlined,
                                                //   color: Colors.grey[700],
                                                //   size: 20,
                                                // ),
                                                // const SizedBox(width: 8),
                                                Text(
                                                  '+ Raum anlegen',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Room List with TextField and Color Palette
                                        if (rooms.isNotEmpty)
                                          ...rooms.map((room) {
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(0),
                                                border: Border.all(
                                                  color: selectedRoom == room
                                                      ? Colors.blue
                                                      : Colors.grey[300]!,
                                                  width: selectedRoom == room
                                                      ? 2
                                                      : 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  // TextField for room name
                                                  Expanded(
                                                    child: TextField(
                                                      key: ValueKey(room.id),
                                                      controller:
                                                          _roomControllers[room
                                                                  .id] ??=
                                                              TextEditingController(
                                                                text: room.name,
                                                              ),
                                                      decoration:
                                                          const InputDecoration(
                                                            hintText:
                                                                'Raumname / Label',
                                                            border: InputBorder
                                                                .none,
                                                            contentPadding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
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
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: colorPalette.map((
                                                      color,
                                                    ) {
                                                      final isSelected =
                                                          room.fillColor ==
                                                          color;
                                                      return GestureDetector(
                                                        onTap: () {
                                                          _saveState();
                                                          setState(() {
                                                            room.fillColor =
                                                                color;
                                                          });
                                                        },
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                left: 6,
                                                              ),
                                                          width: 15,
                                                          height: 15,
                                                          decoration: BoxDecoration(
                                                            color: color,
                                                            border: Border.all(
                                                              color: isSelected
                                                                  ? Colors.black
                                                                  : Colors
                                                                        .grey[400]!,
                                                              width: isSelected
                                                                  ? 2
                                                                  : 1,
                                                            ),
                                                          ),
                                                          child: isSelected
                                                              ? Icon(
                                                                  Icons.clear,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .black,
                                                                )
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
                                                    onPressed: () {
                                                      _saveState();
                                                      setState(() {
                                                        // Dispose controller
                                                        _roomControllers[room
                                                                .id]
                                                            ?.dispose();
                                                        _roomControllers.remove(
                                                          room.id,
                                                        );
                                                        // Remove all doors associated with this room
                                                        doors.removeWhere(
                                                          (door) =>
                                                              door.roomId ==
                                                              room.id,
                                                        );
                                                        rooms.remove(room);
                                                        if (selectedRoom ==
                                                            room) {
                                                          selectedRoom = null;
                                                        }
                                                        _updateCanvasSize();
                                                      });
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        const SizedBox(height: 12),
                                        // Skip step link
                                        InkWell(
                                          onTap: widget.onSkip,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Schritt überspringen',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Save and Next button
                                        Center(
                                          child: PrimaryOutlineButton(
                                            label: _backgroundImageBytes != null
                                                ? 'Speichern & Weiter'
                                                : 'Das passt so',
                                            width: 260,
                                            enabled: rooms.isNotEmpty,
                                            onPressed:
                                                // _backgroundImageBytes != null
                                                _downloadSVG,
                                            // : widget.onComplete,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // App Footer (full width, not constrained)
                        Container(
                          color: Colors.black,
                          child: AppFooter(
                            onLanguageChanged: () {},
                            containerWidth: screenSize.width,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Store viewport size for fit calculations
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.1,
          maxScale: 4,
          child: Stack(
            children: [
              // Background image
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
                  if (polygonMode) {
                    _handlePolygonClick(d.localPosition);
                  } else if (!pencilMode) {
                    selectRoom(d.localPosition);
                  } else {
                    if (doorPlacementMode) {
                      setState(() {
                        doorPlacementMode = false;
                      });
                    }
                  }
                },
                onPanStart: (d) {
                  lastPanPosition = d.localPosition;
                  if (pencilMode) {
                    drawingPath = Path()
                      ..moveTo(d.localPosition.dx, d.localPosition.dy);
                  } else if (polygonMode) {
                    // Update preview position for polygon
                    setState(() {
                      _polygonPreviewPosition = d.localPosition;
                    });
                  }
                },
                onPanUpdate: (d) {
                  if (pencilMode) {
                    setState(() {
                      drawingPath!.lineTo(
                        d.localPosition.dx,
                        d.localPosition.dy,
                      );
                    });
                  } else if (polygonMode) {
                    // Update preview position for polygon
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
                      // Initialize controller for new room
                      _roomControllers[newRoom.id] = TextEditingController(
                        text: newRoom.name,
                      );
                      _roomCounter++;
                      drawingPath = null;
                      _updateCanvasSize();
                    });
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
                    hasBackgroundImage: _backgroundImageBytes != null,
                    polygonPoints: _polygonPoints,
                    polygonPreviewPosition: _polygonPreviewPosition,
                    polygonColor: selectedColor ?? colorPalette[0],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shapeOptionsBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(0),
            // border: Border.all(color: Colors.grey.shade300),
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
                  });
                },
                isSelected:
                    polygonMode || _selectedShapeTool == _ShapeTool.polygon,
              ),
              _shapeOptionButton(
                icon: 'assets/images/Rectangle.svg',
                label: "Rectangle",
                onTap: () {
                  setState(() {
                    _selectedShapeTool = _ShapeTool.rectangle;
                    polygonMode = false;
                  });
                  _addShapeToCanvas(
                    () => createRectangle(const Offset(200, 200)),
                  );
                },
                isSelected: _selectedShapeTool == _ShapeTool.rectangle,
              ),
              // const SizedBox(width: 12),
              // _shapeOptionButton(
              //   icon: Icons.crop_square,
              //   label: "L-shape",
              //   onTap: () {
              //     _addShapeToCanvas(() => createLShape(const Offset(200, 200)));
              //   },
              // ),
              // const SizedBox(width: 12),
              // _shapeOptionButton(
              //   icon: Icons.account_tree,
              //   label: "U-shape",
              //   onTap: () {
              //     _addShapeToCanvas(() => createUShape(const Offset(200, 200)));
              //   },
              // ),
              // const SizedBox(width: 12),
              // _shapeOptionButton(
              //   icon: Icons.call_split,
              //   label: "T-shape",
              //   onTap: () {
              //     _addShapeToCanvas(() => createTShape(const Offset(200, 200)));
              //   },
              // ),
              _shapeOptionButton(
                icon: 'assets/images/Triangle.svg',
                label: "Triangle",
                onTap: () {
                  setState(() {
                    _selectedShapeTool = _ShapeTool.triangle;
                    polygonMode = false;
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
                  });
                  _addShapeToCanvas(
                    () => createCircle(const Offset(200, 200), radius: 50),
                  );
                },
                isSelected: _selectedShapeTool == _ShapeTool.circle,
              ),

              // _shapeOptionButton(
              //   icon: Icons.edit,
              //   label: "Walls",
              //   onTap: () {
              //     setState(() {
              //       pencilMode = !pencilMode;
              //       if (!pencilMode) {
              //         drawingPath = null;
              //         doorPlacementMode = false;
              //       } else {
              //         polygonMode = false;
              //         _polygonPoints.clear();
              //         _polygonPreviewPosition = null;
              //       }
              //     });
              //   },
              //   isSelected: pencilMode,
              // ),
            ],
          ),
        ),
        // Undo Button
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

              // Redo Button
            ],
          ),
        ),
      ],
    );
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
      // Initialize controller for new room
      _roomControllers[newRoom.id] = TextEditingController(text: newRoom.name);
      _roomCounter++;
      _updateCanvasSize();
      // Fit view to show new shape after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToView();
      });
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

  void _createRoomFromPolygon() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Polygon muss mindestens 3 Punkte haben'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
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
      // Create controller for new room
      _roomControllers[roomId] = TextEditingController(text: roomName);
      _updateCanvasSize();
    });

    // Fit view to show new room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToView();
    });
  }

  void _cancelPolygon() {
    setState(() {
      _polygonPoints.clear();
      _polygonPreviewPosition = null;
      polygonMode = false;
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

  Widget _topBar() {
    return Container(
      height: 56,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
          const Text(
            "New project",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          const Text(
            "Ground floor",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const Spacer(),
          // New button
          TextButton.icon(
            onPressed: () => _createNew(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("New"),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
          const SizedBox(width: 8),
          // Open button
          TextButton.icon(
            onPressed: () => _openSVG(),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text("Open"),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
          const SizedBox(width: 8),
          // Background image button
          TextButton.icon(
            onPressed: () => _uploadBackgroundImage(),
            icon: const Icon(Icons.image, size: 18),
            label: const Text("Background"),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.close), onPressed: () {}),
          ElevatedButton.icon(
            onPressed: () => _downloadSVG(),
            icon: const Icon(Icons.save, size: 18),
            label: const Text("Save"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Create new floor plan
  void _createNew() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Floor Plan'),
        content: const Text(
          'This will clear all current rooms and doors. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveState();
              setState(() {
                // Dispose all controllers
                for (final controller in _roomControllers.values) {
                  controller.dispose();
                }
                _roomControllers.clear();
                rooms.clear();
                doors.clear();
                selectedRoom = null;
                selectedDoor = null;
                _roomCounter = 1;
                _updateCanvasSize();
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New floor plan created'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Create New'),
          ),
        ],
      ),
    );
  }

  // Upload background image
  Future<void> _uploadBackgroundImage() async {
    try {
      FilePickerResult? result;

      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg'],
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg'],
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.extension == 'png' ||
            file.extension == 'jpg' ||
            file.extension == 'jpeg') {
          Uint8List imageBytes;

          if (kIsWeb) {
            final bytes = file.bytes;
            if (bytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: Could not read file data'),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            imageBytes = bytes;
          } else {
            final filePath = file.path;
            if (filePath == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: Could not read file path'),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            imageBytes = await File(filePath).readAsBytes();
          }

          // Decode image to get dimensions
          final codec = await ui.instantiateImageCodec(imageBytes);
          final frame = await codec.getNextFrame();
          final image = frame.image;

          setState(() {
            _backgroundImageBytes = imageBytes;
            _backgroundImageWidth = image.width.toDouble();
            _backgroundImageHeight = image.height.toDouble();
            // Update canvas size to match image dimensions
            _updateCanvasSize();
          });

          image.dispose();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background image uploaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading background image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Open SVG file
  Future<void> _openSVG() async {
    try {
      FilePickerResult? result;

      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['svg'],
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['svg'],
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        String svgContent;

        if (kIsWeb) {
          if (file.bytes != null) {
            svgContent = String.fromCharCodes(file.bytes!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not read file data'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        } else {
          if (file.path != null) {
            // For non-web, you would read from file.path
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'File opening is currently only available on web',
                ),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not read file'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        }

        // Parse and load the SVG
        _loadFromSVG(svgContent);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor plan loaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Load rooms and doors from SVG content
  void _loadFromSVG(String svgContent) {
    try {
      final document = xml.XmlDocument.parse(svgContent);
      final newRooms = <Room>[];
      final newDoors = <Door>[];

      // Find all path elements (rooms)
      final pathElements = document.findAllElements('path');
      int roomIndex = 1;

      for (final pathElement in pathElements) {
        final pathData = pathElement.getAttribute('d');
        if (pathData == null || pathData.isEmpty) continue;

        // Skip door gap lines (they're usually small lines)
        final fill = pathElement.getAttribute('fill');

        // Check if this is a room (has fill color) or a door line (just stroke)
        if (fill != null && fill != 'none') {
          // This is a room - paths are in original coordinates, no adjustment needed
          final roomPath = _parseSVGPath(pathData);
          final fillColor = _hexToColor(fill);

          // Try to find room name from nearby text element
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

      // First, collect all text elements with their positions
      final textItems = <Map<String, dynamic>>[];
      for (final textElement in textElements) {
        final text = textElement.text.trim();
        if (text.isEmpty) continue;

        final x = double.tryParse(textElement.getAttribute('x') ?? '') ?? 0;
        final y = double.tryParse(textElement.getAttribute('y') ?? '') ?? 0;

        // Check if this is an area text (contains numbers and m²/m2/mÂ²)
        // Handle both UTF-8 encoded m² and potential encoding issues
        final normalizedText = text
            .toLowerCase()
            .replaceAll('mâ²', 'm²') // Fix encoding issue
            .replaceAll('mÂ²', 'm²') // Fix encoding issue
            .replaceAll('m2', 'm²'); // Handle m2 format
        // Match patterns like "3.00 m²", "3 m²", "3.0m²", etc.
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
        if (textItem['isArea'] == true) continue; // Skip area text

        final text = textItem['text'] as String;
        final textPos = textItem['position'] as Offset;

        if (newRooms.isEmpty) continue;

        // Find the nearest room to this text
        Room? nearestRoom;
        double minDistance = double.infinity;
        int nearestIndex = -1;

        for (int i = 0; i < newRooms.length; i++) {
          final room = newRooms[i];
          final bounds = room.path.getBounds();
          final center = bounds.center;
          final distance = (center - textPos).distance;

          // Prefer text that's above the room center (room names are typically above)
          final yOffset = textPos.dy - center.dy;
          final adjustedDistance =
              distance + (yOffset > 0 ? 50 : 0); // Penalize text below center

          if (adjustedDistance < minDistance) {
            minDistance = adjustedDistance;
            nearestRoom = room;
            nearestIndex = i;
          }
        }

        // Update room name if it's close enough (within 150 pixels)
        if (nearestRoom != null && nearestIndex != -1 && minDistance < 150) {
          // Double-check: ensure this is not area text (safety check)
          final normalizedText = text
              .toLowerCase()
              .replaceAll('mâ²', 'm²')
              .replaceAll('mÂ²', 'm²')
              .replaceAll('m2', 'm²');
          final looksLikeArea = RegExp(
            r'^\d+\.?\d*\s*m²\s*$',
            caseSensitive: false,
          ).hasMatch(normalizedText);

          // Skip if it looks like area text
          if (looksLikeArea) continue;

          // Only update if the room still has a default name or if this text is closer
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
        // Dispose existing controllers
        for (final controller in _roomControllers.values) {
          controller.dispose();
        }
        _roomControllers.clear();

        rooms.clear();
        doors.clear();
        rooms.addAll(newRooms);
        doors.addAll(newDoors);
        // Initialize controllers for all loaded rooms
        for (final room in newRooms) {
          _roomControllers[room.id] = TextEditingController(text: room.name);
        }
        selectedRoom = null;
        selectedDoor = null;
        _roomCounter = roomIndex;
        _updateCanvasSize();
      });

      // Fit view to show all content after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToView();
      });
    } catch (e) {
      debugPrint('Error parsing SVG: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing SVG: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Parse SVG path data string to Flutter Path
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

  // Parse path commands from SVG path data
  List<_PathCommand> _parsePathCommands(String pathData) {
    final commands = <_PathCommand>[];
    // Regex to match SVG path commands: M, L, H, V, C, Q, Z and their coordinates
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

  // Convert hex color string to Color
  Color? _hexToColor(String hex) {
    try {
      hex = hex.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  Widget _contextualBar() {
    String itemName = selectedRoom != null ? selectedRoom!.name : "Door";
    String dimensions = "";

    if (selectedRoom != null) {
      final bounds = selectedRoom!.path.getBounds();
      dimensions =
          "${bounds.width.toStringAsFixed(0)} cm × ${bounds.height.toStringAsFixed(0)} cm";
    } else if (selectedDoor != null) {
      final bounds = selectedDoor!.path.getBounds();
      dimensions =
          "${bounds.width.toStringAsFixed(0)} cm × ${bounds.height.toStringAsFixed(0)} cm";
    }

    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Editable room name
          if (selectedRoom != null)
            GestureDetector(
              onTap: () => _showNameEditor(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            )
          else
            Text(
              itemName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          const SizedBox(width: 8),
          Text(
            dimensions,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          if (selectedRoom != null) ...[
            const SizedBox(width: 16),
            // Color preview - clickable to change color
            GestureDetector(
              onTap: () => _showColorPicker(context),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selectedRoom!.fillColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 1),
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                selectedRoom = null;
                selectedDoor = null;
              });
            },
          ),
          if (selectedRoom != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showNameEditor(context),
            ),
        ],
      ),
    );
  }

  void _showNameEditor(BuildContext context) {
    if (selectedRoom == null) return;

    final controller = TextEditingController(text: selectedRoom!.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter room name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _saveState();
              setState(() {
                selectedRoom!.name = value.trim();
              });
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _saveState();
                setState(() {
                  selectedRoom!.name = controller.text.trim();
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _leftSidebar() {
    return Container(
      width: 64,
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(height: 24),
          Image.asset(
            'assets/images/bryteversebubbles.png',
            width: 40,
            height: 40,
          ),
          SizedBox(height: 20),
          // File operations
          _sidebarButton(Icons.add, "New", () => _createNew()),
          _sidebarButton(Icons.folder_open, "Open", () => _openSVG()),
          _sidebarButton(Icons.clear_all_outlined, "Clear All", () {
            _saveState();
            setState(() {
              // Clear all rooms and doors
              rooms.clear();
              doors.clear();
              // Clear selections
              selectedRoom = null;
              selectedDoor = null;
              // Clear drawing state
              drawingPath = null;
              pencilMode = false;
              doorPlacementMode = false;
              // Clear interaction state
              lastPanPosition = null;
              activeHandle = null;
              startBounds = null;
              // Reset color selection
              selectedColor = null;
              // Reset room counter
              _roomCounter = 1;
              _updateCanvasSize();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All items cleared'),
                duration: Duration(seconds: 2),
              ),
            );
          }),
          _sidebarButton(Icons.save, "Save", () => _downloadSVG()),
          _sidebarButton(Icons.fit_screen, "Fit to View", () {
            _fitToView();
          }),
          const Divider(),
          // Editing tools
          _sidebarButton(Icons.delete, "Delete", () {
            if (selectedRoom != null || selectedDoor != null) {
              _saveState();
              setState(() {
                if (selectedRoom != null) {
                  // Remove all doors associated with this room
                  doors.removeWhere((door) => door.roomId == selectedRoom!.id);
                  rooms.remove(selectedRoom);
                  selectedRoom = null;
                } else if (selectedDoor != null) {
                  doors.remove(selectedDoor);
                  selectedDoor = null;
                }
                _updateCanvasSize();
              });
            }
          }),
          _sidebarButton(Icons.rotate_right, "Rotation", rotateSelected),
          _sidebarButton(Icons.palette, "Color", () {
            if (selectedRoom != null) {
              _showColorPicker(context);
            }
          }),
          const Spacer(),
          _sidebarButton(Icons.undo, "Undo", _undo, enabled: _canUndo),
          _sidebarButton(Icons.redo, "Redo", _redo, enabled: _canRedo),
        ],
      ),
    );
  }

  Widget _sidebarButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
      ),
    );
  }

  Widget _rightSidebar() {
    return Container(
      width: 200,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color Palette Section
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Colors",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colorPalette.map((color) {
                final isSelected = selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    if (selectedRoom != null) {
                      _saveState();
                    }
                    setState(() {
                      selectedColor = color;
                      // Apply to selected room if one is selected
                      if (selectedRoom != null) {
                        selectedRoom!.fillColor = color;
                      }
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          // Structure Section
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Structure",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _structureButton(Icons.crop_square, "Square room", () {
                  _saveState();
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: createRectangle(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _updateCanvasSize();
                  });
                }),
                _structureButton(Icons.crop_square, "L-shape room", () {
                  _saveState();
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: createLShape(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _updateCanvasSize();
                  });
                }),
                _structureButton(Icons.account_tree, "U-shape room", () {
                  _saveState();
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: createUShape(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _updateCanvasSize();
                  });
                }),
                _structureButton(Icons.call_split, "T-shape room", () {
                  _saveState();
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: createTShape(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _updateCanvasSize();
                  });
                }),
                _structureButton(Icons.circle, "Circular room", () {
                  _saveState();
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: createCircle(const Offset(200, 200), radius: 50),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _updateCanvasSize();
                  });
                }),
                _structureButton(Icons.edit, "Walls", () {
                  setState(() {
                    pencilMode = !pencilMode;
                    if (!pencilMode) {
                      drawingPath = null;
                      // Cancel door placement mode if active
                      doorPlacementMode = false;
                    }
                  });
                }, isSelected: pencilMode),
                _structureButton(Icons.stairs, "Stairs", () {}),
                _structureButton(Icons.meeting_room, "Add Door", () {
                  if (selectedRoom != null) {
                    addDoorToRoom(selectedRoom!);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Room Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colorPalette.map((color) {
            final isSelected = selectedRoom?.fillColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedRoom != null) {
                  _saveState();
                  setState(() {
                    selectedRoom!.fillColor = color;
                    selectedColor = color;
                  });
                }
                Navigator.of(context).pop();
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Convert Path to SVG path data string by sampling points
  String _pathToSvgPathData(Path path) {
    final metrics = path.computeMetrics();
    final buffer = StringBuffer();
    bool isFirst = true;

    for (final metric in metrics) {
      // Sample points along the path
      final length = metric.length;
      final sampleCount = math.max(
        10,
        (length / 10).ceil(),
      ); // Sample every 10 pixels
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
          // Check if path is closed (first and last points are close)
          if ((firstPoint - lastPoint).distance < 1.0) {
            buffer.write('Z ');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  // Convert Color to hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';
  }

  // Generate SVG content from rooms and doors
  Future<String> _generateSVG() async {
    // Use background image dimensions if available, otherwise calculate from rooms
    double width;
    double height;
    double viewBoxX = 0;
    double viewBoxY = 0;

    if (_backgroundImageBytes != null &&
        _backgroundImageWidth != null &&
        _backgroundImageHeight != null) {
      // Use exact background image dimensions
      width = _backgroundImageWidth!;
      height = _backgroundImageHeight!;
      // viewBox starts at (0,0) to match the image exactly
    } else {
      // Calculate overall bounds from rooms and doors
      if (rooms.isEmpty && doors.isEmpty) {
        width = 2000;
        height = 2000;
      } else {
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = double.negativeInfinity;
        double maxY = double.negativeInfinity;

        // Calculate bounds from all rooms
        for (final room in rooms) {
          final bounds = room.path.getBounds();
          minX = math.min(minX, bounds.left);
          minY = math.min(minY, bounds.top);
          maxX = math.max(maxX, bounds.right);
          maxY = math.max(maxY, bounds.bottom);
        }

        // Calculate bounds from all doors
        for (final door in doors) {
          final bounds = door.path.getBounds();
          minX = math.min(minX, bounds.left);
          minY = math.min(minY, bounds.top);
          maxX = math.max(maxX, bounds.right);
          maxY = math.max(maxY, bounds.bottom);
        }

        // Add padding around content
        const padding = 100.0;
        final contentWidth = maxX - minX;
        final contentHeight = maxY - minY;

        // Calculate SVG dimensions with padding
        width = contentWidth + (padding * 2);
        height = contentHeight + (padding * 2);

        // ViewBox starts at the minimum coordinates minus padding
        // This ensures all content is visible and centered
        viewBoxX = minX - padding;
        viewBoxY = minY - padding;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" '
      'width="${width.toStringAsFixed(0)}" '
      'height="${height.toStringAsFixed(0)}" '
      'viewBox="${viewBoxX.toStringAsFixed(2)} ${viewBoxY.toStringAsFixed(2)} ${width.toStringAsFixed(2)} ${height.toStringAsFixed(2)}">',
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

      // Add background image - positioned at (0,0) with exact dimensions
      buffer.writeln(
        '  <image x="0" y="0" width="$width" height="$height" '
        'xlink:href="data:image/$imageType;base64,$base64Image" '
        'preserveAspectRatio="none"/>',
      );
    } else {
      // Default background color
      buffer.writeln(
        '  <rect x="0" y="0" width="$width" height="$height" fill="#E3F2FD"/>',
      );
    }

    // Draw rooms (using original coordinates, viewBox handles the viewport)
    for (final room in rooms) {
      final pathData = _pathToSvgPathData(room.path);
      final fillColor = _colorToHex(room.fillColor);

      // Room fill
      buffer.writeln(
        '  <path d="$pathData" fill="$fillColor" stroke="#424242" stroke-width="3"/>',
      );

      // Room name and area (as text) - using original coordinates
      final bounds = room.path.getBounds();
      final center = bounds.center;
      final area = _calculateArea(room.path);
      buffer.writeln(
        '  <text x="${center.dx.toStringAsFixed(2)}" y="${center.dy.toStringAsFixed(2)}" '
        'text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000000">${room.name}</text>',
      );
      buffer.writeln(
        '  <text x="${center.dx.toStringAsFixed(2)}" y="${(center.dy + 20).toStringAsFixed(2)}" '
        'text-anchor="middle" font-family="Arial" font-size="14" fill="#000000">${area.toStringAsFixed(2)} m²</text>',
      );
    }

    // Draw doors (as gaps with swing arcs) - using original coordinates
    for (final door in doors) {
      final bounds = door.path.getBounds();
      final center = bounds.center;
      final doorLength = math.max(bounds.width, bounds.height);

      // Calculate door opening lines (using original coordinates)
      Offset doorLineStart;
      Offset doorLineEnd;

      switch (door.edge) {
        case 'top':
          doorLineStart = Offset(center.dx - doorLength / 2, center.dy);
          doorLineEnd = Offset(center.dx + doorLength / 2, center.dy);
          break;
        case 'bottom':
          doorLineStart = Offset(center.dx - doorLength / 2, center.dy);
          doorLineEnd = Offset(center.dx + doorLength / 2, center.dy);
          break;
        case 'left':
          doorLineStart = Offset(center.dx, center.dy - doorLength / 2);
          doorLineEnd = Offset(center.dx, center.dy + doorLength / 2);
          break;
        case 'right':
          doorLineStart = Offset(center.dx, center.dy - doorLength / 2);
          doorLineEnd = Offset(center.dx, center.dy + doorLength / 2);
          break;
        default:
          continue;
      }
      ;

      // Draw door gap lines
      if (door.edge == 'top' || door.edge == 'bottom') {
        buffer.writeln(
          '  <line x1="${doorLineStart.dx}" y1="${doorLineStart.dy}" '
          'x2="${doorLineStart.dx}" y2="${doorLineStart.dy - (door.edge == 'top' ? 8 : -8)}" '
          'stroke="#000000" stroke-width="2"/>',
        );
        buffer.writeln(
          '  <line x1="${doorLineEnd.dx}" y1="${doorLineEnd.dy}" '
          'x2="${doorLineEnd.dx}" y2="${doorLineEnd.dy - (door.edge == 'top' ? 8 : -8)}" '
          'stroke="#000000" stroke-width="2"/>',
        );
      } else {
        buffer.writeln(
          '  <line x1="${doorLineStart.dx}" y1="${doorLineStart.dy}" '
          'x2="${doorLineStart.dx - (door.edge == 'left' ? 8 : -8)}" y2="${doorLineStart.dy}" '
          'stroke="#000000" stroke-width="2"/>',
        );
        buffer.writeln(
          '  <line x1="${doorLineEnd.dx}" y1="${doorLineEnd.dy}" '
          'x2="${doorLineEnd.dx - (door.edge == 'left' ? 8 : -8)}" y2="${doorLineEnd.dy}" '
          'stroke="#000000" stroke-width="2"/>',
        );
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  // Upload SVG file and navigate to next page
  Future<void> _downloadSVG() async {
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rooms to export'),
          duration: Duration(seconds: 2),
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SVG uploaded successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Prepare rooms data for navigation
          final roomsData = rooms.map((room) {
            return {
              'id': room.id,
              'name': room.name,
              'color': room.fillColor.value.toString(),
              'area': _calculateArea(room.path),
            };
          }).toList();

          // Get query parameters from current route
          final routeState = GoRouterState.of(context);
          final queryParams = routeState.uri.queryParameters;

          // Navigate to building summary page
          if (mounted) {
            context.pushNamed(
              Routelists.buildingSummary,
              queryParameters: {
                if (queryParams['userName'] != null)
                  'userName': queryParams['userName']!,
                if (queryParams['buildingAddress'] != null)
                  'buildingAddress': queryParams['buildingAddress']!,
                if (queryParams['buildingName'] != null)
                  'buildingName': queryParams['buildingName']!,
                if (queryParams['buildingSize'] != null)
                  'buildingSize': queryParams['buildingSize']!,
                if (queryParams['numberOfRooms'] != null)
                  'numberOfRooms': queryParams['numberOfRooms']!,
                if (queryParams['constructionYear'] != null)
                  'constructionYear': queryParams['constructionYear']!,
                'floorPlanUrl': state.url,
                'rooms': Uri.encodeComponent(jsonEncode(roomsData)),
              },
            );
          }
        } else if (state is UploadFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error generating SVG: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting SVG: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Calculate room area (helper method)
  double _calculateArea(Path path) {
    final bounds = path.getBounds();
    return bounds.width * bounds.height / 10000; // Convert to m²
  }

  Widget _structureButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.blue : null),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

/* =======================
   PAINTER
======================= */

class FloorPainter extends CustomPainter {
  final List<Room> rooms;
  final List<Door> doors;
  final Room? selectedRoom;
  final Door? selectedDoor;
  final Path? previewPath;
  final bool hasBackgroundImage;
  final List<Offset> polygonPoints;
  final Offset? polygonPreviewPosition;
  final Color polygonColor;

  FloorPainter({
    required this.rooms,
    required this.doors,
    this.selectedRoom,
    this.selectedDoor,
    this.previewPath,
    this.hasBackgroundImage = false,
    this.polygonPoints = const [],
    this.polygonPreviewPosition,
    this.polygonColor = const Color(0xFFFFB74D),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw rooms with custom colors and dark gray walls
    for (final room in rooms) {
      // Room fill - use room's custom color
      final fillPaint = Paint()
        ..color = room.fillColor
        ..style = PaintingStyle.fill;

      // Wall border - dark gray
      final borderPaint = Paint()
        ..color =
            const Color(0xFF424242) // Dark gray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawPath(room.path, fillPaint);

      // Draw border following the actual path shape
      // Draw border segments, skipping door openings
      _drawRoomBorderWithDoors(canvas, room, borderPaint);

      // Draw room area
      final bounds = room.path.getBounds();
      final area = _calculateArea(room.path);
      _drawRoomArea(canvas, bounds.center, area, room.name);

      // Draw resize handles for selected room
      if (room == selectedRoom) {
        final b = room.path.getBounds();
        final hPaint = Paint()..color = Colors.red;
        const s = 6.0;

        // Draw handles at all four corners
        canvas.drawRect(
          Rect.fromLTWH(b.left - s, b.top - s, s * 2, s * 2),
          hPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(b.right - s, b.top - s, s * 2, s * 2),
          hPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(b.left - s, b.bottom - s, s * 2, s * 2),
          hPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(b.right - s, b.bottom - s, s * 2, s * 2),
          hPaint,
        );
      }
    }

    // Draw doors with swing arcs
    for (final door in doors) {
      _drawDoorWithSwing(canvas, door);
    }

    // Draw dimensions
    _drawDimensions(canvas, rooms);

    // Draw selection highlight
    if (selectedRoom != null) {
      final b = selectedRoom!.path.getBounds();
      canvas.drawRect(
        b.inflate(4),
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (selectedDoor != null) {
      final b = selectedDoor!.path.getBounds();
      canvas.drawRect(
        b.inflate(4),
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (previewPath != null) {
      canvas.drawPath(
        previewPath!,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
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
  }

  double _calculateArea(Path path) {
    // Simple approximation: use bounding box area
    final bounds = path.getBounds();
    return (bounds.width * bounds.height) /
        10000; // Convert to m² (assuming pixels are cm)
  }

  void _drawRoomArea(
    Canvas canvas,
    Offset center,
    double area,
    String roomName,
  ) {
    // Draw room name
    final namePainter = TextPainter(
      text: TextSpan(
        text: roomName,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(
      canvas,
      center - Offset(namePainter.width / 2, namePainter.height / 2 - 12),
    );

    // Draw area below name
    final areaPainter = TextPainter(
      text: TextSpan(
        text: "${area.toStringAsFixed(2)} m²",
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    areaPainter.layout();
    areaPainter.paint(
      canvas,
      center - Offset(areaPainter.width / 2, areaPainter.height / 2 + 8),
    );
  }

  void _drawDoorWithSwing(Canvas canvas, Door door) {
    final bounds = door.path.getBounds();
    final center = bounds.center;
    final doorWidth = math.max(bounds.width, bounds.height);
    // Door panel length matches the door opening size (the cutout)
    final doorPanelLength = doorWidth;
    final doorPanelThickness = 2.5; // Thickness of door panel line
    // Arc radius matches the door opening size (the cutout)
    final arcRadius = doorWidth;

    final doorPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = doorPanelThickness;

    // Light fill paint for arc enclosure
    final arcFillPaint = Paint()
      ..color = Colors.grey.shade200.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Border paint for arc
    final arcBorderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Offset doorHingePoint;
    Offset doorEndPoint; // Door panel end point (in open position, 90 degrees)
    Offset arcCenter;
    double startAngle;
    double sweepAngle;

    switch (door.edge) {
      case 'top':
        // Door on top edge, hinged on LEFT, swings down/right (into room)
        // Hinge is at the left end so arc starts from the right (cut edge)
        doorHingePoint = Offset(center.dx - doorWidth / 2, center.dy);
        // Door panel rotated 90 degrees down from wall
        doorEndPoint = Offset(
          center.dx - doorWidth / 2,
          center.dy + doorPanelLength,
        );
        // Arc center is at the hinge (left end), arc starts from right (cut edge) and sweeps down
        arcCenter = doorHingePoint;
        startAngle =
            0; // Start at 0 degrees (pointing right along the wall - the cut edge)
        sweepAngle = math.pi / 2; // 90 degree arc swinging down into the room
        break;
      case 'bottom':
        // Door on bottom edge, hinged on left, swings up/right (into room)
        doorHingePoint = Offset(center.dx - doorWidth / 2, center.dy);
        // Door panel rotated 90 degrees up from wall
        doorEndPoint = Offset(
          center.dx - doorWidth / 2,
          center.dy - doorPanelLength,
        );
        arcCenter = doorHingePoint;
        startAngle = -math.pi / 2; // Start at -90 degrees (pointing up)
        sweepAngle = math.pi / 2; // 90 degree arc
        break;
      case 'left':
        // Door on left edge, hinged on top, swings right/down (into room)
        doorHingePoint = Offset(center.dx, center.dy - doorWidth / 2);
        // Door panel rotated 90 degrees right from wall
        doorEndPoint = Offset(
          center.dx + doorPanelLength,
          center.dy - doorWidth / 2,
        );
        arcCenter = doorHingePoint;
        startAngle = 0; // Start at 0 degrees (pointing right)
        sweepAngle = math.pi / 2; // 90 degree arc
        break;
      case 'right':
        // Door on right edge, hinged on BOTTOM, swings left/up (into room)
        // Hinge is at the bottom end so arc starts from the top (cut edge)
        doorHingePoint = Offset(center.dx, center.dy + doorWidth / 2);
        // Door panel rotated 90 degrees left from wall
        doorEndPoint = Offset(
          center.dx - doorPanelLength,
          center.dy + doorWidth / 2,
        );
        // Arc center is at the hinge (bottom end), arc starts from top (cut edge)
        arcCenter = doorHingePoint;
        startAngle =
            -math.pi /
            2; // Start at -90 degrees (pointing up along the wall - the cut edge)
        sweepAngle = -math.pi / 2; // 90 degree arc swinging left
        break;
      default:
        return;
    }

    // Draw door panel (straight line from hinge to end point, showing door in open position at 90 degrees)
    canvas.drawLine(doorHingePoint, doorEndPoint, doorPaint);

    // Create enclosed arc path (quarter circle sector showing swing direction)
    final arcPath = Path();
    final arcRect = Rect.fromCircle(center: arcCenter, radius: arcRadius);

    // Move to center (hinge point)
    arcPath.moveTo(arcCenter.dx, arcCenter.dy);

    // Draw line to start of arc (from hinge to arc start)
    final arcStartX = arcCenter.dx + arcRadius * math.cos(startAngle);
    final arcStartY = arcCenter.dy + arcRadius * math.sin(startAngle);
    arcPath.lineTo(arcStartX, arcStartY);

    // Draw quarter-circle arc showing door swing (90 degrees)
    arcPath.arcTo(arcRect, startAngle, sweepAngle, false);

    // Close path back to center (hinge point) to create enclosed sector
    arcPath.close();

    // Draw filled arc enclosure with light background
    canvas.drawPath(arcPath, arcFillPaint);

    // Draw border around the arc enclosure
    canvas.drawPath(arcPath, arcBorderPaint);
  }

  void _drawRoomBorderWithDoors(Canvas canvas, Room room, Paint borderPaint) {
    // Get the path outline
    final pathMetrics = room.path.computeMetrics();

    for (final metric in pathMetrics) {
      final path = metric.extractPath(0, metric.length);

      // Draw the path border
      canvas.drawPath(path, borderPaint);

      // For each door opening, cover the border with canvas color to create gap
      for (final doorOpening in room.doorOpenings) {
        final openingBounds = doorOpening.getBounds();

        // Draw canvas background color to create gap in border
        // Use transparent if background image is present, otherwise use light blue
        final gapPaint = Paint()
          ..color = hasBackgroundImage
              ? Colors
                    .transparent // Transparent when background image is present
              : const Color(0xFFE3F2FD) // Canvas background color (light blue)
          ..style = PaintingStyle.fill;

        // Create a wider rectangle to cover the border line
        final gapRect = openingBounds.inflate(4);
        canvas.drawRect(gapRect, gapPaint);

        // Redraw room fill inside the opening (use room's actual color)
        final roomFillPaint = Paint()
          ..color = room.fillColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(openingBounds, roomFillPaint);
      }
    }
  }

  void _drawDimensions(Canvas canvas, List<Room> rooms) {
    if (rooms.isEmpty) return;

    // Get overall bounds
    Rect? overallBounds;
    for (final room in rooms) {
      final bounds = room.path.getBounds();
      if (overallBounds == null) {
        overallBounds = bounds;
      } else {
        overallBounds = overallBounds.expandToInclude(bounds);
      }
    }

    if (overallBounds == null) return;

    final dimPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textStyle = const TextStyle(color: Colors.green, fontSize: 12);

    // Draw horizontal dimensions
    _drawDimensionLine(
      canvas,
      Offset(overallBounds.left, overallBounds.top - 20),
      Offset(overallBounds.right, overallBounds.top - 20),
      (overallBounds.width / 10).toStringAsFixed(0),
      dimPaint,
      textStyle,
    );

    // Draw vertical dimensions
    _drawDimensionLine(
      canvas,
      Offset(overallBounds.left - 20, overallBounds.top),
      Offset(overallBounds.left - 20, overallBounds.bottom),
      (overallBounds.height / 10).toStringAsFixed(0),
      dimPaint,
      textStyle,
      vertical: true,
    );
  }

  void _drawDimensionLine(
    Canvas canvas,
    Offset start,
    Offset end,
    String label,
    Paint paint,
    TextStyle textStyle, {
    bool vertical = false,
  }) {
    canvas.drawLine(start, end, paint);

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final labelPos = Offset(
      (start.dx + end.dx) / 2 - textPainter.width / 2,
      (start.dy + end.dy) / 2 - textPainter.height / 2,
    );

    textPainter.paint(canvas, labelPos);
  }

  @override
  bool shouldRepaint(FloorPainter oldDelegate) {
    return rooms != oldDelegate.rooms ||
        doors != oldDelegate.doors ||
        selectedRoom != oldDelegate.selectedRoom ||
        selectedDoor != oldDelegate.selectedDoor ||
        previewPath != oldDelegate.previewPath ||
        hasBackgroundImage != oldDelegate.hasBackgroundImage ||
        polygonPoints != oldDelegate.polygonPoints ||
        polygonPreviewPosition != oldDelegate.polygonPreviewPosition ||
        polygonColor != oldDelegate.polygonColor;
  }
}

// Helper class for type checking
abstract class PlanItem {
  Path get path;
}

// Intent classes for keyboard shortcuts
class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}
