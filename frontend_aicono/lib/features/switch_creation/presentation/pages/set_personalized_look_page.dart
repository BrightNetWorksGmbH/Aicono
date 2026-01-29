import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_personalize_look_widget.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/property_setup_cubit.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class SetPersonalizedLookPage extends StatefulWidget {
  final String? userName;
  final InvitationEntity? invitation;

  const SetPersonalizedLookPage({super.key, this.userName, this.invitation});

  @override
  State<SetPersonalizedLookPage> createState() =>
      _SetPersonalizedLookPageState();
}

class _SetPersonalizedLookPageState extends State<SetPersonalizedLookPage> {
  @override
  void initState() {
    super.initState();
    // Store switchId from invitation in PropertySetupCubit
    if (widget.invitation != null && widget.invitation!.verseId.isNotEmpty) {
      sl<PropertySetupCubit>().setSwitchId(widget.invitation!.verseId);
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleContinue() {
    // The widget will handle calling the bloc to complete setup
    // Navigation will happen after success
  }

  void _handleDarkModeChanged(bool darkMode) {
    // Update bloc with dark mode preference
    sl<SwitchCreationCubit>().setDarkMode(darkMode);
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
                BlocProvider.value(
                  value: sl<SwitchCreationCubit>(),
                  child: BlocListener<SwitchCreationCubit, SwitchCreationState>(
                    listener: (context, state) {
                      if (state is SwitchCreationCompleteSuccess) {
                        // Navigate to structure switch page on success
                        if (mounted) {
                          if (widget.invitation != null &&
                              widget.invitation!.verseId.isNotEmpty) {
                            context.pushNamed(
                              Routelists.structureSwitch,
                              pathParameters: {
                                'switchId': widget.invitation!.verseId,
                              },
                              queryParameters: {
                                if (widget.userName != null)
                                  'userName': widget.userName!,
                              },
                            );
                          }
                        }
                      } else if (state is SwitchCreationCompleteFailure) {
                        // Show error message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: SetPersonalizeLookWidget(
                      userName: widget.userName,
                      invitation: widget.invitation,
                      onLanguageChanged: _handleLanguageChanged,
                      onBack: _handleBack,
                      onContinue: _handleContinue,
                      onDarkModeChanged: _handleDarkModeChanged,
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
}
