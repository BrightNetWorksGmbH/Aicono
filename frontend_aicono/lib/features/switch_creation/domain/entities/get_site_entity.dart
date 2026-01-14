import 'package:equatable/equatable.dart';

class GetSiteResponse extends Equatable {
  final bool success;
  final SiteData? data;

  const GetSiteResponse({
    required this.success,
    this.data,
  });

  factory GetSiteResponse.fromJson(Map<String, dynamic> json) {
    return GetSiteResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? SiteData.fromJson(json['data']) : null,
    );
  }

  @override
  List<Object?> get props => [success, data];
}

class SiteData extends Equatable {
  final String id;
  final String name;
  final String address;
  final String resourceType;
  final BryteswitchData? bryteswitchId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SiteData({
    required this.id,
    required this.name,
    required this.address,
    required this.resourceType,
    this.bryteswitchId,
    this.createdAt,
    this.updatedAt,
  });

  factory SiteData.fromJson(Map<String, dynamic> json) {
    return SiteData(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      resourceType: json['resource_type'] ?? '',
      bryteswitchId: json['bryteswitch_id'] != null
          ? BryteswitchData.fromJson(json['bryteswitch_id'])
          : null,
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
        name,
        address,
        resourceType,
        bryteswitchId,
        createdAt,
        updatedAt,
      ];
}

class BryteswitchData extends Equatable {
  final String id;
  final String organizationName;

  const BryteswitchData({
    required this.id,
    required this.organizationName,
  });

  factory BryteswitchData.fromJson(Map<String, dynamic> json) {
    return BryteswitchData(
      id: json['_id'] ?? json['id'] ?? '',
      organizationName: json['organization_name'] ?? '',
    );
  }

  @override
  List<Object?> get props => [id, organizationName];
}
