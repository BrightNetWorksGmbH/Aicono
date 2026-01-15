import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';

class LoxoneConnectionWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback onLanguageChanged;
  final VoidCallback? onConnect;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final bool isLoading;
  final ValueChanged<Map<String, dynamic>>? onConnectionDataReady;

  const LoxoneConnectionWidget({
    super.key,
    this.userName,
    required this.onLanguageChanged,
    this.onConnect,
    this.onSkip,
    this.onBack,
    this.isLoading = false,
    this.onConnectionDataReady,
  });

  @override
  State<LoxoneConnectionWidget> createState() => _LoxoneConnectionWidgetState();
}

class _LoxoneConnectionWidgetState extends State<LoxoneConnectionWidget> {
  final TextEditingController _userController = TextEditingController(
    text: 'AICONO_clouduser01',
  );
  final TextEditingController _passController = TextEditingController(
    text: 'A9f!Q2m#R7xP',
  );
  final TextEditingController _externalAddressController =
      TextEditingController(text: 'dns.loxonecloud.com');
  final TextEditingController _portController = TextEditingController(
    text: '443',
  );
  final TextEditingController _serialNumberController = TextEditingController(
    text: '504F94D107EE',
  );

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _externalAddressController.dispose();
    _portController.dispose();
    _serialNumberController.dispose();
    super.dispose();
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
                userInitial: widget.userName?[0].toUpperCase(),
                verseInitial: null,
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
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
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
                          'Loxone Verbindung',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bitte geben Sie Ihre Loxone-Verbindungsdaten ein',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // User field
                        TextField(
                          controller: _userController,
                          decoration: InputDecoration(
                            labelText: 'Benutzer',
                            hintText: 'AICONO_clouduser01',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.black54,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Password field
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Passwort',
                            hintText: 'A9f!Q2m#R7xP',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.black54,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // External Address field
                        TextField(
                          controller: _externalAddressController,
                          decoration: InputDecoration(
                            labelText: 'Externe Adresse',
                            hintText: 'dns.loxonecloud.com',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.black54,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Port field
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Port',
                            hintText: '443',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.black54,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Serial Number field
                        TextField(
                          controller: _serialNumberController,
                          decoration: InputDecoration(
                            labelText: 'Seriennummer',
                            hintText: '504F94D107EE',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.black54,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.onSkip != null)
                          InkWell(
                            onTap: widget.onSkip,
                            child: Text(
                              'Schritt überspringen',
                              style: AppTextStyles.bodyMedium.copyWith(
                                decoration: TextDecoration.underline,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (widget.onSkip != null)
                          InkWell(
                            onTap: widget.onSkip,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'Schritt überspringen',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    decoration: TextDecoration.underline,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (widget.onSkip != null) const SizedBox(height: 16),
                        PrimaryOutlineButton(
                          label: widget.isLoading
                              ? 'Verbinden...'
                              : 'Verbinden',
                          width: 260,
                          onPressed: widget.isLoading
                              ? null
                              : () {
                                  // Notify parent with connection data
                                  widget.onConnectionDataReady?.call(
                                    getConnectionData(),
                                  );
                                  widget.onConnect?.call();
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> getConnectionData() {
    return {
      'user': _userController.text.trim(),
      'pass': _passController.text.trim(),
      'externalAddress': _externalAddressController.text.trim(),
      'port': int.tryParse(_portController.text.trim()) ?? 443,
      'serialNumber': _serialNumberController.text.trim(),
    };
  }
}
