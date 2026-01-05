import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/invitation_validation_bloc.dart';

class InvitationValidationPage extends StatefulWidget {
  final String token;

  const InvitationValidationPage({super.key, required this.token});

  @override
  State<InvitationValidationPage> createState() =>
      _InvitationValidationPageState();
}

class _InvitationValidationPageState extends State<InvitationValidationPage> {
  @override
  void initState() {
    super.initState();
    // Ensure we are logged out when coming from invitation link
    _logoutIfNeededAndValidate();
  }

  void _logoutIfNeededAndValidate() async {
    try {
      final authService = sl<AuthService>();
      if (authService.isAuthenticated) {
        await authService.logout();
      }
    } catch (_) {
      // Fall back to clearing local state if remote logout fails
      try {
        sl<AuthService>().clearAuth();
      } catch (_) {}
    } finally {
      // Trigger invitation validation after ensuring logout
      if (mounted) {
        context.read<InvitationValidationBloc>().add(
          ValidateInvitation(widget.token),
        );
      }
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvitationValidationBloc, InvitationValidationState>(
      listener: (context, state) {
        if (state is InvitationValidationSuccess) {
          // If user already exists -> go to login; else -> reset password
          if (state.userExists) {
            context.pushNamed(Routelists.login, extra: state.invitation);
          } else {
            context.pushNamed(
              Routelists.resetPassword,
              extra: state.invitation,
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width > 500
                  ? 500
                  : MediaQuery.of(context).size.width * 0.9,
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        // Logo or Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF214a59), Color(0xFF171c23)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.mail_outline,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Content based on state
                        BlocBuilder<
                          InvitationValidationBloc,
                          InvitationValidationState
                        >(
                          builder: (context, state) {
                            if (state is InvitationValidationLoading) {
                              return _buildLoadingContent();
                            } else if (state is InvitationValidationFailure) {
                              return _buildErrorContent(state);
                            } else {
                              return _buildInitialContent();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  AppFooter(
                    onLanguageChanged: _handleLanguageChanged,
                    containerWidth: MediaQuery.of(context).size.width > 500
                        ? 500
                        : MediaQuery.of(context).size.width,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Validating your invitation...',
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please wait while we verify your invitation',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildErrorContent(InvitationValidationFailure state) {
    print(state.invitation?.email);
    return Column(
      children: [
        // Error Icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: state.isExpired ? Colors.orange : Colors.red,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            state.isExpired ? Icons.schedule : Icons.error_outline,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),

        // Error Title
        Text(
          state.isExpired ? 'Invitation Expired' : 'Invalid Invitation',
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Error Message
        Text(
          state.message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 24),

        // Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              print('Navigating to login with invitation: ${state.invitation}');
              context.pushNamed(Routelists.login, extra: state.invitation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Go to Login',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialContent() {
    return Column(
      children: [
        Text(
          'Invitation Validation',
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We are processing your invitation',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
