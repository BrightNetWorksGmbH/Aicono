import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';

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

          // Sites & Buildings (from dashboard endpoints)
          _buildSitesAndBuildingsSection(),

          const SizedBox(height: 32),

          // Reporting Preview Button
          _buildReportingPreviewButton(),

          const SizedBox(height: 32),

          // "Was brauchst Du gerade?" Section
          _buildActionLinksSection(),
        ],
      ),
    );
  }

  Widget _buildSitesAndBuildingsSection() {
    return BlocBuilder<DashboardSitesBloc, DashboardSitesState>(
      builder: (context, sitesState) {
        if (sitesState is DashboardSitesInitial || sitesState is DashboardSitesLoading) {
          return _buildCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading sites...',
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        if (sitesState is DashboardSitesFailure) {
          return _buildCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red[600], size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sitesState.message,
                    style: AppTextStyles.titleSmall.copyWith(color: Colors.red[700]),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    context.read<DashboardSitesBloc>().add(DashboardSitesRequested());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (sitesState is DashboardSitesSuccess) {
          if (sitesState.sites.isEmpty) {
            return _buildCard(
              child: Text(
                'No sites found.',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sites',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSiteDropdown(sitesState),
                    const SizedBox(height: 16),
                    _buildSiteDetails(),
                  ],
                ),
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSiteDropdown(DashboardSitesSuccess sitesState) {
    final detailsState = context.watch<DashboardSiteDetailsBloc>().state;
    String? selectedSiteId;
    if (detailsState is DashboardSiteDetailsLoading) {
      selectedSiteId = detailsState.siteId;
    } else if (detailsState is DashboardSiteDetailsSuccess) {
      selectedSiteId = detailsState.siteId;
    } else if (detailsState is DashboardSiteDetailsFailure) {
      selectedSiteId = detailsState.siteId;
    }

    final value = selectedSiteId ?? sitesState.sites.first.id;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              labelText: 'Select site',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: sitesState.sites
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(
                      s.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              context.read<DashboardSiteDetailsBloc>().add(
                    DashboardSiteDetailsRequested(siteId: id),
                  );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSiteDetails() {
    return BlocBuilder<DashboardSiteDetailsBloc, DashboardSiteDetailsState>(
      builder: (context, state) {
        if (state is DashboardSiteDetailsInitial) {
          return Text(
            'Select a site to view details.',
            style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
          );
        }

        if (state is DashboardSiteDetailsLoading) {
          return Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading site details...',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
              ),
            ],
          );
        }

        if (state is DashboardSiteDetailsFailure) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.message,
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.red[700]),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  context.read<DashboardSiteDetailsBloc>().add(
                        DashboardSiteDetailsRequested(siteId: state.siteId),
                      );
                },
                child: const Text('Retry'),
              ),
            ],
          );
        }

        if (state is DashboardSiteDetailsSuccess) {
          final d = state.details;
          final kpis = d.kpis;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.name,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d.address,
                style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _kpiTile(
                    label: 'Buildings',
                    value: '${d.buildingCount}',
                  ),
                  _kpiTile(
                    label: 'Floors',
                    value: '${d.totalFloors}',
                  ),
                  _kpiTile(
                    label: 'Rooms',
                    value: '${d.totalRooms}',
                  ),
                  _kpiTile(
                    label: 'Sensors',
                    value: '${d.totalSensors}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (kpis != null) ...[
                Text(
                  'KPIs (${kpis.unit})',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiTile(
                      label: 'Total',
                      value: kpis.totalConsumption.toStringAsFixed(3),
                    ),
                    _kpiTile(
                      label: 'Peak',
                      value: kpis.peak.toStringAsFixed(3),
                    ),
                    _kpiTile(
                      label: 'Base',
                      value: kpis.base.toStringAsFixed(3),
                    ),
                    _kpiTile(
                      label: 'Average',
                      value: kpis.average.toStringAsFixed(3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Buildings',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              if (d.buildings.isEmpty)
                Text(
                  'No buildings for this site yet.',
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[700]),
                )
              else
                Column(
                  children: d.buildings.map((b) {
                    final bk = b.kpis;
                    final subtitle = bk == null
                        ? 'No KPI data'
                        : 'Total: ${bk.totalConsumption.toStringAsFixed(3)} ${bk.unit}';
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.apartment, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${b.sensorCount} sensors',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _kpiTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
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
