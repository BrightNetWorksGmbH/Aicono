import 'package:equatable/equatable.dart';

/// Entity representing the details of a BryteSwitch.
class SwitchDetailsEntity extends Equatable {
  final String id;
  final String organizationName;
  final String subDomain;
  final SwitchBrandingEntity branding;
  final bool darkMode;
  final bool isSetupComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SwitchDetailsEntity({
    required this.id,
    required this.organizationName,
    required this.subDomain,
    required this.branding,
    this.darkMode = false,
    this.isSetupComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        organizationName,
        subDomain,
        branding,
        darkMode,
        isSetupComplete,
        createdAt,
        updatedAt,
      ];
}

/// Entity representing switch branding (logo, color).
class SwitchBrandingEntity extends Equatable {
  final String? logoUrl;
  final String primaryColor;
  final String colorName;

  const SwitchBrandingEntity({
    this.logoUrl,
    required this.primaryColor,
    required this.colorName,
  });

  @override
  List<Object?> get props => [logoUrl, primaryColor, colorName];
}
