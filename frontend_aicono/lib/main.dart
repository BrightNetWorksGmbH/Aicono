import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_buildings_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/building_reports_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/app_router.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/register_user_bloc.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/invitation_validation_bloc.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/reset_password_bloc.dart';
import 'package:frontend_aicono/features/Building/presentation/bloc/building_bloc/building_bloc.dart';

import 'package:frontend_aicono/core/services/dynamic_theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await init();

  // Set URL strategy to use path-based routing (removes # from URLs)
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // Initialize authentication service
  final authService = sl<AuthService>();
  await authService.initialize();

  // Initialize dynamic theme based on current (or selected) verse
  final themeService = sl<DynamicThemeService>();
  await themeService.initialize();

  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('de')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      startLocale: const Locale('de'),
      saveLocale: true,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<RegisterUserBloc>(
            create: (context) => RegisterUserBloc(registerUserUseCase: sl()),
          ),
          BlocProvider<InvitationValidationBloc>(
            create: (context) => InvitationValidationBloc(
              invitationUseCase: sl(),
              loginRepository: sl(),
            ),
          ),
          BlocProvider<ResetPasswordBloc>(
            create: (context) => ResetPasswordBloc(resetPasswordUseCase: sl()),
          ),
          BlocProvider<BuildingBloc>(create: (context) => BuildingBloc()),
          BlocProvider<DashboardBuildingDetailsBloc>(
            create: (context) => DashboardBuildingDetailsBloc(
              getDashboardBuildingDetailsUseCase: sl(),
            ),
          ),
          BlocProvider<DashboardFloorDetailsBloc>(
            create: (context) => DashboardFloorDetailsBloc(
              getDashboardFloorDetailsUseCase: sl(),
            ),
          ),
          BlocProvider<DashboardSiteDetailsBloc>(
            create: (context) =>
                DashboardSiteDetailsBloc(getDashboardSiteDetailsUseCase: sl()),
          ),
          BlocProvider<DashboardRoomDetailsBloc>(
            create: (context) =>
                DashboardRoomDetailsBloc(getDashboardRoomDetailsUseCase: sl()),
          ),
          BlocProvider<DashboardSitesBloc>(
            create: (context) {
              final bloc = sl<DashboardSitesBloc>();
              final verseId = sl<LocalStorage>().getSelectedVerseId();
              bloc.add(DashboardSitesRequested(bryteswitchId: verseId));
              return bloc;
            },
          ),
          BlocProvider<ReportSitesBloc>(
            create: (context) => sl<ReportSitesBloc>(),
          ),
          BlocProvider<ReportBuildingsBloc>(
            create: (context) => sl<ReportBuildingsBloc>(),
          ),
          BlocProvider<BuildingReportsBloc>(
            create: (context) => sl<BuildingReportsBloc>(),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BryteSpring',
      routerConfig: AppRouter.instance.router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) => Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) =>
                SelectionArea(child: child ?? const SizedBox.shrink()),
          ),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
