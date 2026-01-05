import 'package:equatable/equatable.dart';

abstract class BryteSightProvisioningEvent extends Equatable {
  const BryteSightProvisioningEvent();

  @override
  List<Object> get props => [];
}

class SetBryteSightProvisioningRequested extends BryteSightProvisioningEvent {
  final String verseId;
  final bool canCreateBrytesight;

  const SetBryteSightProvisioningRequested({
    required this.verseId,
    required this.canCreateBrytesight,
  });

  @override
  List<Object> get props => [verseId, canCreateBrytesight];
}
