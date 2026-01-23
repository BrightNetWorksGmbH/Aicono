import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';

class DashboardBuildingDetailsResponse {
  final bool success;
  final DashboardBuildingDetails? data;

  DashboardBuildingDetailsResponse({
    required this.success,
    required this.data,
  });

  factory DashboardBuildingDetailsResponse.fromJson(Map<String, dynamic> json) {
    return DashboardBuildingDetailsResponse(
      success: json['success'] == true,
      data: (json['data'] is Map<String, dynamic>)
          ? DashboardBuildingDetails.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardBuildingDetails {
  final String id;
  final String name;
  final String siteId;
  final int? buildingSize;
  final int? numFloors;
  final int? yearOfConstruction;
  final String? typeOfUse;
  final int floorCount;
  final int roomCount;
  final int sensorCount;
  final List<DashboardFloor> floors;
  final DashboardKpis? kpis;
  final DashboardTimeRange? timeRange;

  DashboardBuildingDetails({
    required this.id,
    required this.name,
    required this.siteId,
    required this.buildingSize,
    required this.numFloors,
    required this.yearOfConstruction,
    required this.typeOfUse,
    required this.floorCount,
    required this.roomCount,
    required this.sensorCount,
    required this.floors,
    required this.kpis,
    required this.timeRange,
  });

  factory DashboardBuildingDetails.fromJson(Map<String, dynamic> json) {
    final rawFloors = json['floors'];
    final floors = (rawFloors is List)
        ? rawFloors
            .whereType<Map>()
            .map((e) {
              final map = <String, dynamic>{};
              e.forEach((key, value) {
                map[key.toString()] = value;
              });
              return DashboardFloor.fromJson(map);
            })
            .toList()
        : <DashboardFloor>[];

    return DashboardBuildingDetails(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      siteId: (json['siteId'] ?? '').toString(),
      buildingSize: json['building_size'] is int
          ? json['building_size'] as int
          : json['building_size'] != null
              ? int.tryParse('${json['building_size']}')
              : null,
      numFloors: json['num_floors'] is int
          ? json['num_floors'] as int
          : json['num_floors'] != null
              ? int.tryParse('${json['num_floors']}')
              : null,
      yearOfConstruction: json['year_of_construction'] is int
          ? json['year_of_construction'] as int
          : json['year_of_construction'] != null
              ? int.tryParse('${json['year_of_construction']}')
              : null,
      typeOfUse: json['type_of_use']?.toString(),
      floorCount: (json['floor_count'] is int)
          ? json['floor_count'] as int
          : int.tryParse('${json['floor_count']}') ?? 0,
      roomCount: (json['room_count'] is int)
          ? json['room_count'] as int
          : int.tryParse('${json['room_count']}') ?? 0,
      sensorCount: (json['sensor_count'] is int)
          ? json['sensor_count'] as int
          : int.tryParse('${json['sensor_count']}') ?? 0,
      floors: floors,
      kpis: (json['kpis'] is Map<String, dynamic>)
          ? DashboardKpis.fromJson(json['kpis'] as Map<String, dynamic>)
          : null,
      timeRange: (json['time_range'] is Map<String, dynamic>)
          ? DashboardTimeRange.fromJson(json['time_range'] as Map<String, dynamic>)
          : null,
    );
  }
}
