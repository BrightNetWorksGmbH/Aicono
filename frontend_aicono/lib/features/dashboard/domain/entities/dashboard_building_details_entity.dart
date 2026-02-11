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
  final DashboardBuildingAnalytics? analytics;
  /// Raw analytics map for report-style sections (buildingComparison, timeBasedAnalysis, anomalies).
  final Map<String, dynamic>? analyticsRaw;
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
    this.analytics,
    this.analyticsRaw,
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
      analytics: (json['analytics'] is Map<String, dynamic>)
          ? DashboardBuildingAnalytics.fromJson(
              json['analytics'] as Map<String, dynamic>,
            )
          : null,
      analyticsRaw: (json['analytics'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(
              (json['analytics'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k.toString(), v),
              ),
            )
          : null,
      timeRange: (json['time_range'] is Map<String, dynamic>)
          ? DashboardTimeRange.fromJson(json['time_range'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardBuildingAnalytics {
  final DashboardEuiAnalytics? eui;
  final DashboardPerCapitaAnalytics? perCapita;

  DashboardBuildingAnalytics({
    this.eui,
    this.perCapita,
  });

  factory DashboardBuildingAnalytics.fromJson(Map<String, dynamic> json) {
    final euiJson = json['eui'];
    final perCapitaJson = json['perCapita'];
    return DashboardBuildingAnalytics(
      eui: euiJson is Map<String, dynamic>
          ? DashboardEuiAnalytics.fromJson(
              euiJson.map((k, v) => MapEntry(k.toString(), v)),
            )
          : null,
      perCapita: perCapitaJson is Map<String, dynamic>
          ? DashboardPerCapitaAnalytics.fromJson(
              perCapitaJson.map((k, v) => MapEntry(k.toString(), v)),
            )
          : null,
    );
  }
}

class DashboardEuiAnalytics {
  final double eui;
  final double annualizedEui;
  final String unit;
  final bool available;

  DashboardEuiAnalytics({
    required this.eui,
    required this.annualizedEui,
    required this.unit,
    required this.available,
  });

  factory DashboardEuiAnalytics.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    return DashboardEuiAnalytics(
      eui: _toDouble(json['eui']),
      annualizedEui: _toDouble(json['annualizedEUI']),
      unit: (json['unit'] ?? '').toString(),
      available: json['available'] == true,
    );
  }
}

class DashboardPerCapitaAnalytics {
  final double perCapita;
  final String unit;
  final int? numPeople;
  final bool available;

  DashboardPerCapitaAnalytics({
    required this.perCapita,
    required this.unit,
    required this.numPeople,
    required this.available,
  });

  factory DashboardPerCapitaAnalytics.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    return DashboardPerCapitaAnalytics(
      perCapita: _toDouble(json['perCapita']),
      unit: (json['unit'] ?? '').toString(),
      numPeople: (json['numPeople'] is int)
          ? json['numPeople'] as int
          : int.tryParse('${json['numPeople']}'),
      available: json['available'] == true,
    );
  }
}
