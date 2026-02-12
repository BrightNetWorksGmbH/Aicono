import 'package:equatable/equatable.dart';

/// Request entity for updating a switch.
class UpdateSwitchRequest extends Equatable {
  final String organizationName;
  final String subDomain;
  final UpdateSwitchBrandingRequest branding;
  final bool darkMode;

  const UpdateSwitchRequest({
    required this.organizationName,
    required this.subDomain,
    required this.branding,
    this.darkMode = false,
  });

  Map<String, dynamic> toJson() => {
        'organization_name': organizationName,
        'sub_domain': subDomain,
        'branding': branding.toJson(),
        'dark_mode': darkMode,
      };

  @override
  List<Object?> get props => [organizationName, subDomain, branding, darkMode];
}

/// Branding fields for update request.
class UpdateSwitchBrandingRequest extends Equatable {
  final String? logoUrl;
  final String primaryColor;
  final String colorName;

  const UpdateSwitchBrandingRequest({
    this.logoUrl,
    required this.primaryColor,
    required this.colorName,
  });

  Map<String, dynamic> toJson() => {
        if (logoUrl != null && logoUrl!.isNotEmpty) 'logo_url': logoUrl,
        'primary_color': primaryColor,
        'color_name': colorName,
      };

  @override
  List<Object?> get props => [logoUrl, primaryColor, colorName];
}
