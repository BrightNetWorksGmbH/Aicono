import 'package:equatable/equatable.dart';

/// Building info inside report detail
class ReportDetailBuildingEntity extends Equatable {
  final String id;
  final String name;
  final num? size;
  final num? heatedArea;
  final String? typeOfUse;
  final int? numPeople;

  const ReportDetailBuildingEntity({
    required this.id,
    required this.name,
    this.size,
    this.heatedArea,
    this.typeOfUse,
    this.numPeople,
  });

  factory ReportDetailBuildingEntity.fromJson(Map<String, dynamic> json) {
    return ReportDetailBuildingEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      size: json['size'] is num ? json['size'] as num : null,
      heatedArea: json['heatedArea'] is num ? json['heatedArea'] as num : null,
      typeOfUse: (json['typeOfUse'] ?? json['type_of_use'])?.toString(),
      numPeople: json['numPeople'] is int
          ? json['numPeople'] as int
          : int.tryParse('${json['numPeople']}'),
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// Reporting config inside report detail
class ReportDetailReportingEntity extends Equatable {
  final String id;
  final String name;
  final String interval;
  final List<String> reportContents;

  const ReportDetailReportingEntity({
    required this.id,
    required this.name,
    required this.interval,
    this.reportContents = const [],
  });

  factory ReportDetailReportingEntity.fromJson(Map<String, dynamic> json) {
    final raw = json['reportContents'];
    final List<String> contents = (raw is List)
        ? raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return ReportDetailReportingEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      interval: (json['interval'] ?? '').toString(),
      reportContents: contents,
    );
  }

  @override
  List<Object?> get props => [id, name, interval];
}

/// Full report detail from API: /api/v1/dashboard/reports/view/{reportId}
/// reportData is kept as Map for flexibility (nested contents, kpis, etc.)
class ReportDetailEntity extends Equatable {
  final ReportDetailBuildingEntity building;
  final ReportDetailReportingEntity reporting;
  final Map<String, dynamic> reportData;
  final Map<String, dynamic>? timeRange;

  const ReportDetailEntity({
    required this.building,
    required this.reporting,
    required this.reportData,
    this.timeRange,
  });

  /// [json] is the inner "data" object: { building, reporting, reportData, timeRange }
  factory ReportDetailEntity.fromJson(Map<String, dynamic> json) {
    final buildingJson = json['building'];
    final reportingJson = json['reporting'];
    final reportDataJson = json['reportData'];
    final timeRangeJson = json['timeRange'];
    return ReportDetailEntity(
      building: buildingJson is Map<String, dynamic>
          ? ReportDetailBuildingEntity.fromJson(buildingJson)
          : const ReportDetailBuildingEntity(id: '', name: ''),
      reporting: reportingJson is Map<String, dynamic>
          ? ReportDetailReportingEntity.fromJson(reportingJson)
          : const ReportDetailReportingEntity(id: '', name: '', interval: ''),
      reportData: reportDataJson is Map<String, dynamic>
          ? Map<String, dynamic>.from(reportDataJson)
          : <String, dynamic>{},
      timeRange: timeRangeJson is Map<String, dynamic>
          ? Map<String, dynamic>.from(timeRangeJson)
          : null,
    );
  }

  @override
  List<Object?> get props => [building.id, reporting.id];
}

class ReportDetailResponse {
  final bool success;
  final ReportDetailEntity? data;

  const ReportDetailResponse({required this.success, this.data});

  factory ReportDetailResponse.fromJson(Map<String, dynamic> json) {
    ReportDetailEntity? detail;
    if (json['success'] == true && json['data'] != null) {
      final dataMap = json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null;
      if (dataMap != null) {
        detail = ReportDetailEntity.fromJson(dataMap);
      }
    }
    return ReportDetailResponse(success: json['success'] == true, data: detail);
  }
}
