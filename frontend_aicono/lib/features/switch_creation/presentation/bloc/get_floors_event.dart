part of 'get_floors_bloc.dart';

abstract class GetFloorsEvent extends Equatable {
  const GetFloorsEvent();

  @override
  List<Object> get props => [];
}

class GetFloorsSubmitted extends GetFloorsEvent {
  final String buildingId;

  const GetFloorsSubmitted({required this.buildingId});

  @override
  List<Object> get props => [buildingId];
}

