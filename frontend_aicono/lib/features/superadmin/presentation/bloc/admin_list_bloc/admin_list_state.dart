import 'package:frontend_aicono/features/superadmin/domain/entities/admin_entity.dart';

abstract class AdminListState {}

class AdminListInitial extends AdminListState {}

class AdminListLoading extends AdminListState {}

class AdminListLoaded extends AdminListState {
  final List<AdminEntity> admins;

  AdminListLoaded(this.admins);
}

class AdminListFailure extends AdminListState {
  final String message;

  AdminListFailure(this.message);
}
