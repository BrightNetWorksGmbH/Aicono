import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardSiteDetailsUseCase {
  final DashboardRepository repository;

  GetDashboardSiteDetailsUseCase({required this.repository});

  Future<Either<Failure, DashboardSiteDetailsResponse>> call(String siteId) async {
    return repository.getSiteDetails(siteId);
  }
}

