import 'dart:typed_data';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/presentation/pages/login_page.dart';
import 'package:frontend_aicono/features/Authentication/presentation/pages/forgot_password_page.dart';
import 'package:frontend_aicono/features/Authentication/presentation/pages/forgot_reset_password_page.dart';
import 'package:frontend_aicono/features/Authentication/presentation/pages/reset_password_page.dart';
import 'package:frontend_aicono/features/Authentication/presentation/pages/invitation_validation_page.dart';
import 'package:frontend_aicono/features/FloorPlan/presentation/pages/floor_plan_editor_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/activate_switchboard_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/set_organization_name_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/set_switch_name_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/set_switch_image_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/set_switch_color_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/set_personalized_look_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/structure_switch_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/confirm_structure_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/add_property_name_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/add_property_location_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/select_resources_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/add_additional_buildings_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/additional_building_list_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/set_building_details_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/loxone_connection_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/building_floor_management_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/building_responsible_persons_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/building_recipient_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/building_summary_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/room_assignment_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/data_source_selection_page.dart';
import 'package:frontend_aicono/features/superadmin/presentation/pages/add_verse_super_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/building_list_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/building_onboarding_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/floor_plan_activation_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_contact_person_step.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/page/dashboard_page.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/statistics_dashboard_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/view_report_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/switch_settings_page.dart';
import 'package:frontend_aicono/features/user_invite/presentation/pages/invite_user_page.dart';
import 'package:frontend_aicono/features/user_invite/presentation/pages/complete_user_invite_page.dart';

/// App router configuration using go_router
class AppRouter {
  /// Singleton instance
  AppRouter._();

  static final AppRouter instance = AppRouter._();

  // No explicit RouteInformationProvider; let Flutter/GoRouter infer from the browser.

  late final GoRouter router = GoRouter(
    routes: _routes,
    debugLogDiagnostics: true,
    initialLocation: '/',
    errorBuilder: (context, state) {
      print('GoRouter Error: ${state.error}');
      print('GoRouter Error Location: ${state.uri}');
      // If it's an invitation validation URL, extract the token and navigate properly
      if (state.uri.path == '/invitation-validation' &&
          state.uri.queryParameters.containsKey('token')) {
        final token = state.uri.queryParameters['token'];
        return InvitationValidationPage(token: token ?? '');
      }
      // For other errors, redirect to login
      return LoginPage();
    },
    redirect: (context, state) {
      try {
        final authService = sl<AuthService>();

        // Debug logging
        print('AppRouter - Redirect check: ${state.uri.path}');
        print('AppRouter - Full location: ${state.uri.toString()}');
        print('AppRouter - State: $state');
        print('AppRouter - Matched location: ${state.matchedLocation}');
        print('AppRouter - Route name: ${state.name}');
        print('AppRouter - Route path: ${state.path}');

        // Wait for auth service to initialize
        if (!authService.isInitialized) {
          print('AppRouter - Auth service not initialized, allowing');
          return null; // Let the app initialize
        }

        final isAuthenticated = authService.isAuthenticated;
        final currentUser = authService.currentUser;
        final isSuperAdmin = currentUser?.isSuperAdmin ?? false;
        final isLoginRoute = state.uri.path == '/login';
        final isDashboardRoute = state.uri.path == '/dashboard';
        final isSuperAdminRoute =
            state.uri.path == '/${Routelists.addVerseSuper}';

        // Allow unauthenticated access to password reset and forgot password routes
        final isResetPasswordRoute =
            state.uri.path == '/reset-password' ||
            state.uri.path == '/invitation-reset-password';
        final isForgotPasswordRoute =
            state.uri.path == '/${Routelists.forgotPassword}';

        // More comprehensive check for invitation validation routes
        final isInvitationValidationRoute = state.uri.path.startsWith(
          '/invitation-validation',
        );
        final isViewReportRoute = state.uri.path == '/view-report';
        final isStatisticsRoute = state.uri.path == '/statistics';

        final isJoinVerseRoute = false; // Routes removed - not in project

        print(
          'AppRouter - isInvitationValidationRoute: $isInvitationValidationRoute',
        );
        print('AppRouter - isViewReportRoute: $isViewReportRoute');
        print('AppRouter - isJoinVerseRoute: $isJoinVerseRoute');
        print('AppRouter - isAuthenticated: $isAuthenticated');

        // Allow access to invitation validation, view-report, statistics (token-based), join verse, and reset password routes regardless of authentication status
        if (isInvitationValidationRoute ||
            isViewReportRoute ||
            isStatisticsRoute ||
            isJoinVerseRoute ||
            isResetPasswordRoute ||
            isForgotPasswordRoute) {
          print(
            'AppRouter - Allowing access to invitation/join verse/reset password/forgot password route',
          );
          return null; // No redirect needed
        }

        // Super admin routing logic
        if (isSuperAdmin) {
          // If super admin tries to access login, redirect to super admin page
          if (isLoginRoute) {
            return '/${Routelists.addVerseSuper}';
          }
          // If super admin tries to access root, redirect to super admin page
          if (state.uri.path == '/') {
            return '/${Routelists.addVerseSuper}';
          }
          // If super admin tries to access dashboard, redirect to super admin page
          if (isDashboardRoute) {
            return '/${Routelists.addVerseSuper}';
          }
        } else {
          // Non-super admin users cannot access super admin page
          if (isSuperAdminRoute) {
            return '/login';
          }
        }

        // If user is authenticated and trying to access login, redirect to dashboard
        if (isAuthenticated && isLoginRoute && !isSuperAdmin) {
          return '/dashboard';
        }

        // If user is not authenticated and trying to access dashboard, redirect to login
        if (!isAuthenticated && isDashboardRoute) {
          return '/login';
        }

        // If user is not authenticated and on root, redirect to login
        if (!isAuthenticated && state.uri.path == '/') {
          return '/login';
        }

        // If user is authenticated and on root (non-super admin), redirect to dashboard
        if (isAuthenticated && state.uri.path == '/' && !isSuperAdmin) {
          return '/dashboard';
        }

        return null; // No redirect needed
      } catch (e) {
        // If there's any error, redirect to login as fallback
        print('AppRouter - Error in redirect: $e');
        return '/login';
      }
    },
  );

  final List<GoRoute> _routes = [
    GoRoute(
      path: '/',
      name: 'root',
      pageBuilder: (context, state) =>
          _buildPage(context, state, const SizedBox()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        final token = state.uri.queryParameters['token'];
        print(
          'AppRouter - Login route with invitation: $invitation, token: $token',
        );
        return _buildPage(
          context,
          state,
          LoginPage(
            key: ValueKey(invitation?.id ?? token ?? 'no-invitation'),
            invitation: invitation,
            token: token,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.forgotPassword}',
      name: Routelists.forgotPassword,
      pageBuilder: (context, state) {
        return _buildPage(context, state, const ForgotPasswordPage());
      },
    ),
    GoRoute(
      path: '/reset-password',
      name: Routelists.forgotResetPassword,
      redirect: (context, state) {
        final token = state.uri.queryParameters['token'];
        if (token == null || token.isEmpty) {
          // If no token provided, redirect to login
          return '/login';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final token = state.uri.queryParameters['token']!;
        return _buildPage(
          context,
          state,
          ForgotResetPasswordPage(token: token),
        );
      },
    ),
    GoRoute(
      path: '/invitation-reset-password',
      name: Routelists.resetPassword,
      redirect: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        if (invitation == null) {
          // If no invitation provided, redirect to login
          return '/login';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final invitation = state.extra as InvitationEntity;
        return _buildPage(
          context,
          state,
          ResetPasswordPage(invitation: invitation),
        );
      },
    ),
    GoRoute(
      path: '/invitation-validation',
      name: 'invitation-validation',
      redirect: (context, state) {
        final token = state.uri.queryParameters['token'];
        if (token == null || token.isEmpty) {
          // If no token provided, redirect to login
          return '/login';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final token = state.uri.queryParameters['token']!;
        return _buildPage(
          context,
          state,
          InvitationValidationPage(token: token),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.inviteUser}',
      name: Routelists.inviteUser,
      pageBuilder: (context, state) {
        return _buildPage(context, state, const InviteUserPage());
      },
    ),
    GoRoute(
      path: '/${Routelists.completeUserInvite}',
      name: Routelists.completeUserInvite,
      pageBuilder: (context, state) {
        final extra = state.extra;
        String? invitedUserName;
        String? inviterName;
        if (extra is Map) {
          invitedUserName = extra['invitedUserName'] as String?;
          inviterName = extra['inviterName'] as String?;
        }
        return _buildPage(
          context,
          state,
          CompleteUserInvitePage(
            invitedUserName: invitedUserName,
            inviterName: inviterName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.activateSwitchboard}',
      name: Routelists.activateSwitchboard,
      redirect: (context, state) {
        final token = state.uri.queryParameters['token'];
        if (token == null || token.isEmpty) {
          // If no token provided, redirect to login
          return '/login';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final token = state.uri.queryParameters['token']!;
        return _buildPage(
          context,
          state,
          ActivateSwitchboardPage(userName: userName, token: token),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setOrganizationName}',
      name: Routelists.setOrganizationName,
      redirect: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        final token = state.uri.queryParameters['token'];
        // If no invitation and no token, redirect to login
        if (invitation == null && (token == null || token.isEmpty)) {
          return '/login';
        }
        // If invitation is null but we have token, redirect to activate switchboard with token
        if (invitation == null && token != null && token.isNotEmpty) {
          final userName = state.uri.queryParameters['userName'] ?? '';
          return '/${Routelists.activateSwitchboard}?token=$token${userName.isNotEmpty ? '&userName=$userName' : ''}';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final invitation = state.extra as InvitationEntity?;
        return _buildPage(
          context,
          state,
          SetOrganizationNamePage(userName: userName, invitation: invitation),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setSubDomain}',
      name: Routelists.setSubDomain,
      redirect: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        final token = state.uri.queryParameters['token'];
        // If no invitation and no token, redirect to login
        if (invitation == null && (token == null || token.isEmpty)) {
          return '/login';
        }
        // If invitation is null but we have token, redirect to activate switchboard with token
        if (invitation == null && token != null && token.isNotEmpty) {
          final userName = state.uri.queryParameters['userName'] ?? '';
          return '/${Routelists.activateSwitchboard}?token=$token${userName.isNotEmpty ? '&userName=$userName' : ''}';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final organizationName = state.uri.queryParameters['organizationName'];
        final invitation = state.extra as InvitationEntity?;
        return _buildPage(
          context,
          state,
          SetSwitchNamePage(
            userName: userName,
            organizationName: organizationName,
            invitation: invitation,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setSwitchImage}',
      name: Routelists.setSwitchImage,
      redirect: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        final token = state.uri.queryParameters['token'];
        // If no invitation and no token, redirect to login
        if (invitation == null && (token == null || token.isEmpty)) {
          return '/login';
        }
        // If invitation is null but we have token, redirect to activate switchboard with token
        if (invitation == null && token != null && token.isNotEmpty) {
          final userName = state.uri.queryParameters['userName'] ?? '';
          return '/${Routelists.activateSwitchboard}?token=$token${userName.isNotEmpty ? '&userName=$userName' : ''}';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final organizationName = state.uri.queryParameters['organizationName'];
        final invitation = state.extra as InvitationEntity?;
        return _buildPage(
          context,
          state,
          SetSwitchImagePage(
            userName: userName,
            organizationName: organizationName,
            invitation: invitation,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setSwitchColor}',
      name: Routelists.setSwitchColor,
      redirect: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        final token = state.uri.queryParameters['token'];
        // If no invitation and no token, redirect to login
        if (invitation == null && (token == null || token.isEmpty)) {
          return '/login';
        }
        // If invitation is null but we have token, redirect to activate switchboard with token
        if (invitation == null && token != null && token.isNotEmpty) {
          final userName = state.uri.queryParameters['userName'] ?? '';
          return '/${Routelists.activateSwitchboard}?token=$token${userName.isNotEmpty ? '&userName=$userName' : ''}';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final invitation = state.extra as InvitationEntity?;
        return _buildPage(
          context,
          state,
          SetSwitchColorPage(userName: userName, invitation: invitation),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setPersonalizedLook}',
      name: Routelists.setPersonalizedLook,
      redirect: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        final token = state.uri.queryParameters['token'];
        // If no invitation and no token, redirect to login
        if (invitation == null && (token == null || token.isEmpty)) {
          return '/login';
        }
        // If invitation is null but we have token, redirect to activate switchboard with token
        if (invitation == null && token != null && token.isNotEmpty) {
          final userName = state.uri.queryParameters['userName'] ?? '';
          return '/${Routelists.activateSwitchboard}?token=$token${userName.isNotEmpty ? '&userName=$userName' : ''}';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final invitation = state.extra as InvitationEntity?;
        return _buildPage(
          context,
          state,
          SetPersonalizedLookPage(userName: userName, invitation: invitation),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.structureSwitch}/:switchId',
      name: Routelists.structureSwitch,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.pathParameters['switchId'];
        return _buildPage(
          context,
          state,
          StructureSwitchPage(userName: userName, switchId: switchId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.confirmStructure}',
      name: Routelists.confirmStructure,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        return _buildPage(
          context,
          state,
          ConfirmStructurePage(userName: userName, switchId: switchId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addPropertyName}',
      name: Routelists.addPropertyName,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        return _buildPage(
          context,
          state,
          AddPropertyNamePage(userName: userName, switchId: switchId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addPropertyLocation}',
      name: Routelists.addPropertyLocation,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        return _buildPage(
          context,
          state,
          AddPropertyLocationPage(userName: userName, switchId: switchId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.selectResources}',
      name: Routelists.selectResources,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        return _buildPage(
          context,
          state,
          SelectResourcesPage(userName: userName, switchId: switchId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addAdditionalBuildings}',
      name: Routelists.addAdditionalBuildings,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final siteId = state.uri.queryParameters['siteId'];
        return _buildPage(
          context,
          state,
          AddAdditionalBuildingsPage(userName: userName, siteId: siteId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.additionalBuildingList}',
      name: Routelists.additionalBuildingList,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final siteId = state.uri.queryParameters['siteId'];
        return _buildPage(
          context,
          state,
          AdditionalBuildingListPage(userName: userName, siteId: siteId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setBuildingDetails}',
      name: Routelists.setBuildingDetails,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        return _buildPage(
          context,
          state,
          SetBuildingDetailsPage(
            userName: userName,
            buildingAddress: buildingAddress,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.loxoneConnection}',
      name: Routelists.loxoneConnection,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        return _buildPage(
          context,
          state,
          LoxoneConnectionPage(userName: userName, buildingId: buildingId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingFloorManagement}',
      name: Routelists.buildingFloorManagement,
      pageBuilder: (context, state) {
        final buildingName =
            state.uri.queryParameters['buildingName'] ?? 'Building';
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final numberOfFloors =
            int.tryParse(state.uri.queryParameters['numberOfFloors'] ?? '1') ??
            1;
        final totalArea = double.tryParse(
          state.uri.queryParameters['totalArea'] ?? '',
        );
        final constructionYear = state.uri.queryParameters['constructionYear'];

        final numberOfRooms = int.tryParse(
          state.uri.queryParameters['numberOfRooms'] ?? '',
        );
        final siteId = state.uri.queryParameters['siteId'];
        final buildingId =
            state.uri.queryParameters['buildingId'] ??
            '6948dcd113537bff98eb7338'; // Default buildingId if not provided

        final building = BuildingEntity(
          name: buildingName,
          address: buildingAddress,
          numberOfFloors: numberOfFloors,
          numberOfRooms: numberOfRooms,
          totalArea: totalArea,
          constructionYear: constructionYear,
        );

        return _buildPage(
          context,
          state,
          BuildingFloorManagementPage(
            building: building,
            siteId: siteId,
            buildingId: buildingId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.floorPlanEditor}',
      name: Routelists.floorPlanEditor,
      pageBuilder: (context, state) {
        return _buildPage(context, state, const FloorPlanPage());
      },
    ),
    GoRoute(
      path: '/${Routelists.addVerseSuper}',
      name: Routelists.addVerseSuper,
      redirect: (context, state) {
        final authService = sl<AuthService>();
        final currentUser = authService.currentUser;

        // Only allow access if user is super admin
        if (currentUser == null || !currentUser.isSuperAdmin) {
          print('Access denied to super admin page - redirecting to login');
          return '/login';
        }
        return null;
      },
      pageBuilder: (context, state) =>
          _buildPage(context, state, const AddVerseSuperPage()),
    ),
    GoRoute(
      path: '/${Routelists.floorPlanActivation}',
      name: Routelists.floorPlanActivation,
      pageBuilder: (context, state) {
        final imageBytes = state.extra as Uint8List?;
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final buildingSize = state.uri.queryParameters['buildingSize'];
        final numberOfRooms = int.tryParse(
          state.uri.queryParameters['numberOfRooms'] ?? '',
        );
        final constructionYear = state.uri.queryParameters['constructionYear'];
        return _buildPage(
          context,
          state,
          FloorPlanActivationPage(
            initialImageBytes: imageBytes,
            userName: userName,
            buildingAddress: buildingAddress,
            buildingName: buildingName,
            buildingSize: buildingSize,
            numberOfRooms: numberOfRooms,
            constructionYear: constructionYear,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingList}',
      name: Routelists.buildingList,
      pageBuilder: (context, state) {
        return _buildPage(context, state, const BuildingListPage());
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingOnboarding}',
      name: Routelists.buildingOnboarding,
      pageBuilder: (context, state) {
        final buildingId = state.uri.queryParameters['buildingId'];
        return _buildPage(
          context,
          state,
          BuildingOnboardingPage(buildingId: buildingId),
        );
      },
    ),
    GoRoute(
      path: '/view-report',
      name: Routelists.viewReport,
      redirect: (context, state) {
        final token = state.uri.queryParameters['token'];
        if (token == null || token.isEmpty) {
          return '/login';
        }
        return null;
      },
      pageBuilder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return _buildPage(context, state, ViewReportPage(token: token));
      },
    ),
    GoRoute(
      path: '/${Routelists.dashboard}',
      name: Routelists.dashboard,
      pageBuilder: (context, state) {
        final verseId = state.uri.queryParameters['verseId'];
        return _buildPage(context, state, DashboardPage(verseId: verseId));
      },
    ),
    GoRoute(
      path: '/statistics',
      name: Routelists.statistics,
      redirect: (context, state) {
        // When accessed via token (from view-report), token is required
        final token = state.uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          return null; // Allow access with token
        }
        // When accessed from dashboard (authenticated), no token needed
        return null;
      },
      pageBuilder: (context, state) {
        final token = state.uri.queryParameters['token'];
        final verseId = state.uri.queryParameters['verseId'];
        final userName = state.uri.queryParameters['userName'];
        final tokenInfo = state.extra as ReportTokenInfoEntity?;
        return _buildPage(
          context,
          state,
          StatisticsDashboardPage(
            token: token,
            tokenInfo: tokenInfo,
            verseId: verseId,
            userName: userName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.switchSettings}',
      name: Routelists.switchSettings,
      pageBuilder: (context, state) {
        return _buildPage(context, state, const SwitchSettingsScreen());
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingSummary}',
      name: Routelists.buildingSummary,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final buildingSize = state.uri.queryParameters['buildingSize'];
        final numberOfRooms = int.tryParse(
          state.uri.queryParameters['numberOfRooms'] ?? '',
        );
        final constructionYear = state.uri.queryParameters['constructionYear'];
        final floorPlanUrl = state.uri.queryParameters['floorPlanUrl'];
        final floorName = state.uri.queryParameters['floorName'];
        final roomsJson = state.uri.queryParameters['rooms'];

        List<Map<String, dynamic>>? rooms;
        if (roomsJson != null) {
          try {
            final decoded = Uri.decodeComponent(roomsJson);
            final List<dynamic> roomsList = jsonDecode(decoded);
            rooms = roomsList
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList();
          } catch (e) {
            rooms = null;
          }
        }

        return _buildPage(
          context,
          state,
          BuildingSummaryPage(
            userName: userName,
            buildingAddress: buildingAddress,
            buildingName: buildingName,
            buildingSize: buildingSize,
            numberOfRooms: numberOfRooms,
            constructionYear: constructionYear,
            floorPlanUrl: floorPlanUrl,
            floorName: floorName,
            rooms: rooms,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.roomAssignment}',
      name: Routelists.roomAssignment,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final floorPlanUrl = state.uri.queryParameters['floorPlanUrl'];
        final buildingId =
            state.uri.queryParameters['buildingId'] ??
            '6948dcd113537bff98eb7338'; // Default buildingId if not provided
        final floorName =
            state.uri.queryParameters['floorName'] ?? 'Ground Floor';
        final roomsJson = state.uri.queryParameters['rooms'];

        List<Map<String, dynamic>>? rooms;
        if (roomsJson != null) {
          try {
            final decoded = Uri.decodeComponent(roomsJson);
            final List<dynamic> roomsList = jsonDecode(decoded);
            rooms = roomsList
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList();
          } catch (e) {
            rooms = null;
          }
        }

        final numberOfFloors = int.tryParse(
          state.uri.queryParameters['numberOfFloors'] ?? '1',
        );
        final totalArea = double.tryParse(
          state.uri.queryParameters['totalArea'] ?? '',
        );
        final constructionYear = state.uri.queryParameters['constructionYear'];

        return _buildPage(
          context,
          state,
          RoomAssignmentPage(
            userName: userName,
            buildingAddress: buildingAddress,
            buildingName: buildingName,
            floorPlanUrl: floorPlanUrl,
            rooms: rooms,
            buildingId: buildingId,
            floorName: floorName,
            numberOfFloors: numberOfFloors,
            totalArea: totalArea,
            constructionYear: constructionYear,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.dataSourceSelection}',
      name: Routelists.dataSourceSelection,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final floorPlanUrl = state.uri.queryParameters['floorPlanUrl'];
        final selectedRoom = state.uri.queryParameters['selectedRoom'];
        final roomColorStr = state.uri.queryParameters['roomColor'];
        final buildingId =
            state.uri.queryParameters['buildingId'] ??
            '6948dcd113537bff98eb7338'; // Default buildingId if not provided

        Color? roomColor;
        if (roomColorStr != null) {
          try {
            final colorValue = int.tryParse(roomColorStr);
            roomColor = colorValue != null ? Color(colorValue) : null;
          } catch (e) {
            roomColor = null;
          }
        }

        return _buildPage(
          context,
          state,
          DataSourceSelectionPage(
            userName: userName,
            buildingAddress: buildingAddress,
            buildingName: buildingName,
            floorPlanUrl: floorPlanUrl,
            selectedRoom: selectedRoom,
            roomColor: roomColor,
            buildingId: buildingId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingContactPerson}',
      name: Routelists.buildingContactPerson,
      pageBuilder: (context, state) {
        final buildingName = state.uri.queryParameters['buildingName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingId = state.uri.queryParameters['buildingId'];
        final siteId = state.uri.queryParameters['siteId'];
        final userName = state.uri.queryParameters['userName'];
        final totalArea = state.uri.queryParameters['totalArea'];
        final numberOfRooms = state.uri.queryParameters['numberOfRooms'];
        final constructionYear = state.uri.queryParameters['constructionYear'];

        return _buildPage(
          context,
          state,
          BuildingContactPersonStep(
            buildingName: buildingName,
            buildingAddress: buildingAddress,
            buildingId: buildingId,
            siteId: siteId,
            userName: userName,
            totalArea: totalArea,
            numberOfRooms: numberOfRooms,
            constructionYear: constructionYear,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingRecipient}',
      name: Routelists.buildingRecipient,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final buildingId = state.uri.queryParameters['buildingId'];
        final siteId = state.uri.queryParameters['siteId'];
        final contactPerson = state.uri.queryParameters['contactPerson'];
        final totalArea = state.uri.queryParameters['totalArea'];
        final numberOfRooms = state.uri.queryParameters['numberOfRooms'];
        final constructionYear = state.uri.queryParameters['constructionYear'];

        return _buildPage(
          context,
          state,
          BuildingRecipientPage(
            userName: userName,
            buildingAddress: buildingAddress,
            buildingName: buildingName,
            buildingId: buildingId,
            siteId: siteId,
            contactPerson: contactPerson,
            totalArea: totalArea,
            numberOfRooms: numberOfRooms,
            constructionYear: constructionYear,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingResponsiblePersons}',
      name: Routelists.buildingResponsiblePersons,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final buildingId =
            state.uri.queryParameters['buildingId'] ??
            '6948dcd113537bff98eb7338'; // Default buildingId if not provided
        final buildingIds = state
            .uri
            .queryParameters['buildingIds']; // Comma-separated buildingIds
        final siteId = state.uri.queryParameters['siteId'];
        final recipientsJson = state.uri.queryParameters['recipients'];
        final recipient = state.uri.queryParameters['recipient'];
        final allRecipients = state.uri.queryParameters['allRecipients'];
        final recipientConfigs = state.uri.queryParameters['recipientConfigs'];
        final createForAll = state.uri.queryParameters['createForAll'];
        final reportConfigs = state.uri.queryParameters['reportConfigs'];

        return _buildPage(
          context,
          state,
          BuildingResponsiblePersonsPage(
            userName: userName,
            buildingAddress: buildingAddress,
            buildingName: buildingName,
            buildingId: buildingId,
            buildingIds: buildingIds, // Pass buildingIds
            siteId: siteId,
            recipientsJson: recipientsJson,
            recipient: recipient,
            allRecipients: allRecipients,
            recipientConfigs: recipientConfigs,
            createForAll: createForAll,
            reportConfigs: reportConfigs,
          ),
        );
      },
    ),
  ];

  static Page<dynamic> _buildPage(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return NoTransitionPage(child: child);
  }

  /// Push a named route
  void pushNamed(
    BuildContext context,
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    context.pushNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  /// Replace current route with a named route
  void replaceNamed(
    BuildContext context,
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
  }) {
    context.replaceNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  /// Pop the current route
  void pop(BuildContext context) {
    context.pop();
  }
}
