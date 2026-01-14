import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_state.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_bloc.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_state.dart';
import 'package:frontend_aicono/features/superadmin/presentation/components/delete_verse_confirmation_dialog.dart';
import 'package:frontend_aicono/features/superadmin/presentation/components/admin_selection_dialog.dart';

class VerseListTable extends StatefulWidget {
  const VerseListTable({super.key});

  @override
  State<VerseListTable> createState() => _VerseListTableState();
}

class _VerseListTableState extends State<VerseListTable> {
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    // Load verses on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<VerseListBloc>();
        // Only load if bloc is in initial state (avoids unnecessary reloads)
        if (bloc.state is VerseListInitial) {
          bloc.add(LoadAllVersesRequested());
        }
      }
    });
  }

  List<T> _getPaginatedData<T>(List<T> data) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= data.length) return [];
    return data.sublist(
      startIndex,
      endIndex > data.length ? data.length : endIndex,
    );
  }

  int _getTotalPages(int totalItems) {
    return (totalItems / _rowsPerPage).ceil();
  }

  void _showDeleteConfirmation(String verseId, String verseName) {
    DeleteVerseConfirmationDialog.show(
      context,
      verseName: verseName,
      onConfirm: () {
        context.read<DeleteVerseBloc>().add(DeleteVerseRequested(verseId));
      },
    );
  }

  void _showAdminSelectionDialog(
    String verseId,
    String verseName,
    bool isEnabled,
  ) {
    AdminSelectionDialog.show(
      context,
      verseName: verseName,
      verseId: verseId,
      onInvite: (selectedAdminIds) {
        // TODO: Integrate with backend API to send invitations
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('superadmin.invite.invitations_sent'.tr()),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(),
          ),
        );
        // Refresh verse list after invitation
        context.read<VerseListBloc>().add(LoadAllVersesRequested());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to locale changes to rebuild the widget
    final locale = context.locale;

    return MultiBlocListener(
      listeners: [
        BlocListener<DeleteVerseBloc, DeleteVerseState>(
          listener: (context, state) {
            if (state is DeleteVerseSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(),
                ),
              );
              // Refresh the verse list after successful deletion
              context.read<VerseListBloc>().add(LoadAllVersesRequested());
            } else if (state is DeleteVerseFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(),
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<VerseListBloc, VerseListState>(
        key: ValueKey(
          'verse_table_${locale.toString()}',
        ), // Force rebuild on locale change
        builder: (context, state) {
          final allVerses = state is VersesLoaded ? state.verses : [];
          final verses = _getPaginatedData(allVerses);
          final isLoading = state is VerseListLoading;
          final totalPages = _getTotalPages(allVerses.length);

          return Container(
            constraints: BoxConstraints(maxWidth: 1920),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.grey[50]),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'superadmin.registered_verses'.tr(),
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                            ),
                            child: Text(
                              '${allVerses.length} ${allVerses.length == 1 ? 'Switch' : 'Switches'}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize:
                                    MediaQuery.of(context).size.width < 768
                                    ? 11
                                    : 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              context.read<VerseListBloc>().add(
                                LoadAllVersesRequested(),
                              );
                            },
                            tooltip: 'superadmin.refresh'.tr(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Table Content
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (allVerses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'superadmin.no_verses'.tr(),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              Colors.grey[50],
                            ),
                            headingTextStyle: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            dataTextStyle: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.black87,
                            ),
                            columnSpacing:
                                MediaQuery.of(context).size.width < 768
                                ? 12
                                : 24,
                            horizontalMargin:
                                MediaQuery.of(context).size.width < 768
                                ? 8
                                : 20,
                            columns: MediaQuery.of(context).size.width < 768
                                ? [
                                    // Mobile: Show only essential columns
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.number'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.verse_name'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.status'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.actions'.tr(),
                                      ),
                                    ),
                                  ]
                                : [
                                    // Desktop: Show all columns
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.number'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.verse_name'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.subdomain'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.admin_email'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.created'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.status'.tr(),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'superadmin.table.actions'.tr(),
                                      ),
                                    ),
                                  ],
                            rows: verses.asMap().entries.map((entry) {
                              final index =
                                  entry.key + (_currentPage * _rowsPerPage);
                              final verse = entry.value;
                              final createdDate = DateFormat(
                                'yyyy-MM-dd',
                              ).format(verse.createdAt);
                              final isMobile =
                                  MediaQuery.of(context).size.width < 768;

                              return DataRow(
                                cells: isMobile
                                    ? [
                                        // Mobile: Show only essential cells
                                        DataCell(Text('${index + 1}')),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                verse.name,
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              Text(
                                                verse.subdomain ?? 'N/A',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color: Colors.grey[600],
                                                      fontFamily: 'monospace',
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: verse.isSetupComplete
                                                  ? Colors.green[50]
                                                  : Colors.orange[50],
                                            ),
                                            child: Text(
                                              verse.isSetupComplete
                                                  ? 'superadmin.table.active'
                                                        .tr()
                                                  : 'superadmin.table.setup_pending'
                                                        .tr(),
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: verse.isSetupComplete
                                                        ? Colors.green[700]
                                                        : Colors.orange[700],
                                                  ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: ElevatedButton.icon(
                                                  onPressed:
                                                      verse.canCreateBrytesight
                                                      ? null // Disable button when canCreateBrytesight is true
                                                      : () => _showAdminSelectionDialog(
                                                          verse.id,
                                                          verse.name,
                                                          verse
                                                              .canCreateBrytesight,
                                                        ),
                                                  icon: Icon(
                                                    verse.canCreateBrytesight
                                                        ? Icons
                                                              .person_add_disabled_rounded
                                                        : Icons
                                                              .person_add_rounded,
                                                    size: 12,
                                                  ),
                                                  label: Text(
                                                    verse.canCreateBrytesight
                                                        ? 'superadmin.table.disable'
                                                              .tr()
                                                        : 'superadmin.table.enable'
                                                              .tr(),
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 9,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    minimumSize: const Size(
                                                      0,
                                                      32,
                                                    ),
                                                    backgroundColor:
                                                        verse
                                                            .canCreateBrytesight
                                                        ? Colors.grey[100]
                                                        : Colors.teal[50],
                                                    foregroundColor:
                                                        verse
                                                            .canCreateBrytesight
                                                        ? Colors.grey[400]
                                                        : Colors.teal[700],
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 4,
                                                        ),
                                                    shape:
                                                        const RoundedRectangleBorder(),
                                                    side: BorderSide(
                                                      color:
                                                          verse
                                                              .canCreateBrytesight
                                                          ? Colors.grey[300]!
                                                          : Colors.teal[300]!,
                                                      width: 1,
                                                    ),
                                                    disabledBackgroundColor:
                                                        Colors.grey[100],
                                                    disabledForegroundColor:
                                                        Colors.grey[400],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _showDeleteConfirmation(
                                                        verse.id,
                                                        verse.name,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    minimumSize: const Size(
                                                      0,
                                                      32,
                                                    ),
                                                    backgroundColor:
                                                        Colors.white,
                                                    foregroundColor:
                                                        Colors.black,
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                    shape:
                                                        const RoundedRectangleBorder(),
                                                    side: const BorderSide(
                                                      color: Colors.black,
                                                      width: 3,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'superadmin.table.delete'
                                                        .tr(),
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 9,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ]
                                    : [
                                        // Desktop: Show all cells
                                        DataCell(Text('${index + 1}')),
                                        DataCell(
                                          Text(
                                            verse.name,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                            ),
                                            child: Text(
                                              verse.subdomain ?? 'N/A',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    color: Colors.blue[700],
                                                    fontFamily: 'monospace',
                                                  ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(verse.adminEmail)),
                                        DataCell(Text(createdDate)),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: verse.isSetupComplete
                                                  ? Colors.green[50]
                                                  : Colors.orange[50],
                                            ),
                                            child: Text(
                                              verse.isSetupComplete
                                                  ? 'superadmin.table.active'
                                                        .tr()
                                                  : 'superadmin.table.setup_pending'
                                                        .tr(),
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: verse.isSetupComplete
                                                        ? Colors.green[700]
                                                        : Colors.orange[700],
                                                  ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Enable/Disable Button
                                              ElevatedButton.icon(
                                                onPressed:
                                                    verse.canCreateBrytesight
                                                    ? null // Disable button when canCreateBrytesight is true
                                                    : () => _showAdminSelectionDialog(
                                                        verse.id,
                                                        verse.name,
                                                        verse
                                                            .canCreateBrytesight,
                                                      ),
                                                icon: Icon(
                                                  verse.canCreateBrytesight
                                                      ? Icons
                                                            .person_add_disabled_rounded
                                                      : Icons
                                                            .person_add_rounded,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  verse.canCreateBrytesight
                                                      ? 'superadmin.table.disable'
                                                            .tr()
                                                      : 'superadmin.table.enable'
                                                            .tr(),
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  fixedSize: const Size(
                                                    180,
                                                    36,
                                                  ),
                                                  backgroundColor:
                                                      verse.canCreateBrytesight
                                                      ? Colors.grey[100]
                                                      : Colors.teal[50],
                                                  foregroundColor:
                                                      verse.canCreateBrytesight
                                                      ? Colors.grey[400]
                                                      : Colors.teal[700],
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  shape:
                                                      const RoundedRectangleBorder(),
                                                  side: BorderSide(
                                                    color:
                                                        verse
                                                            .canCreateBrytesight
                                                        ? Colors.grey[300]!
                                                        : Colors.teal[300]!,
                                                    width: 1,
                                                  ),
                                                  disabledBackgroundColor:
                                                      Colors.grey[100],
                                                  disabledForegroundColor:
                                                      Colors.grey[400],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Delete Button
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _showDeleteConfirmation(
                                                      verse.id,
                                                      verse.name,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.black,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  shape:
                                                      const RoundedRectangleBorder(),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 3,
                                                  ),
                                                ),
                                                child: Text(
                                                  'superadmin.table.delete'
                                                      .tr(),
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),

                // Pagination Controls
                if (allVerses.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rows per page selector
                        Row(
                          children: [
                            Text(
                              'Rows per page:',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButton<int>(
                                value: _rowsPerPage,
                                underline: const SizedBox(),
                                items: [5, 10, 20, 50]
                                    .map(
                                      (value) => DropdownMenuItem<int>(
                                        value: value,
                                        child: Text('$value'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _rowsPerPage = value;
                                      _currentPage = 0; // Reset to first page
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // Page info and navigation
                        Row(
                          children: [
                            Text(
                              'Page ${_currentPage + 1} of ${totalPages > 0 ? totalPages : 1}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Previous page button
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 0
                                  ? () {
                                      setState(() {
                                        _currentPage--;
                                      });
                                    }
                                  : null,
                              tooltip: 'Previous page',
                              color: Colors.teal[600],
                            ),
                            // Next page button
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _currentPage < totalPages - 1
                                  ? () {
                                      setState(() {
                                        _currentPage++;
                                      });
                                    }
                                  : null,
                              tooltip: 'Next page',
                              color: Colors.teal[600],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
