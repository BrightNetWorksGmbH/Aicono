import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_sidebar.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/verse/presentation/components/broken_border_painter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import '../../../../core/theme/app_theme.dart';

class SwitchSettingsScreen extends StatefulWidget {
  const SwitchSettingsScreen({super.key});

  @override
  State<SwitchSettingsScreen> createState() => _SwitchSettingsScreenState();
}

class _SwitchSettingsScreenState extends State<SwitchSettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TextEditingController _organizationController;
  late TextEditingController _switchNameController;
  late TextEditingController _subdomainController;
  late TextEditingController _colorNameController;
  final _colorController = TextEditingController();
  late FocusNode _switchNameFocusNode;
  late FocusNode _organizationFocusNode;
  late FocusNode _subdomainFocusNode;
  late FocusNode _colorNameFocusNode;
  bool _isEditingSwitchName = false;
  bool _isEditingOrganization = false;
  bool _isEditingSubdomain = false;
  bool _isEditingColorName = false;
  bool isButtonEnabled = false;
  Uint8List? _selectedImageBytes;

  XFile? _logoFile;
  Color _primaryColor = Colors.blue;
  String colorHex = "";
  String? _networkLogoUrl;

  @override
  void initState() {
    super.initState();

    _organizationController = TextEditingController();
    _switchNameController = TextEditingController();
    _subdomainController = TextEditingController();
    _colorNameController = TextEditingController();
    _switchNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_switchNameFocusNode.hasFocus && _isEditingSwitchName) {
          setState(() {
            _isEditingSwitchName = false;
          });
        }
      });
    _organizationFocusNode = FocusNode()
      ..addListener(() {
        if (!_organizationFocusNode.hasFocus && _isEditingOrganization) {
          setState(() {
            _isEditingOrganization = false;
          });
        }
      });
    _subdomainFocusNode = FocusNode()
      ..addListener(() {
        if (!_subdomainFocusNode.hasFocus && _isEditingSubdomain) {
          setState(() {
            _isEditingSubdomain = false;
          });
        }
      });
    _colorNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_colorNameFocusNode.hasFocus && _isEditingColorName) {
          setState(() {
            _isEditingColorName = false;
          });
        }
      });
    // Initialize with 6-digit hex format
    String hexValue = _primaryColor.value.toRadixString(16).padLeft(8, '0');
    colorHex = '#${hexValue.substring(2)}'; // Remove alpha channel
  }

  @override
  void dispose() {
    _organizationController.dispose();
    _switchNameController.dispose();
    _subdomainController.dispose();
    _colorNameController.dispose();
    _colorController.dispose();
    _switchNameFocusNode.dispose();
    _organizationFocusNode.dispose();
    _subdomainFocusNode.dispose();
    _colorNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();

    if (kIsWeb) {
      // Web: no permissions needed
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _logoFile = pickedFile; // ✅ always XFile
          _selectedImageBytes = bytes; // use for Image.memory preview
        });
      }
    } else {
      // Mobile: pick image (permissions handled by image_picker)
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _logoFile = pickedFile;
        });
      }
    }
    changeBottomEnabled();
  }

  void _pickColor() {
    () async {
      final Color? picked = await showDialog<Color?>(
        context: context,
        builder: (dialogCtx) {
          Color tempColor = _primaryColor;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Pick Brand Color"),
            content: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return ColorPicker(
                    pickerColor: tempColor,
                    onColorChanged: (color) {
                      setStateDialog(() => tempColor = color);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(tempColor),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (picked != null) {
        // Convert to 6-digit hex format (remove alpha channel)
        String hexValue = picked.value.toRadixString(16).padLeft(8, '0');
        colorHex =
            '#${hexValue.substring(2)}'; // Remove alpha (first 2 characters)
        setState(() {
          _primaryColor = picked;
          _colorController.text = colorHex;
        });
        changeBottomEnabled();
      }
    }();
  }

  bool _isValidHexColor(String hex) {
    if (hex.isEmpty) return false;

    // Remove # if present
    String cleanHex = hex.replaceFirst('#', '');

    // Check if it's exactly 6 characters and contains only valid hex characters
    if (cleanHex.length != 6) return false;

    // Check if all characters are valid hex digits (0-9, A-F, a-f)
    RegExp hexPattern = RegExp(r'^[0-9A-Fa-f]{6}$');
    return hexPattern.hasMatch(cleanHex);
  }

  void changeBottomEnabled() {
    setState(() {
      isButtonEnabled =
          _organizationController.text.isNotEmpty &&
          _switchNameController.text.isNotEmpty &&
          _subdomainController.text.isNotEmpty &&
          _colorNameController.text.isNotEmpty &&
          colorHex.isNotEmpty &&
          _isValidHexColor(colorHex);
    });
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  Future<void> _saveSettings() async {
    // UI only - no integration
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      context.pushNamed(Routelists.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final bloc = sl<DashboardSitesBloc>();
            bloc.add(const DashboardSitesRequested(bryteswitchId: null));
            return bloc;
          },
        ),
        BlocProvider(create: (context) => sl<DashboardSiteDetailsBloc>()),
        BlocProvider(create: (context) => sl<DashboardBuildingDetailsBloc>()),
        BlocProvider(create: (context) => sl<DashboardFloorDetailsBloc>()),
        BlocProvider(create: (context) => sl<DashboardRoomDetailsBloc>()),
      ],
      child: SafeArea(
        child: Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey[50]!, Colors.grey[100]!],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: DashboardSidebar(
                    isInDrawer: true,
                    showBackToDashboard: true,
                    activeSection: 'settings',
                    onLanguageChanged: _handleLanguageChanged,
                  ),
                ),
              ),
            ),
          ),
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenSize.height),
              child: Center(
                child: Container(
                  width: screenSize.width,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
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
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: TopHeader(
                                  onLanguageChanged: _handleLanguageChanged,
                                  containerWidth: screenSize.width > 1200
                                      ? 1200
                                      : screenSize.width,
                                  // Only provide onMenuTap on narrow screens to open drawer
                                  // On wide screens, leave it null so the menu shows popup
                                  onMenuTap: screenSize.width < 800
                                      ? () {
                                          _scaffoldKey.currentState
                                              ?.openDrawer();
                                        }
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final isNarrow = screenSize.width < 800;
                                    final mainFlex = isNarrow ? 1 : 7;
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!isNarrow)
                                          Expanded(
                                            flex: 3,
                                            child: DashboardSidebar(
                                              showBackToDashboard: true,
                                              activeSection: 'settings',
                                              onLanguageChanged:
                                                  _handleLanguageChanged,
                                            ),
                                          ),
                                        Expanded(
                                          flex: mainFlex,
                                          child: Container(
                                            color: Colors.white,
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: _buildSettingsContent(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      AppFooter(
                        onLanguageChanged: _handleLanguageChanged,
                        containerWidth: screenSize.width > 1200
                            ? 1200
                            : screenSize.width,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header Section - Centered with close icon on right
          Stack(
            children: [
              // Centered title and subtitle
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Switch Settings',
                      style: AppTextStyles.appTitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your switch configuration and branding',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Close icon positioned on the right
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 32),
                  onPressed: () {
                    context.pushNamed(Routelists.dashboard);
                  },
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // General Info Section
          _buildSectionCard(
            title: "General Information",
            child: Column(
              children: [
                // Switch name - display + change pattern
                _isEditingSwitchName
                    ? TextField(
                        controller: _switchNameController,
                        focusNode: _switchNameFocusNode,
                        autofocus: true,
                        onChanged: (value) {
                          changeBottomEnabled();
                        },
                        decoration: InputDecoration(
                          prefixText: 'Switch name: ',
                          prefixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black,
                          ),
                          hintText: _switchNameController.text.isEmpty
                              ? "Enter switch name"
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black,
                        ),
                        onSubmitted: (_) {
                          setState(() {
                            _isEditingSwitchName = false;
                          });
                          _switchNameFocusNode.unfocus();
                        },
                        onEditingComplete: () {
                          setState(() {
                            _isEditingSwitchName = false;
                          });
                          _switchNameFocusNode.unfocus();
                        },
                      )
                    : Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Switch name: ${_switchNameController.text.isEmpty ? "" : _switchNameController.text}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isEditingSwitchName = true;
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 50),
                                  () {
                                    _switchNameFocusNode.requestFocus();
                                    _switchNameController.selection =
                                        TextSelection(
                                          baseOffset: 0,
                                          extentOffset:
                                              _switchNameController.text.length,
                                        );
                                  },
                                );
                              },
                              child: Text(
                                'Change Switch Name',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                const SizedBox(height: 16),

                // Organization name - display + change pattern
                _isEditingOrganization
                    ? TextField(
                        controller: _organizationController,
                        focusNode: _organizationFocusNode,
                        autofocus: true,
                        onChanged: (value) {
                          changeBottomEnabled();
                        },
                        decoration: InputDecoration(
                          prefixText: 'Organization: ',
                          prefixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black,
                          ),
                          hintText: _organizationController.text.isEmpty
                              ? "Enter organization name"
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black,
                        ),
                        onSubmitted: (_) {
                          setState(() {
                            _isEditingOrganization = false;
                          });
                          _organizationFocusNode.unfocus();
                        },
                        onEditingComplete: () {
                          setState(() {
                            _isEditingOrganization = false;
                          });
                          _organizationFocusNode.unfocus();
                        },
                      )
                    : Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Organization: ${_organizationController.text.isEmpty ? "" : _organizationController.text}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isEditingOrganization = true;
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 50),
                                  () {
                                    _organizationFocusNode.requestFocus();
                                    _organizationController
                                        .selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          _organizationController.text.length,
                                    );
                                  },
                                );
                              },
                              child: Text(
                                'Change Organization Name',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                const SizedBox(height: 16),

                // Subdomain - display + change pattern
                _isEditingSubdomain
                    ? TextField(
                        controller: _subdomainController,
                        focusNode: _subdomainFocusNode,
                        autofocus: true,
                        onChanged: (value) {
                          changeBottomEnabled();
                        },
                        decoration: InputDecoration(
                          prefixText: 'Subdomain: ',
                          prefixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black,
                          ),
                          hintText: _subdomainController.text.isEmpty
                              ? "your-subdomain"
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black,
                        ),
                        onSubmitted: (_) {
                          setState(() {
                            _isEditingSubdomain = false;
                          });
                          _subdomainFocusNode.unfocus();
                        },
                        onEditingComplete: () {
                          setState(() {
                            _isEditingSubdomain = false;
                          });
                          _subdomainFocusNode.unfocus();
                        },
                      )
                    : Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subdomain: ${_subdomainController.text.isEmpty ? "" : _subdomainController.text}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isEditingSubdomain = true;
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 50),
                                  () {
                                    _subdomainFocusNode.requestFocus();
                                    _subdomainController.selection =
                                        TextSelection(
                                          baseOffset: 0,
                                          extentOffset:
                                              _subdomainController.text.length,
                                        );
                                  },
                                );
                              },
                              child: Text(
                                'Change Subdomain',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logo Section
          _buildSectionCard(
            title: "Logo",
            child: _buildLogoUploadArea(_networkLogoUrl),
          ),
          const SizedBox(height: 24),

          // Branding Section
          _buildSectionCard(
            title: "Branding",
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLargeScreen = constraints.maxWidth > 600;

                if (isLargeScreen) {
                  // Large screen: Everything in a single row
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Color Widget
                      Container(
                        width: 120,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            colorHex.toUpperCase(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Choose Color Link
                      InkWell(
                        onTap: _pickColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '+ Choose Color',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                      // Color Name Field (switches between display and edit modes)
                      Expanded(
                        child: _isEditingColorName
                            ? TextField(
                                controller: _colorNameController,
                                focusNode: _colorNameFocusNode,
                                autofocus: true,
                                decoration: InputDecoration(
                                  prefixText: 'Color name: ',
                                  prefixStyle: AppTextStyles.bodyMedium
                                      .copyWith(color: Colors.black),
                                  hintText: _colorNameController.text.isEmpty
                                      ? "Bright-NetWorks-Turquoise"
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.black,
                                ),
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) {
                                  setState(() {
                                    _isEditingColorName = false;
                                  });
                                  _colorNameFocusNode.unfocus();
                                },
                                onEditingComplete: () {
                                  setState(() {
                                    _isEditingColorName = false;
                                  });
                                  _colorNameFocusNode.unfocus();
                                },
                              )
                            : Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left: Color name display
                                    Text(
                                      'Color name: ${_colorNameController.text.isEmpty ? "Bright-NetWorks-Turquoise" : _colorNameController.text}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    // Right: Change color name link
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isEditingColorName = true;
                                        });
                                        // Focus the TextField after a short delay to ensure it's built
                                        Future.delayed(
                                          const Duration(milliseconds: 50),
                                          () {
                                            _colorNameFocusNode.requestFocus();
                                            // Select all text for easy editing
                                            _colorNameController
                                                .selection = TextSelection(
                                              baseOffset: 0,
                                              extentOffset: _colorNameController
                                                  .text
                                                  .length,
                                            );
                                          },
                                        );
                                      },
                                      child: Text(
                                        'Change Color Name',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: Colors.grey[700],
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                } else {
                  // Small screen: Stacked layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Accent Color Input
                      Row(
                        children: [
                          Container(
                            width: 120,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                colorHex.toUpperCase(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _pickColor,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '+ Choose Color',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.black,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Color Name Input
                      TextField(
                        controller: _colorNameController,
                        decoration: InputDecoration(
                          prefixText: 'Color name: ',
                          prefixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black,
                          ),
                          hintText: _colorNameController.text.isEmpty
                              ? "Bright-NetWorks-Turquoise"
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 32),

          // Save Button - Center aligned with fixed width
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MouseRegion(
                child: SizedBox(
                  width: 200,
                  child: OutlinedButton(
                    onPressed:
                        (isButtonEnabled &&
                            (_logoFile != null || _networkLogoUrl != null))
                        ? _saveSettings
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                          (isButtonEnabled &&
                              (_logoFile != null || _networkLogoUrl != null))
                          ? const Color(0xFF171C23)
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      side: BorderSide(
                        color:
                            (isButtonEnabled &&
                                (_logoFile != null || _networkLogoUrl != null))
                            ? const Color(0xFF171C23)
                            : Colors.grey,
                        width: 3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(
                      'Update Settings',
                      style: AppTextStyles.buttonText.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            (isButtonEnabled &&
                                (_logoFile != null || _networkLogoUrl != null))
                            ? const Color(0xFF171C23)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    String? description,
    String? actionLinkText,
    VoidCallback? onActionLinkTap,
    bool? showActionLink,
  }) {
    // Show action link if explicitly set, otherwise don't show
    final shouldShowActionLink = showActionLink ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (shouldShowActionLink &&
                  actionLinkText != null &&
                  onActionLinkTap != null)
                InkWell(
                  onTap: onActionLinkTap,
                  child: Text(
                    actionLinkText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF0095A5), // Light blue/teal
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLogoUploadArea(String? networkLogoUrl) {
    return Container(
      width: double.infinity,
      child: CustomPaint(
        painter: BrokenBorderPainter(
          borderColor: Colors.grey[300]!,
          borderWidth: 1.0,
          dashLength: 8.0,
          dashSpace: 4.0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              InkWell(
                onTap: _pickLogo,
                child: Text(
                  '+ Choose Image from File',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF0095A5),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF0095A5),
                size: 24,
              ),
              const SizedBox(height: 16),
              if (_logoFile != null ||
                  (networkLogoUrl != null && networkLogoUrl.isNotEmpty))
                Container(
                  height: 80,
                  width: double.infinity,
                  color: Colors.white,
                  child: _logoFile != null
                      ? kIsWeb
                            ? Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(_logoFile!.path),
                                fit: BoxFit.contain,
                              )
                      : networkLogoUrl != null && networkLogoUrl.isNotEmpty
                      ? Image.network(
                          networkLogoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.grey,
                            );
                          },
                        )
                      : null,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SWITCH',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Color(0xFF0095A5),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
