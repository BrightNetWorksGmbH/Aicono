import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_sidebar.dart';
import 'package:frontend_aicono/features/settings/domain/entities/profile_update_request.dart';
import 'package:frontend_aicono/features/settings/presentation/bloc/profile_bloc.dart';
import 'package:frontend_aicono/features/settings/presentation/bloc/change_password_bloc.dart';
import 'package:frontend_aicono/features/upload/domain/usecases/upload_usecase.dart';
import 'package:frontend_aicono/features/verse/presentation/components/broken_border_painter.dart';
import '../../../../core/theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _positionController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late FocusNode _firstNameFocusNode;
  late FocusNode _lastNameFocusNode;
  late FocusNode _phoneFocusNode;
  late FocusNode _positionFocusNode;

  bool _isEditingFirstName = false;
  bool _isEditingLastName = false;
  bool _isEditingPhone = false;
  bool _isEditingPosition = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool isButtonEnabled = false;
  Uint8List? _selectedImageBytes;
  XFile? _avatarFile;
  String? _networkAvatarUrl;

  String get _effectiveSwitchId =>
      sl<LocalStorage>().getSelectedVerseId() ?? '';

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _positionController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _firstNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_firstNameFocusNode.hasFocus && _isEditingFirstName) {
          setState(() => _isEditingFirstName = false);
        }
      });
    _lastNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_lastNameFocusNode.hasFocus && _isEditingLastName) {
          setState(() => _isEditingLastName = false);
        }
      });
    _phoneFocusNode = FocusNode()
      ..addListener(() {
        if (!_phoneFocusNode.hasFocus && _isEditingPhone) {
          setState(() => _isEditingPhone = false);
        }
      });
    _positionFocusNode = FocusNode()
      ..addListener(() {
        if (!_positionFocusNode.hasFocus && _isEditingPosition) {
          setState(() => _isEditingPosition = false);
        }
      });

    _prefillFromAuth();
  }

  void _prefillFromAuth() {
    final user = sl<AuthService>().currentUser;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phoneNumber ?? '';
      _positionController.text = user.position;
      _networkAvatarUrl = user.avatarUrl != null && user.avatarUrl!.isNotEmpty
          ? user.avatarUrl
          : null;
    }
    _updateButtonEnabled();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _positionFocusNode.dispose();
    super.dispose();
  }

  void _updateButtonEnabled() {
    setState(() {
      isButtonEnabled =
          _firstNameController.text.trim().isNotEmpty &&
          _lastNameController.text.trim().isNotEmpty &&
          _positionController.text.trim().isNotEmpty;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _avatarFile = pickedFile;
          _selectedImageBytes = bytes;
        });
      } else {
        setState(() {
          _avatarFile = pickedFile;
        });
      }
      _updateButtonEnabled();
    }
  }

  void _changePassword(BuildContext context) {
    final current = _currentPasswordController.text;
    final newPwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.fill_passwords'.tr())),
      );
      return;
    }
    if (newPwd != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.passwords_match'.tr())),
      );
      return;
    }

    context.read<ChangePasswordBloc>().add(
          ChangePasswordSubmitted(
            currentPassword: current,
            newPassword: newPwd,
            confirmPassword: confirm,
          ),
        );
  }

  void _handleLanguageChanged() => setState(() {});

  Future<void> _saveSettings(BuildContext context) async {
    final user = sl<AuthService>().currentUser;
    if (user == null) return;

    String? profilePictureUrl = _networkAvatarUrl;
    if (_avatarFile != null) {
      final verseId = _effectiveSwitchId.isNotEmpty
          ? _effectiveSwitchId
          : user.id;
      final uploadResult = await sl<UploadImage>().call(
        _avatarFile!,
        verseId,
        'profile',
      );
      final url = uploadResult.fold((_) => null, (u) => u);
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uploadResult.fold(
                  (f) => f.message,
                  (_) => 'profile.upload_failed'.tr(),
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      profilePictureUrl = url;
    }

    final request = ProfileUpdateRequest(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email:
          sl<AuthService>().currentUser?.email ?? _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      position: _positionController.text.trim(),
      profilePictureUrl: profilePictureUrl,
    );

    context.read<ProfileBloc>().add(ProfileUpdateSubmitted(request: request));
  }

  void _populateFromUser(dynamic user) {
    // Only overwrite when API returns non-empty values; preserve prefill otherwise
    final fn = user.firstName?.toString().trim();
    if (fn != null && fn.isNotEmpty) {
      _firstNameController.text = fn;
    }
    final ln = user.lastName?.toString().trim();
    if (ln != null && ln.isNotEmpty) {
      _lastNameController.text = ln;
    }
    final em = user.email?.toString().trim();
    if (em != null && em.isNotEmpty) {
      _emailController.text = em;
    }
    final phone = user.phoneNumber?.toString().trim();
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
    }
    final pos = user.position?.toString().trim();
    if (pos != null && pos.isNotEmpty) {
      _positionController.text = pos;
    }
    final avatarUrl = user.avatarUrl;
    _networkAvatarUrl = avatarUrl != null && avatarUrl.toString().isNotEmpty
        ? avatarUrl.toString()
        : null;
    _updateButtonEnabled();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<ProfileBloc>()),
        BlocProvider(create: (context) => sl<ChangePasswordBloc>()),
      ],
      child: BlocListener<ChangePasswordBloc, ChangePasswordState>(
        listenWhen: (prev, curr) =>
            curr is ChangePasswordSuccess || curr is ChangePasswordFailure,
        listener: (context, state) {
          if (state is ChangePasswordSuccess) {
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('profile.password_changed'.tr()),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is ChangePasswordFailure) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'profile.password_change_failed'.tr(
                    namedArgs: {'message': state.message},
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) => prev != curr,
        listener: (context, state) {
          if (state is ProfileLoaded) {
            _populateFromUser(state.user);
          } else if (state is ProfileUpdateSuccess) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('profile.profile_updated'.tr()),
                backgroundColor: Colors.green,
              ),
            );
            context.goNamed(Routelists.dashboard);
          } else if (state is ProfileFailure) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
          child: BlocBuilder<ProfileBloc, ProfileState>(
            buildWhen: (prev, curr) =>
                curr is ProfileInitial ||
                curr is ProfileLoading ||
                curr is ProfileLoaded ||
                curr is ProfileFailure,
            builder: (context, state) {
              return _ProfileLoader(
                scaffoldKey: _scaffoldKey,
                screenSize: screenSize,
                onLanguageChanged: _handleLanguageChanged,
                effectiveSwitchId: _effectiveSwitchId,
                child: _buildContent(context, state),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'profile.title'.tr(),
                      style: AppTextStyles.appTitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'profile.subtitle'.tr(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 32),
                  onPressed: () => context.pushNamed(Routelists.dashboard),
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildSectionCard(
            title: 'profile.general_info'.tr(),
            child: Column(
              children: [
                _buildEditableRow(
                  label: 'profile.first_name'.tr(),
                  controller: _firstNameController,
                  hint: 'profile.enter_first_name'.tr(),
                  isEditing: _isEditingFirstName,
                  focusNode: _firstNameFocusNode,
                  changeLinkText: 'profile.change_first_name'.tr(),
                  onEditTap: () {
                    setState(() => _isEditingFirstName = true);
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _firstNameFocusNode.requestFocus();
                      _firstNameController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _firstNameController.text.length,
                      );
                    });
                  },
                  onSubmitted: () {
                    setState(() => _isEditingFirstName = false);
                    _firstNameFocusNode.unfocus();
                  },
                ),
                const SizedBox(height: 16),
                _buildEditableRow(
                  label: 'profile.last_name'.tr(),
                  controller: _lastNameController,
                  hint: 'profile.enter_last_name'.tr(),
                  isEditing: _isEditingLastName,
                  focusNode: _lastNameFocusNode,
                  changeLinkText: 'profile.change_last_name'.tr(),
                  onEditTap: () {
                    setState(() => _isEditingLastName = true);
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _lastNameFocusNode.requestFocus();
                      _lastNameController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _lastNameController.text.length,
                      );
                    });
                  },
                  onSubmitted: () {
                    setState(() => _isEditingLastName = false);
                    _lastNameFocusNode.unfocus();
                  },
                ),
                const SizedBox(height: 16),
                _buildReadOnlyRow(
                  label: 'profile.email'.tr(),
                  value: _emailController.text,
                ),
                const SizedBox(height: 16),
                _buildEditableRow(
                  label: 'profile.phone_number'.tr(),
                  controller: _phoneController,
                  hint: 'profile.phone_hint'.tr(),
                  isEditing: _isEditingPhone,
                  focusNode: _phoneFocusNode,
                  changeLinkText: 'profile.change_phone_number'.tr(),
                  onEditTap: () {
                    setState(() => _isEditingPhone = true);
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _phoneFocusNode.requestFocus();
                      _phoneController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _phoneController.text.length,
                      );
                    });
                  },
                  onSubmitted: () {
                    setState(() => _isEditingPhone = false);
                    _phoneFocusNode.unfocus();
                  },
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildEditableRow(
                  label: 'profile.position'.tr(),
                  controller: _positionController,
                  hint: 'profile.position_hint'.tr(),
                  isEditing: _isEditingPosition,
                  focusNode: _positionFocusNode,
                  changeLinkText: 'profile.change_position'.tr(),
                  onEditTap: () {
                    setState(() => _isEditingPosition = true);
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _positionFocusNode.requestFocus();
                      _positionController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _positionController.text.length,
                      );
                    });
                  },
                  onSubmitted: () {
                    setState(() => _isEditingPosition = false);
                    _positionFocusNode.unfocus();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionCard(
            title: 'profile.profile_picture'.tr(),
            child: _buildProfilePictureUploadArea(_networkAvatarUrl),
          ),
          const SizedBox(height: 24),

          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              final isUpdating = state is ProfileUpdating;
              final canSave = isButtonEnabled && !isUpdating;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    child: OutlinedButton(
                      onPressed: canSave ? () => _saveSettings(context) : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: canSave
                            ? const Color(0xFF171C23)
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        side: BorderSide(
                          color: canSave
                              ? const Color(0xFF171C23)
                              : Colors.grey,
                          width: 3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: isUpdating
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF171C23),
                              ),
                            )
                          : Text(
                              'profile.update_settings'.tr(),
                              style: AppTextStyles.buttonText.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: canSave
                                    ? const Color(0xFF171C23)
                                    : Colors.grey,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          _buildSectionCard(
            title: 'profile.security'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'profile.change_password'.tr(),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _currentPasswordController,
                  hint: 'profile.current_password'.tr(),
                  obscure: _obscureCurrentPassword,
                  onToggle: () => setState(
                    () => _obscureCurrentPassword = !_obscureCurrentPassword,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _newPasswordController,
                  hint: 'profile.new_password'.tr(),
                  obscure: _obscureNewPassword,
                  onToggle: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  hint: 'profile.confirm_password'.tr(),
                  obscure: _obscureConfirmPassword,
                  onToggle: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                const SizedBox(height: 12),
                BlocBuilder<ChangePasswordBloc, ChangePasswordState>(
                  buildWhen: (prev, curr) =>
                      prev is ChangePasswordLoading ||
                      curr is ChangePasswordLoading ||
                      curr is ChangePasswordSuccess ||
                      curr is ChangePasswordFailure,
                  builder: (context, cpState) {
                    final isChanging =
                        cpState is ChangePasswordLoading;
                    return Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: isChanging ? null : () => _changePassword(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: isChanging
                                ? Colors.grey
                                : const Color(0xFF171C23),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            side: BorderSide(
                              color: isChanging
                                  ? Colors.grey
                                  : const Color(0xFF171C23),
                              width: 3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: isChanging
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF171C23),
                                  ),
                                )
                              : Text(
                                  'profile.change_password'.tr(),
                                  style: AppTextStyles.buttonText.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF171C23),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isEditing,
    required FocusNode focusNode,
    required String changeLinkText,
    required VoidCallback onEditTap,
    required VoidCallback onSubmitted,
    TextInputType? keyboardType,
  }) {
    if (isEditing) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        keyboardType: keyboardType,
        onChanged: (_) => _updateButtonEnabled(),
        decoration: InputDecoration(
          prefixText: label,
          prefixStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.black),
          hintText: controller.text.isEmpty ? hint : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.black),
        onSubmitted: (_) => onSubmitted(),
        onEditingComplete: onSubmitted,
      );
    }
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label${controller.text.isEmpty ? "" : controller.text}',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
          ),
          InkWell(
            onTap: onEditTap,
            child: Text(
              changeLinkText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[700],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow({required String label, required String value}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.zero,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$label${value.isEmpty ? "" : value}',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildProfilePictureUploadArea(String? networkAvatarUrl) {
    return SizedBox(
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
                onTap: _pickAvatar,
                child: Text(
                  'profile.choose_image'.tr(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF0095A5),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              if (_avatarFile != null ||
                  (networkAvatarUrl != null && networkAvatarUrl.isNotEmpty))
                Container(
                  height: 80,
                  width: double.infinity,
                  color: Colors.white,
                  child: _avatarFile != null
                      ? kIsWeb
                            ? Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(_avatarFile!.path),
                                fit: BoxFit.contain,
                              )
                      : networkAvatarUrl != null && networkAvatarUrl.isNotEmpty
                      ? Image.network(
                          networkAvatarUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person,
                                size: 48,
                                color: Colors.grey,
                              ),
                        )
                      : null,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'profile.profile_placeholder'.tr(),
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
      keyboardType: TextInputType.visiblePassword,
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
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
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProfileLoader extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Size screenSize;
  final VoidCallback onLanguageChanged;
  final String effectiveSwitchId;
  final Widget child;

  const _ProfileLoader({
    required this.scaffoldKey,
    required this.screenSize,
    required this.onLanguageChanged,
    required this.effectiveSwitchId,
    required this.child,
  });

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(ProfileRequested());
    });
  }

  Future<void> _handleSwitchSelected(String verseId) async {
    await sl<LocalStorage>().setSelectedVerseId(verseId);
    if (!mounted) return;
    context.goNamed(Routelists.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        key: widget.scaffoldKey,
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
                  activeSection: 'profile',
                  verseId: widget.effectiveSwitchId.isNotEmpty
                      ? widget.effectiveSwitchId
                      : null,
                  onLanguageChanged: widget.onLanguageChanged,
                  onSwitchSelected: _handleSwitchSelected,
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.screenSize.height),
            child: Center(
              child: Container(
                width: widget.screenSize.width,
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
                                onLanguageChanged: widget.onLanguageChanged,
                                containerWidth: widget.screenSize.width > 1200
                                    ? 1200
                                    : widget.screenSize.width,
                                switchId: widget.effectiveSwitchId,
                                onMenuTap: widget.screenSize.width < 800
                                    ? () {
                                        widget.scaffoldKey.currentState
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
                                  final isNarrow =
                                      widget.screenSize.width < 800;
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
                                            activeSection: 'profile',
                                            verseId: widget.effectiveSwitchId
                                                    .isNotEmpty
                                                ? widget.effectiveSwitchId
                                                : null,
                                            onLanguageChanged:
                                                widget.onLanguageChanged,
                                            onSwitchSelected: _handleSwitchSelected,
                                          ),
                                        ),
                                      Expanded(
                                        flex: mainFlex,
                                        child: Container(
                                          color: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: widget.child,
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
                      onLanguageChanged: widget.onLanguageChanged,
                      containerWidth: widget.screenSize.width > 1200
                          ? 1200
                          : widget.screenSize.width,
                    ),
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
