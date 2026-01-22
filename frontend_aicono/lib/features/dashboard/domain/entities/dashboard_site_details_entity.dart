class DashboardSiteDetailsResponse {
  final bool success;
  final DashboardSiteDetails? data;

  DashboardSiteDetailsResponse({
    required this.success,
    required this.data,
  });

  factory DashboardSiteDetailsResponse.fromJson(Map<String, dynamic> json) {
    return DashboardSiteDetailsResponse(
      success: json['success'] == true,
      data: (json['data'] is Map<String, dynamic>)
          ? DashboardSiteDetails.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardSiteDetails {
  final String id;
  final String name;
  final String address;
  final String resourceType;
  final DashboardBryteSwitchInfoDetails? bryteSwitch;

  final int buildingCount;
  final int totalFloors;
  final int totalRooms;
  final int totalSensors;

  final List<DashboardBuilding> buildings;
  final DashboardKpis? kpis;
  final DashboardTimeRange? timeRange;

  DashboardSiteDetails({
    required this.id,
    required this.name,
    required this.address,
    required this.resourceType,
    required this.bryteSwitch,
    required this.buildingCount,
    required this.totalFloors,
    required this.totalRooms,
    required this.totalSensors,
    required this.buildings,
    required this.kpis,
    required this.timeRange,
  });

  factory DashboardSiteDetails.fromJson(Map<String, dynamic> json) {
    final rawBuildings = json['buildings'];
    final buildings = (rawBuildings is List)
        ? rawBuildings
            .whereType<Map>()
            .map((e) => DashboardBuilding.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v),
                )))
            .toList()
        : <DashboardBuilding>[];

    return DashboardSiteDetails(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      resourceType: (json['resource_type'] ?? '').toString(),
      bryteSwitch: (json['bryteswitch_id'] is Map<String, dynamic>)
          ? DashboardBryteSwitchInfoDetails.fromJson(
              json['bryteswitch_id'] as Map<String, dynamic>,
            )
          : null,
      buildingCount: (json['building_count'] is int)
          ? json['building_count'] as int
          : int.tryParse('${json['building_count']}') ?? 0,
      totalFloors: (json['total_floors'] is int)
          ? json['total_floors'] as int
          : int.tryParse('${json['total_floors']}') ?? 0,
      totalRooms: (json['total_rooms'] is int)
          ? json['total_rooms'] as int
          : int.tryParse('${json['total_rooms']}') ?? 0,
      totalSensors: (json['total_sensors'] is int)
          ? json['total_sensors'] as int
          : int.tryParse('${json['total_sensors']}') ?? 0,
      buildings: buildings,
      kpis: (json['kpis'] is Map<String, dynamic>)
          ? DashboardKpis.fromJson(json['kpis'] as Map<String, dynamic>)
          : null,
      timeRange: (json['time_range'] is Map<String, dynamic>)
          ? DashboardTimeRange.fromJson(json['time_range'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardBryteSwitchInfoDetails {
  final String id;
  final String organizationName;

  DashboardBryteSwitchInfoDetails({
    required this.id,
    required this.organizationName,
  });

  factory DashboardBryteSwitchInfoDetails.fromJson(Map<String, dynamic> json) {
    return DashboardBryteSwitchInfoDetails(
      id: (json['_id'] ?? '').toString(),
      organizationName: (json['organization_name'] ?? '').toString(),
    );
  }
}

class DashboardBuilding {
  final String id;
  final String name;
  final String siteId;

  final int floorCount;
  final int roomCount;
  final int sensorCount;

  final DashboardKpis? kpis;

  DashboardBuilding({
    required this.id,
    required this.name,
    required this.siteId,
    required this.floorCount,
    required this.roomCount,
    required this.sensorCount,
    required this.kpis,
  });

  factory DashboardBuilding.fromJson(Map<String, dynamic> json) {
    return DashboardBuilding(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      siteId: (json['siteId'] ?? '').toString(),
      floorCount: (json['floor_count'] is int)
          ? json['floor_count'] as int
          : int.tryParse('${json['floor_count']}') ?? 0,
      roomCount: (json['room_count'] is int)
          ? json['room_count'] as int
          : int.tryParse('${json['room_count']}') ?? 0,
      sensorCount: (json['sensor_count'] is int)
          ? json['sensor_count'] as int
          : int.tryParse('${json['sensor_count']}') ?? 0,
      kpis: (json['kpis'] is Map<String, dynamic>)
          ? DashboardKpis.fromJson(json['kpis'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardKpis {
  final double totalConsumption;
  final double peak;
  final double base;
  final double average;
  final int averageQuality;
  final String unit;
  final bool dataQualityWarning;
  final List<DashboardKpiBreakdownItem> breakdown;

  DashboardKpis({
    required this.totalConsumption,
    required this.peak,
    required this.base,
    required this.average,
    required this.averageQuality,
    required this.unit,
    required this.dataQualityWarning,
    required this.breakdown,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['breakdown'];
    final breakdown = (rawBreakdown is List)
        ? rawBreakdown
            .whereType<Map>()
            .map((e) => DashboardKpiBreakdownItem.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v),
                )))
            .toList()
        : <DashboardKpiBreakdownItem>[];

    return DashboardKpis(
      totalConsumption: _toDouble(json['total_consumption']),
      peak: _toDouble(json['peak']),
      base: _toDouble(json['base']),
      average: _toDouble(json['average']),
      averageQuality: (json['average_quality'] is int)
          ? json['average_quality'] as int
          : int.tryParse('${json['average_quality']}') ?? 0,
      unit: (json['unit'] ?? '').toString(),
      dataQualityWarning: json['data_quality_warning'] == true,
      breakdown: breakdown,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

class DashboardKpiBreakdownItem {
  final String measurementType;
  final double total;
  final double average;
  final double min;
  final double max;
  final int count;
  final String unit;

  DashboardKpiBreakdownItem({
    required this.measurementType,
    required this.total,
    required this.average,
    required this.min,
    required this.max,
    required this.count,
    required this.unit,
  });

  factory DashboardKpiBreakdownItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    return DashboardKpiBreakdownItem(
      measurementType: (json['measurement_type'] ?? '').toString(),
      total: toDouble(json['total']),
      average: toDouble(json['average']),
      min: toDouble(json['min']),
      max: toDouble(json['max']),
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse('${json['count']}') ?? 0,
      unit: (json['unit'] ?? '').toString(),
    );
  }
}

class DashboardTimeRange {
  final String start;
  final String end;

  DashboardTimeRange({
    required this.start,
    required this.end,
  });

  factory DashboardTimeRange.fromJson(Map<String, dynamic> json) {
    return DashboardTimeRange(
      start: (json['start'] ?? '').toString(),
      end: (json['end'] ?? '').toString(),
    );
  }
}

