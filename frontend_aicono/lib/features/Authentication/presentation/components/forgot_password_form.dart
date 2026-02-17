import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forget_password_bloc/forgot_password_bloc.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forget_password_bloc/forgot_password_event.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forget_password_bloc/forgot_password_state.dart';

import '../../../../core/theme/app_theme.dart';

class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({super.key});

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ForgotPasswordBloc>().add(
        SendResetLinkRequested(_emailController.text.trim()),
      );
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

    return BlocListener<ForgotPasswordBloc, ForgotPasswordState>(
      listener: (context, state) {
        if (state is ForgotPasswordSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to login after showing success
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.goNamed(Routelists.login);
            }
          });
        } else if (state is ForgotPasswordFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Padding(
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
                  ? min(max(0, (screenSize.height - contentWidth)), 200)
                  : 0,
            ),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF214a59), Color(0xFF171c23)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),

                    // Logo
                    SizedBox(
                      width: contentWidth > 600
                          ? contentWidth - 200
                          : contentWidth,
                      child: SvgPicture.asset(
                        'assets/images/logo_white_horizontal.svg',
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 54),

                    // Title
                    SizedBox(
                      width: contentWidth > 600
                          ? contentWidth - contentWidth / 3
                          : contentWidth,
                      child: Text(
                        'forgot_password.title'.tr(),
                        style: AppTextStyles.appTitle,
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description
                    SizedBox(
                      width: contentWidth > 600
                          ? contentWidth - contentWidth / 3
                          : contentWidth,
                      child: Text(
                        'forgot_password.description'.tr(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Email Field
                    SizedBox(
                      width: contentWidth > 600
                          ? contentWidth - contentWidth / 3
                          : contentWidth,
                      child: TextFormField(
                        controller: _emailController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'forgot_password.email_placeholder'.tr(),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'forgot_password.email_required'.tr();
                          }
                          // Basic email validation
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'forgot_password.email_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button (with login form style)
                    BlocBuilder<ForgotPasswordBloc, ForgotPasswordState>(
                      builder: (context, state) {
                        final isLoading = state is ForgotPasswordLoading;
                        return SizedBox(
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
                                  onPressed: isLoading ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: const Color.fromARGB(
                                      0,
                                      148,
                                      124,
                                      124,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
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
                                      : Text(
                                          'forgot_password.submit_button'.tr(),
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Back to Login Link
                    Container(
                      width: contentWidth > 600
                          ? contentWidth - contentWidth / 3
                          : contentWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            context.goNamed(Routelists.login);
                          },
                          child: Text(
                            'forgot_password.back_to_login'.tr(),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
