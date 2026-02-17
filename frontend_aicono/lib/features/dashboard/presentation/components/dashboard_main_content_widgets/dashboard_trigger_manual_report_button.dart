import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/trigger_report_bloc.dart';

/// Button that triggers a manual report (Daily) and shows loading/success/error via TriggerReportBloc.
class DashboardTriggerManualReportButton extends StatelessWidget {
  const DashboardTriggerManualReportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TriggerReportBloc, TriggerReportState>(
      listener: (context, state) {
        if (state is TriggerReportSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.response.message.isNotEmpty
                    ? state.response.message
                    : 'dashboard.main_content.trigger_report_success'.tr(),
              ),
              backgroundColor: Colors.green[700],
            ),
          );
        }
        if (state is TriggerReportFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is TriggerReportLoading;
        return Center(
          child: SizedBox(
            width: 270,
            height: 40,
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: isLoading
                    ? null
                    : () {
                        context.read<TriggerReportBloc>().add(
                              const TriggerReportRequested('Daily'),
                            );
                      },
                child: Container(
                  width: 270,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isLoading
                          ? Colors.grey.shade400
                          : const Color(0xFF636F57),
                      width: 4,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'dashboard.main_content.trigger_report_loading'
                                    .tr(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'dashboard.main_content.trigger_manual_report'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
