import 'dart:math';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/services/saved_accounts_service.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';

class LoginForm extends StatefulWidget {
  final InvitationEntity? invitation;
  final String? token;
  const LoginForm({super.key, this.invitation, this.token});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  List<SavedAccount> _savedAccounts = [];
  SavedAccount? _currentAccount;
  bool _obscureLoginPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    print('LoginForm initState - invitation: ${widget.invitation}');
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final savedAccountsService = sl<SavedAccountsService>();
      final accounts = await savedAccountsService.getSavedAccounts();

      setState(() {
        _savedAccounts = accounts;
      });

      // If invitation is provided, use invitation email
      if (widget.invitation != null) {
        _emailController.text = widget.invitation!.email;
      } else if (accounts.isNotEmpty) {
        // Use last used account or first account
        final lastUsedAccount = await savedAccountsService.getLastUsedAccount();
        final accountToUse = lastUsedAccount ?? accounts.first;

        _emailController.text = accountToUse.email;
        _passwordController.text = accountToUse.password;
        _currentAccount = accountToUse;
      }
    } catch (e) {
      // Fallback to invitation email if available
      if (widget.invitation != null) {
        _emailController.text = widget.invitation!.email;
      }
    }
  }

  @override
  void didUpdateWidget(LoginForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update email if invitation changed
    if (oldWidget.invitation != widget.invitation) {
      _emailController.text = widget.invitation?.email ?? '';

      setState(() {});
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = sl<AuthService>();
      final result = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: ${failure.message}')),
          );
        },
        (user) async {
          // Save account if remember me is checked (do this BEFORE any early returns)
          if (_rememberMe) {
            try {
              final savedAccountsService = sl<SavedAccountsService>();
              await savedAccountsService.saveAccount(
                email: _emailController.text.trim(),
                password: _passwordController.text,
                firstName: user.firstName,
                lastName: user.lastName,
              );
            } catch (e) {}
          }

          // Check if user is super admin - route to super admin page
          if (user.isSuperAdmin) {
            context.goNamed(Routelists.addVerseSuper);
            return;
          }

          // Post-login routing based on joined verses, invitation param, or pending invitations
          try {
            // 1) If an invitation param is provided, prioritize it
            if (widget.invitation != null &&
                widget.invitation!.email.toLowerCase() ==
                    _emailController.text.trim().toLowerCase()) {
              // Check if setup is not complete, navigate to activate switchboard
              if (!widget.invitation!.isSetupComplete) {
                final tokenToUse = widget.token ?? widget.invitation!.token;
                if (tokenToUse != null) {
                  context.pushNamed(
                    Routelists.activateSwitchboard,
                    queryParameters: {'token': tokenToUse},
                  );
                }
                return;
              }

              final localStorage = sl<LocalStorage>();
              localStorage.setSelectedVerseId(widget.invitation!.verseId);
              final invitedVerseId = widget.invitation!.verseId;
              final alreadyMember = user.joinedVerse.contains(invitedVerseId);
              print('henok - user.joinedVerse: ${user.joinedVerse.toString()}');

              if (alreadyMember) {
                // Already member of the invited switch → go directly to dashboard
                context.goNamed(Routelists.dashboard);
                return;
              }

              // Not a member of the invited switch → decide join vs create based on verse setup
              await _checkVerseSetupAndRedirect();
              return;
            }

            // 2) No invitation param: if already in any verse → dashboard
            if (user.joinedVerse.isNotEmpty) {
              context.goNamed(Routelists.dashboard);
              return;
            }

            // 3) No joined verses: if has pending invitations → use index 0
            if (user.pendingInvitations.isNotEmpty) {
              final firstInvitation = user.pendingInvitations.first;
              // Check if setup is not complete, navigate to activate switchboard
              if (!firstInvitation.isSetupComplete) {
                final tokenToUse = widget.token ?? firstInvitation.token;
                if (tokenToUse != null) {
                  context.pushNamed(
                    Routelists.activateSwitchboard,
                    queryParameters: {'token': tokenToUse},
                  );
                }
                return;
              }
              await _checkVerseSetupAndRedirectFor(firstInvitation);
              return;
            }
          } catch (e) {
            print('Post-login routing check failed: $e');
          }

          // Login successful - navigate to dashboard
          context.goNamed(Routelists.dashboard);
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLanguageMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final popupWidth = 180.0;
    final popupHeight = 150.0;

    // Login form is 500px wide and centered
    // Menu button is at the right edge of the form
    final formWidth = 500.0;
    final formLeft = (screenWidth - formWidth) / 2;

    // Position popup just above the menu button (near right edge of form)
    final left =
        formLeft + formWidth - popupWidth - 20; // Near right edge of form
    final top = screenHeight - 280; // Just above where menu button would be

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        left,
        top,
        left + popupWidth,
        top + popupHeight,
      ),
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.black87),
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'dashboard.sidebar.change_language'.tr(),
                        style: AppTextStyles.titleSmall,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildLanguageOptions(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageOptions(BuildContext context) {
    final currentLocale = context.locale;

    return Column(
      children: [
        _buildLanguageOption(
          context: context,
          locale: const Locale('en'),
          label: 'dashboard.sidebar.english'.tr(),
          isSelected: currentLocale.languageCode == 'en',
        ),
        SizedBox(height: 4),
        _buildLanguageOption(
          context: context,
          locale: const Locale('de'),
          label: 'dashboard.sidebar.deutsch'.tr(),
          isSelected: currentLocale.languageCode == 'de',
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        await context.setLocale(locale);
        if (!mounted) return;
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        _showLanguageMenu();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (value) async {
                await context.setLocale(locale);
                if (!mounted) return;
                Navigator.pop(context);
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                _showLanguageMenu();
              },
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSelectionDialog() {
    if (_savedAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved accounts found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'login_screen.switch_account'.tr(),
          style: AppTextStyles.titleMedium,
        ),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _savedAccounts.length,
            itemBuilder: (context, index) {
              final account = _savedAccounts[index];
              final isCurrentAccount = _currentAccount?.email == account.email;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrentAccount
                      ? Colors.teal[600]
                      : Colors.grey[400],
                  child: Text(
                    account.firstName?.isNotEmpty == true
                        ? account.firstName![0].toUpperCase()
                        : account.email[0].toUpperCase(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  account.firstName?.isNotEmpty == true
                      ? '${account.firstName} ${account.lastName ?? ''}'
                      : account.email,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: isCurrentAccount
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(account.email, style: AppTextStyles.bodySmall),
                trailing: isCurrentAccount
                    ? Icon(Icons.check, color: Colors.teal[600])
                    : null,
                onTap: () {
                  setState(() {
                    _emailController.text = account.email;
                    _passwordController.text = account.password;
                    _currentAccount = account;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr(), style: AppTextStyles.bodyMedium),
          ),
          if (_currentAccount != null)
            TextButton(
              onPressed: () {
                _removeCurrentAccount();
                Navigator.of(context).pop();
              },
              child: Text(
                'Remove',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.red[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _removeCurrentAccount() async {
    if (_currentAccount == null) return;

    try {
      final savedAccountsService = sl<SavedAccountsService>();
      await savedAccountsService.removeAccount(_currentAccount!.email);

      // Reload accounts
      await _loadSavedAccounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account removed: ${_currentAccount!.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkVerseSetupAndRedirect() async {
    if (widget.invitation == null) return;
    await _checkVerseSetupAndRedirectFor(widget.invitation!);
  }

  Future<void> _checkVerseSetupAndRedirectFor(InvitationEntity inv) async {
    try {
      final loginRepository = sl<LoginRepository>();
      final userResult = await loginRepository.getCurrentUser();

      await userResult.fold(
        (failure) {
          // If we cannot load user, fall back to dashboard
          context.goNamed(Routelists.dashboard);
        },
        (user) async {
          if (user == null) {
            context.goNamed(Routelists.login);
            return;
          }

          final invitedVerseId = inv.verseId;
          final alreadyMember = user.joinedVerse.contains(invitedVerseId);

          if (alreadyMember) {
            // User already in this switch → go directly to dashboard
            context.goNamed(Routelists.dashboard);
          } else {
            // Not yet in this switch → show join-switch page
            context.pushNamed(Routelists.almostJoinVerse, extra: inv);
          }
        },
      );
    } catch (_) {
      // On error, default to dashboard to avoid blocking login
      context.goNamed(Routelists.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double contentWidth = screenSize.width < 600
        ? screenSize.width
        : screenSize.width < 1200
        ? screenSize.width * 0.5
        : screenSize.width * 0.5;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        constraints: BoxConstraints(minHeight: screenSize.height),
        width: screenSize.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: max(0, (screenSize.width - contentWidth) / 2),
            vertical: screenSize.width - 600 > 0
                ? min(max(0, (screenSize.width - contentWidth) / 4), 200)
                : 0,
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF214a59), Color(0xFF171c23)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: screenSize.width > 800
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: contentWidth > 600
                          ? contentWidth - 200
                          : contentWidth,
                      child: SvgPicture.asset(
                        'assets/images/logo_white_horizontal.svg',
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 56),
                    Text(
                      'login_screen.welcome_message'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: contentWidth > 600
                      ? contentWidth - contentWidth / 3
                      : contentWidth,
                  child: TextField(
                    controller: _emailController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'login_screen.email_placeholder'.tr(),
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[400],
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF3a6ca6),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF3a6ca6),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF3a6ca6),
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
                const SizedBox(height: 16),
                Container(
                  width: contentWidth > 600
                      ? contentWidth - contentWidth / 3
                      : contentWidth,
                  child: TextField(
                    controller: _passwordController,
                    textAlign: TextAlign.center,
                    obscureText: _obscureLoginPassword,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'login_screen.password_placeholder'.tr(),
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[400],
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF3a6ca6),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF3a6ca6),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF3a6ca6),
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            _obscureLoginPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureLoginPassword = !_obscureLoginPassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.visiblePassword,
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Theme(
                      data: ThemeData(
                        unselectedWidgetColor: const Color(0xFF30363D),
                      ),
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (bool? value) {
                          setState(() {
                            _rememberMe = value ?? true;
                          });
                        },
                        activeColor: const Color(0xFF171c23),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3a6ca6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'login_screen.remember_me'.tr(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: contentWidth > 600
                      ? contentWidth - contentWidth / 3
                      : contentWidth,
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4, left: 4),
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xFF3a6ca6),
                            width: 4,
                          ),
                          color: Colors.transparent,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(bottom: 4, right: 4),
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 4),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: const Color.fromARGB(0, 148, 124, 124),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'login_screen.login_button'.tr(),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Forgot Password Link
                SizedBox(
                  width: contentWidth > 600
                      ? contentWidth - contentWidth / 3
                      : contentWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        context.pushNamed(Routelists.forgotPassword);
                        // context.goNamed(
                        //   Routelists.activateSwitchboard,
                        //   queryParameters: {'userName': 'test'},
                        // );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: contentWidth > 600
                      ? contentWidth - contentWidth / 3
                      : contentWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _showAccountSelectionDialog,
                        child: Text(
                          'login_screen.switch_account'.tr(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _showLanguageMenu,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'MENU',
                                style: AppTextStyles.labelSmall.copyWith(
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(3, (i) {
                                  return Container(
                                    width: 50,
                                    height: 2,
                                    margin: EdgeInsets.only(
                                      bottom: i == 2 ? 0 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF3a6ca6),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
