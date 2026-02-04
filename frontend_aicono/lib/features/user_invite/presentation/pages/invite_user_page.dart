import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/role_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/invitation_request_entity.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/roles_bloc/roles_bloc.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/roles_bloc/roles_event.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/roles_bloc/roles_state.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/send_invitation_bloc/send_invitation_bloc.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/send_invitation_bloc/send_invitation_event.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/send_invitation_bloc/send_invitation_state.dart';
import 'package:go_router/go_router.dart';

/// Invite user page with full backend integration.
/// Fetches roles from API and sends invitation via POST.
class InviteUserPage extends StatefulWidget {
  /// Optional switch ID from navigation (e.g. from dashboard sidebar).
  /// If null, falls back to LocalStorage.getSelectedVerseId().
  final String? switchId;

  const InviteUserPage({super.key, this.switchId});

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _namePositionController = TextEditingController();

  RoleEntity? _selectedRole;

  String _firstName = '';
  String _lastName = '';
  String _position = '';

  bool get _isFormValid {
    return _emailController.text.trim().isNotEmpty &&
        _firstName.isNotEmpty &&
        _lastName.isNotEmpty &&
        _position.isNotEmpty &&
        _selectedRole != null;
  }

  String? get _bryteswitchId {
    return widget.switchId ?? sl<LocalStorage>().getSelectedVerseId();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _namePositionController.dispose();
    super.dispose();
  }

  void _parseUserInput(String input) {
    final normalizedInput = input
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts = normalizedInput.split(' ');
    if (parts.length < 2) {
      _firstName = '';
      _lastName = '';
      _position = '';
      return;
    }

    _position = parts.last;
    final nameParts = parts.sublist(0, parts.length - 1);
    _firstName = nameParts.first;
    _lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleSubmit(BuildContext context) {
    _parseUserInput(_namePositionController.text);
    setState(() {});
    if (!_isFormValid) return;

    final bryteswitchId = _bryteswitchId;
    if (bryteswitchId == null || bryteswitchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('invite_user.select_company_first_snackbar'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final request = InvitationRequestEntity(
      bryteswitchId: bryteswitchId,
      roleId: _selectedRole!.id,
      recipientEmail: _emailController.text.trim(),
      firstName: _firstName,
      lastName: _lastName,
      position: _position,
      expiresInDays: 7,
    );

    context.read<SendInvitationBloc>().add(
      SendInvitationSubmitted(request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bryteswitchId = _bryteswitchId;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final bloc = sl<RolesBloc>();
            if (bryteswitchId != null && bryteswitchId.isNotEmpty) {
              bloc.add(RolesRequested(bryteswitchId: bryteswitchId));
            }
            return bloc;
          },
        ),
        BlocProvider(create: (context) => sl<SendInvitationBloc>()),
      ],
      child: BlocListener<SendInvitationBloc, SendInvitationState>(
        listener: (context, state) {
          if (state is SendInvitationSuccess) {
            context.pushNamed(
              Routelists.completeUserInvite,
              extra: {'invitedUserName': _firstName},
            );
            context.read<SendInvitationBloc>().add(SendInvitationReset());
          }
          if (state is SendInvitationFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Builder(
          builder: (blocContext) {
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
                                  containerWidth: screenSize.width,
                                ),
                                const SizedBox(height: 40),
                                SizedBox(
                                  width: screenSize.width < 600
                                      ? screenSize.width * 0.95
                                      : screenSize.width < 1200
                                      ? screenSize.width * 0.5
                                      : screenSize.width * 0.6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            onPressed: () => context.pop(),
                                            icon: const Icon(Icons.close),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'invite_user.title'.tr(),
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.headlineMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (bryteswitchId == null ||
                                          bryteswitchId.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Text(
                                            'invite_user.select_company_first_warning'
                                                .tr(),
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.orange[800],
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      TextField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'invite_user.email_label'
                                              .tr(),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.zero,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _namePositionController,
                                        onChanged: (value) {
                                          _parseUserInput(value);
                                          setState(() {});
                                        },
                                        decoration: InputDecoration(
                                          labelText:
                                              'invite_user.name_position_label'
                                                  .tr(),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.zero,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'invite_user.select_role_label'.tr(),
                                          style: AppTextStyles.titleSmall
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      BlocBuilder<RolesBloc, RolesState>(
                                        builder: (context, rolesState) {
                                          if (rolesState is RolesLoading) {
                                            return const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          if (rolesState is RolesFailure) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Text(
                                                rolesState.message,
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: Colors.red,
                                                    ),
                                              ),
                                            );
                                          }
                                          if (rolesState is RolesSuccess &&
                                              rolesState.roles.isNotEmpty) {
                                            return Wrap(
                                              spacing: 24,
                                              runSpacing: 8,
                                              children: rolesState.roles
                                                  .map(
                                                    (role) => _RoleOption(
                                                      label: role.name,
                                                      role: role,
                                                      selectedRole:
                                                          _selectedRole,
                                                      onChanged: (r) =>
                                                          setState(
                                                            () =>
                                                                _selectedRole =
                                                                    r,
                                                          ),
                                                    ),
                                                  )
                                                  .toList(),
                                            );
                                          }
                                          if (rolesState is RolesSuccess &&
                                              rolesState.roles.isEmpty) {
                                            return Text(
                                              'invite_user.no_roles_available'
                                                  .tr(),
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      if (_firstName.isNotEmpty)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'invite_user.employee_profile_info'
                                                .tr(
                                                  namedArgs: {
                                                    'name': _firstName,
                                                  },
                                                ),
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        ),
                                      if (_firstName.isNotEmpty)
                                        const SizedBox(height: 24),
                                      BlocBuilder<
                                        SendInvitationBloc,
                                        SendInvitationState
                                      >(
                                        builder: (context, sendState) {
                                          final isLoading =
                                              sendState
                                                  is SendInvitationLoading;
                                          final canSubmit =
                                              _isFormValid &&
                                              bryteswitchId != null &&
                                              bryteswitchId.isNotEmpty &&
                                              !isLoading;

                                          return PrimaryOutlineButton(
                                            label:
                                                'invite_user.send_invitation_button'
                                                    .tr(),
                                            enabled: canSubmit,
                                            loading: isLoading,
                                            width: double.infinity,
                                            onPressed: canSubmit
                                                ? () =>
                                                      _handleSubmit(blocContext)
                                                : null,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 100),
                                    ],
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
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final RoleEntity role;
  final RoleEntity? selectedRole;
  final ValueChanged<RoleEntity> onChanged;

  const _RoleOption({
    required this.label,
    required this.role,
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedRole?.id == role.id;
    return InkWell(
      onTap: () => onChanged(role),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(value: isSelected, onChanged: (_) => onChanged(role)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}
