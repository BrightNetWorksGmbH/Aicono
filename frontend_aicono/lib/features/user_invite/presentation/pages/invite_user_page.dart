import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

/// Simple UI-only version of the invite user flow.
/// No backend / bloc integration – just matches the BryteSwitch design.
class InviteUserPage extends StatefulWidget {
  const InviteUserPage({super.key});

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _namePositionController = TextEditingController();

  String? _selectedRole; // 'expert', 'read_only', 'admin'

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

  @override
  void dispose() {
    _emailController.dispose();
    _namePositionController.dispose();
    super.dispose();
  }

  void _parseUserInput(String input) {
    final normalizedInput = input
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
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

  void _handleSubmit() {
    _parseUserInput(_namePositionController.text);
    setState(() {});
    if (!_isFormValid) return;

    // For now: purely UI – navigate to a static confirmation page.
    context.pushNamed(
      Routelists.completeUserInvite,
      extra: {
        'invitedUserName': _firstName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
                // White card with invite form
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () => context.pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Nutzer hinzufügen',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Mail',
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
                                decoration: const InputDecoration(
                                  labelText: 'Vor- und Nachname, Position',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Bitte wähle die Rolle aus:',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                children: [
                                  _RoleOption(
                                    label: 'Experte',
                                    value: 'expert',
                                    groupValue: _selectedRole,
                                    onChanged: (v) =>
                                        setState(() => _selectedRole = v),
                                  ),
                                  _RoleOption(
                                    label: 'Nur Lesezugriff',
                                    value: 'read_only',
                                    groupValue: _selectedRole,
                                    onChanged: (v) =>
                                        setState(() => _selectedRole = v),
                                  ),
                                  _RoleOption(
                                    label: 'Administrator',
                                    value: 'admin',
                                    groupValue: _selectedRole,
                                    onChanged: (v) =>
                                        setState(() => _selectedRole = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (_firstName.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Was muss Deine Organisation wissen?\n'
                                    'Wenn $_firstName ein Mitarbeiter Deiner Organisation ist, '
                                    'kannst Du sein Mitarbeiterprofil verknüpfen.',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                              const SizedBox(height: 24),
                              PrimaryOutlineButton(
                                label: 'Einladung senden',
                                enabled: _isFormValid,
                                width: double.infinity,
                                onPressed: _isFormValid ? _handleSubmit : null,
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
                // Footer on primary background (like dashboard)
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
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onChanged;

  const _RoleOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XCheckBox(
            value: isSelected,
            onChanged: (_) => onChanged(value),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

