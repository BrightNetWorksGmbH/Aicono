import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/presentation/components/login_form.dart';

class LoginPage extends StatefulWidget {
  final InvitationEntity? invitation;
  final String? token;
  const LoginPage({super.key, this.invitation, this.token});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    print('LoginPage initState - invitation: ${widget.invitation}');
  }

  void _handleLanguageChanged() {
    // Force rebuild when language changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenSize.width,

            decoration: BoxDecoration(
              color: Colors.white,

              // borderRadius: BorderRadius.circular(24.0),
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
                // LoginHeader(onLanguageChanged: _handleLanguageChanged),
                LoginForm(
                  key: ValueKey(
                    widget.invitation?.id ?? widget.token ?? 'no-invitation',
                  ),
                  invitation: widget.invitation,
                  token: widget.token,
                ),
                AppFooter(
                  onLanguageChanged: _handleLanguageChanged,
                  isWhiteBackground: true,
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
