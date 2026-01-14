import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

abstract class BuildingState extends Equatable {
  const BuildingState();

  @override
  List<Object?> get props => [];
}

class BuildingInitial extends BuildingState {
  const BuildingInitial();
}

class BuildingLoading extends BuildingState {
  const BuildingLoading();
}

class BuildingLoaded extends BuildingState {
  final List<BuildingEntity> buildings;
  final BuildingEntity? selectedBuilding;

  const BuildingLoaded({
    required this.buildings,
    this.selectedBuilding,
  });

  @override
  List<Object?> get props => [buildings, selectedBuilding];

  BuildingLoaded copyWith({
    List<BuildingEntity>? buildings,
    BuildingEntity? selectedBuilding,
  }) {
    return BuildingLoaded(
      buildings: buildings ?? this.buildings,
      selectedBuilding: selectedBuilding ?? this.selectedBuilding,
    );
  }
}

class BuildingError extends BuildingState {
  final String message;

  const BuildingError(this.message);

  @override
  List<Object?> get props => [message];
}

class BuildingCreated extends BuildingState {
  final BuildingEntity building;

  const BuildingCreated(this.building);

  @override
  List<Object?> get props => [building];
}

class BuildingUpdated extends BuildingState {
  final BuildingEntity building;

  const BuildingUpdated(this.building);

  @override
  List<Object?> get props => [building];
}

class BuildingDeleted extends BuildingState {
  final String buildingId;

  const BuildingDeleted(this.buildingId);

  @override
  List<Object?> get props => [buildingId];
}

