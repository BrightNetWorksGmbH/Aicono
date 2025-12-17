import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend_aicono/core/constant.dart';

class LoginFooter extends StatefulWidget {
  const LoginFooter({super.key});

  @override
  State<LoginFooter> createState() => _LoginFooterState();
}

class _LoginFooterState extends State<LoginFooter> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // color: const Color(0xFF161B22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'login_screen.footer_title'.tr(),
              style: TextStyle(
                color: AppTheme.text,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFooterFeature('login_screen.footer_feature_1'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_2'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_3'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_4'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_5'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_6'.tr()),
                  ],
                ),
                SizedBox(width: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'login_screen.footer_social_media'.tr(),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Social Media Icons (placeholders)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FaIcon(FontAwesomeIcons.linkedin, color: Colors.white),
                        SizedBox(width: 8),
                        FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                        SizedBox(width: 8),
                        FaIcon(FontAwesomeIcons.instagram, color: Colors.white),
                        SizedBox(width: 8),
                        FaIcon(FontAwesomeIcons.facebook, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'login_screen.footer_relevant_links'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFooterLink(
                          'login_screen.footer_link_contact'.tr(),
                        ),
                        _buildFooterLink(
                          'login_screen.footer_link_data_protection'.tr(),
                        ),
                        _buildFooterLink(
                          'login_screen.footer_link_privacy_settings'.tr(),
                        ),
                        _buildFooterLink(
                          'login_screen.footer_link_imprint'.tr(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.apple, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stephan',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CEO & Founder',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Image.asset('assets/images/bryteversebubbles.png', height: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(color: Colors.white, fontSize: 8),
                  ),
                  // const SizedBox(height: 2),
                  Icon(Icons.menu, color: Colors.white),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check, color: Color(0xFF238636), size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
