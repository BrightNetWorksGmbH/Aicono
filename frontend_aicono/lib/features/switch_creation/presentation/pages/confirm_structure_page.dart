import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/confirm_structure_widget.dart';

import '../../../../core/injection_container.dart';
import '../../../../core/storage/local_storage.dart';

class ConfirmStructurePage extends StatefulWidget {
  final String? userName;
  final String? switchId;

  const ConfirmStructurePage({super.key, this.userName, this.switchId});

  @override
  State<ConfirmStructurePage> createState() => _ConfirmStructurePageState();
}

class _ConfirmStructurePageState extends State<ConfirmStructurePage> {
  String? _userDisplayName;

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
        (_) {
          if (mounted) {
            setState(() => _userDisplayName = widget.userName ?? 'User');
          }
        },
        (user) {
          if (mounted && user != null) {
            final firstName = user.firstName.isNotEmpty ? user.firstName : '';
            final lastName = user.lastName.isNotEmpty ? user.lastName : '';
            final name = '$firstName $lastName'.trim();
            setState(() =>
                _userDisplayName = name.isNotEmpty ? name : (widget.userName ?? 'User'));
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _userDisplayName = widget.userName ?? 'User');
      }
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() => context.pop();

  void _handleSkip() async {
    // TODO: navigate to switchboard/dashboard directly (skip structure setup)
    final localStorage = sl<LocalStorage>();
    await localStorage.setSelectedVerseId(widget.switchId!);
    context.pushNamed(
      Routelists.selectPropertyType,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
      },
    );
  }

  void _handleFindStructure() async {
    // Navigate to select property type page
    final localStorage = sl<LocalStorage>();
    await localStorage.setSelectedVerseId(widget.switchId!);
    context.pushNamed(
      Routelists.selectPropertyType,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.switchId != null) 'switchId': widget.switchId!,
      },
    );
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
                ConfirmStructureWidget(
                  userName: _userDisplayName ?? widget.userName,
                  onLanguageChanged: _handleLanguageChanged,
                  onBack: _handleBack,
                  onSkip: _handleSkip,
                  onFindStructure: _handleFindStructure,
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
