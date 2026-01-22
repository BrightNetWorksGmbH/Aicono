import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardSitesUseCase {
  final DashboardRepository repository;

  GetDashboardSitesUseCase({required this.repository});

  Future<Either<Failure, DashboardSitesResponse>> call() async {
    return repository.getSites();
  }
}

