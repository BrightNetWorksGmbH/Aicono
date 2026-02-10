import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/services/dynamic_theme_service.dart';
import 'package:frontend_aicono/core/services/file_upload_service.dart';
import 'package:frontend_aicono/core/services/saved_accounts_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/invitation_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/register_user_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/forgot_password_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/forgot_reset_password_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/reset_password_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/data/repositories/invitation_repository_impl.dart';
import 'package:frontend_aicono/features/Authentication/data/repositories/register_user_repository_impl.dart';
import 'package:frontend_aicono/features/Authentication/data/repositories/forgot_password_repository_impl.dart';
import 'package:frontend_aicono/features/Authentication/data/repositories/forgot_reset_password_repository_impl.dart';
import 'package:frontend_aicono/features/Authentication/data/repositories/reset_password_repository_impl.dart';
import 'package:frontend_aicono/features/Authentication/data/repositories/login_repository_impl.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/invitation_repository.dart';
import 'package:frontend_aicono/core/services/token_service.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/register_user_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/forgot_password_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/forgot_reset_password_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/reset_password_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/invitation_usecase.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/login_usecase.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/register_user_usecase.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/send_reset_link_usecase.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/forgot_reset_password_usecase.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/reset_password_usecase.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forget_password_bloc/forgot_password_bloc.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forgot_reset_password_bloc/forgot_reset_password_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_site_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/create_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_buildings_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/connect_loxone_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/save_floor_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_floors_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/create_site_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/update_site_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_site_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/create_buildings_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_buildings_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/connect_loxone_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_loxone_rooms_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/save_floor_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_floors_usecase.dart';
import 'package:frontend_aicono/features/upload/data/datasources/upload_remote_data_source.dart';
import 'package:frontend_aicono/features/upload/data/repositories/upload_repository_impl.dart';
import 'package:frontend_aicono/features/upload/domain/repositories/upload_repository.dart';
import 'package:frontend_aicono/features/upload/domain/usecases/upload_usecase.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/data/datasources/complete_setup_remote_data_source.dart';
import 'package:frontend_aicono/features/switch_creation/data/repositories/complete_setup_repository_impl.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/complete_setup_usecase.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/reports_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/reporting_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:frontend_aicono/features/dashboard/data/repositories/reports_repository_impl.dart';
import 'package:frontend_aicono/features/dashboard/data/repositories/reporting_repository_impl.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reporting_repository.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_site_details_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_sites_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_building_details_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_floor_details_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_room_details_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_sites_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_buildings_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_building_reports_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_detail_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_view_by_token_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_token_info_usecase.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/trigger_report_usecase.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_buildings_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/building_reports_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_detail_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_view_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_token_info_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/trigger_report_bloc.dart';
import 'package:frontend_aicono/features/realtime/data/datasources/realtime_remote_datasource.dart';
import 'package:frontend_aicono/features/realtime/data/repositories/realtime_repository_impl.dart';
import 'package:frontend_aicono/features/realtime/domain/repositories/realtime_repository.dart';
import 'package:frontend_aicono/features/realtime/presentation/bloc/realtime_sensor_bloc.dart';
import 'package:frontend_aicono/features/superadmin/data/datasources/verse_remote_datasource.dart';
import 'package:frontend_aicono/features/superadmin/data/repositories/verse_repository_impl.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/create_verse_usecase.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/get_all_verses_usecase.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/delete_verse_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_bloc.dart';
import 'package:frontend_aicono/features/user_invite/data/datasources/user_invite_remote_datasource.dart';
import 'package:frontend_aicono/features/user_invite/data/repositories/user_invite_repository_impl.dart';
import 'package:frontend_aicono/features/user_invite/domain/repositories/user_invite_repository.dart';
import 'package:frontend_aicono/features/user_invite/domain/usecases/get_roles_usecase.dart';
import 'package:frontend_aicono/features/user_invite/domain/usecases/send_invitation_usecase.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/roles_bloc/roles_bloc.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/send_invitation_bloc/send_invitation_bloc.dart';
import 'package:frontend_aicono/features/join_invite/data/datasources/join_invite_remote_datasource.dart';
import 'package:frontend_aicono/features/join_invite/data/repositories/join_invite_repository_impl.dart';
import 'package:frontend_aicono/features/join_invite/domain/repositories/join_invite_repository.dart';
import 'package:frontend_aicono/features/join_invite/domain/usecases/join_switch_usecase.dart';
import 'package:frontend_aicono/features/join_invite/presentation/bloc/join_invite_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // External dependencies
  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPrefs);
  // FlutterSecureStorage works on web with default configuration
  sl.registerLazySingleton(() => const FlutterSecureStorage());

  // Network
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => DioClient(dio: sl()));
  sl.registerLazySingleton(() => Connectivity());

  // Services
  sl.registerLazySingleton(() => DynamicThemeService());
  sl.registerLazySingleton(() => LocalStorage(sl()));

  // Data sources
  sl.registerLazySingleton<InvitationRemoteDataSource>(
    () => InvitationRemoteDataSourceImpl(dioClient: sl()),
  );

  sl.registerLazySingleton<RegisterUserRemoteDataSource>(
    () => RegisterUserRemoteDataSourceImpl(dioClient: sl()),
  );

  sl.registerLazySingleton<ForgotPasswordRemoteDataSource>(
    () => ForgotPasswordRemoteDataSourceImpl(dioClient: sl()),
  );

  sl.registerLazySingleton<ForgotResetPasswordRemoteDataSource>(
    () => ForgotResetPasswordRemoteDataSourceImpl(dioClient: sl()),
  );

  sl.registerLazySingleton<ResetPasswordRemoteDataSource>(
    () => ResetPasswordRemoteDataSourceImpl(dioClient: sl()),
  );

  sl.registerLazySingleton<CompleteSetupRemoteDataSource>(
    () => CompleteSetupRemoteDataSourceImpl(dioClient: sl()),
  );

  sl.registerLazySingleton<VerseRemoteDataSource>(
    () => VerseRemoteDataSourceImpl(dioClient: sl()),
  );

  // Dashboard data source
  sl.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSourceImpl(dioClient: sl()),
  );

  // Reports data source
  sl.registerLazySingleton<ReportsRemoteDataSource>(
    () => ReportsRemoteDataSourceImpl(dioClient: sl()),
  );

  // Reporting data source (trigger, scheduler)
  sl.registerLazySingleton<ReportingRemoteDataSource>(
    () => ReportingRemoteDataSourceImpl(dioClient: sl()),
  );

  // Realtime WebSocket data source
  sl.registerLazySingleton<RealtimeRemoteDataSource>(
    () => RealtimeRemoteDataSourceImpl(
      baseUrl: sl<DioClient>().dio.options.baseUrl,
    ),
  );

  // Join invite data source
  sl.registerLazySingleton<JoinInviteRemoteDataSource>(
    () => JoinInviteRemoteDataSourceImpl(dioClient: sl()),
  );

  // User invite data source
  sl.registerLazySingleton<UserInviteRemoteDataSource>(
    () => UserInviteRemoteDataSourceImpl(dioClient: sl()),
  );

  // Repositories - Auth is online-only, Verse is offline-first
  sl.registerLazySingleton<InvitationRepository>(
    () => InvitationRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<RegisterUserRepository>(
    () => RegisterUserRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<ForgotPasswordRepository>(
    () => ForgotPasswordRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<ForgotResetPasswordRepository>(
    () => ForgotResetPasswordRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<ResetPasswordRepository>(
    () => ResetPasswordRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<LoginRepository>(
    () => LoginRepositoryImpl(dioClient: sl(), prefs: sl()),
  );

  sl.registerLazySingleton<CompleteSetupRepository>(
    () => CompleteSetupRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<VerseRepository>(
    () => VerseRepositoryImpl(remoteDataSource: sl()),
  );

  // Dashboard repository
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(remoteDataSource: sl()),
  );

  // Reports repository
  sl.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(remoteDataSource: sl()),
  );

  // Reporting repository
  sl.registerLazySingleton<ReportingRepository>(
    () => ReportingRepositoryImpl(remoteDataSource: sl()),
  );

  // Realtime repository
  sl.registerLazySingleton<RealtimeRepository>(
    () => RealtimeRepositoryImpl(dataSource: sl()),
  );

  // Join invite repository
  sl.registerLazySingleton<JoinInviteRepository>(
    () => JoinInviteRepositoryImpl(remoteDataSource: sl()),
  );

  // User invite repository
  sl.registerLazySingleton<UserInviteRepository>(
    () => UserInviteRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => InvitationUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUserUseCase(repository: sl()));
  sl.registerLazySingleton(() => SendResetLinkUseCase(repository: sl()));
  sl.registerLazySingleton(() => ForgotResetPasswordUseCase(repository: sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(repository: sl()));
  sl.registerLazySingleton(() => CompleteSetupUseCase(repository: sl()));
  sl.registerLazySingleton(() => CreateSiteUseCase(repository: sl()));
  sl.registerLazySingleton(() => UpdateSiteUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetSiteUseCase(repository: sl()));
  sl.registerLazySingleton(() => CreateBuildingsUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetBuildingsUseCase(repository: sl()));
  sl.registerLazySingleton(() => ConnectLoxoneUseCase(repository: sl()));

  sl.registerLazySingleton(() => GetLoxoneRoomsUseCase(repository: sl()));

  sl.registerLazySingleton(() => SaveFloorUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetFloorsUseCase(sl()));
  sl.registerLazySingleton(() => GetDashboardSitesUseCase(repository: sl()));
  sl.registerLazySingleton(
    () => GetDashboardSiteDetailsUseCase(repository: sl()),
  );
  sl.registerLazySingleton(
    () => GetDashboardBuildingDetailsUseCase(repository: sl()),
  );
  sl.registerLazySingleton(
    () => GetDashboardFloorDetailsUseCase(repository: sl()),
  );
  sl.registerLazySingleton(
    () => GetDashboardRoomDetailsUseCase(repository: sl()),
  );
  sl.registerLazySingleton(() => GetReportSitesUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetReportBuildingsUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetBuildingReportsUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetReportDetailUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetReportViewByTokenUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetReportTokenInfoUseCase(repository: sl()));
  sl.registerLazySingleton(
    () => TriggerReportUseCase(repository: sl<ReportingRepository>()),
  );

  // Join invite use cases
  sl.registerLazySingleton(() => JoinSwitchUseCase(repository: sl()));

  // User invite use cases
  sl.registerLazySingleton(() => GetRolesUseCase(repository: sl()));
  sl.registerLazySingleton(() => SendInvitationUseCase(repository: sl()));

  // Superadmin use cases
  sl.registerLazySingleton(() => CreateVerseUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetAllVersesUseCase(repository: sl()));
  sl.registerLazySingleton(() => DeleteVerseUseCase(repository: sl()));

  // Services
  sl.registerLazySingleton(() => AuthService(sl()));
  sl.registerLazySingleton(
    () => SavedAccountsService(prefs: sl(), secureStorage: sl()),
  );
  sl.registerLazySingleton(() => UploadService(dio: sl()));

  // Register TokenService
  sl.registerLazySingleton(() => TokenService());

  // Forgot Password Bloc
  sl.registerFactory(() => ForgotPasswordBloc(sendResetLinkUseCase: sl()));

  // Forgot Reset Password Bloc
  sl.registerFactory(
    () => ForgotResetPasswordBloc(forgotResetPasswordUseCase: sl()),
  );

  // Switch Creation Bloc (singleton to persist state across pages)
  sl.registerLazySingleton(
    () => SwitchCreationCubit(completeSetupUseCase: sl()),
  );

  // Property Setup Bloc (singleton to persist state across pages)
  sl.registerLazySingleton(() => PropertySetupCubit());

  // Create Site Bloc
  sl.registerFactory(() => CreateSiteBloc(
        createSiteUseCase: sl(),
        updateSiteUseCase: sl(),
      ));

  // Get Site Bloc
  sl.registerFactory(() => GetSiteBloc(getSiteUseCase: sl()));

  // Create Buildings Bloc
  sl.registerFactory(() => CreateBuildingsBloc(createBuildingsUseCase: sl()));

  // Get Buildings Bloc
  sl.registerFactory(() => GetBuildingsBloc(getBuildingsUseCase: sl()));

  // Connect Loxone Bloc
  sl.registerFactory(() => ConnectLoxoneBloc(connectLoxoneUseCase: sl()));

  // Get Loxone Rooms Bloc
  sl.registerFactory(() => GetLoxoneRoomsBloc(getLoxoneRoomsUseCase: sl()));

  // Save Floor Bloc
  sl.registerFactory(() => SaveFloorBloc(saveFloorUseCase: sl()));

  // Get Floors Bloc
  sl.registerFactory(() => GetFloorsBloc(getFloorsUseCase: sl()));

  // Dashboard blocs
  sl.registerFactory(() => DashboardSitesBloc(getDashboardSitesUseCase: sl()));
  sl.registerFactory(
    () => DashboardSiteDetailsBloc(getDashboardSiteDetailsUseCase: sl()),
  );
  sl.registerFactory(
    () =>
        DashboardBuildingDetailsBloc(getDashboardBuildingDetailsUseCase: sl()),
  );
  sl.registerFactory(
    () => DashboardFloorDetailsBloc(getDashboardFloorDetailsUseCase: sl()),
  );
  sl.registerFactory(
    () => DashboardRoomDetailsBloc(getDashboardRoomDetailsUseCase: sl()),
  );
  sl.registerFactory(() => ReportSitesBloc(getReportSitesUseCase: sl()));
  sl.registerFactory(
    () => ReportBuildingsBloc(getReportBuildingsUseCase: sl()),
  );
  sl.registerFactory(
    () => BuildingReportsBloc(getBuildingReportsUseCase: sl()),
  );
  sl.registerFactory(() => ReportDetailBloc(getReportDetailUseCase: sl()));
  sl.registerFactory(() => ReportViewBloc(getReportViewByTokenUseCase: sl()));
  sl.registerFactory(
    () => ReportTokenInfoBloc(getReportTokenInfoUseCase: sl()),
  );
  sl.registerFactory(() => TriggerReportBloc(triggerReportUseCase: sl()));

  // Realtime sensor bloc (factory - new instance per screen that needs it)
  sl.registerFactory(
    () => RealtimeSensorBloc(repository: sl<RealtimeRepository>()),
  );

  // User invite blocs
  sl.registerFactory(() => RolesBloc(getRolesUseCase: sl()));
  sl.registerFactory(() => SendInvitationBloc(sendInvitationUseCase: sl()));

  // Join invite bloc
  sl.registerFactory(() => JoinInviteBloc(joinSwitchUseCase: sl()));

  // Upload dependencies
  sl.registerLazySingleton<UploadRemoteDataSource>(
    () => UploadRemoteDataSourceImpl(dio: sl(), tokenService: sl()),
  );
  sl.registerLazySingleton<UploadRepository>(
    () => UploadRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => UploadImage(sl()));
  sl.registerFactory(() => UploadBloc(sl()));

  // Superadmin blocs
  sl.registerFactory(() => VerseCreateBloc(createVerseUseCase: sl()));
  sl.registerFactory(() => VerseListBloc(getAllVersesUseCase: sl()));
  sl.registerFactory(() => DeleteVerseBloc(deleteVerseUseCase: sl()));
}
