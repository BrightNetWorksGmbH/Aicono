import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/app_footer.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/top_part_widget.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';
import 'package:frontend_aicono/core/routing/safe_go_router.dart';

class DataSourceSelectionPage extends StatefulWidget {
  final String? userName;
  final String? buildingAddress;
  final String? buildingName;
  final String? floorPlanUrl;
  final String? selectedRoom;
  final Color? roomColor;
  final String? buildingId;

  const DataSourceSelectionPage({
    super.key,
    this.userName,
    this.buildingAddress,
    this.buildingName,
    this.floorPlanUrl,
    this.selectedRoom,
    this.roomColor,
    this.buildingId,
  });

  @override
  State<DataSourceSelectionPage> createState() =>
      _DataSourceSelectionPageState();
}

class _DataSourceSelectionPageState extends State<DataSourceSelectionPage> {
  String? _selectedSource; // Only one selection allowed
  bool _hasFetched = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleLanguageChanged() {
    setState(() {});
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<dynamic> _filterRooms(List<dynamic> rooms, String query) {
    if (query.isEmpty) {
      return rooms;
    }
    return rooms.where((room) {
      final roomName = room.name?.toString().toLowerCase() ?? '';
      return roomName.contains(query);
    }).toList();
  }

  void _handleContinue() {
    // Pass back the selected loxone room ID when popping
    if (context.canPop() && _selectedSource != null) {
      context.pop(_selectedSource); // Pass the selected loxone_room_id
    } else if (context.canPop()) {
      context.pop();
    }
  }

  void _handleSkip() {
    // Skip to next step - don't assign a room
    if (context.canPop()) {
      context.pop();
    }
  }

  void _toggleSource(String source) {
    setState(() {
      // Only allow one selection at a time (radio button behavior)
      _selectedSource = _selectedSource == source ? null : source;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocProvider(
      create: (_) => sl<GetLoxoneRoomsBloc>(),
      child: BlocListener<GetLoxoneRoomsBloc, GetLoxoneRoomsState>(
        listener: (context, state) {
          if (state is GetLoxoneRoomsFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Builder(
          builder: (blocContext) {
            // Fetch rooms when buildingId is available and we haven't fetched yet
            if (!_hasFetched &&
                widget.buildingId != null &&
                widget.buildingId!.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  blocContext.read<GetLoxoneRoomsBloc>().add(
                    GetLoxoneRoomsSubmitted(buildingId: widget.buildingId!),
                  );
                  _hasFetched = true;
                }
              });
            }

            return BlocBuilder<GetLoxoneRoomsBloc, GetLoxoneRoomsState>(
              builder: (context, state) {
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
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Container(
                                height: (screenSize.height * 0.95) + 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 20),
                                      Material(
                                        color: Colors.transparent,
                                        child: TopHeader(
                                          onLanguageChanged:
                                              _handleLanguageChanged,
                                          containerWidth: screenSize.width > 500
                                              ? 500
                                              : screenSize.width * 0.98,
                                          userInitial: widget.userName?[0]
                                              .toUpperCase(),
                                          verseInitial: null,
                                        ),
                                      ),
                                      if (widget.userName != null) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          'Fast geschafft, ${widget.userName}!',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(color: Colors.black87),
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: 0.9,
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Color(0xFF8B9A5B)),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 50),
                                      Expanded(
                                        child: SizedBox(
                                          width: screenSize.width < 600
                                              ? screenSize.width * 0.95
                                              : screenSize.width < 1200
                                              ? screenSize.width * 0.5
                                              : screenSize.width * 0.6,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Woher kommen die Messdaten im Raum?',
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles
                                                    .headlineSmall
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                              const SizedBox(height: 32),
                                              // Room Input Field
                                              if (widget.selectedRoom != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 18,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black54,
                                                      width: 2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        '+ ${widget.selectedRoom}',
                                                        style: AppTextStyles
                                                            .bodyMedium
                                                            .copyWith(
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                      ),
                                                      const Spacer(),
                                                      Container(
                                                        width: 24,
                                                        height: 24,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              widget
                                                                  .roomColor ??
                                                              const Color(
                                                                0xFFFFEB3B,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Colors.black54,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (widget.selectedRoom != null)
                                                const SizedBox(height: 24),
                                              // Scrollable Data Source Options with fixed height
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    children: [
                                                      // Search Field - only show when rooms are loaded
                                                      if (state
                                                              is GetLoxoneRoomsSuccess &&
                                                          state
                                                              .rooms
                                                              .isNotEmpty)
                                                        Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 16,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                              color: Colors
                                                                  .black54,
                                                              width: 1,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: TextField(
                                                            controller:
                                                                _searchController,
                                                            onChanged:
                                                                _onSearchChanged,
                                                            decoration: InputDecoration(
                                                              hintText:
                                                                  'Suchen...',
                                                              hintStyle: AppTextStyles
                                                                  .bodyMedium
                                                                  .copyWith(
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              prefixIcon:
                                                                  const Icon(
                                                                    Icons
                                                                        .search,
                                                                    color: Colors
                                                                        .black54,
                                                                  ),
                                                              suffixIcon:
                                                                  _searchQuery
                                                                      .isNotEmpty
                                                                  ? IconButton(
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .clear,
                                                                        color: Colors
                                                                            .black54,
                                                                      ),
                                                                      onPressed: () {
                                                                        _searchController
                                                                            .clear();
                                                                        _onSearchChanged(
                                                                          '',
                                                                        );
                                                                      },
                                                                    )
                                                                  : null,
                                                            ),
                                                            style: AppTextStyles
                                                                .bodyMedium
                                                                .copyWith(
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                          ),
                                                        ),
                                                      if (state
                                                          is GetLoxoneRoomsLoading)
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                32.0,
                                                              ),
                                                          child:
                                                              CircularProgressIndicator(),
                                                        )
                                                      else if (state
                                                          is GetLoxoneRoomsSuccess) ...[
                                                        if (_filterRooms(
                                                          state.rooms,
                                                          _searchQuery,
                                                        ).isEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  16.0,
                                                                ),
                                                            child: Text(
                                                              'Keine Ergebnisse gefunden',
                                                              style: AppTextStyles
                                                                  .bodyMedium
                                                                  .copyWith(
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          )
                                                        else
                                                          ..._filterRooms(
                                                            state.rooms,
                                                            _searchQuery,
                                                          ).map((room) {
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    bottom: 16,
                                                                  ),
                                                              child:
                                                                  _buildCheckboxOption(
                                                                    room.id,
                                                                    room.name,
                                                                  ),
                                                            );
                                                          }).toList(),
                                                      ] else if (state
                                                          is GetLoxoneRoomsFailure)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                16.0,
                                                              ),
                                                          child: Text(
                                                            'Fehler beim Laden der Datenquellen: ${state.message}',
                                                            style: AppTextStyles
                                                                .bodyMedium
                                                                .copyWith(
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        )
                                                      else
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                16.0,
                                                              ),
                                                          child: Text(
                                                            'Keine Datenquellen verfügbar',
                                                            style: AppTextStyles
                                                                .bodyMedium,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              // Fixed buttons at the bottom
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _handleSkip,
                                                  child: Text(
                                                    'Schritt überspringen',
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          color: Colors.black87,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Material(
                                                color: Colors.transparent,
                                                child: PrimaryOutlineButton(
                                                  label: 'Das passt so',
                                                  width: 260,
                                                  onPressed: _handleContinue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(String key, String label) {
    final isSelected = _selectedSource == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSource(key),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged:
                    null, // Let InkWell handle the tap to avoid gesture conflict
                activeColor: const Color(0xFF8B9A5B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
