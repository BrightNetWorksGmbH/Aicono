import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/complete_setup_usecase.dart';

class SwitchCreationState extends Equatable {
  final String? organizationName;
  final String? subDomain;
  final String? logoUrl;
  final String? primaryColor;
  final String? colorName;
  final bool? darkMode;
  final bool isLoading;
  final String? errorMessage;

  const SwitchCreationState({
    this.organizationName,
    this.subDomain,
    this.logoUrl,
    this.primaryColor,
    this.colorName,
    this.darkMode,
    this.isLoading = false,
    this.errorMessage,
  });

  SwitchCreationState copyWith({
    String? organizationName,
    String? subDomain,
    String? logoUrl,
    String? primaryColor,
    String? colorName,
    bool? darkMode,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SwitchCreationState(
      organizationName: organizationName ?? this.organizationName,
      subDomain: subDomain ?? this.subDomain,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      colorName: colorName ?? this.colorName,
      darkMode: darkMode ?? this.darkMode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  CompleteSetupRequest toCompleteSetupRequest() {
    // Trim and clean all string values to ensure proper formatting
    return CompleteSetupRequest(
      organizationName: (organizationName ?? '').trim(),
      subDomain: (subDomain ?? '').trim(),
      branding: Branding(
        logoUrl: logoUrl?.trim(),
        primaryColor: primaryColor?.trim(),
        colorName: colorName?.trim(),
      ),
      darkMode: darkMode ?? false,
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
    isLoading,
    errorMessage,
  ];
}

class SwitchCreationCompleteSuccess extends SwitchCreationState {
  const SwitchCreationCompleteSuccess({
    required super.organizationName,
    required super.subDomain,
    super.logoUrl,
    super.primaryColor,
    super.colorName,
    super.darkMode,
  }) : super(isLoading: false, errorMessage: null);
}

class SwitchCreationCompleteFailure extends SwitchCreationState {
  final String message;

  const SwitchCreationCompleteFailure({
    required this.message,
    super.organizationName,
    super.subDomain,
    super.logoUrl,
    super.primaryColor,
    super.colorName,
    super.darkMode,
  }) : super(isLoading: false, errorMessage: message);
}

class SwitchCreationCubit extends Cubit<SwitchCreationState> {
  final CompleteSetupUseCase completeSetupUseCase;

  SwitchCreationCubit({required this.completeSetupUseCase})
    : super(const SwitchCreationState());

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
    // Preserve existing state values, only update what's provided
    emit(
      state.copyWith(
        organizationName: organizationName ?? state.organizationName,
        subDomain: subDomain ?? state.subDomain,
        logoUrl: logoUrl ?? state.logoUrl,
        primaryColor: primaryColor ?? state.primaryColor,
        colorName: colorName ?? state.colorName,
        darkMode: darkMode ?? state.darkMode,
      ),
    );
  }

  Future<void> completeSetup(String switchId) async {
    // Validate required fields
    if (state.organizationName == null || state.organizationName!.isEmpty) {
      emit(
        SwitchCreationCompleteFailure(
          message: 'Organization name is required',
          organizationName: state.organizationName,
          subDomain: state.subDomain,
          logoUrl: state.logoUrl,
          primaryColor: state.primaryColor,
          colorName: state.colorName,
          darkMode: state.darkMode,
        ),
      );
      return;
    }

    if (state.subDomain == null || state.subDomain!.isEmpty) {
      emit(
        SwitchCreationCompleteFailure(
          message: 'Sub domain is required',
          organizationName: state.organizationName,
          subDomain: state.subDomain,
          logoUrl: state.logoUrl,
          primaryColor: state.primaryColor,
          colorName: state.colorName,
          darkMode: state.darkMode,
        ),
      );
      return;
    }

    // Emit loading state
    emit(state.copyWith(isLoading: true, errorMessage: null));

    // Create request from state
    final request = state.toCompleteSetupRequest();

    // Debug: Log the request being created
    if (kDebugMode) {
      print('🔍 Creating CompleteSetupRequest:');
      print('Organization: ${request.organizationName}');
      print('SubDomain: ${request.subDomain}');
      print('DarkMode: ${request.darkMode}');
      print('Branding - LogoURL: ${request.branding.logoUrl}');
      print('Branding - PrimaryColor: ${request.branding.primaryColor}');
      print('Branding - ColorName: ${request.branding.colorName}');
      print('Request JSON: ${request.toJson()}');
    }

    // Call use case
    final result = await completeSetupUseCase(switchId, request);

    result.fold(
      (failure) {
        emit(
          SwitchCreationCompleteFailure(
            message: failure.message,
            organizationName: state.organizationName,
            subDomain: state.subDomain,
            logoUrl: state.logoUrl,
            primaryColor: state.primaryColor,
            colorName: state.colorName,
            darkMode: state.darkMode,
          ),
        );
      },
      (response) {
        emit(
          SwitchCreationCompleteSuccess(
            organizationName: state.organizationName!,
            subDomain: state.subDomain!,
            logoUrl: state.logoUrl,
            primaryColor: state.primaryColor,
            colorName: state.colorName,
            darkMode: state.darkMode ?? false,
          ),
        );
      },
    );
  }

  void reset() {
    emit(const SwitchCreationState());
  }
}
