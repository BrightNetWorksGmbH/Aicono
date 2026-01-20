import 'package:frontend_aicono/features/switch_creation/domain/entities/save_floor_entity.dart';

class FloorDetail {
  final String id;
  final String buildingId;
  final String name;
  final String? floorPlanLink;
  final List<FloorRoom> rooms;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FloorDetail({
    required this.id,
    required this.buildingId,
    required this.name,
    this.floorPlanLink,
    required this.rooms,
    this.createdAt,
    this.updatedAt,
  });

  factory FloorDetail.fromJson(Map<String, dynamic> json) {
    List<FloorRoom> roomsList = [];
    if (json['rooms'] != null && json['rooms'] is List) {
      roomsList = (json['rooms'] as List)
          .map((r) {
            if (r is Map<String, dynamic>) {
              return FloorRoom(
                name: r['name'] ?? '',
                color: r['color'] ?? '#FF5733',
                loxoneRoomId: r['loxone_room_id'] ?? r['loxoneRoomId'] ?? '',
              );
            }
            return FloorRoom(
              name: '',
              color: '#FF5733',
              loxoneRoomId: '',
            );
          })
          .toList();
    }

    return FloorDetail(
      id: json['_id'] ?? json['id'] ?? '',
      buildingId: json['building_id'] ?? json['buildingId'] ?? '',
      name: json['name'] ?? '',
      floorPlanLink: json['floor_plan_link'] ?? json['floorPlanLink'],
      rooms: roomsList,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

class GetFloorsResponse {
  final bool success;
  final String message;
  final List<FloorDetail> floors;

  GetFloorsResponse({
    required this.success,
    required this.message,
    required this.floors,
  });

  factory GetFloorsResponse.fromJson(dynamic json) {
    // Handle both array response and wrapped response
    List<FloorDetail> floors = [];
    
    if (json is List) {
      // Direct array response
      floors = json
          .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
          .toList();
    } else if (json is Map<String, dynamic>) {
      // Wrapped response
      if (json['data'] != null && json['data'] is List) {
        floors = (json['data'] as List)
            .map((f) => FloorDetail.fromJson(f as Map<String, dynamic>))
            .toList();
      }
    }

    return GetFloorsResponse(
      success: json is Map<String, dynamic> ? (json['success'] ?? true) : true,
      message: json is Map<String, dynamic>
          ? (json['message'] ?? 'Floors fetched successfully')
          : 'Floors fetched successfully',
      floors: floors,
    );
  }
}

