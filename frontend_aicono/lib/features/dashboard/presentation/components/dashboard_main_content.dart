import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';

class DashboardMainContent extends StatefulWidget {
  final String? verseId;

  const DashboardMainContent({super.key, this.verseId});

  @override
  State<DashboardMainContent> createState() => _DashboardMainContentState();
}

class _DashboardMainContentState extends State<DashboardMainContent> {
  String? _userFirstName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final loginRepository = sl<LoginRepository>();
      final userResult = await loginRepository.getCurrentUser();

      userResult.fold(
        (failure) {
          // Use default if loading fails
          if (mounted) {
            setState(() {
              _userFirstName = 'User';
            });
          }
        },
        (user) {
          if (mounted && user != null) {
            setState(() {
              _userFirstName = user.firstName.isNotEmpty
                  ? user.firstName
                  : 'User';
            });
          }
        },
      );
    } catch (e) {
      // Use default on error
      if (mounted) {
        setState(() {
          _userFirstName = 'User';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(),

          const SizedBox(height: 24),

          // Reporting Preview Button
          _buildReportingPreviewButton(),

          const SizedBox(height: 32),

          // "Was brauchst Du gerade?" Section
          _buildActionLinksSection(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.main_content.greeting'.tr(
            namedArgs: {
              'name': _userFirstName ?? 'User',
            },
          ),
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'dashboard.main_content.welcome_back'.tr(),
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildReportingPreviewButton() {
    return Center(
      child: PrimaryOutlineButton(
        onPressed: () {
          // TODO: Navigate to reporting preview page
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'dashboard.main_content.reporting_preview'.tr() +
                    ' ' +
                    'dashboard.main_content.coming_soon'.tr(),
              ),
            ),
          );
        },
        label: 'dashboard.main_content.reporting_preview'.tr(),
        width: 200,
      ),
    );
  }

  Widget _buildActionLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'dashboard.main_content.what_do_you_need'.tr(),
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.search,
              size: 20,
              color: Colors.grey[600],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildActionLink(
          text: 'dashboard.main_content.enter_measurement_data'.tr(),
          onTap: () {
            // TODO: Navigate to enter measurement data page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.enter_measurement_data'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionLink(
          text: 'dashboard.main_content.add_building'.tr(),
          onTap: () {
            // TODO: Navigate to add building page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.add_building'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionLink(
          text: 'dashboard.main_content.add_room'.tr(),
          onTap: () {
            // TODO: Navigate to add room page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.add_room'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionLink(
          text: 'dashboard.main_content.add_branding'.tr(),
          onTap: () {
            // TODO: Navigate to branding page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.main_content.add_branding'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionLink({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: AppTextStyles.titleSmall.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
