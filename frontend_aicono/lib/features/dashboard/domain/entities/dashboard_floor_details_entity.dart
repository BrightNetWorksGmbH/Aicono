import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';

class DashboardFloorDetailsResponse {
  final bool success;
  final DashboardFloorDetails? data;

  DashboardFloorDetailsResponse({
    required this.success,
    required this.data,
  });

  factory DashboardFloorDetailsResponse.fromJson(Map<String, dynamic> json) {
    return DashboardFloorDetailsResponse(
      success: json['success'] == true,
      data: (json['data'] is Map<String, dynamic>)
          ? DashboardFloorDetails.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardFloorDetails {
  final String id;
  final String name;
  final String buildingId;
  final String? floorPlanLink;
  final int roomCount;
  final int sensorCount;
  final List<DashboardRoom> rooms;
  final DashboardKpis? kpis;
  final DashboardTimeRange? timeRange;

  DashboardFloorDetails({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.floorPlanLink,
    required this.roomCount,
    required this.sensorCount,
    required this.rooms,
    required this.kpis,
    required this.timeRange,
  });

  factory DashboardFloorDetails.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'];
    final rooms = (rawRooms is List)
        ? rawRooms
            .whereType<Map>()
            .map((e) {
              final map = <String, dynamic>{};
              e.forEach((key, value) {
                map[key.toString()] = value;
              });
              return DashboardRoom.fromJson(map);
            })
            .toList()
        : <DashboardRoom>[];

    return DashboardFloorDetails(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      buildingId: (json['buildingId'] ?? '').toString(),
      floorPlanLink: json['floor_plan_link']?.toString(),
      roomCount: (json['room_count'] is int)
          ? json['room_count'] as int
          : int.tryParse('${json['room_count']}') ?? 0,
      sensorCount: (json['sensor_count'] is int)
          ? json['sensor_count'] as int
          : int.tryParse('${json['sensor_count']}') ?? 0,
      rooms: rooms,
      kpis: (json['kpis'] is Map<String, dynamic>)
          ? DashboardKpis.fromJson(json['kpis'] as Map<String, dynamic>)
          : null,
      timeRange: (json['time_range'] is Map<String, dynamic>)
          ? DashboardTimeRange.fromJson(json['time_range'] as Map<String, dynamic>)
          : null,
    );
  }
}
