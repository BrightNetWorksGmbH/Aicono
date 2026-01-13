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
import 'package:frontend_aicono/features/switch_creation/presentation/pages/building_detail/set_building_details_page.dart';
import 'package:frontend_aicono/features/superadmin/presentation/pages/add_verse_super_page.dart';

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

        final isJoinVerseRoute = false; // Routes removed - not in project

        print(
          'AppRouter - isInvitationValidationRoute: $isInvitationValidationRoute',
        );
        print('AppRouter - isJoinVerseRoute: $isJoinVerseRoute');
        print('AppRouter - isAuthenticated: $isAuthenticated');

        // Allow access to invitation validation, join verse, and reset password routes regardless of authentication status
        if (isInvitationValidationRoute ||
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

        // If user is authenticated and trying to access login, redirect based on role
        if (isAuthenticated && isLoginRoute && !isSuperAdmin) {
          return null; // Stay on login page for non-super admins
        }

        // If user is not authenticated and trying to access dashboard, redirect to login
        if (!isAuthenticated && isDashboardRoute) {
          return '/login';
        }

        // If user is not authenticated and on root, redirect to login
        if (!isAuthenticated && state.uri.path == '/') {
          return '/login';
        }

        // If user is authenticated and on root (non-super admin), redirect to login
        if (isAuthenticated && state.uri.path == '/' && !isSuperAdmin) {
          return '/login';
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
        print('AppRouter - Login route with invitation: $invitation, token: $token');
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
          ActivateSwitchboardPage(
            userName: userName,
            token: token,
          ),
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
      path: '/${Routelists.setSwitchName}',
      name: Routelists.setSwitchName,
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
      path: '/${Routelists.structureSwitch}',
      name: Routelists.structureSwitch,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          StructureSwitchPage(userName: userName),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.confirmStructure}',
      name: Routelists.confirmStructure,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          ConfirmStructurePage(userName: userName),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addPropertyName}',
      name: Routelists.addPropertyName,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          AddPropertyNamePage(userName: userName),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addPropertyLocation}',
      name: Routelists.addPropertyLocation,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          AddPropertyLocationPage(userName: userName),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.selectResources}',
      name: Routelists.selectResources,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          SelectResourcesPage(userName: userName),
        );
      },
    ),
    GoRoute(
      path: '/${Routelists.addAdditionalBuildings}',
      name: Routelists.addAdditionalBuildings,
      pageBuilder: (context, state) {
        final userName = state.uri.queryParameters['userName'];
        return _buildPage(
          context,
          state,
          AddAdditionalBuildingsPage(userName: userName),
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
  }) {
    context.pushNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
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
