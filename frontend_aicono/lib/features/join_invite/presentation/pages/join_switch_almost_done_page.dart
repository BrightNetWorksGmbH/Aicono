import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/join_invite/presentation/bloc/join_invite_bloc.dart';
import 'package:frontend_aicono/features/join_invite/presentation/components/join_switch_almost_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

class JoinSwitchAlmostDonePage extends StatefulWidget {
  final InvitationEntity invitation;

  const JoinSwitchAlmostDonePage({super.key, required this.invitation});

  @override
  State<JoinSwitchAlmostDonePage> createState() =>
      _JoinSwitchAlmostDonePageState();
}

class _JoinSwitchAlmostDonePageState extends State<JoinSwitchAlmostDonePage> {
  void _handleLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return BlocProvider(
      create: (_) => sl<JoinInviteBloc>(),
      child: BlocConsumer<JoinInviteBloc, JoinInviteState>(
        listener: (context, state) {
          if (state is JoinInviteSuccess) {
            // After successful join, navigate to login so user can sign in
            context.goNamed(Routelists.login);
          } else if (state is JoinInviteFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final joining = state is JoinInviteLoading;

          return SafeArea(
            child: Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: Container(
                  width: screenSize.width,
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12.0),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              TopHeader(
                                onLanguageChanged: _handleLanguageChanged,
                                containerWidth: screenSize.width > 500
                                    ? 500
                                    : screenSize.width * 0.98,
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                width: screenSize.width < 600
                                    ? screenSize.width * 0.95
                                    : screenSize.width < 1200
                                    ? screenSize.width * 0.5
                                    : screenSize.width * 0.6,
                                child: JoinSwitchAlmostComponent(
                                  invitation: widget.invitation,
                                  joining: joining,
                                  onJoinPressed: () {
                                    context.read<JoinInviteBloc>().add(
                                      JoinSwitchRequested(
                                        invitation: widget.invitation,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        color: AppTheme.primary,
                        child: AppFooter(
                          onLanguageChanged: _handleLanguageChanged,
                          containerWidth: screenSize.width > 500
                              ? 500
                              : screenSize.width,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
