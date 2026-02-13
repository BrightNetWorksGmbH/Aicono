import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/switch_role_entity.dart';

class SwitchSwitchingDialog extends StatefulWidget {
  final List<SwitchRoleEntity> roles;
  final String? currentSwitchId;
  final SwitchRoleEntity? currentRole;
  /// Called when user selects a switch. Required when [returnSelectionResult] is false.
  final void Function(String bryteswitchId)? onSwitchSelected;
  /// When true, the dialog pops with the selected [SwitchRoleEntity] for use with showDialog<T>.
  final bool returnSelectionResult;

  const SwitchSwitchingDialog({
    super.key,
    required this.roles,
    this.currentSwitchId,
    this.currentRole,
    this.onSwitchSelected,
    this.returnSelectionResult = false,
  });

  @override
  State<SwitchSwitchingDialog> createState() => _SwitchSwitchingDialogState();
}

class _SwitchSwitchingDialogState extends State<SwitchSwitchingDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? _selectedSwitchId;

  @override
  void initState() {
    super.initState();
    _selectedSwitchId = widget.currentSwitchId;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _animationController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _closeDialog([SwitchRoleEntity? result]) {
    _animationController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  SwitchRoleEntity? _getRoleById(String bryteswitchId) {
    try {
      return widget.roles.firstWhere((r) => r.bryteswitchId == bryteswitchId);
    } catch (_) {
      return null;
    }
  }

  void _selectSwitch(String bryteswitchId) {
    setState(() {
      _selectedSwitchId = bryteswitchId;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      widget.onSwitchSelected?.call(bryteswitchId);
      if (widget.returnSelectionResult) {
        _closeDialog(_getRoleById(bryteswitchId));
      } else {
        _closeDialog();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                if (widget.currentRole != null) _buildCurrentSwitchInfo(),
                _buildSwitchList(),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.swap_horiz, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dashboard.switch_switcher.title'.tr(),
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dashboard.switch_switcher.subtitle'.tr(),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeDialog,
            icon: Icon(Icons.close, color: Colors.grey[600]),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSwitchInfo() {
    final role = widget.currentRole!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(Icons.business, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dashboard.switch_switcher.current'.tr(),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role.organizationName.isNotEmpty
                      ? role.organizationName
                      : role.subDomain,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'dashboard.switch_switcher.active'.tr(),
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchList() {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.roles.length,
        itemBuilder: (context, index) {
          final role = widget.roles[index];
          final switchId = role.bryteswitchId;
          final name = role.organizationName.isNotEmpty
              ? role.organizationName
              : (role.subDomain.isNotEmpty ? role.subDomain : switchId);
          final isCurrent = switchId == widget.currentSwitchId;
          final isSelected = switchId == _selectedSwitchId;

          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200 + (index * 50)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isCurrent ? null : () => _selectSwitch(switchId),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.1)
                                : isCurrent
                                ? Colors.grey[50]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : isCurrent
                                  ? Colors.grey[300]!
                                  : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: isCurrent
                                      ? Colors.grey[400]
                                      : AppTheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent
                                            ? Colors.grey[500]
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (isCurrent)
                                      Text(
                                        'dashboard.switch_switcher.current_switch'
                                            .tr(),
                                        style: AppTextStyles.labelMedium
                                            .copyWith(color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primary,
                                  size: 20,
                                )
                              else if (isSelected)
                                Icon(
                                  Icons.radio_button_checked,
                                  color: AppTheme.primary,
                                  size: 20,
                                )
                              else
                                Icon(
                                  Icons.radio_button_unchecked,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => _closeDialog(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'common.cancel'.tr(),
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed:
                  _selectedSwitchId != null &&
                      _selectedSwitchId != widget.currentSwitchId
                  ? () => _selectSwitch(_selectedSwitchId!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'dashboard.switch_switcher.switch'.tr(),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
