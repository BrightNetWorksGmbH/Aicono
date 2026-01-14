import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_event.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_state.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';

class BuildingBloc extends Bloc<BuildingEvent, BuildingState> {
  // In-memory storage for now (can be replaced with actual repository later)
  final List<BuildingEntity> _buildings = [];

  BuildingBloc() : super(const BuildingInitial()) {
    on<LoadBuildingsEvent>(_onLoadBuildings);
    on<CreateBuildingEvent>(_onCreateBuilding);
    on<UpdateBuildingEvent>(_onUpdateBuilding);
    on<DeleteBuildingEvent>(_onDeleteBuilding);
    on<SelectBuildingEvent>(_onSelectBuilding);
  }

  void _onLoadBuildings(
    LoadBuildingsEvent event,
    Emitter<BuildingState> emit,
  ) async {
    emit(const BuildingLoading());
    try {
      // Simulate loading delay
      await Future.delayed(const Duration(milliseconds: 500));
      emit(BuildingLoaded(buildings: List.from(_buildings)));
    } catch (e) {
      emit(BuildingError(e.toString()));
    }
  }

  void _onCreateBuilding(
    CreateBuildingEvent event,
    Emitter<BuildingState> emit,
  ) async {
    try {
      final newBuilding = event.building.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'draft',
      );
      _buildings.add(newBuilding);
      emit(BuildingCreated(newBuilding));
      emit(BuildingLoaded(buildings: List.from(_buildings)));
    } catch (e) {
      emit(BuildingError(e.toString()));
    }
  }

  void _onUpdateBuilding(
    UpdateBuildingEvent event,
    Emitter<BuildingState> emit,
  ) async {
    try {
      final index = _buildings.indexWhere((b) => b.id == event.building.id);
      if (index != -1) {
        final updatedBuilding = event.building.copyWith(
          updatedAt: DateTime.now(),
        );
        _buildings[index] = updatedBuilding;
        emit(BuildingUpdated(updatedBuilding));
        emit(BuildingLoaded(buildings: List.from(_buildings)));
      }
    } catch (e) {
      emit(BuildingError(e.toString()));
    }
  }

  void _onDeleteBuilding(
    DeleteBuildingEvent event,
    Emitter<BuildingState> emit,
  ) async {
    try {
      _buildings.removeWhere((b) => b.id == event.buildingId);
      emit(BuildingDeleted(event.buildingId));
      emit(BuildingLoaded(buildings: List.from(_buildings)));
    } catch (e) {
      emit(BuildingError(e.toString()));
    }
  }

  void _onSelectBuilding(
    SelectBuildingEvent event,
    Emitter<BuildingState> emit,
  ) {
    if (state is BuildingLoaded) {
      final currentState = state as BuildingLoaded;
      emit(currentState.copyWith(selectedBuilding: event.building));
    }
  }
}

