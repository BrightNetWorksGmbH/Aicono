import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

class BuildingResponsiblePersonsPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? buildingId;
  final String? siteId;

  const BuildingResponsiblePersonsPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.buildingId,
    this.siteId,
  });

  @override
  State<BuildingResponsiblePersonsPage> createState() =>
      _BuildingResponsiblePersonsPageState();
}

class _BuildingResponsiblePersonsPageState
    extends State<BuildingResponsiblePersonsPage> {
  final TextEditingController _reportingNameController =
      TextEditingController();
  String _selectedFrequencyKey = 'monthly';
  final Map<String, bool> _reportOptions = {
    'total_consumption': true,
    'peak_loads': false,
    'anomalies': false,
    'rooms_by_consumption': true,
    'underutilization': true,
  };

  String get _selectedFrequency =>
      'building_responsible_persons.$_selectedFrequencyKey'.tr();

  @override
  void dispose() {
    _reportingNameController.dispose();
    super.dispose();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleFrequencyChange() {
    // Show frequency selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('building_responsible_persons.select_frequency'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFrequencyOption(
              'building_responsible_persons.daily'.tr(),
              'daily',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.weekly'.tr(),
              'weekly',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.monthly'.tr(),
              'monthly',
            ),
            _buildFrequencyOption(
              'building_responsible_persons.yearly'.tr(),
              'yearly',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyOption(String frequency, String key) {
    return ListTile(
      title: Text(frequency),
      onTap: () {
        setState(() {
          _selectedFrequencyKey = key;
        });
        Navigator.of(context).pop();
      },
    );
  }

  void _handleReportOptionToggle(String option) {
    setState(() {
      _reportOptions[option] = !(_reportOptions[option] ?? false);
    });
  }

  String _getReportOptionLabel(String key) {
    return 'building_responsible_persons.$key'.tr();
  }

  void _handleContinue() {
    // TODO: Save responsible persons data
    // Navigate back to add additional buildings page
    context.goNamed(
      Routelists.addAdditionalBuildings,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.siteId != null && widget.siteId!.isNotEmpty)
          'siteId': widget.siteId!,
      },
    );
  }

  void _handleSkip() {
    // Skip this step
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenSize.width,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    height: (screenSize.height * 0.95) + 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Material(
                            color: Colors.transparent,
                            child: TopHeader(
                              onLanguageChanged: _handleLanguageChanged,
                              containerWidth: screenSize.width > 500
                                  ? 500
                                  : screenSize.width * 0.98,
                              userInitial: widget.userName?[0].toUpperCase(),
                              verseInitial: null,
                            ),
                          ),
                          if (widget.userName != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'building_responsible_persons.progress_text'.tr(
                                namedArgs: {'name': widget.userName!},
                              ),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.95,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B9A5B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                          const SizedBox(height: 50),
                          Expanded(
                            child: SingleChildScrollView(
                              child: SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.userName != null
                                          ? 'building_responsible_persons.title'
                                                .tr(
                                                  namedArgs: {
                                                    'name': widget.userName!,
                                                  },
                                                )
                                          : 'building_responsible_persons.title_fallback'
                                                .tr(),
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.headlineSmall
                                          .copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Reporting Name Field
                                    Container(
                                      height: 50,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF8B9A5B),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: TextFormField(
                                        controller: _reportingNameController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'building_responsible_persons.reporting_name_hint'
                                                  .tr(),
                                          border: InputBorder.none,
                                          hintStyle: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Frequency Field
                                    Container(
                                      height: 50,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF8B9A5B),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _selectedFrequency,
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: Colors.black87,
                                                  ),
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _handleFrequencyChange,
                                              child: Text(
                                                '+ ${'building_responsible_persons.change_frequency'.tr()}',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      decoration: TextDecoration
                                                          .underline,
                                                      color: Colors.black,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Report Options Checkboxes - Row 1
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildReportOptionCheckbox(
                                          'total_consumption',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'peak_loads',
                                        ),
                                        _buildReportOptionCheckbox('anomalies'),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Report Options Checkboxes - Row 2
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildReportOptionCheckbox(
                                          'rooms_by_consumption',
                                        ),
                                        _buildReportOptionCheckbox(
                                          'underutilization',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    // Additional Options
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          // TODO: Handle create own routines
                                        },
                                        child: Text(
                                          '+ ${'building_responsible_persons.create_own_routines'.tr()}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                decoration:
                                                    TextDecoration.underline,
                                                color: Colors.black87,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleSkip,
                                        child: Text(
                                          'building_responsible_persons.skip_step'
                                              .tr(),
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                decoration:
                                                    TextDecoration.underline,
                                                color: Colors.black87,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Material(
                                      color: Colors.transparent,
                                      child: PrimaryOutlineButton(
                                        label:
                                            'building_responsible_persons.button_text'
                                                .tr(),
                                        width: 260,
                                        onPressed: _handleContinue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildReportOptionCheckbox(String option) {
    final isSelected = _reportOptions[option] ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleReportOptionToggle(option),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // border: Border.all(color: Colors.black54, width: 1),
            // borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                ),
                child: isSelected
                    ? const Icon(Icons.close, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                _getReportOptionLabel(option),
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
