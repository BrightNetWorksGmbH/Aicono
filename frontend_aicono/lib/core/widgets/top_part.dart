import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../features/Authentication/domain/repositories/login_repository.dart';
import '../services/auth_service.dart';
import '../storage/local_storage.dart';
import '../theme/app_theme.dart';

class TopHeader extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback onLanguageChanged;
  final double height;
  final double containerWidth;
  final String? brytesightId;
  final ValueChanged<String>? onBrytesightChanged;

  const TopHeader({
    super.key,
    this.onMenuTap,
    required this.onLanguageChanged,
    this.height = 56,
    required this.containerWidth,
    this.brytesightId,
    this.onBrytesightChanged,
  });

  @override
  State<TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<TopHeader> {
  String? _userAvatarUrl;
  String _userInitial = '?';
  String? _verseLogoUrl;
  bool _isLanguageExpanded = false;
  String? currentVerseId;
  User? _currentUser;
  bool _canViewBrytesightSettings = false;
  String? _currentBrytesightId;
  Map<String, _BrytesightSummary> _brytesightSummaries = {};
  bool _isLoadingBrytesights = false;
  final GlobalKey _brytesightFieldKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(covariant TopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newBrytesightId = widget.brytesightId;
    if (newBrytesightId != null &&
        newBrytesightId.isNotEmpty &&
        newBrytesightId != oldWidget.brytesightId &&
        newBrytesightId != _currentBrytesightId) {
      setState(() {
        _currentBrytesightId = newBrytesightId;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final loginRepository = sl<LoginRepository>();
      final localStorage = sl<LocalStorage>();

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
          // _user = user;
          if (user != null && user.joinedVerse.isNotEmpty) {
            // Prefer previously selected verse if available and still valid
            final saved = localStorage.getSelectedVerseId();
            final initialVerseId =
                (saved != null && user.joinedVerse.contains(saved))
                ? saved
                : user.joinedVerse.first;
            setState(() {
              currentVerseId = initialVerseId;
            });
            // _evaluateSettingsPermission();
          } else {
            setState(() {
              currentVerseId = null;
            });
            // _evaluateSettingsPermission();
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

  Future<void> _loadUser() async {
    try {
      final repo = sl<LoginRepository>();
      final res = await repo.getCurrentUser();
      res.fold((_) {}, (User? user) {
        if (!mounted) return;
        if (user != null) {
          String first = '?';
          if (user.firstName.trim().isNotEmpty) {
            first = user.firstName.trim()[0];
          } else if (user.email.isNotEmpty) {
            first = user.email[0];
          }
          setState(() {
            _currentUser = user;
            _userInitial = first.toUpperCase();
            _userAvatarUrl = user.avatarUrl ?? null;
          });
          // _evaluateSettingsPermission();
          // _initializeBrytesightSelection(user);
        }
      });
    } catch (_) {}
  }

  void _showMenuPopup(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // final brytesightSection = _buildBrytesightSection();
    final hasBrytesightSection = false;
    // brytesightSection != null;
    final hasBrytesightId =
        (_currentBrytesightId != null && _currentBrytesightId!.isNotEmpty) ||
        (widget.brytesightId != null && widget.brytesightId!.isNotEmpty);

    // Calculate position based on container width
    // Increase width if brytesight section is present (it's 230px wide)
    final popupWidth = hasBrytesightSection ? 280.0 : 220.0;
    final popupHeight = hasBrytesightSection ? 300.0 : 200.0;

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
    final top = kToolbarHeight + 20; // Position below the toolbar

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
        // if (brytesightSection != null)
        //   _StaticPopupMenuEntry(
        //     child: Padding(
        //       padding: const EdgeInsets.symmetric(horizontal: 12.0),
        //       child: Container(child: brytesightSection),
        //     ),
        //   ),
        // if (widget.brytesightSection != null) const PopupMenuDivider(),
        // PopupMenuItem<String>(
        //   value: 'profile',
        //   child: Row(
        //     children: const [
        //       Icon(Icons.person_outline, size: 18),
        //       SizedBox(width: 8),
        //       Text('Profile'),
        //     ],
        //   ),
        // ),
        if (_canViewBrytesightSettings && hasBrytesightId)
          PopupMenuItem<String>(
            value: 'settings',
            child: Row(
              children: const [
                Icon(Icons.settings, size: 18),
                SizedBox(width: 8),
                Text('Settings'),
              ],
            ),
          ),
        if (hasBrytesightId)
          PopupMenuItem<String>(
            value: 'share',
            child: Row(
              children: const [
                Icon(Icons.share, size: 18),
                SizedBox(width: 8),
                Text('Share Brytesight Link'),
              ],
            ),
          ),
        PopupMenuItem<String>(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isLanguageExpanded = !_isLanguageExpanded;
                  });
                  setMenuState(() {}); // Update the menu UI
                },
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
                              'Change language',
                              style: AppTextStyles.titleSmall,
                            ),
                            Spacer(),
                            Icon(
                              _isLanguageExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                            ),
                          ],
                        ),
                        if (_isLanguageExpanded) ...[
                          SizedBox(height: 8),
                          _buildLanguageOptions(context),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
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
      if (value == null) return;

      final activeBrytesightId =
          _currentBrytesightId ?? widget.brytesightId ?? '';

      switch (value) {
        // case 'profile':
        //   // navigate to profile page
        //   try {
        //     context.pushNamed(
        //       Routelists.profile,
        //       extra: {
        //         'verseId':
        //             context.read<DashboardBloc>().state is DashboardLoaded
        //             ? (context.read<DashboardBloc>().state as DashboardLoaded)
        //                   .dashboardData
        //                   .data
        //                   .verse
        //                   .id
        //             : null,
        //       },
        //     );
        //   } catch (_) {
        //     // fallback
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(content: Text('Profile – coming soon')),
        //     );
        //   }
        //   break;

        case 'settings':
          if (_canViewBrytesightSettings && activeBrytesightId.isNotEmpty) {
            try {
              context.pushNamed(
                Routelists.login,
                extra: {'brytesightId': activeBrytesightId},
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error opening settings: $e')),
                );
              }
            }
          }
          break;
        case 'share':
          if (activeBrytesightId.isNotEmpty) {
            _shareBrytesightLink(context, activeBrytesightId);
          }
          break;
        case 'logout':
          try {
            await sl<AuthService>().logout();
            if (!mounted) return;
            context.goNamed(Routelists.login);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
          }
          break;
      }
    });
  }

  void _navigateToSettings(BuildContext context) {
    final activeBrytesightId =
        _currentBrytesightId ?? widget.brytesightId ?? '';

    if (!_canViewBrytesightSettings || activeBrytesightId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings are not available for this Brytesight.'),
        ),
      );
      return;
    }

    try {
      context.pushNamed(
        Routelists.login,
        extra: {'brytesightId': activeBrytesightId},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening settings: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.read<NotificationBloc>().add(LoadUnreadCount("widget"));

    // Try reading verse logo from dashboard bloc
    try {
      // final state = context.read<DashboardBloc>().state;
      // if (state is DashboardLoaded) {
      //   _verseLogoUrl = state.dashboardData.data.verse.branding.logoUrl;
      // }
    } catch (_) {}

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStackedAvatars(),
          Image.asset('assets/images/bryteversebubbles.png', height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // BlocBuilder<NotificationBloc, NotificationState>(
              //   builder: (context, state) {
              //     if (state is NotificationLoaded) {
              //       if (state.unreadCount == 0) {
              //         return IconButton(
              //           icon: const Icon(
              //             Icons.notifications,
              //             color: Colors.black54,
              //           ),
              //           onPressed: () {
              //             if (currentVerseId == null) {
              //               ScaffoldMessenger.of(context).showSnackBar(
              //                 const SnackBar(
              //                   content: Text('No verse selected'),
              //                 ),
              //               );
              //               return;
              //             }
              //             showDialog(
              //               context: context,
              //               builder: (_) =>
              //                   NotificationScreen(verseId: currentVerseId!),
              //             );
              //           },
              //         );
              //       }
              //       return Badge(
              //         label: Text(state.unreadCount.toString()),
              //         child: IconButton(
              //           icon: const Icon(
              //             Icons.notifications,
              //             color: Colors.black54,
              //           ),
              //           onPressed: () {
              //             if (currentVerseId == null) {
              //               ScaffoldMessenger.of(context).showSnackBar(
              //                 const SnackBar(
              //                   content: Text('No verse selected'),
              //                 ),
              //               );
              //               return;
              //             }
              //             showDialog(
              //               context: context,
              //               builder: (_) =>
              //                   NotificationScreen(verseId: currentVerseId!),
              //             );
              //           },
              //         ),
              //       );
              //     }
              //     return IconButton(
              //       icon: const Icon(
              //         Icons.notifications,
              //         color: Colors.black54,
              //       ),
              //       onPressed: () {
              //         if (currentVerseId == null) {
              //           ScaffoldMessenger.of(context).showSnackBar(
              //             const SnackBar(content: Text('No verse selected')),
              //           );
              //           return;
              //         }
              //         showDialog(
              //           context: context,
              //           builder: (_) =>
              //               NotificationScreen(verseId: currentVerseId!),
              //         );
              //       },
              //     );
              //   },
              // ),
              // const SizedBox(width: 12),
              // Show menu button for small screens (when onMenuTap is provided)
              if (widget.onMenuTap != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: widget.onMenuTap!,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Icon(Icons.menu, color: Colors.black87, size: 24),
                  ),
                ),
              ],
              // Only show profile/language menu button on large screens (when onMenuTap is null)
              if (widget.onMenuTap == null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _navigateToSettings(context),
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
          ),
        ],
      ),
    );
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
        SizedBox(height: 4),
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
        if (!mounted) return;
        setState(() {
          _isLanguageExpanded = false;
        });
        // Notify parent to rebuild (mirrors AppFooter behavior)
        widget.onLanguageChanged();
        // close the popup after selection to reflect instant changes
        Navigator.of(context).pop();
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
                setState(() {
                  _isLanguageExpanded = false;
                });
                widget.onLanguageChanged();
                Navigator.of(context).pop();
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

  Widget _buildStackedAvatars() {
    const avatarSize = 36.0;
    const overlap = 26.0;

    return SizedBox(
      width: avatarSize + overlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: overlap, child: _verseAvatar(avatarSize / 2)),
          Positioned(left: 0, child: _userAvatar(avatarSize / 2)),
        ],
      ),
    );
  }

  Widget _userAvatar(double radius) {
    if (_userAvatarUrl != null && _userAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_userAvatarUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade700,
      child: Text(
        _userInitial,
        style: AppTextStyles.titleSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _verseAvatar(double radius) {
    if (_verseLogoUrl != null && _verseLogoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_verseLogoUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade400,
      child: const Icon(Icons.business, color: Colors.white, size: 16),
    );
  }

  // Widget? _buildBrytesightSection() {
  //   final brytesights = _currentUser?.joinedSight ?? const <String>[];
  //   if (brytesights.isEmpty) {
  //     return null;
  //   }

  //   if (_isLoadingBrytesights && _brytesightSummaries.isEmpty) {
  //     return const Center(
  //       child: Padding(
  //         padding: EdgeInsets.symmetric(vertical: 16),
  //         child: SizedBox(
  //           width: 24,
  //           height: 24,
  //           child: CircularProgressIndicator(strokeWidth: 2),
  //         ),
  //       ),
  //     );
  //   }

  //   final String fallbackSelected =
  //       (_currentBrytesightId != null &&
  //           brytesights.contains(_currentBrytesightId))
  //       ? _currentBrytesightId!
  //       : brytesights.first;

  //   return Container(
  //     padding: EdgeInsets.symmetric(vertical: 8.0),
  //     // color: Colors.red,
  //     // width: 230,
  //     child: InkWell(
  //       key: _brytesightFieldKey,
  //       onTap: () => _showBrytesightPicker(brytesights, fallbackSelected),
  //       child: Row(
  //         children: [
  //           Expanded(
  //             child: _buildSelectedBrytesightLabel(
  //               _brytesightSummaries[fallbackSelected],
  //               fallbackSelected,
  //             ),
  //           ),
  //           const SizedBox(width: 8),
  //           const Icon(Icons.arrow_drop_down),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Future<void> _showBrytesightPicker(
    List<String> brytesights,
    String selectedId,
  ) async {
    final renderBox =
        _brytesightFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final selection = await showMenu<String>(
      color: Colors.white,
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy + size.height + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      items: brytesights
          .map(
            (id) => PopupMenuItem<String>(
              value: id,
              child: SizedBox(
                width: size.width - 40,
                child: _buildBrytesightOption(_brytesightSummaries[id], id),
              ),
            ),
          )
          .toList(),
    );

    if (selection != null) {
      // await _handleBrytesightSelection(selection);
    }
  }

  Widget _buildBrytesightOption(
    _BrytesightSummary? summary,
    String fallbackId,
  ) {
    final displayName = summary?.name ?? fallbackId;
    return Row(
      children: [
        _buildBrytesightAvatar(summary?.logoUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedBrytesightLabel(
    _BrytesightSummary? summary,
    String fallbackId,
  ) {
    final displayName = summary?.name ?? fallbackId;
    return Row(
      children: [
        _buildBrytesightAvatar(summary?.logoUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              // fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrytesightAvatar(String? logoUrl) {
    final resolvedUrl = (logoUrl != null && logoUrl.isNotEmpty)
        ? logoUrl
        : null;
    final imageProvider = resolvedUrl != null
        ? NetworkImage(resolvedUrl)
        : null;

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[200],
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(Icons.hub, size: 16, color: AppTheme.primary)
          : null,
    );
  }

  Future<void> _shareBrytesightLink(
    BuildContext context,
    String brytesightId,
  ) async {
    try {
      // Get the current URL origin
      String baseUrl;
      if (kIsWeb) {
        // For web, get the current origin
        baseUrl = Uri.base.origin;
      } else {
        // For mobile/desktop, you might want to use a configurable base URL
        // For now, using localhost as fallback
        baseUrl = 'http://localhost:55975';
      }

      // Build the full guest challenge link
      final shareUrl = "test";
      // '$baseUrl/${Routelists.guestChallengeList}/$brytesightId';

      // Try Web Share API on web (if supported)
      if (kIsWeb) {
        try {
          // Use universal_io or dart:html for Web Share API
          // For now, we'll use clipboard as it's more reliable
          await Clipboard.setData(ClipboardData(text: shareUrl));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('top_header.link_copied'.tr()),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        } catch (e) {
          // Fall through to clipboard method
        }
      }

      // Fallback: Copy to clipboard
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('top_header.link_copied'.tr()),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('top_header.share_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BrytesightSummary {
  final String id;
  final String name;
  final String? logoUrl;

  const _BrytesightSummary({
    required this.id,
    required this.name,
    this.logoUrl,
  });
}

class _StaticPopupMenuEntry extends PopupMenuEntry<String> {
  final Widget child;

  const _StaticPopupMenuEntry({required this.child});

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(String? value) => false;

  @override
  State<_StaticPopupMenuEntry> createState() => _StaticPopupMenuEntryState();
}

class _StaticPopupMenuEntryState extends State<_StaticPopupMenuEntry> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: Material(color: Colors.transparent, child: widget.child),
    );
  }
}
