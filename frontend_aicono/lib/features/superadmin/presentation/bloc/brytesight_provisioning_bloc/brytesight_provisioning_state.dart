import 'package:equatable/equatable.dart';

abstract class BryteSightProvisioningState extends Equatable {
  const BryteSightProvisioningState();

  @override
  List<Object> get props => [];
}

class BryteSightProvisioningInitial extends BryteSightProvisioningState {}

class BryteSightProvisioningLoading extends BryteSightProvisioningState {}

class BryteSightProvisioningSuccess extends BryteSightProvisioningState {
  final String message;

  const BryteSightProvisioningSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class BryteSightProvisioningFailure extends BryteSightProvisioningState {
  final String message;

  const BryteSightProvisioningFailure(this.message);

  @override
  List<Object> get props => [message];
}
