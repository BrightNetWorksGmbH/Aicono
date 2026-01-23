import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';

class DashboardRoomDetailsResponse {
  final bool success;
  final DashboardRoomDetails? data;

  DashboardRoomDetailsResponse({
    required this.success,
    required this.data,
  });

  factory DashboardRoomDetailsResponse.fromJson(Map<String, dynamic> json) {
    return DashboardRoomDetailsResponse(
      success: json['success'] == true,
      data: (json['data'] is Map<String, dynamic>)
          ? DashboardRoomDetails.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardRoomDetails {
  final String id;
  final String name;
  final String color;
  final String floorId;
  final DashboardLoxoneRoomInfo? loxoneRoomId;
  final int sensorCount;
  final List<dynamic> sensors;
  final DashboardKpis? kpis;
  final DashboardRoomMeasurements? measurements;
  final DashboardTimeRange? timeRange;

  DashboardRoomDetails({
    required this.id,
    required this.name,
    required this.color,
    required this.floorId,
    required this.loxoneRoomId,
    required this.sensorCount,
    required this.sensors,
    required this.kpis,
    required this.measurements,
    required this.timeRange,
  });

  factory DashboardRoomDetails.fromJson(Map<String, dynamic> json) {
    final rawSensors = json['sensors'];
    final sensors = (rawSensors is List) ? rawSensors : <dynamic>[];

    return DashboardRoomDetails(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      color: (json['color'] ?? '#000000').toString(),
      floorId: (json['floorId'] ?? '').toString(),
      loxoneRoomId: (json['loxone_room_id'] is Map<String, dynamic>)
          ? DashboardLoxoneRoomInfo.fromJson(
              json['loxone_room_id'] as Map<String, dynamic>,
            )
          : null,
      sensorCount: (json['sensor_count'] is int)
          ? json['sensor_count'] as int
          : int.tryParse('${json['sensor_count']}') ?? 0,
      sensors: sensors,
      kpis: (json['kpis'] is Map<String, dynamic>)
          ? DashboardKpis.fromJson(json['kpis'] as Map<String, dynamic>)
          : null,
      measurements: (json['measurements'] is Map<String, dynamic>)
          ? DashboardRoomMeasurements.fromJson(
              json['measurements'] as Map<String, dynamic>,
            )
          : null,
      timeRange: (json['time_range'] is Map<String, dynamic>)
          ? DashboardTimeRange.fromJson(json['time_range'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardRoomMeasurements {
  final List<dynamic> data;
  final int count;
  final int resolution;
  final String resolutionLabel;

  DashboardRoomMeasurements({
    required this.data,
    required this.count,
    required this.resolution,
    required this.resolutionLabel,
  });

  factory DashboardRoomMeasurements.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = (rawData is List) ? rawData : <dynamic>[];

    return DashboardRoomMeasurements(
      data: data,
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse('${json['count']}') ?? 0,
      resolution: (json['resolution'] is int)
          ? json['resolution'] as int
          : int.tryParse('${json['resolution']}') ?? 0,
      resolutionLabel: (json['resolution_label'] ?? '').toString(),
    );
  }
}
