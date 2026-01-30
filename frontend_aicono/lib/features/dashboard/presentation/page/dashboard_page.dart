import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/dynamic_theme_service.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_sidebar.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/dashboard_main_content.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_site_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_building_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_floor_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/dashboard_room_details_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_sites_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_buildings_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/building_reports_bloc.dart';
import 'package:frontend_aicono/features/dashboard/presentation/bloc/report_detail_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';

class DashboardPage extends StatefulWidget {
  final String? verseId;

  const DashboardPage({super.key, this.verseId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? currentVerseId;
  String? selectedReportId;
  late DynamicThemeService _themeService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initialSitesRequestDone = false;

  @override
  void initState() {
    super.initState();
    _themeService = sl<DynamicThemeService>();
    _themeService.addListener(_onThemeChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final authService = sl<AuthService>();
      final localStorage = sl<LocalStorage>();

      // Refresh profile from server to get latest data
      print('Dashboard: Refreshing user profile from server...');
      final profileResult = await authService.refreshProfile();

      await profileResult.fold(
        (failure) async {
          // If profile refresh fails, fall back to cached user data
          print(
            'Dashboard: Profile refresh failed, using cached data: ${failure.message}',
          );
          final loginRepository = sl<LoginRepository>();
          final userResult = await loginRepository.getCurrentUser();

          userResult.fold((failure) {
            // Handle error
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'dashboard.error.failed_to_load_user'.tr(
                      namedArgs: {'error': failure.message},
                    ),
                  ),
                ),
              );
            }
          }, (user) => _processUserData(user, localStorage));
        },
        (user) async {
          // Profile refreshed successfully
          print('Dashboard: Profile refreshed. Verses: ${user.joinedVerse}');
          _processUserData(user, localStorage);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'dashboard.error.loading_dashboard'.tr(
                namedArgs: {'error': '$e'},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processUserData(User? user, LocalStorage localStorage) {
    if (user == null) {
      // No user - should not happen but handle gracefully
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    if (user.joinedVerse.isNotEmpty) {
      // User has verses - proceed normally
      String? initialVerseId;

      // Priority order: passed verseId > saved verseId > first verse
      if (widget.verseId != null && user.joinedVerse.contains(widget.verseId)) {
        // Use the passed verseId if user has access to it
        initialVerseId = widget.verseId;
        print('Dashboard: Using passed verseId: $initialVerseId');
        localStorage.setSelectedVerseId(initialVerseId!);
      } else {
        // Fall back to saved or first verse
        final saved = localStorage.getSelectedVerseId();
        initialVerseId = (saved != null && user.joinedVerse.contains(saved))
            ? saved
            : user.joinedVerse.first;
        print('Dashboard: Using fallback verseId: $initialVerseId');
      }

      setState(() {
        currentVerseId = initialVerseId;
      });
    } else {
      // No joined verses - redirect to login
      print('Dashboard: User has no verses, redirecting...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('dashboard.error.no_verses_available'.tr()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        // Redirect to login after showing message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/login');
          }
        });
      }
      setState(() {
        currentVerseId = null;
      });
    }
  }

  /// Call this when user switches organization. [blocContext] must be a context
  /// that has access to the dashboard blocs (e.g. from a Builder below MultiBlocProvider).
  Future<void> setCurrentVerse(String verseId, BuildContext blocContext) async {
    final localStorage = sl<LocalStorage>();
    await localStorage.setSelectedVerseId(verseId);
    if (mounted) {
      setState(() {
        currentVerseId = verseId;
        selectedReportId = null;
      });
      // Reload dashboard data for the new switch: reset details and request sites again
      blocContext.read<ReportDetailBloc>().add(ReportDetailReset());
      blocContext.read<DashboardSiteDetailsBloc>().add(
        DashboardSiteDetailsReset(),
      );
      blocContext.read<DashboardBuildingDetailsBloc>().add(
        DashboardBuildingDetailsReset(),
      );
      blocContext.read<DashboardFloorDetailsBloc>().add(
        DashboardFloorDetailsReset(),
      );
      blocContext.read<DashboardRoomDetailsBloc>().add(
        DashboardRoomDetailsReset(),
      );
      blocContext.read<DashboardSitesBloc>().add(
        DashboardSitesRequested(bryteswitchId: verseId),
      );
      blocContext.read<ReportSitesBloc>().add(ReportSitesReset());
      blocContext.read<ReportSitesBloc>().add(
        ReportSitesRequested(bryteswitchId: verseId),
      );
    }
  }

  void _handleLanguageChanged() {
    // Force rebuild when language changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<DashboardSitesBloc>()),
        BlocProvider(create: (context) => sl<DashboardSiteDetailsBloc>()),
        BlocProvider(create: (context) => sl<DashboardBuildingDetailsBloc>()),
        BlocProvider(create: (context) => sl<DashboardFloorDetailsBloc>()),
        BlocProvider(create: (context) => sl<DashboardRoomDetailsBloc>()),
        BlocProvider(create: (context) => sl<ReportSitesBloc>()),
        BlocProvider(create: (context) => sl<ReportBuildingsBloc>()),
        BlocProvider(create: (context) => sl<BuildingReportsBloc>()),
        BlocProvider(create: (context) => sl<ReportDetailBloc>()),
      ],
      child: Builder(
        builder: (blocContext) {
          // Request sites for current switch once we have currentVerseId
          if (currentVerseId != null && !_initialSitesRequestDone) {
            _initialSitesRequestDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                blocContext.read<DashboardSitesBloc>().add(
                  DashboardSitesRequested(bryteswitchId: currentVerseId),
                );
              }
            });
          }
          return MultiBlocListener(
            listeners: [
              BlocListener<DashboardSitesBloc, DashboardSitesState>(
                listener: (context, state) {
                  if (state is DashboardSitesSuccess &&
                      state.sites.isNotEmpty) {
                    final detailsState = context
                        .read<DashboardSiteDetailsBloc>()
                        .state;
                    String? selectedSiteId;
                    if (detailsState is DashboardSiteDetailsLoading) {
                      selectedSiteId = detailsState.siteId;
                    } else if (detailsState is DashboardSiteDetailsSuccess) {
                      selectedSiteId = detailsState.siteId;
                    } else if (detailsState is DashboardSiteDetailsFailure) {
                      selectedSiteId = detailsState.siteId;
                    }

                    if (selectedSiteId == null) {
                      context.read<DashboardSiteDetailsBloc>().add(
                        DashboardSiteDetailsRequested(
                          siteId: state.sites.first.id,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
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
                        verseId: currentVerseId,
                        onLanguageChanged: _handleLanguageChanged,
                        onSwitchSelected: (verseId) =>
                            setCurrentVerse(verseId, blocContext),
                        onReportSelected: (reportId) {
                          setState(() => selectedReportId = reportId);
                          if (reportId != null) {
                            blocContext.read<ReportDetailBloc>().add(
                              ReportDetailRequested(reportId),
                            );
                          } else {
                            blocContext.read<ReportDetailBloc>().add(
                              ReportDetailReset(),
                            );
                          }
                        },
                        onPropertySelected: () {
                          setState(() => selectedReportId = null);
                          blocContext.read<ReportDetailBloc>().add(
                            ReportDetailReset(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              backgroundColor: AppTheme.primary,
              body: Center(
                child: Container(
                  width: screenSize.width,
                  color: AppTheme.primary,
                  child: ListView(
                    children: [
                      // White background container - full width
                      Container(
                        margin: const EdgeInsets.all(8),
                        height: screenSize.height,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Builder(
                          builder: (context) {
                            final isNarrow = screenSize.width < 800;
                            final isMobile = screenSize.width < 600;
                            final mainFlex = isNarrow ? 1 : 7;

                            return Column(
                              children: [
                                // Top Header
                                Padding(
                                  padding: const EdgeInsets.only(top: 24.0),
                                  child: TopHeader(
                                    onLanguageChanged: () {
                                      setState(() {});
                                    },
                                    containerWidth: screenSize.width,
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
                                Expanded(
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1920,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Sidebar shown inline on wide screens, hidden on narrow
                                        // Fixed sidebar - scrollable internally if content is long
                                        if (!isNarrow)
                                          SizedBox(
                                            width:
                                                (screenSize.width > 1920
                                                    ? 1920
                                                    : screenSize.width) *
                                                0.25,
                                            child: SingleChildScrollView(
                                              child: DashboardSidebar(
                                                verseId: currentVerseId,
                                                onLanguageChanged:
                                                    _handleLanguageChanged,
                                                onSwitchSelected: (verseId) =>
                                                    setCurrentVerse(
                                                      verseId,
                                                      blocContext,
                                                    ),
                                                onReportSelected: (reportId) {
                                                  setState(
                                                    () => selectedReportId =
                                                        reportId,
                                                  );
                                                  if (reportId != null) {
                                                    blocContext
                                                        .read<
                                                          ReportDetailBloc
                                                        >()
                                                        .add(
                                                          ReportDetailRequested(
                                                            reportId,
                                                          ),
                                                        );
                                                  } else {
                                                    blocContext
                                                        .read<
                                                          ReportDetailBloc
                                                        >()
                                                        .add(
                                                          ReportDetailReset(),
                                                        );
                                                  }
                                                },
                                                onPropertySelected: () {
                                                  setState(
                                                    () =>
                                                        selectedReportId = null,
                                                  );
                                                  blocContext
                                                      .read<ReportDetailBloc>()
                                                      .add(ReportDetailReset());
                                                },
                                              ),
                                            ),
                                          ),

                                        // Main content with improved styling - scrollable
                                        Expanded(
                                          flex: mainFlex,
                                          child: SingleChildScrollView(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isNarrow
                                                    ? (screenSize.width < 800
                                                          ? 8.0
                                                          : 24.0)
                                                    : 0,
                                              ),
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 1920,
                                                    ),
                                                padding: EdgeInsets.all(
                                                  isMobile ? 8 : 16,
                                                ),
                                                child: DashboardMainContent(
                                                  verseId: currentVerseId,
                                                  selectedReportId:
                                                      selectedReportId,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Footer - centered with max width
                      Container(
                        color: AppTheme.primary,
                        constraints: const BoxConstraints(maxWidth: 1920),
                        child: AppFooter(
                          onLanguageChanged: _handleLanguageChanged,
                          containerWidth: screenSize.width > 1920
                              ? 1920
                              : screenSize.width,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
