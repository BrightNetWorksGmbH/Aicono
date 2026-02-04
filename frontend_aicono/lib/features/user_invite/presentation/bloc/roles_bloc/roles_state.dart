import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/role_entity.dart';

abstract class RolesState extends Equatable {
  const RolesState();

  @override
  List<Object?> get props => [];
}

class RolesInitial extends RolesState {}

class RolesLoading extends RolesState {}

class RolesSuccess extends RolesState {
  final List<RoleEntity> roles;

  const RolesSuccess({required this.roles});

  @override
  List<Object?> get props => [roles];
}

class RolesFailure extends RolesState {
  final String message;

  const RolesFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
