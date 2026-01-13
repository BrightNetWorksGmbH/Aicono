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
import 'package:frontend_aicono/features/upload/data/datasources/upload_remote_data_source.dart';
import 'package:frontend_aicono/features/upload/data/repositories/upload_repository_impl.dart';
import 'package:frontend_aicono/features/upload/domain/repositories/upload_repository.dart';
import 'package:frontend_aicono/features/upload/domain/usecases/upload_usecase.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_bloc.dart';
import 'package:frontend_aicono/features/switch_creation/data/datasources/complete_setup_remote_data_source.dart';
import 'package:frontend_aicono/features/switch_creation/data/repositories/complete_setup_repository_impl.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/complete_setup_usecase.dart';

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

  // Use cases
  sl.registerLazySingleton(() => InvitationUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUserUseCase(repository: sl()));
  sl.registerLazySingleton(() => SendResetLinkUseCase(repository: sl()));
  sl.registerLazySingleton(() => ForgotResetPasswordUseCase(repository: sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(repository: sl()));
  sl.registerLazySingleton(() => CompleteSetupUseCase(repository: sl()));

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

  // Upload dependencies
  sl.registerLazySingleton<UploadRemoteDataSource>(
    () => UploadRemoteDataSourceImpl(dio: sl(), tokenService: sl()),
  );
  sl.registerLazySingleton<UploadRepository>(
    () => UploadRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => UploadImage(sl()));
  sl.registerFactory(() => UploadBloc(sl()));
}
