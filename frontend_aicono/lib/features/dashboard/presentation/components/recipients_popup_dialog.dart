import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';

/// Popup dialog showing all recipients with search. Shown when user taps
/// the recipients icon in the report detail header.
class RecipientsPopupDialog extends StatefulWidget {
  final List<ReportRecipientEntity> recipients;

  const RecipientsPopupDialog({super.key, required this.recipients});

  /// Shows the recipients popup dialog.
  static void show(BuildContext context, List<ReportRecipientEntity> recipients) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => RecipientsPopupDialog(recipients: recipients),
    );
  }

  @override
  State<RecipientsPopupDialog> createState() => _RecipientsPopupDialogState();
}

class _RecipientsPopupDialogState extends State<RecipientsPopupDialog> {
  late List<ReportRecipientEntity> _filtered;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.recipients);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) {
        _filtered = List.from(widget.recipients);
      } else {
        _filtered = widget.recipients
            .where(
              (r) =>
                  r.recipientName.toLowerCase().contains(q) ||
                  r.recipientEmail.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.recipients.length;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: title, total count, close
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All recipients',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: $total recipient${total == 1 ? '' : 's'}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[500],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: AppTextStyles.bodyMedium,
              ),
            ),
            // Scrollable list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey[300],
                ),
                itemBuilder: (context, index) {
                  final r = _filtered[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.recipientName.isNotEmpty ? r.recipientName : '—',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        if (r.recipientEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.recipientEmail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
