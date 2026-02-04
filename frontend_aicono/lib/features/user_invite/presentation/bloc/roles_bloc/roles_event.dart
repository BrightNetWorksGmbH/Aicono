import 'package:equatable/equatable.dart';

abstract class RolesEvent extends Equatable {
  const RolesEvent();

  @override
  List<Object?> get props => [];
}

class RolesRequested extends RolesEvent {
  final String bryteswitchId;

  const RolesRequested({required this.bryteswitchId});

  @override
  List<Object?> get props => [bryteswitchId];
}

class RolesReset extends RolesEvent {}
