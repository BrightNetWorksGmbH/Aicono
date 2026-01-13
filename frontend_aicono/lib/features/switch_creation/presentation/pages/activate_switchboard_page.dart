import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/activate_switchboard_widget.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/invitation_usecase.dart';

class ActivateSwitchboardPage extends StatefulWidget {
  final String? userName;
  final String token;
  const ActivateSwitchboardPage({
    super.key,
    this.userName,
    required this.token,
  });

  @override
  State<ActivateSwitchboardPage> createState() =>
      _ActivateSwitchboardPageState();
}

class _ActivateSwitchboardPageState extends State<ActivateSwitchboardPage> {
  InvitationEntity? _invitation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInvitation();
  }

  Future<void> _fetchInvitation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final invitationUseCase = sl<InvitationUseCase>();
      final result = await invitationUseCase.getInvitationByToken(
        widget.token,
      );

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message;
          });
        },
        (invitation) {
          setState(() {
            _isLoading = false;
            _invitation = invitation;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load invitation: $e';
      });
    }
  }

  void _handleLanguageChanged() {
    // Force rebuild when language changes
    setState(() {});
  }

  void _handleContinue() {
    if (_invitation == null) {
      // Show error or retry
      return;
    }
    // Navigate to set organization name page, passing userName if available and invitation
    context.pushNamed(
      Routelists.setOrganizationName,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        'token': widget.token,
      },
      extra: _invitation,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenSize.width,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : Column(
                        children: [
                          ActivateSwitchboardWidget(
                            userName: _invitation?.firstName ?? widget.userName,
                            onLanguageChanged: _handleLanguageChanged,
                            onContinue: _handleContinue,
                          ),
                          AppFooter(
                            onLanguageChanged: _handleLanguageChanged,
                            containerWidth: screenSize.width,
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading invitation...',
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 24),
          Text(
            'Error loading invitation',
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchInvitation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }
}
