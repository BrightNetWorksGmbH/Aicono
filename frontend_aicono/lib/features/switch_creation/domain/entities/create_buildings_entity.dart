import 'package:equatable/equatable.dart';

class CreateBuildingsRequest extends Equatable {
  final List<String> buildingNames;

  const CreateBuildingsRequest({
    required this.buildingNames,
  });

  Map<String, dynamic> toJson() {
    return {
      'buildingNames': buildingNames,
    };
  }

  @override
  List<Object?> get props => [buildingNames];
}

class CreateBuildingsResponse extends Equatable {
  final bool success;
  final String? message;
  final List<BuildingData>? buildings;

  const CreateBuildingsResponse({
    required this.success,
    this.message,
    this.buildings,
  });

  factory CreateBuildingsResponse.fromJson(Map<String, dynamic> json) {
    List<BuildingData>? buildingsList;
    if (json['data'] != null) {
      if (json['data'] is List) {
        buildingsList = (json['data'] as List)
            .map((item) => BuildingData.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (json['data'] is Map<String, dynamic>) {
        buildingsList = [BuildingData.fromJson(json['data'] as Map<String, dynamic>)];
      }
    }

    return CreateBuildingsResponse(
      success: json['success'] ?? false,
      message: json['message'],
      buildings: buildingsList,
    );
  }

  @override
  List<Object?> get props => [success, message, buildings];
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
