class DashboardSitesResponse {
  final bool success;
  final List<DashboardSiteSummary> data;
  final int count;

  DashboardSitesResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory DashboardSitesResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List<DashboardSiteSummary> sites = (rawData is List)
        ? rawData
            .whereType<Map>()
            .map((e) => DashboardSiteSummary.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v),
                )))
            .toList()
        : <DashboardSiteSummary>[];

    return DashboardSitesResponse(
      success: json['success'] == true,
      data: sites,
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse('${json['count']}') ?? sites.length,
    );
  }
}

class DashboardSiteSummary {
  final String id;
  final String name;
  final String address;
  final String resourceType;
  final DashboardBryteSwitchInfo? bryteSwitch;
  final int buildingCount;

  DashboardSiteSummary({
    required this.id,
    required this.name,
    required this.address,
    required this.resourceType,
    required this.bryteSwitch,
    required this.buildingCount,
  });

  factory DashboardSiteSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSiteSummary(
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
    );
  }
}

class DashboardBryteSwitchInfo {
  final String id;
  final String organizationName;
  final String? subDomain;

  DashboardBryteSwitchInfo({
    required this.id,
    required this.organizationName,
    required this.subDomain,
  });

  factory DashboardBryteSwitchInfo.fromJson(Map<String, dynamic> json) {
    return DashboardBryteSwitchInfo(
      id: (json['_id'] ?? '').toString(),
      organizationName: (json['organization_name'] ?? '').toString(),
      subDomain: json['sub_domain']?.toString(),
    );
  }
}

