import 'package:equatable/equatable.dart';

class GetBuildingsResponse extends Equatable {
  final bool success;
  final List<BuildingData> buildings;

  const GetBuildingsResponse({
    required this.success,
    required this.buildings,
  });

  factory GetBuildingsResponse.fromJson(Map<String, dynamic> json) {
    List<BuildingData> buildingsList = [];
    if (json['data'] != null && json['data'] is List) {
      buildingsList = (json['data'] as List)
          .map((item) => BuildingData.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return GetBuildingsResponse(
      success: json['success'] ?? false,
      buildings: buildingsList,
    );
  }

  @override
  List<Object?> get props => [success, buildings];
}

class BuildingData extends Equatable {
  final String id;
  final String siteId;
  final String name;
  final String miniserverProtocol;
  final bool miniserverConnected;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BuildingData({
    required this.id,
    required this.siteId,
    required this.name,
    required this.miniserverProtocol,
    required this.miniserverConnected,
    this.createdAt,
    this.updatedAt,
  });

  factory BuildingData.fromJson(Map<String, dynamic> json) {
    return BuildingData(
      id: json['_id'] ?? json['id'] ?? '',
      siteId: json['site_id'] ?? '',
      name: json['name'] ?? '',
      miniserverProtocol: json['miniserver_protocol'] ?? '',
      miniserverConnected: json['miniserver_connected'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        siteId,
        name,
        miniserverProtocol,
        miniserverConnected,
        createdAt,
        updatedAt,
      ];
}
