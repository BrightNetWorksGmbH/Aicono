import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/widgets/primary_outline_button.dart';
import 'package:frontend_aicono/core/widgets/xChackbox.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_room_entity.dart';
import 'package:frontend_aicono/features/switch_creation/presentation/bloc/get_loxone_rooms_bloc.dart';

/// Dialog for selecting a Loxone room to link to a floor plan room.
class LoxoneRoomSelectionDialog extends StatefulWidget {
  final String selectedRoomName;
  final Color roomColor;
  final String buildingId;

  const LoxoneRoomSelectionDialog({
    super.key,
    required this.selectedRoomName,
    required this.roomColor,
    required this.buildingId,
  });

  @override
  State<LoxoneRoomSelectionDialog> createState() =>
      _LoxoneRoomSelectionDialogState();
}

class _LoxoneRoomSelectionDialogState extends State<LoxoneRoomSelectionDialog> {
  String? _selectedSource;
  bool _hasFetched = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<LoxoneRoom> _filterRooms(List<LoxoneRoom> rooms, String query) {
    if (query.isEmpty) {
      return rooms;
    }
    return rooms
        .where((room) => room.name.toLowerCase().contains(query))
        .toList();
  }

  void _handleContinue() {
    if (_selectedSource != null) {
      String roomName = '';
      if (context.read<GetLoxoneRoomsBloc>().state is GetLoxoneRoomsSuccess) {
        final state =
            context.read<GetLoxoneRoomsBloc>().state as GetLoxoneRoomsSuccess;
        if (state.rooms.isNotEmpty) {
          final selectedRoom = state.rooms.firstWhere(
            (room) => room.id == _selectedSource,
            orElse: () => state.rooms.first,
          );
          roomName = selectedRoom.name;
        }
      }
      Navigator.of(context).pop({'id': _selectedSource!, 'name': roomName});
    } else {
      Navigator.of(context).pop();
    }
  }

  void _toggleSource(String source) {
    setState(() {
      _selectedSource = _selectedSource == source ? null : source;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocListener<GetLoxoneRoomsBloc, GetLoxoneRoomsState>(
      listener: (context, state) {
        if (state is GetLoxoneRoomsFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Builder(
        builder: (blocContext) {
          if (!_hasFetched && widget.buildingId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                blocContext.read<GetLoxoneRoomsBloc>().add(
                      GetLoxoneRoomsSubmitted(buildingId: widget.buildingId),
                    );
                _hasFetched = true;
              }
            });
          }

          return BlocBuilder<GetLoxoneRoomsBloc, GetLoxoneRoomsState>(
            builder: (context, state) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: Container(
                  width: screenSize.width < 600
                      ? screenSize.width
                      : screenSize.width < 1200
                          ? screenSize.width * 0.5
                          : screenSize.width * 0.5,
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * 0.9,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Select Loxone Room',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black54, width: 2),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '+ ${widget.selectedRoomName}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: widget.roomColor,
                                  border: Border.all(
                                    color: Colors.black54,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (state is GetLoxoneRoomsSuccess &&
                                    state.rooms.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black54,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      decoration: InputDecoration(
                                        hintText: 'Search...',
                                        hintStyle: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.grey),
                                        border: InputBorder.none,
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.black54,
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: Colors.black54,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _onSearchChanged('');
                                                },
                                              )
                                            : null,
                                      ),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                if (state is GetLoxoneRoomsLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(),
                                  )
                                else if (state is GetLoxoneRoomsSuccess) ...[
                                  if (_filterRooms(
                                    state.rooms,
                                    _searchQuery,
                                  ).isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'No results found',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    ..._filterRooms(
                                      state.rooms,
                                      _searchQuery,
                                    ).map((room) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: _buildCheckboxOption(
                                          room.id,
                                          room.name,
                                        ),
                                      );
                                    }).toList(),
                                ] else if (state is GetLoxoneRoomsFailure)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Error loading rooms: ${state.message}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.red,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No rooms available',
                                      style: AppTextStyles.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Material(
                          color: Colors.transparent,
                          child: PrimaryOutlineButton(
                            label: 'Select',
                            width: 260,
                            onPressed: _handleContinue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCheckboxOption(String key, String label) {
    final isSelected = _selectedSource == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSource(key),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 1),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              XCheckBox(
                value: isSelected,
                onChanged: (value) => _toggleSource(key),
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
