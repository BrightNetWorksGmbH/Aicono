import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_view_widget.dart';

class DashboardSidebar extends StatefulWidget {
  const DashboardSidebar({
    super.key,
    this.isInDrawer = false,
    this.onLanguageChanged,
  });

  /// Whether the sidebar is being used in a drawer (affects width)
  final bool isInDrawer;

  /// Callback for when language changes (to trigger dashboard rebuild)
  final VoidCallback? onLanguageChanged;

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  String? currentVerseId;
  List<TreeItemEntity> _properties = [];
  List<TreeItemEntity> _reportings = [];

  @override
  void initState() {
    super.initState();
    _loadVerseId();
    _loadSampleData();
  }

  void _loadVerseId() {
    final localStorage = sl<LocalStorage>();
    final savedVerseId = localStorage.getSelectedVerseId();
    setState(() {
      currentVerseId = savedVerseId;
    });
  }

  void _loadSampleData() {
    // Dummy hierarchical data for properties
    setState(() {
      _properties = [
        TreeItemEntity(
          id: 'prop1',
          name: 'Hauptsitz Münster',
          type: 'property',
          children: [
            TreeItemEntity(
              id: 'prop1_building1',
              name: 'Gebäude A',
              type: 'property',
              children: [
                TreeItemEntity(
                  id: 'prop1_building1_floor1',
                  name: 'Erdgeschoss',
                  type: 'property',
                ),
                TreeItemEntity(
                  id: 'prop1_building1_floor2',
                  name: '1. Obergeschoss',
                  type: 'property',
                ),
              ],
            ),
            TreeItemEntity(
              id: 'prop1_building2',
              name: 'Gebäude B',
              type: 'property',
            ),
          ],
        ),
        TreeItemEntity(
          id: 'prop2',
          name: 'Zweigstelle Regensburg',
          type: 'property',
          children: [
            TreeItemEntity(
              id: 'prop2_building1',
              name: 'Hauptgebäude',
              type: 'property',
            ),
          ],
        ),
      ];

      // Dummy hierarchical data for reportings
      _reportings = [
        TreeItemEntity(
          id: 'rep1',
          name: 'CFO Reporting Münster',
          type: 'reporting',
          children: [
            TreeItemEntity(
              id: 'rep1_q1',
              name: 'Q1 2024',
              type: 'reporting',
            ),
            TreeItemEntity(
              id: 'rep1_q2',
              name: 'Q2 2024',
              type: 'reporting',
            ),
          ],
        ),
        TreeItemEntity(
          id: 'rep2',
          name: 'CFO Reporting Regensburg',
          type: 'reporting',
          children: [
            TreeItemEntity(
              id: 'rep2_q1',
              name: 'Q1 2024',
              type: 'reporting',
            ),
          ],
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isInDrawer ? null : 310,
      padding: EdgeInsets.all(widget.isInDrawer ? 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deine Liegenschaften (Your Properties)
            _buildPropertiesSection(),

            const SizedBox(height: 16),

            // Deine Reportings (Your Reportings)
            _buildReportingsSection(),

            const SizedBox(height: 16),

            // Deine Unternehmen (Your Companies)
            _buildVerseSection(),

            const SizedBox(height: 16),

            // Settings Section
            _buildSettingsSection(),

            const SizedBox(height: 24),

            // Profile and Language options (for mobile/drawer)
            if (widget.isInDrawer) ...[
              _buildProfileSection(),
              const SizedBox(height: 16),
              _buildLanguageSection(),
              const SizedBox(height: 16),
            ],

            // Logout Button
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Clear selection when clicking on section title
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.properties'.tr(),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        TreeViewWidget(
          items: _properties,
          onItemTap: (item) {
            // Handle item tap
            print('Property tapped: ${item.name}');
          },
          onAddItem: () {
            // TODO: Navigate to add location page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.sidebar.add_location'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
          addItemLabel: 'dashboard.sidebar.add_location'.tr(),
        ),
      ],
    );
  }

  Widget _buildReportingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Clear selection when clicking on section title
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.reportings'.tr(),
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        TreeViewWidget(
          items: _reportings,
          onItemTap: (item) {
            // Handle item tap
            print('Reporting tapped: ${item.name}');
          },
          onAddItem: () {
            // TODO: Navigate to add reporting page
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'dashboard.sidebar.add_reporting'.tr() +
                      ' ' +
                      'dashboard.main_content.coming_soon'.tr(),
                ),
              ),
            );
          },
          addItemLabel: 'dashboard.sidebar.add_reporting'.tr(),
        ),
      ],
    );
  }

  Widget _buildVerseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.sidebar.companies'.tr(),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        const SizedBox(height: 12),
        // Company logo placeholder
        Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Icon(
            Icons.business,
            color: AppTheme.primary,
            size: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (currentVerseId != null) {
              context.pushNamed(
                Routelists.verseSettings,
                extra: {'verseId': currentVerseId},
              );
            }
          },
          child: Text(
            'dashboard.sidebar.settings'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        InkWell(
          onTap: () {
            // TODO: Navigate to Links page
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.links'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        InkWell(
          onTap: () {
            if (currentVerseId != null) {
              context.pushNamed(
                Routelists.statistics,
                pathParameters: {
                  'verseId': currentVerseId ?? '',
                },
              );
            }
          },
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Text(
            'dashboard.sidebar.statistics'.tr(),
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Divider(
          height: 20,
          thickness: 1,
          color: Color(0x40000000),
        ),
        InkWell(
          onTap: () {
            if (currentVerseId != null) {
              context.pushNamed(
                Routelists.inviteUser,
                extra: {
                  'verseId': currentVerseId,
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'dashboard.sidebar.add_user'.tr(),
              style: AppTextStyles.titleSmall.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return InkWell(
      onTap: _handleProfileTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 16, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              'dashboard.sidebar.profile'.tr(),
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.sidebar.language'.tr(),
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildLanguageOption(
          context: context,
          locale: const Locale('en'),
          label: 'dashboard.sidebar.english'.tr(),
          isSelected: context.locale.languageCode == 'en',
        ),
        const SizedBox(height: 4),
        _buildLanguageOption(
          context: context,
          locale: const Locale('de'),
          label: 'dashboard.sidebar.deutsch'.tr(),
          isSelected: context.locale.languageCode == 'de',
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        await context.setLocale(locale);
        if (!mounted) return;
        setState(() {});
        // Notify parent to rebuild dashboard content
        widget.onLanguageChanged?.call();
      },
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            if (isSelected)
              Icon(Icons.check, size: 16, color: AppTheme.primary)
            else
              const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: isSelected ? AppTheme.primary : Colors.black54,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProfileTap() {
    try {
      context.pushNamed(Routelists.profile, extra: {'verseId': currentVerseId});
    } catch (_) {
      // fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'dashboard.sidebar.profile'.tr() +
                ' ' +
                'dashboard.main_content.coming_soon'.tr(),
          ),
        ),
      );
    }
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _handleLogout,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.logout, size: 16, color: Colors.red[600]),
            const SizedBox(width: 8),
            Text(
              'dashboard.sidebar.logout'.tr(),
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      final authService = sl<AuthService>();
      // Clear selected verse on logout proactively
      await sl<LocalStorage>().clearSelectedVerseId();
      await authService.logout();

      if (mounted) {
        // Navigate to login page
        context.goNamed(Routelists.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'dashboard.error.loading_dashboard'.tr(
                namedArgs: {'error': '$e'},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
