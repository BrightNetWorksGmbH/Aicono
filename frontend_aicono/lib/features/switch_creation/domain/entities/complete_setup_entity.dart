import 'package:equatable/equatable.dart';

class CompleteSetupRequest extends Equatable {
  final String organizationName;
  final String subDomain;
  final Branding branding;
  final bool darkMode;

  const CompleteSetupRequest({
    required this.organizationName,
    required this.subDomain,
    required this.branding,
    required this.darkMode,
  });

  Map<String, dynamic> toJson() {
    final brandingJson = branding.toJson();
    // Always include branding object (server expects it)
    return {
      'organization_name': organizationName,
      'sub_domain': subDomain,
      'branding': brandingJson, // Always include, even if empty
      'dark_mode': darkMode,
    };
  }

  @override
  List<Object?> get props => [organizationName, subDomain, branding, darkMode];
}

class Branding extends Equatable {
  final String? logoUrl;
  final String? primaryColor;
  final String? colorName;

  const Branding({
    this.logoUrl,
    this.primaryColor,
    this.colorName,
  });

  Map<String, dynamic> toJson() {
    return {
      if (logoUrl != null) 'logo_url': logoUrl,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (colorName != null) 'color_name': colorName,
    };
  }

  @override
  List<Object?> get props => [logoUrl, primaryColor, colorName];
}

class CompleteSetupResponse extends Equatable {
  final bool success;
  final String? message;

  const CompleteSetupResponse({
    required this.success,
    this.message,
  });

  factory CompleteSetupResponse.fromJson(Map<String, dynamic> json) {
    return CompleteSetupResponse(
      success: json['success'] ?? false,
      message: json['message'],
    );
  }

  @override
  List<Object?> get props => [success, message];
}
