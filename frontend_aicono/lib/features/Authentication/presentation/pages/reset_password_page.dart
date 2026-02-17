import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/loading_widget.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/register_user_entity.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/register_user_bloc.dart';

class ResetPasswordPage extends StatefulWidget {
  final InvitationEntity invitation;
  const ResetPasswordPage({super.key, required this.invitation});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isStrongPassword(String value) {
    // Enforce: >= 8 chars, at least 1 upper, 1 lower, 1 digit, 1 special
    if (value.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+~=]',
    ).hasMatch(value);
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleRegisterUser(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final request = RegisterUserRequest(
        email: widget.invitation.email,
        password: _passwordController.text,
        invitationToken: widget.invitation.token,
      );

      context.read<RegisterUserBloc>().add(RegisterUserSubmitted(request));
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterUserBloc, RegisterUserState>(
      listener: (context, state) {
        if (state is RegisterUserSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account created successfully! Welcome ${state.response.firstName}!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to dashboard after successful registration
          context.goNamed(Routelists.login, extra: widget.invitation);
        } else if (state is RegisterUserFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Builder(
        builder: (context) => BlocBuilder<RegisterUserBloc, RegisterUserState>(
          builder: (context, state) {
            return _buildRegisterUserForm(context);
          },
        ),
      ),
    );
  }

  Widget _buildRegisterUserForm(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenSize.width > 500 ? 500 : screenSize.width * 0.9,
            margin: const EdgeInsets.symmetric(vertical: 20.0),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF214a59), Color(0xFF171c23)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Personalized greeting
                          const SizedBox(height: 24),
                          Text(
                            'login_screen.welcome_message'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set your password to complete your account setup',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textAlign: TextAlign.center,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (!_isStrongPassword(value)) {
                                return 'Use 8+ chars with upper, lower, number and symbol';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'reset_password.password_hint'.tr(),
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Align(
                          //   alignment: Alignment.centerLeft,
                          //   child: Text(
                          //     'reset_password.confirm_label'.tr(),
                          //     style: const TextStyle(
                          //       color: Colors.black,
                          //       fontWeight: FontWeight.w600,
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            textAlign: TextAlign.center,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'reset_password.confirm_hint'.tr(),
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          BlocBuilder<RegisterUserBloc, RegisterUserState>(
                            builder: (context, state) {
                              return SizedBox(
                                width: double.infinity,
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(
                                        top: 4,
                                        left: 4,
                                      ),
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(
                                        bottom: 4,
                                        right: 4,
                                      ),
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 4,
                                        ),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: state is RegisterUserLoading
                                            ? null
                                            : () =>
                                                  _handleRegisterUser(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: const Color.fromARGB(
                                            0,
                                            148,
                                            124,
                                            124,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          minimumSize: const Size.fromHeight(
                                            48,
                                          ),
                                        ),
                                        child: state is RegisterUserLoading
                                            ? const LoadingWidget(
                                                size: 20,
                                                color: Colors.white,
                                                showMessage: false,
                                              )
                                            : Text(
                                                'Create Account',
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              context.pushNamed(
                                Routelists.login,
                                extra: widget.invitation,
                              );
                            },
                            child: Text(
                              'reset_password.back_to_login'.tr(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
                AppFooter(
                  onLanguageChanged: _handleLanguageChanged,
                  containerWidth: screenSize.width > 500
                      ? 500
                      : screenSize.width * 0.9,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
