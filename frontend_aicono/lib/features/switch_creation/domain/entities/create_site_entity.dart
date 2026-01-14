import 'package:equatable/equatable.dart';

class CreateSiteRequest extends Equatable {
  final String name;
  final String address;
  final String resourceType;

  const CreateSiteRequest({
    required this.name,
    required this.address,
    required this.resourceType,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'resource_type': resourceType,
    };
  }

  @override
  List<Object?> get props => [name, address, resourceType];
}

class CreateSiteResponse extends Equatable {
  final bool success;
  final String? message;
  final SiteData? data;

  const CreateSiteResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory CreateSiteResponse.fromJson(Map<String, dynamic> json) {
    return CreateSiteResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? SiteData.fromJson(json['data']) : null,
    );
  }

  @override
  List<Object?> get props => [success, message, data];
}

class SiteData extends Equatable {
  final String id;
  final String name;
  final String address;
  final String resourceType;
  final String bryteswitchId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SiteData({
    required this.id,
    required this.name,
    required this.address,
    required this.resourceType,
    required this.bryteswitchId,
    this.createdAt,
    this.updatedAt,
  });

  factory SiteData.fromJson(Map<String, dynamic> json) {
    return SiteData(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      resourceType: json['resource_type'] ?? '',
      bryteswitchId: json['bryteswitch_id'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, address, resourceType, bryteswitchId, createdAt, updatedAt];
}
