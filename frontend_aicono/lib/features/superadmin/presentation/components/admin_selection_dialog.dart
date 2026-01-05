import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/admin_entity.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/admin_list_bloc/admin_list_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/admin_list_bloc/admin_list_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/admin_list_bloc/admin_list_state.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_provisioning_bloc/brytesight_provisioning_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_provisioning_bloc/brytesight_provisioning_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_provisioning_bloc/brytesight_provisioning_state.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_invitation_bloc/brytesight_invitation_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_invitation_bloc/brytesight_invitation_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_invitation_bloc/brytesight_invitation_state.dart';

class AdminSelectionDialog extends StatefulWidget {
  final String verseName;
  final String verseId;
  final Function(List<String> selectedAdminIds) onInvite;

  const AdminSelectionDialog({
    super.key,
    required this.verseName,
    required this.verseId,
    required this.onInvite,
  });

  static Future<void> show(
    BuildContext context, {
    required String verseName,
    required String verseId,
    required Function(List<String> selectedAdminIds) onInvite,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                sl<AdminListBloc>()..add(LoadVerseAdminsRequested(verseId)),
          ),
          BlocProvider(create: (context) => sl<BryteSightProvisioningBloc>()),
          BlocProvider(create: (context) => sl<BryteSightInvitationBloc>()),
        ],
        child: AdminSelectionDialog(
          verseName: verseName,
          verseId: verseId,
          onInvite: onInvite,
        ),
      ),
    );
  }

  @override
  State<AdminSelectionDialog> createState() => _AdminSelectionDialogState();
}

class _AdminSelectionDialogState extends State<AdminSelectionDialog> {
  final Set<String> _selectedAdminIds = {};
  final TextEditingController _searchController = TextEditingController();
  List<AdminEntity> _allAdmins = [];
  List<AdminEntity> _filteredAdmins = [];
  bool _isProcessingInvitations = false;
  int _currentInvitationIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterAdmins);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAdmins() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAdmins = _allAdmins.where((admin) {
        return admin.fullName.toLowerCase().contains(query) ||
            admin.email.toLowerCase().contains(query) ||
            admin.firstName.toLowerCase().contains(query) ||
            admin.lastName.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _updateFilteredList(List<AdminEntity> admins) {
    _allAdmins = admins;
    _filterAdmins();
  }

  void _toggleSelection(String adminId) {
    setState(() {
      if (_selectedAdminIds.contains(adminId)) {
        _selectedAdminIds.remove(adminId);
      } else {
        _selectedAdminIds.add(adminId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedAdminIds.length == _filteredAdmins.length) {
        _selectedAdminIds.clear();
      } else {
        _selectedAdminIds.clear();
        _selectedAdminIds.addAll(_filteredAdmins.map((a) => a.id));
      }
    });
  }

  void _handleInvite() {
    if (_selectedAdminIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('superadmin.invite.select_at_least_one'.tr()),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
        ),
      );
      return;
    }

    // Enable provisioning first
    setState(() {
      _isProcessingInvitations = true;
      _currentInvitationIndex = 0;
    });

    context.read<BryteSightProvisioningBloc>().add(
      SetBryteSightProvisioningRequested(
        verseId: widget.verseId,
        canCreateBrytesight: true,
      ),
    );
  }

  Future<void> _sendInvitationsSequentially(List<String> adminEmails) async {
    if (_currentInvitationIndex >= adminEmails.length) {
      // All invitations sent successfully
      setState(() {
        _isProcessingInvitations = false;
      });
      Navigator.of(context).pop();
      widget.onInvite(_selectedAdminIds.toList());
      return;
    }

    final email = adminEmails[_currentInvitationIndex];

    context.read<BryteSightInvitationBloc>().add(
      SendBryteSightInvitationRequested(
        verseId: widget.verseId,
        recipientEmail: email,
      ),
    );
  }

  String _getInitials(AdminEntity admin) {
    return '${admin.firstName[0]}${admin.lastName[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AdminListBloc, AdminListState>(
          listener: (context, state) {
            if (state is AdminListLoaded) {
              _updateFilteredList(state.admins);
            } else if (state is AdminListFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(),
                ),
              );
            }
          },
        ),
        BlocListener<BryteSightProvisioningBloc, BryteSightProvisioningState>(
          listener: (context, state) {
            if (state is BryteSightProvisioningSuccess) {
              // Provisioning successful, now send invitations sequentially
              final selectedAdminEmails = _filteredAdmins
                  .where((admin) => _selectedAdminIds.contains(admin.id))
                  .map((admin) => admin.email)
                  .toList();
              _sendInvitationsSequentially(selectedAdminEmails);
            } else if (state is BryteSightProvisioningFailure) {
              setState(() {
                _isProcessingInvitations = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(),
                ),
              );
            }
          },
        ),
        BlocListener<BryteSightInvitationBloc, BryteSightInvitationState>(
          listener: (context, state) {
            if (state is BryteSightInvitationSuccess) {
              // Get all selected admin emails
              final selectedAdminEmails = _filteredAdmins
                  .where((admin) => _selectedAdminIds.contains(admin.id))
                  .map((admin) => admin.email)
                  .toList();

              // Check if there are more invitations to send
              if (_currentInvitationIndex + 1 >= selectedAdminEmails.length) {
                // All invitations sent successfully
                setState(() {
                  _isProcessingInvitations = false;
                });
                Navigator.of(context).pop();
                widget.onInvite(_selectedAdminIds.toList());
              } else {
                // Send next invitation
                setState(() {
                  _currentInvitationIndex++;
                });
                _sendInvitationsSequentially(selectedAdminEmails);
              }
            } else if (state is BryteSightInvitationFailure) {
              setState(() {
                _isProcessingInvitations = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(),
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<AdminListBloc, AdminListState>(
        builder: (context, state) {
          final isAllSelected =
              _filteredAdmins.isNotEmpty &&
              _selectedAdminIds.length == _filteredAdmins.length;

          return Dialog(
            shape: const RoundedRectangleBorder(),
            child: Container(
              width: MediaQuery.of(context).size.width > 600
                  ? 600
                  : double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.teal[600]),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'superadmin.invite.title'.tr(),
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.verseName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'common.cancel'.tr(),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            enabled: state is! AdminListLoading,
                            decoration: InputDecoration(
                              hintText: 'superadmin.invite.search_hint'.tr(),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey[600],
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.teal[600]!,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Select All Button
                        if (state is AdminListLoaded &&
                            _filteredAdmins.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: isAllSelected
                                  ? Colors.teal[600]
                                  : Colors.white,
                              border: Border.all(
                                color: isAllSelected
                                    ? Colors.teal[600]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _selectAll,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAllSelected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        size: 20,
                                        color: isAllSelected
                                            ? Colors.white
                                            : Colors.grey[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'superadmin.invite.select_all'.tr(),
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: isAllSelected
                                                  ? Colors.white
                                                  : Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Selected Count

                  // Admin List
                  Flexible(child: _buildAdminList(state, isAllSelected)),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'common.cancel'.tr(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        BlocBuilder<
                          BryteSightProvisioningBloc,
                          BryteSightProvisioningState
                        >(
                          builder: (context, provisioningState) {
                            return BlocBuilder<
                              BryteSightInvitationBloc,
                              BryteSightInvitationState
                            >(
                              builder: (context, invitationState) {
                                final isLoading =
                                    state is AdminListLoading ||
                                    provisioningState
                                        is BryteSightProvisioningLoading ||
                                    invitationState
                                        is BryteSightInvitationLoading ||
                                    _isProcessingInvitations;

                                return ElevatedButton(
                                  onPressed: isLoading ? null : _handleInvite,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[600],
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLoading)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.send_rounded,
                                          size: 20,
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isProcessingInvitations
                                            ? 'superadmin.invite.sending_invitations'.tr(
                                                namedArgs: {
                                                  'current':
                                                      '${_currentInvitationIndex + 1}',
                                                  'total':
                                                      '${_selectedAdminIds.length}',
                                                },
                                              )
                                            : _selectedAdminIds.isEmpty
                                            ? 'superadmin.invite.send_invitation'
                                                  .tr()
                                            : 'superadmin.invite.send_invitation_count'.tr(
                                                namedArgs: {
                                                  'count':
                                                      '${_selectedAdminIds.length}',
                                                },
                                              ),
                                        style: AppTextStyles.buttonText
                                            .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminList(AdminListState state, bool isAllSelected) {
    if (state is AdminListLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state is AdminListFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                state.message,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  context.read<AdminListBloc>().add(
                    LoadVerseAdminsRequested(widget.verseId),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    if (state is AdminListInitial || _filteredAdmins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'superadmin.invite.no_results'.tr()
                    : 'superadmin.invite.no_admins'.tr(),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      itemCount: _filteredAdmins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final admin = _filteredAdmins[index];
        final isSelected = _selectedAdminIds.contains(admin.id);

        return _AdminListItem(
          admin: admin,
          isSelected: isSelected,
          onTap: () => _toggleSelection(admin.id),
          getInitials: _getInitials,
        );
      },
    );
  }
}

class _AdminListItem extends StatelessWidget {
  final AdminEntity admin;
  final bool isSelected;
  final VoidCallback onTap;
  final String Function(AdminEntity) getInitials;

  const _AdminListItem({
    required this.admin,
    required this.isSelected,
    required this.onTap,
    required this.getInitials,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal[50] : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.teal[600]! : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.teal[600]!.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.teal[600] : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.teal[600]! : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 16),
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.teal[600],
                child: Text(
                  getInitials(admin),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.fullName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      admin.email,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Selection Indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(color: Colors.teal[600]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'superadmin.invite.selected'.tr(),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
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
