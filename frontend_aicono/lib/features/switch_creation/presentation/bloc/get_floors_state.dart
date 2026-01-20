part of 'get_floors_bloc.dart';

abstract class GetFloorsState extends Equatable {
  const GetFloorsState();

  @override
  List<Object> get props => [];
}

class GetFloorsInitial extends GetFloorsState {}

class GetFloorsLoading extends GetFloorsState {}

class GetFloorsSuccess extends GetFloorsState {
  final List<FloorDetail> floors;

  const GetFloorsSuccess({required this.floors});

  @override
  List<Object> get props => [floors];
}

class GetFloorsFailure extends GetFloorsState {
  final String message;

  const GetFloorsFailure({required this.message});

  @override
  List<Object> get props => [message];
}

