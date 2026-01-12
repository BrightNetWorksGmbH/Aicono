import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class SwitchCreationState extends Equatable {
  final String? organizationName;
  final String? subDomain;
  final String? logoUrl;
  final String? primaryColor;
  final String? colorName;
  final bool? darkMode;

  const SwitchCreationState({
    this.organizationName,
    this.subDomain,
    this.logoUrl,
    this.primaryColor,
    this.colorName,
    this.darkMode,
  });

  SwitchCreationState copyWith({
    String? organizationName,
    String? subDomain,
    String? logoUrl,
    String? primaryColor,
    String? colorName,
    bool? darkMode,
  }) {
    return SwitchCreationState(
      organizationName: organizationName ?? this.organizationName,
      subDomain: subDomain ?? this.subDomain,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      colorName: colorName ?? this.colorName,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organization_name': organizationName,
      'sub_domain': subDomain,
      'branding': {
        'logo_url': logoUrl,
        'primary_color': primaryColor,
        'color_name': colorName,
      },
      'dark_mode': darkMode,
    };
  }

  @override
  List<Object?> get props => [
        organizationName,
        subDomain,
        logoUrl,
        primaryColor,
        colorName,
        darkMode,
      ];
}

class SwitchCreationCubit extends Cubit<SwitchCreationState> {
  SwitchCreationCubit() : super(const SwitchCreationState());

  void setOrganizationName(String organizationName) {
    emit(state.copyWith(organizationName: organizationName));
  }

  void setSubDomain(String subDomain) {
    emit(state.copyWith(subDomain: subDomain));
  }

  void setLogoUrl(String? logoUrl) {
    emit(state.copyWith(logoUrl: logoUrl));
  }

  void setPrimaryColor(String? primaryColor) {
    emit(state.copyWith(primaryColor: primaryColor));
  }

  void setColorName(String? colorName) {
    emit(state.copyWith(colorName: colorName));
  }

  void setDarkMode(bool darkMode) {
    emit(state.copyWith(darkMode: darkMode));
  }

  void initializeFromInvitation({
    String? organizationName,
    String? subDomain,
    String? logoUrl,
    String? primaryColor,
    String? colorName,
    bool? darkMode,
  }) {
    emit(SwitchCreationState(
      organizationName: organizationName,
      subDomain: subDomain,
      logoUrl: logoUrl,
      primaryColor: primaryColor,
      colorName: colorName,
      darkMode: darkMode,
    ));
  }

  void reset() {
    emit(const SwitchCreationState());
  }
}
