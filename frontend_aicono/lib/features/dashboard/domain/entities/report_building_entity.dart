import 'package:equatable/equatable.dart';

/// Building summary from reports API: /api/v1/dashboard/reports/sites/{siteId}/buildings
class ReportBuildingEntity extends Equatable {
  final String id;
  final String name;
  final String siteId;
  final int reportCount;

  const ReportBuildingEntity({
    required this.id,
    required this.name,
    required this.siteId,
    required this.reportCount,
  });

  factory ReportBuildingEntity.fromJson(Map<String, dynamic> json) {
    return ReportBuildingEntity(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      siteId: (json['siteId'] ?? '').toString(),
      reportCount: (json['report_count'] is int)
          ? json['report_count'] as int
          : int.tryParse('${json['report_count']}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, siteId, reportCount];
}

class ReportBuildingsResponse {
  final bool success;
  final List<ReportBuildingEntity> data;
  final int count;

  const ReportBuildingsResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory ReportBuildingsResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List<ReportBuildingEntity> buildings = (rawData is List)
        ? rawData
              .whereType<Map<String, dynamic>>()
              .map((e) => ReportBuildingEntity.fromJson(e))
              .toList()
        : <ReportBuildingEntity>[];
    return ReportBuildingsResponse(
      success: json['success'] == true,
      data: buildings,
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse('${json['count']}') ?? buildings.length,
    );
  }
}
