import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';

/// Data model for switch details API response.
class SwitchDetailsModel {
  final String id;
  final String organizationName;
  final String subDomain;
  final SwitchBrandingModel branding;
  final bool darkMode;
  final bool isSetupComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SwitchDetailsModel({
    required this.id,
    required this.organizationName,
    required this.subDomain,
    required this.branding,
    this.darkMode = false,
    this.isSetupComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  factory SwitchDetailsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return SwitchDetailsModel(
      id: data['_id'] ?? data['id'] ?? '',
      organizationName: data['organization_name'] ?? '',
      subDomain: data['sub_domain'] ?? '',
      branding: SwitchBrandingModel.fromJson(
        data['branding'] ?? <String, dynamic>{},
      ),
      darkMode: data['dark_mode'] ?? false,
      isSetupComplete: data['is_setup_complete'] ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
    );
  }

  SwitchDetailsEntity toEntity() => SwitchDetailsEntity(
        id: id,
        organizationName: organizationName,
        subDomain: subDomain,
        branding: branding.toEntity(),
        darkMode: darkMode,
        isSetupComplete: isSetupComplete,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class SwitchBrandingModel {
  final String? logoUrl;
  final String primaryColor;
  final String colorName;

  const SwitchBrandingModel({
    this.logoUrl,
    required this.primaryColor,
    required this.colorName,
  });

  factory SwitchBrandingModel.fromJson(Map<String, dynamic> json) {
    return SwitchBrandingModel(
      logoUrl: json['logo_url']?.toString(),
      primaryColor: json['primary_color'] ?? '#0095A5',
      colorName: json['color_name'] ?? '',
    );
  }

  SwitchBrandingEntity toEntity() => SwitchBrandingEntity(
        logoUrl: logoUrl,
        primaryColor: primaryColor,
        colorName: colorName,
      );
}
