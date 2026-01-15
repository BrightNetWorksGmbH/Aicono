import 'package:equatable/equatable.dart';

class LoxoneRoom extends Equatable {
  final String id;
  final String name;
  final String buildingId;
  final String loxoneRoomUuid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LoxoneRoom({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.loxoneRoomUuid,
    this.createdAt,
    this.updatedAt,
  });

  factory LoxoneRoom.fromJson(Map<String, dynamic> json) {
    return LoxoneRoom(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      buildingId: json['building_id']?.toString() ?? '',
      loxoneRoomUuid: json['loxone_room_uuid']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'building_id': buildingId,
      'loxone_room_uuid': loxoneRoomUuid,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, buildingId, loxoneRoomUuid, createdAt, updatedAt];
}

class LoxoneRoomsResponse extends Equatable {
  final bool success;
  final String? message;
  final List<LoxoneRoom> rooms;

  const LoxoneRoomsResponse({
    required this.success,
    this.message,
    required this.rooms,
  });

  factory LoxoneRoomsResponse.fromJson(dynamic json) {
    // Handle both array response and wrapped object response
    List<dynamic> roomsList;
    
    if (json is List) {
      // Direct array response
      roomsList = json;
    } else if (json is Map<String, dynamic>) {
      // Wrapped in object with 'data' or 'rooms' field
      roomsList = json['data'] ?? json['rooms'] ?? [];
    } else {
      roomsList = [];
    }

    return LoxoneRoomsResponse(
      success: json is Map<String, dynamic> ? (json['success'] ?? true) : true,
      message: json is Map<String, dynamic> ? json['message'] : null,
      rooms: roomsList
          .map((room) => LoxoneRoom.fromJson(room as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [success, message, rooms];
}

