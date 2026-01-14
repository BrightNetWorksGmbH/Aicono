import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

abstract class BuildingEvent extends Equatable {
  const BuildingEvent();

  @override
  List<Object?> get props => [];
}

class LoadBuildingsEvent extends BuildingEvent {
  const LoadBuildingsEvent();
}

class CreateBuildingEvent extends BuildingEvent {
  final BuildingEntity building;

  const CreateBuildingEvent(this.building);

  @override
  List<Object?> get props => [building];
}

class UpdateBuildingEvent extends BuildingEvent {
  final BuildingEntity building;

  const UpdateBuildingEvent(this.building);

  @override
  List<Object?> get props => [building];
}

class DeleteBuildingEvent extends BuildingEvent {
  final String buildingId;

  const DeleteBuildingEvent(this.buildingId);

  @override
  List<Object?> get props => [buildingId];
}

class SelectBuildingEvent extends BuildingEvent {
  final BuildingEntity building;

  const SelectBuildingEvent(this.building);

  @override
  List<Object?> get props => [building];
}

