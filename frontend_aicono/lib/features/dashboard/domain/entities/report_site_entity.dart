import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';

/// Site summary from reports API: /api/v1/dashboard/reports/sites
class ReportSiteEntity extends Equatable {
  final String id;
  final String name;
  final String address;
  final String resourceType;
  final DashboardBryteSwitchInfo? bryteSwitch;
  final int buildingCount;
  final int reportCount;

  const ReportSiteEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.resourceType,
    this.bryteSwitch,
    required this.buildingCount,
    required this.reportCount,
  });

  factory ReportSiteEntity.fromJson(Map<String, dynamic> json) {
    return ReportSiteEntity(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      resourceType: (json['resource_type'] ?? '').toString(),
      bryteSwitch: (json['bryteswitch_id'] is Map<String, dynamic>)
          ? DashboardBryteSwitchInfo.fromJson(
              json['bryteswitch_id'] as Map<String, dynamic>,
            )
          : null,
      buildingCount: (json['building_count'] is int)
          ? json['building_count'] as int
          : int.tryParse('${json['building_count']}') ?? 0,
      reportCount: (json['report_count'] is int)
          ? json['report_count'] as int
          : int.tryParse('${json['report_count']}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, buildingCount, reportCount];
}

class ReportSitesResponse {
  final bool success;
  final List<ReportSiteEntity> data;
  final int count;

  const ReportSitesResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory ReportSitesResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List<ReportSiteEntity> sites = (rawData is List)
        ? rawData
              .whereType<Map<String, dynamic>>()
              .map((e) => ReportSiteEntity.fromJson(e))
              .toList()
        : <ReportSiteEntity>[];
    return ReportSitesResponse(
      success: json['success'] == true,
      data: sites,
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse('${json['count']}') ?? sites.length,
    );
  }
}
