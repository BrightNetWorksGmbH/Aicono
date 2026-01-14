import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class PropertySetupState extends Equatable {
  final String? propertyName;
  final String? location;
  final List<String> resourceTypes;

  const PropertySetupState({
    this.propertyName,
    this.location,
    this.resourceTypes = const [],
  });

  PropertySetupState copyWith({
    String? propertyName,
    String? location,
    List<String>? resourceTypes,
  }) {
    return PropertySetupState(
      propertyName: propertyName ?? this.propertyName,
      location: location ?? this.location,
      resourceTypes: resourceTypes ?? this.resourceTypes,
    );
  }

  @override
  List<Object?> get props => [propertyName, location, resourceTypes];
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

  void reset() {
    emit(const PropertySetupState());
  }
}
