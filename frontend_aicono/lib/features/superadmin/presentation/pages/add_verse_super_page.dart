import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_state.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/components/add_verse_form.dart';
import 'package:frontend_aicono/features/superadmin/presentation/components/verse_list_table.dart';

class AddVerseSuperPage extends StatefulWidget {
  const AddVerseSuperPage({super.key});

  @override
  State<AddVerseSuperPage> createState() => _AddVerseSuperPageState();
}

class _AddVerseSuperPageState extends State<AddVerseSuperPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _handleLanguageChanged() {
    // setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<VerseListBloc>()),
        BlocProvider(create: (context) => sl<VerseCreateBloc>()),
        BlocProvider(create: (context) => sl<DeleteVerseBloc>()),
      ],
      child: BlocListener<VerseCreateBloc, VerseCreateState>(
        listener: (context, state) {
          if (state is VerseCreateSuccess) {
            // Refresh the verse list after successful creation
            context.read<VerseListBloc>().add(LoadAllVersesRequested());
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: Center(
              child: Container(
                width: screenSize.width,
                decoration: BoxDecoration(
                  color: Colors.teal[600],
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
                        constraints: BoxConstraints(
                          minHeight: screenSize.height - 300,
                        ),
                        decoration: BoxDecoration(color: Colors.white),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Page Title
                                  Text(
                                    'superadmin.title'.tr(),
                                    style: AppTextStyles.headlineLarge.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'superadmin.description'.tr(),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Add Verse Form
                                  const AddVerseForm(),

                                  const SizedBox(height: 48),

                                  // Verse List Table
                                  const VerseListTable(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
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
        ),
      ),
    );
  }
}
