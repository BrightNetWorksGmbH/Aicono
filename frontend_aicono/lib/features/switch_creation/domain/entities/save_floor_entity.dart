import 'package:equatable/equatable.dart';

class FloorRoom extends Equatable {
  final String name;
  final String color;
  final String loxoneRoomId;

  const FloorRoom({
    required this.name,
    required this.color,
    required this.loxoneRoomId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
      'loxone_room_id': loxoneRoomId,
    };
  }

  @override
  List<Object?> get props => [name, color, loxoneRoomId];
}

class SaveFloorRequest extends Equatable {
  final String name;
  final String floorPlanLink;
  final List<FloorRoom> rooms;

  const SaveFloorRequest({
    required this.name,
    required this.floorPlanLink,
    required this.rooms,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'floor_plan_link': floorPlanLink,
      'rooms': rooms.map((room) => room.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [name, floorPlanLink, rooms];
}

class SaveFloorResponse extends Equatable {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const SaveFloorResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory SaveFloorResponse.fromJson(Map<String, dynamic> json) {
    return SaveFloorResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  @override
  List<Object?> get props => [success, message, data];
}

