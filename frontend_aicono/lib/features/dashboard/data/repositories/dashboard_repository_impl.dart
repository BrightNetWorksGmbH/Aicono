import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;

  DashboardRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, DashboardSitesResponse>> getSites() async {
    return remoteDataSource.getSites();
  }

  @override
  Future<Either<Failure, DashboardSiteDetailsResponse>> getSiteDetails(
    String siteId,
  ) async {
    return remoteDataSource.getSiteDetails(siteId);
  }
}

