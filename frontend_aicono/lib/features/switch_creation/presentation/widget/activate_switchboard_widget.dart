import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';

class ActivateSwitchboardWidget extends StatelessWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onContinue;

  const ActivateSwitchboardWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onContinue,
  });

  String _buildGreeting() {
    if (userName != null && userName!.trim().isNotEmpty) {
      return 'activate_switchboard.greeting'.tr(
        namedArgs: {'name': userName!.trim()},
      );
    }
    return 'activate_switchboard.greeting_fallback'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Padding(
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
              TopHeader(
                onLanguageChanged: onLanguageChanged,
                containerWidth: screenSize.width > 500
                    ? 500
                    : screenSize.width * 0.98,
              ),
              const SizedBox(height: 50),
              SizedBox(
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
                      _buildGreeting(),
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 36),
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: const [Icon(Icons.close)],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'activate_switchboard.title'.tr(),
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'activate_switchboard.description'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 36),
                    PrimaryOutlineButton(
                      label: 'activate_switchboard.button_text'.tr(),
                      width: 250,
                      onPressed: onContinue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
