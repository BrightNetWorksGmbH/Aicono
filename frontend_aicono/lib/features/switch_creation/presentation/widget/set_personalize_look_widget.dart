import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';

class SetPersonalizeLookWidget extends StatefulWidget {
  final String? userName;
  final InvitationEntity? invitation;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final ValueChanged<bool>? onDarkModeChanged;

  const SetPersonalizeLookWidget({
    super.key,
    this.userName,
    this.invitation,
    required this.onLanguageChanged,
    this.onContinue,
    this.onBack,
    this.onDarkModeChanged,
  });

  @override
  State<SetPersonalizeLookWidget> createState() =>
      _SetPersonalizeLookWidgetState();
}

class _SetPersonalizeLookWidgetState extends State<SetPersonalizeLookWidget> {
  bool _opt1 = true; // Light mode
  bool _opt2 = false; // Dark mode

  @override
  void initState() {
    super.initState();
    // Initialize from bloc state if available
    final cubit = sl<SwitchCreationCubit>();
    final darkMode = cubit.state.darkMode;
    if (darkMode != null) {
      _opt1 = !darkMode;
      _opt2 = darkMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
                onLanguageChanged: widget.onLanguageChanged,
                containerWidth: screenSize.width > 500
                    ? 500
                    : screenSize.width * 0.98,
              ),
              if (widget.onBack != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 50),
              SizedBox(
                width: screenSize.width < 600
                    ? screenSize.width * 0.95
                    : screenSize.width < 1200
                    ? screenSize.width * 0.5
                    : screenSize.width * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        'set_personalized_look.title'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineLarge.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildOption(
                      value: _opt1,
                      onChanged: (v) {
                        setState(() {
                          _opt1 = v ?? false;
                          if (_opt1) {
                            _opt2 = false; // Ensure only one is selected
                            // Update bloc with light mode (darkMode = false)
                            sl<SwitchCreationCubit>().setDarkMode(false);
                            widget.onDarkModeChanged?.call(false);
                          }
                        });
                      },
                      text: 'set_personalized_look.option_1'.tr(),
                    ),
                    _buildOption(
                      value: _opt2,
                      onChanged: (v) {
                        setState(() {
                          _opt2 = v ?? false;
                          if (_opt2) {
                            _opt1 = false; // Ensure only one is selected
                            // Update bloc with dark mode (darkMode = true)
                            sl<SwitchCreationCubit>().setDarkMode(true);
                            widget.onDarkModeChanged?.call(true);
                          }
                        });
                      },
                      text: 'set_personalized_look.option_2'.tr(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'set_personalized_look.tip'.tr(),
                      textAlign: TextAlign.left,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    BlocBuilder<SwitchCreationCubit, SwitchCreationState>(
                      builder: (context, state) {
                        final isLoading = state.isLoading;
                        return Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 260,
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : PrimaryOutlineButton(
                                  label: 'set_personalized_look.button_text'
                                      .tr(),
                                  width: 260,
                                  onPressed: () {
                                    // Get switch ID from invitation
                                    if (widget.invitation == null ||
                                        widget.invitation!.verseId.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'set_personalized_look.invalid_invitation'
                                                .tr(),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // Call bloc to complete setup
                                    context
                                        .read<SwitchCreationCubit>()
                                        .completeSetup(
                                          widget.invitation!.verseId,
                                        );
                                  },
                                ),
                        );
                      },
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

  Widget _buildOption({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          XCheckBox(value: value, onChanged: onChanged),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
