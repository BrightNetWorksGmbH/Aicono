import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/routing/routeLists.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/widget/set_switch_image_widget.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/switch_creation_cubit.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_bloc.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_event.dart';
import 'package:frontend_aicono/features/upload/presentation/bloc/upload_state.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

class SetSwitchImagePage extends StatefulWidget {
  final String? userName;
  final String? organizationName;
  final InvitationEntity? invitation;

  const SetSwitchImagePage({
    super.key,
    this.userName,
    this.organizationName,
    this.invitation,
  });

  @override
  State<SetSwitchImagePage> createState() => _SetSwitchImagePageState();
}

class _SetSwitchImagePageState extends State<SetSwitchImagePage> {
  XFile? _selectedImageFile;
  bool _skipLogo = false;

  @override
  void initState() {
    super.initState();
    // Initialize bloc from invitation if available
    if (widget.invitation != null) {
      final cubit = sl<SwitchCreationCubit>();
      cubit.initializeFromInvitation(
        organizationName: widget.invitation!.organizationName,
        subDomain: widget.invitation!.subDomain,
      );
    }
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _handleImageSelected(XFile? imageFile) {
    setState(() {
      _selectedImageFile = imageFile;
      _skipLogo = false;
    });
    // Don't upload immediately - wait for continue button
  }

  void _handleSkipLogoChanged(bool skip) {
    setState(() {
      _skipLogo = skip;
      if (skip) {
        _selectedImageFile = null;
      }
    });
  }

  void _handleContinue(BuildContext blocContext) {
    // If image is set, upload it first
    if (_selectedImageFile != null && widget.invitation != null) {
      final uploadBloc = blocContext.read<UploadBloc>();
      uploadBloc.add(
        UploadImageEvent(
          _selectedImageFile!,
          widget.invitation!.verseId, // Use verseId as switchId
          'switchlogo', // folderPath
        ),
      );
      // Navigation will happen after upload success in the listener
    } else {
      // No image or skip logo - navigate directly
      _navigateToNextPage();
    }
  }

  void _navigateToNextPage() {
    // Navigate to set switch color page, passing userName, token, and invitation
    context.pushNamed(
      Routelists.setSwitchColor,
      queryParameters: {
        if (widget.userName != null) 'userName': widget.userName!,
        if (widget.invitation != null) 'token': widget.invitation!.token,
      },
      extra: widget.invitation,
    );
  }

  void _handleVerseChange() {
    // TODO: implement verse change functionality
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocProvider(
      create: (context) => sl<UploadBloc>(),
      child: BlocListener<UploadBloc, UploadState>(
        listener: (context, state) {
          if (state is UploadSuccess) {
            // Store the URL in switch creation bloc
            sl<SwitchCreationCubit>().setLogoUrl(state.url);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image uploaded successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              // Navigate to next page after successful upload
              _navigateToNextPage();
            }
          } else if (state is UploadFailure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: BlocBuilder<UploadBloc, UploadState>(
          builder: (context, uploadState) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: screenSize.width,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
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
                        SetSwitchImageWidget(
                          userName: widget.userName,
                          organizationName: widget.organizationName,
                          selectedImageFile: _selectedImageFile,
                          skipLogo: _skipLogo,
                          isUploading: uploadState is UploadLoading,
                          onLanguageChanged: _handleLanguageChanged,
                          onImageSelected: _handleImageSelected,
                          onSkipLogoChanged: _handleSkipLogoChanged,
                          onBack: _handleBack,
                          onContinue: () => _handleContinue(context),
                          onVerseChange: _handleVerseChange,
                        ),
                        AppFooter(
                          onLanguageChanged: _handleLanguageChanged,
                          containerWidth: screenSize.width,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
