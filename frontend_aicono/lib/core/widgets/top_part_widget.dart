import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';

/// Top header widget with menu, language switcher, and logout functionality.
///
/// You can pass real data via [userInitial], [verseInitial] and wire
/// behaviour via [onMenuTap] / [onLanguageChanged].
class TopHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback onLanguageChanged;
  final double height;
  final double containerWidth;
  final String? userInitial;
  final String? verseInitial;

  const TopHeader({
    super.key,
    this.onMenuTap,
    required this.onLanguageChanged,
    this.height = 56,
    required this.containerWidth,
    this.userInitial,
    this.verseInitial,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStackedAvatars(),
          Image.asset('assets/images/bryteversebubbles.png', height: 40),
          _buildRightSection(context),
        ],
      ),
    );
  }

  Widget _buildStackedAvatars() {
    const avatarSize = 36.0;
    const overlap = 26.0;

    return SizedBox(
      width: avatarSize + overlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: overlap, child: _buildVerseAvatar(avatarSize / 2)),
          Positioned(left: 0, child: _buildUserAvatar(avatarSize / 2)),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(double radius) {
    final initial = (userInitial != null && userInitial!.isNotEmpty)
        ? userInitial!.substring(0, 1).toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade700,
      child: Text(
        initial,
        style: AppTextStyles.titleSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVerseAvatar(double radius) {
    final initial = (verseInitial != null && verseInitial!.isNotEmpty)
        ? verseInitial!.substring(0, 1).toUpperCase()
        : 'B';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade400,
      child: Text(
        initial,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRightSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onMenuTap != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onMenuTap,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.menu, color: Colors.black87, size: 24),
            ),
          ),
        ] else ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showMenuPopup(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'MENU',
                    style: AppTextStyles.labelSmall.copyWith(
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
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
                          color: AppTheme.primary,
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
      ],
    );
  }

  void _showMenuPopup(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const popupWidth = 220.0;
    const popupHeight = 200.0;

    final containerLeftOffset = (screenWidth - containerWidth) / 2;
    final menuIconCenter = containerWidth - 25;
    final left = containerLeftOffset + menuIconCenter - (popupWidth / 2);
    final adjustedLeft = left.clamp(10.0, screenWidth - popupWidth - 10);
    final top = kToolbarHeight + 20;

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
                      const Icon(Icons.language, size: 18),
                      const SizedBox(width: 8),
                      Text('Change language', style: AppTextStyles.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLanguageOptions(context),
                ],
              ),
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'logout') {
        await _handleLogout(context);
      }
    });
  }

  Widget _buildLanguageOptions(BuildContext context) {
    final currentLocale = context.locale;

    return Column(
      children: [
        _buildLanguageOption(
          context: context,
          locale: const Locale('en'),
          label: 'English',
          isSelected: currentLocale.languageCode == 'en',
        ),
        const SizedBox(height: 4),
        _buildLanguageOption(
          context: context,
          locale: const Locale('de'),
          label: 'Deutsch',
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
        if (!context.mounted) return;

        // Close the current menu
        Navigator.pop(context);

        // Notify parent to rebuild
        onLanguageChanged();

        // Small delay to ensure locale is updated, then reopen menu
        await Future.delayed(const Duration(milliseconds: 100));
        if (!context.mounted) return;
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
                if (!context.mounted) return;

                // Close the current menu
                Navigator.pop(context);

                // Notify parent to rebuild
                onLanguageChanged();

                // Small delay to ensure locale is updated, then reopen menu
                await Future.delayed(const Duration(milliseconds: 100));
                if (!context.mounted) return;
                _showMenuPopup(context);
              },
            ),
            const SizedBox(width: 4),
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

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final authService = sl<AuthService>();
      await authService.logout();

      // Navigate to login page after successful logout
      if (context.mounted) {
        context.goNamed(Routelists.login);
      }
    } catch (e) {
      // If logout fails, still try to clear local state and navigate
      try {
        sl<AuthService>().clearAuth();
        if (context.mounted) {
          context.goNamed(Routelists.login);
        }
      } catch (_) {
        // If navigation fails, at least we tried
      }
    }
  }
}
