import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

import '../../features/Authentication/domain/repositories/login_repository.dart';
import '../routing/routeLists.dart';

class AppFooter extends StatefulWidget {
  final VoidCallback onLanguageChanged;
  final double containerWidth;

  const AppFooter({
    super.key,
    required this.onLanguageChanged,
    required this.containerWidth,
  });

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  String? currentUserName;
  String? currentUserRole;
  String? currentUserProfile;

  @override
  initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final loginRepository = sl<LoginRepository>();

      // Load current user
      final userResult = await loginRepository.getCurrentUser();

      userResult.fold(
        (failure) {
          // Handle error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load user: ${failure.message}'),
              ),
            );
          }
        },
        (user) {
          if (user != null) {
            setState(() {
              currentUserName = user.firstName;
              currentUserProfile = user.avatarUrl;
              currentUserRole = user.position;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

        // Close the current menu
        Navigator.pop(context);

        // Notify parent to rebuild
        widget.onLanguageChanged();

        // Small delay to ensure locale is updated, then reopen menu
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        _showMenuPopup(context);
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

                // Close the current menu
                Navigator.pop(context);

                // Notify parent to rebuild
                widget.onLanguageChanged();

                // Small delay to ensure locale is updated, then reopen menu
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                _showMenuPopup(context);
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

  Widget _buildSocialIcon(String assetPath) {
    return Container(
      width: 24,
      height: 24,
      child: SvgPicture.asset(
        assetPath,
        colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildSocialIconPng(String assetPath) {
    return Container(
      width: 24,
      height: 24,
      child: Image.asset(assetPath, color: Colors.white, fit: BoxFit.contain),
    );
  }

  void _showMenuPopup(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate position based on container width
    final popupWidth = 200.0;
    final popupHeight = 150.0;

    // Calculate the container's position on screen
    // When container is centered, we need to account for the centering
    final containerLeftOffset = (screenWidth - widget.containerWidth) / 2;

    // Position the popup above the menu icon within the container
    final menuIconCenter =
        widget.containerWidth - 25; // Approximate center of menu icon
    final left =
        containerLeftOffset +
        menuIconCenter -
        (popupWidth / 2); // Center the popup above the icon

    // Ensure popup doesn't go outside screen bounds
    final adjustedLeft = left.clamp(10.0, screenWidth - popupWidth - 10);
    final top = screenHeight - popupHeight - 60; // Position above footer

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        adjustedLeft,
        top,
        adjustedLeft + popupWidth,
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
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppTheme.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),

            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                final featuresColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFooterFeature('login_screen.footer_feature_1'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_2'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_3'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_4'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_5'.tr()),
                    _buildFooterFeature('login_screen.footer_feature_6'.tr()),
                  ],
                );

                final linksColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'login_screen.footer_relevant_links'.tr(),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFooterLink('login_screen.footer_link_contact'.tr()),
                    _buildFooterLink(
                      'login_screen.footer_link_data_protection'.tr(),
                    ),
                    _buildFooterLink(
                      'login_screen.footer_link_privacy_settings'.tr(),
                      onTap: () {
                        context.pushNamed(Routelists.privacyPolicy);
                      },
                    ),
                    _buildFooterLink('login_screen.footer_link_imprint'.tr()),
                  ],
                );

                final socialColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'login_screen.footer_social_media'.tr(),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Social Media Icons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSocialIconPng('assets/images/linkedIN.png'),
                        SizedBox(width: 8),
                        _buildSocialIcon('assets/images/whatsapp-icon.svg'),
                        SizedBox(width: 8),
                        _buildSocialIcon(
                          'assets/images/black-instagram-icon.svg',
                        ),
                        SizedBox(width: 8),
                        _buildSocialIcon('assets/images/vimeo-icon.svg'),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );

                if (!isNarrow) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [featuresColumn, linksColumn, socialColumn],
                  );
                }

                // Narrow layout: stack columns vertically and stretch to width
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    featuresColumn,
                    const SizedBox(height: 16),
                    linksColumn,
                    const SizedBox(height: 16),
                    socialColumn,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Image.asset('assets/images/appfoter.png'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentUserName != null && currentUserName!.isNotEmpty)
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
                      child: ClipOval(
                        child: Image.network(
                          currentUserProfile ??
                              'https://www.gravatar.com/avatar/placeholder',
                          width: 26,
                          height: 26,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.account_circle,
                              size: 26,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentUserName != null &&
                            currentUserName!.isNotEmpty)
                          Text(
                            currentUserName!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          currentUserRole ?? 'CEO & Founder',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              Image.asset('assets/images/bryteversebubbles.png', height: 40),
              InkWell(
                onTap: () {
                  _showMenuPopup(context);
                },
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
                            margin: EdgeInsets.only(bottom: i == 2 ? 0 : 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildFooterFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Image.asset(
            'assets/images/check.png',
            width: 16,
            height: 16,
            color: Color(0xFF238636),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppTheme.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
