import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class PropertySetupState extends Equatable {
  final String? propertyName;
  final String? location;
  final List<String> resourceTypes;
  final String? siteId;
  final String? buildingId;
  final String? switchId;

  const PropertySetupState({
    this.propertyName,
    this.location,
    this.resourceTypes = const [],
    this.siteId,
    this.buildingId,
    this.switchId,
  });

  PropertySetupState copyWith({
    String? propertyName,
    String? location,
    List<String>? resourceTypes,
    String? siteId,
    String? buildingId,
    String? switchId,
  }) {
    return PropertySetupState(
      propertyName: propertyName ?? this.propertyName,
      location: location ?? this.location,
      resourceTypes: resourceTypes ?? this.resourceTypes,
      siteId: siteId ?? this.siteId,
      buildingId: buildingId ?? this.buildingId,
      switchId: switchId ?? this.switchId,
    );
  }

  @override
  List<Object?> get props => [
    propertyName,
    location,
    resourceTypes,
    siteId,
    buildingId,
    switchId,
  ];
}

class PropertySetupCubit extends Cubit<PropertySetupState> {
  PropertySetupCubit() : super(const PropertySetupState());

  void setPropertyName(String propertyName) {
    emit(state.copyWith(propertyName: propertyName));
  }

  void setLocation(String location) {
    emit(state.copyWith(location: location));
  }

  void setResourceTypes(List<String> resourceTypes) {
    emit(state.copyWith(resourceTypes: resourceTypes));
  }

  void setSiteId(String siteId) {
    emit(state.copyWith(siteId: siteId));
  }

  void setBuildingId(String buildingId) {
    emit(state.copyWith(buildingId: buildingId));
  }

  void setSwitchId(String switchId) {
    emit(state.copyWith(switchId: switchId));
  }

  void reset() {
    emit(const PropertySetupState());
  }
}
