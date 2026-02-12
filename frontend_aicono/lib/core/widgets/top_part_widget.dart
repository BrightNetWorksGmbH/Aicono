import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/settings/domain/usecases/get_switch_by_id_usecase.dart';

/// Top header widget with menu, language switcher, and logout functionality.
///
/// Displays user and switch avatars. When [switchId] is provided, fetches switch
/// logo from API. User avatar/initial comes from AuthService when not overridden.
class TopHeader extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback onLanguageChanged;
  final double height;
  final double containerWidth;
  final String? userInitial;
  final String? verseInitial;
  final String? userAvatarUrl;
  final String? switchLogoUrl;
  final String? switchId;

  const TopHeader({
    super.key,
    this.onMenuTap,
    required this.onLanguageChanged,
    this.height = 56,
    required this.containerWidth,
    this.userInitial,
    this.verseInitial,
    this.userAvatarUrl,
    this.switchLogoUrl,
    this.switchId,
  });

  @override
  State<TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<TopHeader> {
  String? _loadedUserAvatarUrl;
  String? _loadedUserInitial;
  String? _loadedSwitchLogoUrl;
  String? _loadedVerseInitial;

  @override
  void initState() {
    super.initState();
    _loadAvatarData();
  }

  @override
  void didUpdateWidget(TopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.switchId != widget.switchId ||
        oldWidget.userAvatarUrl != widget.userAvatarUrl ||
        oldWidget.switchLogoUrl != widget.switchLogoUrl) {
      _loadAvatarData();
    }
  }

  Future<void> _loadAvatarData() async {
    final authService = sl<AuthService>();
    final user = authService.currentUser;

    if (user != null && mounted) {
      final avatarUrl = user.avatarUrl;
      setState(() {
        _loadedUserAvatarUrl = widget.userAvatarUrl ??
            (avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null);
        final name = '${user.firstName} ${user.lastName}'.trim();
        _loadedUserInitial = widget.userInitial ??
            (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?');
      });
    }

    if (widget.switchLogoUrl != null && mounted) {
      setState(() {
        _loadedSwitchLogoUrl = widget.switchLogoUrl;
        _loadedVerseInitial = widget.verseInitial ?? 'B';
      });
      return;
    }

    final effectiveSwitchId =
        widget.switchId ?? sl<LocalStorage>().getSelectedVerseId();
    if (effectiveSwitchId != null &&
        effectiveSwitchId.isNotEmpty &&
        mounted) {
      final result =
          await sl<GetSwitchByIdUseCase>().call(effectiveSwitchId);
      if (!mounted) return;
      result.fold(
        (_) {},
        (switchDetails) {
          if (mounted) {
            setState(() {
              final logoUrl = switchDetails.branding.logoUrl;
              _loadedSwitchLogoUrl = logoUrl != null && logoUrl.isNotEmpty
                  ? logoUrl
                  : null;
              _loadedVerseInitial = switchDetails.organizationName.isNotEmpty
                  ? switchDetails.organizationName
                      .substring(0, 1)
                      .toUpperCase()
                  : 'B';
            });
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStackedAvatars(),
          _buildBrandLogo(),
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
          Positioned(
            left: overlap,
            child: _buildVerseAvatar(avatarSize / 2),
          ),
          Positioned(left: 0, child: _buildUserAvatar(avatarSize / 2)),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(double radius) {
    final avatarUrl = widget.userAvatarUrl ?? _loadedUserAvatarUrl;
    final initial = widget.userInitial ??
        _loadedUserInitial ??
        (avatarUrl == null || avatarUrl.isEmpty ? '?' : null) ??
        '?';
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade700,
      backgroundImage: hasImage ? NetworkImage(avatarUrl!) : null,
      onBackgroundImageError: hasImage ? (_, trace) {} : null,
      child: !hasImage
          ? Text(
              initial,
              style: AppTextStyles.titleSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }

  Widget _buildVerseAvatar(double radius) {
    final logoUrl = widget.switchLogoUrl ?? _loadedSwitchLogoUrl;
    final initial = widget.verseInitial ??
        _loadedVerseInitial ??
        (logoUrl == null || logoUrl.isEmpty ? 'B' : null) ??
        'B';
    final hasImage = logoUrl != null && logoUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: hasImage ? NetworkImage(logoUrl!) : null,
      onBackgroundImageError: hasImage ? (_, trace) {} : null,
      child: !hasImage
          ? Text(
              initial,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }

  Widget _buildBrandLogo() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'AI',
            style: AppTextStyles.appTitle.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: 'CONO',
            style: AppTextStyles.appTitle.copyWith(
              color: const Color(0xFF636F57),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.onMenuTap != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: widget.onMenuTap,
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

    final containerLeftOffset = (screenWidth - widget.containerWidth) / 2;
    final menuIconCenter = widget.containerWidth - 25;
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
        widget.onLanguageChanged();

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
                widget.onLanguageChanged();

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
