import 'dart:typed_data';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
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
import 'package:frontend_aicono/features/switch_creation/presentation/pages/select_property_type_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/add_properties_page.dart';
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
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/building_setup_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/sensor_min_max_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/building_summary_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/room_assignment_page.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/data_source_selection_page.dart';
import 'package:frontend_aicono/features/superadmin/presentation/pages/add_verse_super_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/building_list_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/building_onboarding_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/floor_plan_activation_page.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/steps/building_contact_person_step.dart';
import 'package:frontend_aicono/features/Building/presentation/pages/add_floor_name_page.dart';
import 'package:frontend_aicono/features/Building/domain/entities/building_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/page/dashboard_page.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/statistics_dashboard_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/view_report_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/edit_site_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/edit_building_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/edit_floor_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/edit_room_page.dart';
import 'package:frontend_aicono/features/dashboard/presentation/pages/dashboard_report_setup_page.dart';
import 'package:frontend_aicono/core/pages/not_found_page.dart';
import 'package:frontend_aicono/features/settings/presentation/pages/switch_settings_page.dart';
import 'package:frontend_aicono/features/settings/presentation/pages/profile_page.dart';
import 'package:frontend_aicono/features/user_invite/presentation/pages/invite_user_page.dart';
import 'package:frontend_aicono/features/user_invite/presentation/pages/complete_user_invite_page.dart';
import 'package:frontend_aicono/features/join_invite/presentation/pages/join_switch_almost_done_page.dart';

import '../../features/FloorPlan/presentation/pages/floor_plan_backup.dart';

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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
        if (invitation == null) {
          // If no invitation provided, redirect to login
          return '/login';
        }
        return null; // Continue to pageBuilder
      },
      pageBuilder: (context, state) {
        final invitation = _parseInvitationFromExtra(state.extra);
        if (invitation == null) {
          // If no invitation after parsing, redirect to login
          return _buildPage(context, state, const LoginPage());
        }
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
      path: '/${Routelists.almostJoinVerse}',
      name: Routelists.almostJoinVerse,
      pageBuilder: (context, state) {
        final invitation = state.extra as InvitationEntity?;
        if (invitation == null) {
          // If no invitation, redirect to login
          return _buildPage(context, state, const LoginPage());
        }
        return _buildPage(
          context,
          state,
          JoinSwitchAlmostDonePage(invitation: invitation),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.inviteUser}',
      name: Routelists.inviteUser,
      pageBuilder: (context, state) {
        final switchId = state.uri.queryParameters['switchId'];
        return _buildPage(context, state, InviteUserPage(switchId: switchId));
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
        final invitation = _parseInvitationFromExtra(state.extra);
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
      path: '/${Routelists.selectPropertyType}',
      name: Routelists.selectPropertyType,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        // final siteId = state.uri.queryParameters['siteId'] ?? '';

        // final validationError = _validateRequiredParams(state, siteId: siteId);
        // if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          SelectPropertyTypePage(
            userName: userName,
            switchId: switchId,
            // siteId: siteId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addProperties}',
      name: Routelists.addProperties,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        final isSingleProperty =
            state.uri.queryParameters['isSingleProperty'] == 'true';
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        return _buildPage(
          context,
          state,
          AddPropertiesPage(
            userName: userName,
            switchId: switchId,
            fromDashboard: fromDashboard,
            isSingleProperty: isSingleProperty,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addPropertyName}',
      name: Routelists.addPropertyName,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        final propertyName = state.uri.queryParameters['propertyName'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';

        final validationError = _validateRequiredParams(state, siteId: siteId);
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          AddPropertyNamePage(
            userName: userName,
            switchId: switchId,
            propertyName: propertyName,
            siteId: siteId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addPropertyLocation}',
      name: Routelists.addPropertyLocation,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';

        final validationError = _validateRequiredParams(state, siteId: siteId);
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          AddPropertyLocationPage(
            userName: userName,
            switchId: switchId,
            siteId: siteId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.selectResources}',
      name: Routelists.selectResources,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';

        final validationError = _validateRequiredParams(state, siteId: siteId);
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          SelectResourcesPage(
            userName: userName,
            switchId: switchId,
            siteId: siteId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addAdditionalBuildings}',
      name: Routelists.addAdditionalBuildings,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final fromDashboard = state.uri.queryParameters['fromDashboard'];

        final validationError = _validateRequiredParams(state, siteId: siteId);
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          AddAdditionalBuildingsPage(
            userName: userName,
            siteId: siteId,
            fromDashboard: fromDashboard,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.additionalBuildingList}',
      name: Routelists.additionalBuildingList,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final switchId = state.uri.queryParameters['switchId'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];

        final validationError = _validateRequiredParams(state, siteId: siteId);
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          AdditionalBuildingListPage(
            userName: userName,
            siteId: siteId,
            switchId: switchId,
            fromDashboard: fromDashboard,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.setBuildingDetails}',
      name: Routelists.setBuildingDetails,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final fromDashboard = state.uri.queryParameters['fromDashboard'];

        final validationError = _validateRequiredParams(
          state,
          siteId: siteId,
          buildingId: buildingId,
        );
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          SetBuildingDetailsPage(
            userName: userName,
            buildingAddress: buildingAddress,
            buildingId: buildingId,
            siteId: siteId,
            fromDashboard: fromDashboard,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.loxoneConnection}',
      name: Routelists.loxoneConnection,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final siteId = state.uri.queryParameters['siteId'] ?? "";
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        if (siteId.isEmpty || buildingId.isEmpty) {
          final missingParams = siteId.isEmpty && buildingId.isEmpty
              ? 'siteId and buildingId'
              : siteId.isEmpty
              ? 'siteId'
              : 'buildingId';
          return _buildPage(
            context,
            state,
            NotFoundPage(
              message: 'Required parameters missing: $missingParams',
            ),
          );
        }
        return _buildPage(
          context,
          state,
          LoxoneConnectionPage(
            userName: userName,
            buildingId: buildingId,
            siteId: siteId,
          ),
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
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final completedFloorName =
            state.uri.queryParameters['completedFloorName'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        final floorName = state.uri.queryParameters['floorName'];
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];

        final validationError = _validateRequiredParams(
          state,
          siteId: siteId,
          buildingId: buildingId,
        );
        if (validationError != null) return validationError;

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
            completedFloorName: completedFloorName,
            fromDashboard: fromDashboard,
            floorName: floorName,
            userName: userName,
            switchId: switchId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addFloorName}',
      name: Routelists.addFloorName,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        final switchId = state.uri.queryParameters['switchId'];
        final floorName = state.uri.queryParameters['floorName'];
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final fromDashboard = state.uri.queryParameters['fromDashboard'];

        final validationError = _validateRequiredParams(
          state,
          siteId: siteId,
          buildingId: buildingId,
        );
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          AddFloorNamePage(
            userName: userName,
            switchId: switchId,
            floorName: floorName,
            siteId: siteId,
            buildingId: buildingId,
            fromDashboard: fromDashboard,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.floorPlanEditor}',
      name: Routelists.floorPlanEditor,
      pageBuilder: (context, state) {
        // return _buildPage(context, state, const FloorPlanPage());
        return _buildPage(context, state, const FloorPlanBackupPage());
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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final validationError = _validateRequiredParams(
          state,
          buildingId: buildingId,
          siteId: siteId,
        );
        if (validationError != null) return validationError;

        return _buildPage(
          context,
          state,
          BuildingOnboardingPage(buildingId: buildingId, siteId: siteId),
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
        var verseId = state.uri.queryParameters['verseId'];
        if (verseId == null || verseId.isEmpty) {
          verseId = sl<LocalStorage>().getSelectedVerseId();
        }
        // Use refresh param in key to force new instance when returning from switch settings
        // (ensures _loadDashboardData runs and switch name updates immediately)
        final refresh = state.uri.queryParameters['refresh'] ?? '';
        return _buildPage(
          context,
          state,
          DashboardPage(
            key: ValueKey('${verseId ?? 'dashboard'}_$refresh'),
            verseId: verseId,
          ),
        );
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
        final recipientName = state.uri.queryParameters['recipientName'];
        final tokenInfo = state.extra as ReportTokenInfoEntity?;
        String? displayName = recipientName;
        if (displayName == null || displayName.isEmpty) {
          final n = tokenInfo?.recipient.name.trim();
          displayName = n != null && n.isNotEmpty
              ? n
              : tokenInfo?.recipient.email.trim();
        }
        if (displayName == null || displayName.isEmpty) {
          displayName = userName;
        }
        displayName ??= 'Stephan';
        return _buildPage(
          context,
          state,
          StatisticsDashboardPage(
            token: token,
            tokenInfo: tokenInfo,
            verseId: verseId,
            userName: userName,
            recipientName: displayName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.switchSettings}',
      name: Routelists.switchSettings,
      pageBuilder: (context, state) {
        var switchId = state.uri.queryParameters['switchId'] ?? '';
        if (switchId.isEmpty) {
          switchId = sl<LocalStorage>().getSelectedVerseId() ?? '';
        }
        return _buildPage(
          context,
          state,
          SwitchSettingsScreen(switchId: switchId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.profile}',
      name: Routelists.profile,
      pageBuilder: (context, state) {
        return _buildPage(context, state, const ProfilePage());
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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final siteId = state.uri.queryParameters['siteId'] ?? '';
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

        final validationError = _validateRequiredParams(
          state,
          buildingId: buildingId,
          siteId: siteId,
        );
        if (validationError != null) return validationError;

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
            buildingId: buildingId,
            siteId: siteId,
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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final floorName =
            state.uri.queryParameters['floorName'] ?? 'Ground Floor';

        final validationError = _validateRequiredParams(
          state,
          buildingId: buildingId,
          siteId: siteId,
        );
        if (validationError != null) return validationError;
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
            siteId: siteId,
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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';

        final validationError = _validateRequiredParams(
          state,
          buildingId: buildingId,
        );
        if (validationError != null) return validationError;

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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final userName = state.uri.queryParameters['userName'];
        final totalArea = state.uri.queryParameters['totalArea'];
        final numberOfRooms = state.uri.queryParameters['numberOfRooms'];
        final constructionYear = state.uri.queryParameters['constructionYear'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        final floorName = state.uri.queryParameters['floorName'];

        final validationError = _validateRequiredParams(
          state,
          siteId: siteId,
          buildingId: buildingId,
        );
        if (validationError != null) return validationError;

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
            fromDashboard: fromDashboard,
            floorName: floorName,
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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final contactPerson = state.uri.queryParameters['contactPerson'];
        final totalArea = state.uri.queryParameters['totalArea'];
        final numberOfRooms = state.uri.queryParameters['numberOfRooms'];
        final constructionYear = state.uri.queryParameters['constructionYear'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        final floorName = state.uri.queryParameters['floorName'];

        final validationError = _validateRequiredParams(
          state,
          siteId: siteId,
          buildingId: buildingId,
        );
        if (validationError != null) return validationError;

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
            fromDashboard: fromDashboard,
            floorName: floorName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.buildingSetup}',
      name: Routelists.buildingSetup,
      pageBuilder: (context, state) {
        final buildingId = state.uri.queryParameters['buildingId'];
        final siteId = state.uri.queryParameters['siteId'];
        final buildingName = state.uri.queryParameters['buildingName'];
        final buildingAddress = state.uri.queryParameters['buildingAddress'];
        final numberOfFloors = state.uri.queryParameters['numberOfFloors'];
        final numberOfRooms = state.uri.queryParameters['numberOfRooms'];
        final totalArea = state.uri.queryParameters['totalArea'];
        final constructionYear = state.uri.queryParameters['constructionYear'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          BuildingSetupPage(
            buildingId: buildingId,
            siteId: siteId,
            buildingName: buildingName,
            buildingAddress: buildingAddress,
            numberOfFloors: numberOfFloors,
            numberOfRooms: numberOfRooms,
            totalArea: totalArea,
            constructionYear: constructionYear,
            fromDashboard: fromDashboard,
            userName: userName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.sensorMinMax}',
      name: Routelists.sensorMinMax,
      pageBuilder: (context, state) {
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final siteId = state.uri.queryParameters['siteId'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];

        if (buildingId.isEmpty) {
          return _buildPage(
            context,
            state,
            NotFoundPage(message: 'Required parameter missing: buildingId'),
          );
        }

        return _buildPage(
          context,
          state,
          SensorMinMaxPage(
            buildingId: buildingId,
            siteId: siteId,
            fromDashboard: fromDashboard,
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
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final buildingIds = state
            .uri
            .queryParameters['buildingIds']; // Comma-separated buildingIds
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        final recipientsJson = state.uri.queryParameters['recipients'];
        final recipient = state.uri.queryParameters['recipient'];
        final allRecipients = state.uri.queryParameters['allRecipients'];
        final recipientConfigs = state.uri.queryParameters['recipientConfigs'];
        final createForAll = state.uri.queryParameters['createForAll'];
        final reportConfigs = state.uri.queryParameters['reportConfigs'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        final floorName = state.uri.queryParameters['floorName'];

        // If buildingIds is provided, we don't need to validate individual buildingId
        // Otherwise, validate buildingId and siteId
        if (buildingIds == null || buildingIds.isEmpty) {
          final validationError = _validateRequiredParams(
            state,
            siteId: siteId,
            buildingId: buildingId,
          );
          if (validationError != null) return validationError;
        } else {
          // If buildingIds is provided, still validate siteId
          final validationError = _validateRequiredParams(
            state,
            siteId: siteId,
          );
          if (validationError != null) return validationError;
        }

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
            fromDashboard: fromDashboard,
            floorName: floorName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.editSite}',
      name: Routelists.editSite,
      pageBuilder: (context, state) {
        final siteId = state.uri.queryParameters['siteId'] ?? '';
        if (siteId.isEmpty) {
          return _buildPage(
            context,
            state,
            NotFoundPage(message: 'Required parameter missing: siteId'),
          );
        }
        return _buildPage(context, state, EditSitePage(siteId: siteId));
      },
    ),
    GoRoute(
      path: '/${Routelists.editBuilding}',
      name: Routelists.editBuilding,
      pageBuilder: (context, state) {
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        if (buildingId.isEmpty) {
          return _buildPage(
            context,
            state,
            NotFoundPage(message: 'Required parameter missing: buildingId'),
          );
        }
        return _buildPage(
          context,
          state,
          EditBuildingPage(buildingId: buildingId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.editFloor}',
      name: Routelists.editFloor,
      pageBuilder: (context, state) {
        final floorId = state.uri.queryParameters['floorId'] ?? '';
        if (floorId.isEmpty) {
          return _buildPage(
            context,
            state,
            NotFoundPage(message: 'Required parameter missing: floorId'),
          );
        }
        return _buildPage(context, state, EditFloorPage(floorId: floorId));
      },
    ),
    GoRoute(
      path: '/${Routelists.editRoom}',
      name: Routelists.editRoom,
      pageBuilder: (context, state) {
        final roomId = state.uri.queryParameters['roomId'] ?? '';
        final buildingId = state.uri.queryParameters['buildingId'];
        if (roomId.isEmpty) {
          return _buildPage(
            context,
            state,
            NotFoundPage(message: 'Required parameter missing: roomId'),
          );
        }
        return _buildPage(
          context,
          state,
          EditRoomPage(roomId: roomId, buildingId: buildingId),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.dashboardReportSetup}',
      name: Routelists.dashboardReportSetup,
      pageBuilder: (context, state) {
        final buildingId = state.uri.queryParameters['buildingId'] ?? '';
        final reportingJson = state.uri.queryParameters['reporting'];
        final recipientsJson = state.uri.queryParameters['recipients'];
        final fromDashboard = state.uri.queryParameters['fromDashboard'];
        if (buildingId.isEmpty) {
          return _buildPage(
            context,
            state,
            NotFoundPage(message: 'Required parameters missing: buildingId'),
          );
        }
        return _buildPage(
          context,
          state,
          DashboardReportSetupPage(
            buildingId: buildingId,
            reportingJson: reportingJson,
            recipientsJson: recipientsJson,
            fromDashboard: fromDashboard,
          ),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.notFound}',
      name: Routelists.notFound,
      pageBuilder: (context, state) {
        final message = state.uri.queryParameters['message'];
        return _buildPage(context, state, NotFoundPage(message: message));
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

  /// Helper function to safely parse InvitationEntity from state.extra
  /// Handles both InvitationEntity instances and JSON maps (from navigation history)
  static InvitationEntity? _parseInvitationFromExtra(Object? extra) {
    if (extra == null) return null;

    // If it's already an InvitationEntity, return it
    if (extra is InvitationEntity) {
      return extra;
    }

    // If it's a Map (JSON), try to convert it to InvitationEntity
    // Handle both Map<String, dynamic> and Map<dynamic, dynamic> (from JSON deserialization)
    if (extra is Map) {
      try {
        // Convert to Map<String, dynamic> if needed
        final jsonMap = extra is Map<String, dynamic>
            ? extra
            : Map<String, dynamic>.from(
                extra.map((key, value) => MapEntry(key.toString(), value)),
              );
        return InvitationEntity.fromJson(jsonMap);
      } catch (e) {
        debugPrint('Error parsing InvitationEntity from JSON: $e');
        return null;
      }
    }

    return null;
  }

  /// Helper function to validate required parameters and return 404 page if missing
  static Page<dynamic>? _validateRequiredParams(
    GoRouterState state, {
    String? siteId,
    String? buildingId,
  }) {
    final List<String> missingParams = [];

    if (siteId != null && (siteId.isEmpty || siteId == 'null')) {
      missingParams.add('siteId');
    }

    if (buildingId != null && (buildingId.isEmpty || buildingId == 'null')) {
      missingParams.add('buildingId');
    }

    if (missingParams.isNotEmpty) {
      final missingParamsStr = missingParams.join(' and ');
      return NoTransitionPage(
        child: NotFoundPage(
          message: 'Required parameters missing: $missingParamsStr',
        ),
      );
    }

    return null;
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
